extends Area2D

## 空中得分区（金环）：球穿过去就得分并涨连击，
## 但球不会消失、也不回球——纯粹是"打准了"的奖励。
## move_amplitude 大于 0 时左右往复移动，关卡越高动得越快。

@export var score_value: int = 60
@export var move_amplitude: float = 90.0
@export var move_speed: float = 0.6

var _gm = null
var _sprite: Sprite2D = null
var _base_x: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _cur_speed: float = 0.6
var _cooldown: float = 0.0


func _ready() -> void:
	_gm = get_node_or_null("/root/Main/GameManager")
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_base_x = position.x
	body_entered.connect(_on_body_entered)
	if _gm != null:
		_gm.round_started.connect(_on_round_started)
	_on_round_started()


func _on_round_started() -> void:
	var lv := 1
	if _gm != null:
		lv = _gm.level
	_cur_speed = move_speed * (1.0 + float(lv - 1) * 0.25)
	_phase = randf() * TAU
	_time = 0.0
	# 即使不移动也要跑 _process，否则 _cooldown 永远不递减、金环只能计一次分
	set_process(true)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if move_amplitude <= 0.0:
		return
	_time += delta
	position.x = _base_x + sin(_time * _cur_speed + _phase) * move_amplitude


func _on_body_entered(body: Node2D) -> void:
	if body.name == "BallTemplate":
		return
	if not body.is_in_group("balls"):
		return
	if "spawn_grace" in body and body.spawn_grace > 0.0:
		return
	if _cooldown > 0.0:
		return

	_cooldown = 0.4
	if _gm != null:
		var gained: int = int(_gm.on_bucket_enter(score_value))
		_spawn_float_text("穿过！+%d 分" % gained, body.global_position)
	_flash()


func _flash() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	_sprite.modulate = Color(2.4, 2.4, 2.4, 1)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.3)


func _spawn_float_text(text: String, pos: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-100, -40)
	lbl.size = Vector2(260, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 34)
	root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -150), 0.9)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lbl.queue_free)
