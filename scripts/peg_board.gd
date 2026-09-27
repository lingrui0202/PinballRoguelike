extends Node2D

## 图钉阵：每局开局随机决定每颗图钉是否存在、是否左右移动、是脆钉还是硬钉。
## 两种图钉：
##   脆钉（默认）——有耐久，被撞一次掉一点，耐久归零就击碎（消失 + 加分）。
##   硬钉（钢钉）——打不碎，撞上去只有分和一下闪光，永远留在台面上。
## 本局把所有脆钉打光会触发一次性"清台"奖励（回球 + 加分），硬钉不计入清台条件。
## 关卡越高，图钉越密、会动的越多、动得越快、硬钉越多。

@export var disable_ratio: float = 0.25
## 会左右移动的图钉比例
@export var moving_ratio: float = 0.25
@export var move_amplitude: float = 55.0
@export var move_speed: float = 0.9

## 每局随机把多大比例的图钉变成打不碎的硬钉（关卡越高越多）
@export var hard_ratio: float = 0.25
## 每关硬钉比例递增，上限 0.6
@export var hard_ratio_max: float = 0.6
@export var hard_ratio_step: float = 0.03
## 写死的硬钉名单：填节点名（如 Peg_r0_c0），这些钉子永远是硬钉，用于固定台面设计。
## 留空则完全由 hard_ratio 随机决定。
@export var hard_peg_names: PackedStringArray = []
## 硬钉的颜色，白盒阶段靠色块区分：冷蓝 = 打不碎
@export var hard_color: Color = Color(0.55, 0.78, 1.0, 0.95)

## 一颗脆钉要撞几次才碎
@export var peg_hp: int = 3
## 击碎一颗图钉的得分（另外还会叠加 GameManager 的"图钉赏金"强化）
@export var break_score: int = 50
## 清台奖励：回多少球、加多少分
@export var clear_bonus_balls: int = 8
@export var clear_bonus_score: int = 800

var _gm = null
var _movers: Array = []
var _time: float = 0.0
## 脆钉 → 剩余耐久
var _hp: Dictionary = {}
## 硬钉集合（打不碎）
var _hard: Dictionary = {}
## 本局脆钉总数 / 剩余数（硬钉不计入清台条件）
var _alive_total: int = 0
var _alive_left: int = 0
var _hard_total: int = 0
var _cleared: bool = false


func _ready() -> void:
	_gm = get_node_or_null("/root/Main/GameManager")
	if _gm != null:
		_gm.round_started.connect(_randomize_board)
	set_process(true)
	_randomize_board()


func _process(delta: float) -> void:
	if _movers.is_empty():
		return
	_time += delta
	for m in _movers:
		if is_instance_valid(m.node):
			m.node.position.x = m.base_x + sin(_time * m.speed + m.phase) * move_amplitude


## 这颗图钉是不是打不碎的硬钉
func is_hard(peg: Node) -> bool:
	return peg != null and _hard.has(peg)


## 球撞到图钉：返回这次撞击是否把图钉打碎了
func hit_peg(peg: Node, is_heavy: bool) -> bool:
	if peg == null or not is_instance_valid(peg):
		return false
	# 硬钉：重球也打不动，只拿分，不掉耐久
	if _hard.has(peg):
		return false
	if not _hp.has(peg):
		return false

	# 重球一击必碎，不用管剩余耐久
	if is_heavy:
		_hp[peg] = 0
	else:
		_hp[peg] = int(_hp[peg]) - 1

	# 受伤但没碎：颜色越打越红
	if _hp[peg] > 0:
		_tint(peg, 1.0 - float(_hp[peg]) / float(maxi(1, peg_hp)))
		return false

	_break_peg(peg)
	return true


func _break_peg(peg: Node) -> void:
	_hp.erase(peg)
	peg.visible = false
	var shape := peg.get_node_or_null("CollisionShape2D")
	if shape != null:
		# 击碎是在球的碰撞回调里触发的，此刻物理服务器正在 flush，
		# 直接改 disabled 会报错，必须延后一帧
		shape.set_deferred("disabled", true)
	# 移出 pegs 组，球就再也撞不到它、也不会重复计分
	if peg.is_in_group("pegs"):
		peg.remove_from_group("pegs")

	_alive_left = maxi(0, _alive_left - 1)
	if _gm != null:
		_gm.add_score(break_score + _gm.bonus_break_score)

	if _alive_left <= 0 and not _cleared:
		_cleared = true
		if _gm != null:
			_gm.add_balls(clear_bonus_balls)
			_gm.add_score(clear_bonus_score)


## 本局初始配色：硬钉冷蓝，脆钉白
func _base_color(peg: Node) -> void:
	var sprite := peg.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	sprite.modulate = hard_color if _hard.has(peg) else Color(1, 1, 1, 0.85)


## 脆钉受伤：越打越红
func _tint(peg: Node, damage: float) -> void:
	var sprite := peg.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var d := clampf(damage, 0.0, 1.0)
	sprite.modulate = Color(1.0, 1.0 - 0.6 * d, 1.0 - 0.75 * d, 0.85)


## 随机决定每颗图钉本局是否存在、是否移动
func _randomize_board() -> void:
	_movers.clear()
	_hp.clear()
	_hard.clear()
	_time = 0.0
	_cleared = false
	_alive_total = 0
	_alive_left = 0
	_hard_total = 0

	var lv := 1
	if _gm != null:
		lv = _gm.level
	# 关卡越高：图钉越密、会动的越多、动得越快、硬钉越多
	var disable := maxf(0.05, disable_ratio - float(lv - 1) * 0.03)
	var moving := minf(0.6, moving_ratio + float(lv - 1) * 0.05)
	var speed := move_speed * (1.0 + float(lv - 1) * 0.2)
	var hard := minf(hard_ratio_max, hard_ratio + float(lv - 1) * hard_ratio_step)

	for peg in get_children():
		if not (peg is StaticBody2D):
			continue

		# 先复位：上一局打碎的图钉这一局重新出现
		peg.visible = true
		var shape := peg.get_node_or_null("CollisionShape2D")
		if shape != null:
			shape.disabled = false
		if not peg.is_in_group("pegs"):
			peg.add_to_group("pegs")

		var enabled := randf() > disable
		peg.visible = enabled
		if shape != null:
			shape.disabled = not enabled
		if not enabled:
			# 本局不存在的图钉必须移出 pegs 组，保证"在组里" == "台面上真的有这颗钉"
			if peg.is_in_group("pegs"):
				peg.remove_from_group("pegs")
			continue

		# 硬钉：写死名单优先，其余按比例随机
		if hard_peg_names.has(peg.name) or randf() < hard:
			_hard[peg] = true
			_hard_total += 1
			_base_color(peg)
		else:
			_hp[peg] = peg_hp
			_alive_total += 1
			_alive_left += 1
			_base_color(peg)

		if randf() < moving:
			_movers.append({
				"node": peg,
				"base_x": peg.position.x,
				"phase": randf() * TAU,
				"speed": speed,
			})


## HUD 属性面板用：本局还剩多少图钉
func get_alive_pegs() -> int:
	return _alive_left


func get_total_pegs() -> int:
	return _alive_total


## HUD 属性面板用：本局硬钉数量
func get_hard_pegs() -> int:
	return _hard_total
