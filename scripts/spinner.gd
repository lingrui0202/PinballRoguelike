extends AnimatableBody2D

## 旋转挡板：绕自身中心匀速旋转，把撞上来的球甩向随机方向。
## 关卡越高转得越快。白盒阶段就是一根旋转的色条。

@export var rotate_speed_deg: float = 90.0
## 每关转速递增比例
@export var level_speed_step: float = 0.2

var _gm = null
var _cur_speed: float = 90.0


func _ready() -> void:
	_gm = get_node_or_null("/root/Main/GameManager")
	# 让物理服务器看到挡板的运动，否则球不会被"甩"出去，只会被挤开
	sync_to_physics = true
	if _gm != null:
		_gm.round_started.connect(_on_round_started)
	_on_round_started()


func _on_round_started() -> void:
	var lv := 1
	if _gm != null:
		lv = _gm.level
	_cur_speed = rotate_speed_deg * (1.0 + float(lv - 1) * level_speed_step)


func _process(delta: float) -> void:
	rotation += deg_to_rad(_cur_speed) * delta
