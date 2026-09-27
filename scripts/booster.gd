extends Area2D

## 加速带：球进入时被朝 boost_direction 推一把，制造路径突变。
## 白盒阶段是一条横着的色块。

@export var boost_direction: Vector2 = Vector2.UP
@export var boost_impulse: float = 520.0
@export var cooldown: float = 0.3

var _cooldown_left: float = 0.0
var _sprite: Sprite2D = null


func _ready() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	body_entered.connect(_on_body_entered)
	set_process(true)


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


func _on_body_entered(body: Node2D) -> void:
	if body.name == "BallTemplate":
		return
	if not body.is_in_group("balls"):
		return
	if _cooldown_left > 0.0:
		return
	if "spawn_grace" in body and body.spawn_grace > 0.0:
		return

	if body is RigidBody2D:
		var d := boost_direction
		if d.length() < 0.01:
			d = Vector2.UP
		# 按质量给冲量，重球和普通球获得的加速度一致
		body.apply_central_impulse(d.normalized() * boost_impulse * body.mass)

	_cooldown_left = cooldown
	_flash()


func _flash() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	_sprite.modulate = Color(1.8, 2.2, 1.8, 1)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
