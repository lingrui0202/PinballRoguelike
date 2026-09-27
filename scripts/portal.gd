extends Area2D

## 传送门：球从这一端进去，从 target 那一端出来，速度保留。
## 两端都会进冷却，避免球在出口被立刻传回去。

@export var target: NodePath
@export var cooldown: float = 0.6
@export var keep_speed: bool = true

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

	var dest := get_node_or_null(target)
	if dest == null:
		return

	var v := Vector2.ZERO
	if body is RigidBody2D:
		v = body.linear_velocity

	# 直接改 RigidBody 的位置要延后一帧，否则会和物理服务器的内部状态打架
	body.set_deferred("global_position", dest.global_position)
	if body is RigidBody2D and keep_speed:
		body.set_deferred("linear_velocity", v)

	_cooldown_left = cooldown
	if dest.has_method("start_cooldown"):
		dest.start_cooldown()
	_flash()


func start_cooldown() -> void:
	_cooldown_left = cooldown


func _flash() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	_sprite.modulate = Color(0.6, 1.6, 2.4, 1)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
