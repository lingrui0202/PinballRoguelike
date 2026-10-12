extends SceneTree

## 生成 3D 预览场景并截图（第 3 周作业：Godot 导入预览）。
##
## 用法（在工程根目录，需要窗口模式，不能 --headless）：
##   godot --path . -s tools/capture_preview.gd
##
## 做两件事：
##   1. 搭一个预览场景（glb 实例 + 相机 + 平行光 + 环境光），存成 res://scenes3d/LauncherPreview.tscn
##   2. 等渲染稳定后把视口截图存成 res://assets3d/preview_godot.png

const GLB_PATH := "res://assets3d/launcher.glb"
const SCENE_PATH := "res://scenes3d/LauncherPreview.tscn"
const SHOT_PATH := "res://assets3d/preview_godot.png"
const WAIT_FRAMES := 30

var frames := 0
var shot_done := false


## 造一个"从 from 看向 target"的 Transform3D，不依赖节点是否已进树
func aim(from: Vector3, target: Vector3) -> Transform3D:
	var dir := target - from
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	return Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), from)


func _initialize() -> void:
	root.size = Vector2i(1200, 1000)

	var preview := Node3D.new()
	preview.name = "LauncherPreview"
	root.add_child(preview)

	# --- 模型 ---
	var glb: PackedScene = load(GLB_PATH)
	if glb == null:
		push_error("找不到 " + GLB_PATH + "，先跑一次 godot --headless --path . --import")
		return
	var model := glb.instantiate()
	model.name = "Launcher"
	preview.add_child(model)

	# --- 环境光 ---
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.90, 0.92, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.88)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	preview.add_child(world_env)

	# --- 主光 + 补光 ---
	# _initialize() 阶段节点还没真正进树，look_at 会报错，
	# 所以用 Transform3D + Basis.looking_at 直接算朝向。
	var target := Vector3(0.0, 0.45, 0.0)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	preview.add_child(key)
	key.global_transform = aim(Vector3(3.0, 5.0, 4.0), target)
	key.light_energy = 1.4

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	preview.add_child(fill)
	fill.global_transform = aim(Vector3(-4.0, 2.0, -3.0), target)
	fill.light_energy = 0.6

	# --- 相机（3/4 视角，比斜视图稍高一点）---
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	preview.add_child(cam)
	cam.global_transform = aim(Vector3(1.45, 1.05, 1.65), target)
	cam.fov = 45.0
	cam.current = true

	# --- 存成场景文件（子节点必须设置 owner，否则存出来是空场景）---
	for child in preview.get_children():
		child.owner = preview
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes3d"))
	var packed := PackedScene.new()
	var err := packed.pack(preview)
	if err != OK:
		push_error("打包预览场景失败：%d" % err)
	err = ResourceSaver.save(packed, SCENE_PATH)
	print("SCENE_SAVED %s err=%d" % [SCENE_PATH, err])


func _process(_delta: float) -> bool:
	frames += 1
	if frames < WAIT_FRAMES:
		return false
	if not shot_done:
		var img := root.get_texture().get_image()
		# 裁成正方形并居中，出图更像"资源预览图"而不是宽屏截图
		var w := img.get_width()
		var h := img.get_height()
		var s := mini(w, h)
		img = img.get_region(Rect2i((w - s) / 2, (h - s) / 2, s, s))
		img.save_png(SHOT_PATH)
		print("SHOT_SAVED %s size=%dx%d" % [SHOT_PATH, img.get_width(), img.get_height()])
		shot_done = true
		return false
	return frames > WAIT_FRAMES + 5
