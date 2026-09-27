extends Area2D

## 底部区域。is_reward 为真时是洞口，进洞回球 + 得分；
## 否则是普通区域，球进去消失、不回球也不扣分。
## 洞口上的 +N 标签会随局间强化实时变化。

@export var is_reward: bool = false
@export var reward_balls: int = 3
@export var score_value: int = 300

var _gm = null
var _label: Label = null
var _sprite: Sprite2D = null
var _shape: CollisionShape2D = null
## 场景里写死的标签原文（如 "+5球 +600分"），刷新时只替换最前面的球数，保留后面的分数说明
var _label_pattern: String = ""
## 场景里写死的原始缩放，"洞口变宽"强化在此基础上放大
var _base_sprite_scale := Vector2.ONE
var _base_shape_scale := Vector2.ONE


func _ready() -> void:
	_gm = get_node_or_null("/root/Main/GameManager")
	if _gm != null:
		_gm.buffs_changed.connect(_refresh_label)
	_label = get_node_or_null("Label") as Label
	if _label != null:
		_label_pattern = _label.text
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _sprite != null:
		_base_sprite_scale = _sprite.scale
	if _shape != null:
		_base_shape_scale = _shape.scale
	body_entered.connect(_on_body_entered)
	_refresh_label()


## 强化变动时刷新洞口标签（这就是"+3 会随词条变化"）与洞口宽度
func _refresh_label() -> void:
	if _gm == null:
		return
	if _label != null and is_reward:
		var pattern := _label_pattern if not _label_pattern.is_empty() else _label.text
		var count := reward_balls + int(_gm.bonus_reward)
		_label.text = "+%d%s" % [count, pattern.substr(_count_prefix_len(pattern))]
	_apply_width()


## 洞口变宽强化：只横向放大贴图与碰撞体，高度不变
func _apply_width() -> void:
	if not is_reward or _gm == null:
		return
	var w := 1.0 + float(_gm.bonus_bucket_width)
	if _sprite != null:
		_sprite.scale = Vector2(_base_sprite_scale.x * w, _base_sprite_scale.y)
	if _shape != null:
		_shape.scale = Vector2(_base_shape_scale.x * w, _base_shape_scale.y)


## 返回开头 "+数字" 的长度，例如 "+12球" 返回 3
func _count_prefix_len(s: String) -> int:
	if s.is_empty() or s[0] != "+":
		return 0
	var i := 1
	while i < s.length() and s[i].is_valid_int():
		i += 1
	return i


func _on_body_entered(body: Node2D) -> void:
	if body.name == "BallTemplate":
		return
	if not body.is_in_group("balls"):
		return

	# 刚发射的球有短暂保护期，避免出生瞬间就被判进洞
	if "spawn_grace" in body and body.spawn_grace > 0.0:
		return

	if is_reward and _gm != null:
		var back: int = reward_balls + int(_gm.bonus_reward)
		var gained: int = int(_gm.on_bucket_enter(score_value))
		_gm.add_balls(back)
		_spawn_float_text("+%d 球   +%d 分" % [back, gained], body.global_position)
		_flash()

	# 普通区域：球安静消失，不再飘 MISS

	body.queue_free()
	if _gm != null:
		_gm.notify_ball_removed()


## 洞口闪一下
func _flash() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	_sprite.modulate = Color(2.2, 2.2, 2.2, 1)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.35)


## 飘字：上浮并淡出
func _spawn_float_text(text: String, pos: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-90, -40)
	lbl.size = Vector2(240, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 36)
	root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -150), 0.9)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lbl.queue_free)
