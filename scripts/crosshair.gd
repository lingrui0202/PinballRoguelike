extends Node2D

## 游戏内鼠标光标（准星）。
## 系统箭头在游戏窗口里容易看不清（深色背景糊在一起），
## 这里在最上层再画一个十字准星，瞄准时始终能看到"指到哪"。
## 挂在 CanvasLayer 下，不会被弹珠 / 洞口 / HUD 盖住。
##
## 位置用 get_local_mouse_position()：和发射器瞄准用的是同一套引擎坐标，
## 所以准星永远等于"球真正会飞出去的方向"。
## 注意：如果开了任务栏自动隐藏，Godot 拿到的窗口几何可能是过期的，
## 引擎坐标会和屏幕箭头差一截（按一次 Win 让任务栏弹出就会刷新对齐）。
##
## F1 可以开关准星。

@export var arm: float = 14.0
@export var line_width: float = 2.0
@export var dot_radius: float = 2.0
@export var inner_color: Color = Color(1.0, 0.97, 0.82, 0.95)
@export var outline_color: Color = Color(0.03, 0.04, 0.09, 0.9)


func _ready() -> void:
	# 结算 / 强化面板会暂停游戏树，但光标要一直能看见，否则没法点按钮
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	queue_redraw()


## F1 切换准星显示
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()


## 画布本地坐标 → 屏幕像素的缩放（窗口缩放 + DPI）
func _canvas_scale() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ONE
	return (vp.get_final_transform() * get_global_transform_with_canvas()).get_scale()


func _draw() -> void:
	var p := get_local_mouse_position()
	var s := _canvas_scale()
	# k：把 1 屏幕像素换算成画布单位，保证窗口缩放时准星大小恒定
	var k := 1.0 / maxf(0.001, (absf(s.x) + absf(s.y)) * 0.5)
	var r := arm * k
	var w := line_width * k
	var pad := (line_width + 2.0) * k

	# 先描深色边再画亮色：深色背景和亮色弹珠上都看得清
	draw_line(p + Vector2(-r - pad, 0.0), p + Vector2(r + pad, 0.0), outline_color, w + 2.0 * k)
	draw_line(p + Vector2(0.0, -r - pad), p + Vector2(0.0, r + pad), outline_color, w + 2.0 * k)
	draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), inner_color, w)
	draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), inner_color, w)
	draw_arc(p, 6.0 * k, 0.0, TAU, 28, inner_color, w, true)
	# 正中实心点：一眼看出"准星中心 = 鼠标位置"
	draw_circle(p, dot_radius * k, inner_color)
