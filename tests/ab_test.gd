extends SceneTree

## 无头 A/B 测试：验证"弹珠弹性 bounce"这一个变量对单局成绩的影响。
##
## 用法（在工程根目录）：
##   godot --headless --path . -s tests/ab_test.gd -- --bounce=0.8
##   godot --headless --path . -s tests/ab_test.gd -- --bounce=0.5
##
## 设计要点：
##   - 固定随机种子（seed(20261012)），两次运行台面布局、图钉脆硬完全一致；
##   - 只改 BallTemplate 物理材质的 bounce，其余一律不动（单变量原则）；
##   - 不依赖鼠标：直接调用 Launcher._spawn_ball，固定朝 -75°、力度 1300 发射；
##   - 每 0.5 秒发 1 颗、共 40 颗，正常走 consume_fire 扣库存、进洞回球；
##   - 发射完等场上球清空（上限再等 40 秒），最后打印一行 AB_RESULT JSON。
##
## 输出字段：
##   fired        实际发射数（应为 40）
##   final_score  最终得分
##   balls_left   剩余库存（发射 40 次 + 进洞回球的净结果）
##   pegs_left    本局剩余脆钉数（打碎越多说明球在台面上活跃越久）
##   score_5s     每 5 秒的分数快照（看得分节奏）
##   wall_time    测试耗时

const FIRE_COUNT := 40
const FIRE_INTERVAL := 0.5
const POWER := 1300.0
const AIM_DEG := -75.0
const WAIT_AFTER_FIRE := 40.0

var bounce_value := 0.8
var seed_value := 20261012
var fired := 0
var fire_timer := 0.0
var elapsed := 0.0
var wait_after_fire := 0.0
var started := false
var finished := false
var gm: Node = null
var launcher: Node = null
var board: Node = null
var score_5s := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bounce="):
			bounce_value = a.get_slice("=", 1).to_float()
		elif a.begins_with("--seed="):
			seed_value = a.get_slice("=", 1).to_int()
	seed(seed_value)
	root.add_child(load("res://scenes/Main.tscn").instantiate())


func _process(delta: float) -> bool:
	if finished:
		return true
	elapsed += delta

	if not started:
		if elapsed < 0.5:
			return false
		gm = root.get_node_or_null("Main/GameManager")
		launcher = root.get_node_or_null("Main/Launcher")
		board = root.get_node_or_null("Main/PegBoard")
		if gm == null or launcher == null or board == null:
			push_error("A/B 测试找不到 Main/GameManager|Launcher|PegBoard")
			return true
		var tmpl: RigidBody2D = root.get_node_or_null("Main/BallTemplate")
		if tmpl == null or tmpl.physics_material_override == null:
			push_error("BallTemplate 或其 physics_material_override 缺失")
			return true
		# 只改运行时内存里的副本，不会写回 Main.tscn
		tmpl.physics_material_override.bounce = bounce_value
		started = true
		fire_timer = 0.2
		return false

	# 每 5 秒记一次分数快照
	var mark := str(int(elapsed / 5.0) * 5)
	if not score_5s.has(mark):
		score_5s[mark] = gm.score

	if fired < FIRE_COUNT:
		fire_timer -= delta
		if fire_timer <= 0.0 and gm.can_fire():
			fire_timer = FIRE_INTERVAL
			if gm.consume_fire():
				var dir := Vector2.from_angle(deg_to_rad(AIM_DEG))
				launcher._spawn_ball(dir, POWER, false)
				fired += 1
		return false

	# 全部发射完：等场上球清空或超时
	wait_after_fire += delta
	var remaining := get_nodes_in_group("balls").size()
	if remaining == 0 or wait_after_fire > WAIT_AFTER_FIRE or elapsed > 145.0:
		finished = true
		_report()
	return false


func _report() -> void:
	var out := {
		"bounce": bounce_value,
		"fired": fired,
		"final_score": gm.score,
		"balls_left": gm.balls,
		"pegs_left": board.get_alive_pegs(),
		"pegs_total": board.get_total_pegs(),
		"score_5s": score_5s,
		"wall_time": snappedf(elapsed, 0.1),
	}
	print("AB_RESULT " + JSON.stringify(out))
