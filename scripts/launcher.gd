extends Node2D

## 发射器：鼠标控制方向，按住左键蓄力，松开射出一颗球。
## 鼠标停在 HUD 控件上时不响应输入（避免点按钮误发射）。
## 蓄力拉满会射出重球：一击击碎图钉、图钉分双倍，代价是弹得更沉。

@export var ball_template: NodePath
@export var cleanup_y: float = 1150.0

## 蓄力
@export var charge_time: float = 1.0
## 力度下限按重力反推：900 约能上升 413px，必定进入图钉区；
## 上限 1700 约能上升 1474px，可以打满全场撞到天花板。
@export var min_impulse: float = 900.0
@export var max_impulse: float = 1700.0
@export var base_jitter_deg: float = 6.0

## 横移
@export var move_speed: float = 700.0
@export var min_x: float = 300.0
@export var max_x: float = 1700.0

## 瞄准线
@export var aim_length: float = 200.0

## 蓄力到这个比例就发射重球（一击击碎图钉、图钉分双倍）
@export var heavy_charge_threshold: float = 0.99
## 分裂发射时，额外球相对主球的角度偏移
@export var split_angle_deg: float = 10.0

var _charging: bool = false
var _charge: float = 0.0
var _spawned: Array = []
var _gm = null
var _aim: Line2D = null


func _ready() -> void:
	_gm = get_node_or_null("/root/Main/GameManager")
	_aim = get_node_or_null("AimLine") as Line2D
	if _gm == null:
		push_error("Launcher 找不到 GameManager 节点（应为 /root/Main/GameManager）")


func _process(delta: float) -> void:
	if _charging:
		var t := maxf(0.15, charge_time + float(_gm.bonus_charge_time)) if _gm != null else charge_time
		_charge = minf(1.0, _charge + delta / t)
	_update_aim()
	_cleanup()


## 瞄准方向：发射器指向鼠标，限制在朝上的扇形内。
## 下限抬到 20°，避免球几乎水平出生、当场掉进底部判定区。
func _aim_direction() -> Vector2:
	var raw := get_global_mouse_position() - global_position
	if raw.length() < 1.0:
		return Vector2.UP
	var angle := raw.normalized().angle()
	# 屏幕 y 向下：正上方是 -PI/2。限制在 -160° ~ -20°
	angle = clampf(angle, -PI + 0.35, -0.35)
	return Vector2.from_angle(angle)


func _update_aim() -> void:
	if _aim == null:
		return
	var d := _aim_direction()
	var length := aim_length * (0.45 + 0.55 * _charge)
	_aim.points = PackedVector2Array([Vector2.ZERO, d * length])


## 鼠标是否停在 HUD 这类 UI 控件上。
## 用 gui_get_hovered_control 判断，Button 默认 mouse_filter 为 STOP，会被正确识别。
func _is_pointer_over_ui() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.gui_get_hovered_control() != null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 鼠标停在 HUD 上时完全不响应：否则点"结算""强化""选关"会顺带打出去一颗球
		if _is_pointer_over_ui():
			return
		if event.pressed:
			if _gm != null and _gm.can_fire():
				_charging = true
				_charge = 0.0
		elif _charging:
			_charging = false
			_fire_one(_charge)
			_charge = 0.0


func _fire_one(charge: float) -> void:
	if _gm == null or not _gm.can_fire():
		return

	if ball_template.is_empty():
		push_error("BallTemplate 没设置！请在 Inspector 里把 BallTemplate 拖进 Ball Template 字段")
		return

	var template := get_node_or_null(ball_template)
	if template == null:
		push_error("BallTemplate 路径无效，检查 Inspector 里的 Ball Template 字段")
		return

	if not _gm.consume_fire():
		return

	var c := clampf(charge, 0.0, 1.0)
	var heavy := c >= heavy_charge_threshold
	var dir := _aim_direction_with_jitter(c)
	var power := min_impulse + (max_impulse - min_impulse) * c + float(_gm.bonus_impulse)

	_spawn_ball(dir, power, heavy)

	# 分裂发射：额外多射几颗，不额外消耗库存（每发仍然只扣 1 颗球）
	var split := int(_gm.bonus_split)
	for i in range(split):
		var side := 1.0 if i % 2 == 0 else -1.0
		var step := float(i / 2 + 1) * deg_to_rad(split_angle_deg) * side
		_spawn_ball(dir.rotated(step), power, heavy)


## 蓄力越满越准；局间强化会进一步收窄抖动
func _aim_direction_with_jitter(charge: float) -> Vector2:
	var jitter_mult := float(_gm.bonus_jitter_mult)
	var jitter_deg := base_jitter_deg * jitter_mult * (1.0 - 0.7 * clampf(charge, 0.0, 1.0))
	var jitter := deg_to_rad(randf_range(-jitter_deg, jitter_deg))
	return _aim_direction().rotated(jitter)


## 复制模板生成一颗球并推出去。球只能由 BallTemplate 复制产生。
func _spawn_ball(dir: Vector2, power: float, heavy: bool) -> void:
	var template := get_node_or_null(ball_template)
	var ball := template.duplicate() as RigidBody2D
	ball.name = "Ball"
	ball.visible = true
	ball.freeze = false
	ball.is_heavy = heavy
	# 沿瞄准方向偏出一点出生，避免和发射器自身重叠
	ball.global_position = global_position + dir * 34.0
	ball.add_to_group("balls")
	template.get_parent().add_child(ball)

	# add_child 之后 _ready 才把重球质量乘上去，这里按最终质量给冲量，保证初速一致
	ball.apply_central_impulse(dir * power * ball.mass)
	_spawned.append(ball)


func _cleanup() -> void:
	var alive: Array = []
	for b in _spawned:
		if is_instance_valid(b):
			if b.global_position.y > cleanup_y:
				b.queue_free()
				if _gm != null:
					_gm.notify_ball_removed()
			else:
				alive.append(b)
	_spawned = alive
