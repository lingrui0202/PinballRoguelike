extends RigidBody2D

## 弹珠：撞到图钉时给玩家加分、给图钉掉耐久，耐久归零就击碎它。
## 挂在 BallTemplate 上，复制出来的球会继承本脚本。
## is_heavy 为重球（蓄力满发射）：撞钉一击必碎且双倍图钉分，质量更大、颜色更沉。

## 每颗球在本次飞行中最多计多少次图钉分，避免在同一点反复刷分
@export var max_peg_hits: int = 12
## 存活上限（秒）：球卡住不动时强制清掉，避免场上永远有球导致无法结算
@export var life_time: float = 15.0
## 重球的质量倍数
@export var heavy_mass_scale: float = 2.5

## 出生后的保护时间（秒）：这段时间不会被底部区域判定，
## 避免低角度发射时球一出生就落在判定区内被吃掉。
var spawn_grace: float = 0.35
## 蓄力满发射的重球
var is_heavy: bool = false

var _gm = null
var _board = null
var _hit_count: int = 0
var _hit_cooldown: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	# 模板球不参与计分
	if name == "BallTemplate":
		return

	_gm = get_node_or_null("/root/Main/GameManager")
	_board = get_node_or_null("/root/Main/PegBoard")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# 巨球强化：整体放大（碰撞体跟着一起放大）
	if _gm != null:
		var s := 1.0 + float(_gm.bonus_ball_scale)
		scale = Vector2(s, s)

	if is_heavy:
		mass *= heavy_mass_scale
		var sprite := get_node_or_null("Sprite2D")
		if sprite != null:
			sprite.modulate = Color(1.0, 0.55, 0.25, 1.0)


func _process(delta: float) -> void:
	if name == "BallTemplate":
		return

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if spawn_grace > 0.0:
		spawn_grace -= delta

	_age += delta
	if _age > life_time:
		_despawn()


func _on_body_entered(body: Node) -> void:
	if name == "BallTemplate":
		return
	if _hit_cooldown > 0.0 or _hit_count >= max_peg_hits:
		return
	if not body.is_in_group("pegs"):
		return

	_hit_cooldown = 0.06

	# 耐久一定要掉：能不能打碎不能取决于这颗球还剩多少计分额度，
	# 否则会出现"明明打中了却永远打不碎"的图钉
	var broke := false
	if _board != null:
		broke = _board.hit_peg(body, is_heavy)

	# 只有计分受上限约束，避免一颗球在同一片图钉里无限刷分
	if _gm != null and _hit_count < max_peg_hits:
		_hit_count += 1
		_gm.on_peg_hit(2 if is_heavy else 1)

	if broke:
		return

	# 图钉没碎时闪一下表示打中：硬钉闪青（提示"这颗打不动"），脆钉闪黄
	# 用 as Sprite2D 显式定型，modulate 才是已知的 Color 类型
	var sprite := body.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		var rest := sprite.modulate
		var hit_color := Color(0.6, 1.0, 1.3, 1.0) if (_board != null and _board.is_hard(body)) else Color(1, 0.95, 0.4, 1)
		var tw := create_tween()
		sprite.modulate = hit_color
		# 回到打之前的状态：脆钉保留受伤的红色，硬钉保留冷蓝
		tw.tween_property(sprite, "modulate", rest, 0.25)


func _despawn() -> void:
	if _gm != null:
		_gm.notify_ball_removed()
	queue_free()
