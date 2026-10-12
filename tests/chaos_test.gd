extends SceneTree

## 无脑乱打模拟：验证第 1 关目标分对"零技巧玩法"的区分度（作业2 证据收集）。
##
## 用法（在工程根目录）：
##   godot --headless --path . -s tests/chaos_test.gd -- --seed=20261012
##
## 策略：完全不看落点——每 0.6 秒朝随机方向（-160° ~ -20°）、随机力度（900 ~ 1700）
## 发射一颗普通球，直到本局结算（时间到 / 球打光 / 达到 2 倍目标分自动过关）。
## 输出 CHAOS_RESULT 一行 JSON，其中 success 表示"乱打是否也能过关"。
## 若乱打都能稳定过关，说明目标分没有给"瞄准"留出表达空间。

const FIRE_INTERVAL := 0.6

var seed_value := 20261012
## chaos = 随机方向随机力度（零技巧）；aimed = 固定 -75°、力度 1300（会瞄准的打法）
var mode := "chaos"
## 运行时整体调整洞口回球量（经济 A/B，不改 tscn）：+1 = 恢复旧经济，-1 = 更狠
var reward_delta := 0
var elapsed := 0.0
var fire_timer := 0.0
var started := false
var finished := false
var gm: Node = null
var launcher: Node = null
var result_success: bool = false
var result_score: int = 0
var result_level: int = 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = a.get_slice("=", 1).to_int()
		elif a.begins_with("--mode="):
			mode = a.get_slice("=", 1)
		elif a.begins_with("--reward_delta="):
			reward_delta = a.get_slice("=", 1).to_int()
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
		if gm == null or launcher == null:
			push_error("chaos_test 找不到 GameManager/Launcher")
			return true
		gm.round_result.connect(
			func(success: bool, score: int, level: int) -> void:
				result_success = success
				result_score = score
				result_level = level
		)
		# 经济 A/B：整体平移所有洞口回球量
		if reward_delta != 0:
			for b in root.get_node("Main").get_children():
				# 金环也是 Area2D，要用属性探测过滤
				if b is Area2D and "is_reward" in b and b.is_reward:
					b.reward_balls = maxi(0, b.reward_balls + reward_delta)
		started = true
		fire_timer = 0.2
		return false

	# 结算后等 1.5 秒（让场上球运动完、遥测打印出来），再收尾
	if gm.phase != 0: # Phase.PLAYING == 0
		if _settle_seen == 0.0:
			_settle_seen = elapsed
		elif elapsed - _settle_seen > 1.5:
			finished = true
			_report()
		return false

	# 按模式发射：
	#   chaos = 不看落点随机打；aimed = 固定 -75°、力度 1300；
	#   smart  = 朝场上随机一颗活着的图钉瞄准（模拟"会瞄的玩家"）
	fire_timer -= delta
	if fire_timer <= 0.0 and gm.can_fire():
		fire_timer = FIRE_INTERVAL
		var ang := deg_to_rad(randf_range(-160.0, -20.0))
		var power := randf_range(900.0, 1700.0)
		if mode == "aimed":
			ang = deg_to_rad(-75.0)
			power = 1300.0
		elif mode == "smart":
			var target := _pick_peg()
			if target != null:
				ang = clampf((target - launcher.global_position).angle(), -PI + 0.35, -0.35)
				power = randf_range(1100.0, 1500.0)
		elif mode == "hole":
			# 瞄最高价值的洞口（真人会发现：洞口收益远高于图钉）
			var bucket := _best_bucket()
			if bucket != null:
				ang = clampf((bucket - launcher.global_position).angle(), -PI + 0.35, -0.35)
				power = randf_range(1000.0, 1600.0)
		if gm.consume_fire():
			launcher._spawn_ball(Vector2.from_angle(ang), power, false)
	return false


## 目前场上分值最高的洞口位置
func _best_bucket() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_score := -1
	for b in root.get_node("Main").get_children():
		if b is Area2D and "is_reward" in b and b.is_reward and b.score_value > best_score:
			best_score = b.score_value
			best = b.global_position
	return best


## 随机挑一颗活着的图钉作为瞄准目标
func _pick_peg() -> Vector2:
	var pegs := get_nodes_in_group("pegs")
	var alive: Array = []
	for p in pegs:
		if p.visible and p.global_position.y < 700.0:
			alive.append(p)
	if alive.is_empty():
		return Vector2.ZERO
	var peg: Node2D = alive[randi() % alive.size()]
	return peg.global_position


var _settle_seen := 0.0


func _report() -> void:
	var out := {
		"seed": seed_value,
		"mode": mode,
		"reward_delta": reward_delta,
		"success": result_success,
		"score": result_score,
		"target": gm.target_score,
		"level_after": result_level,
		"shots": gm.telemetry_shots,
		"bucket_hits": gm.telemetry_bucket_hits,
		"dead_drops": gm.telemetry_dead_drops,
		"peg_breaks": gm.telemetry_peg_breaks,
		"max_combo": gm.telemetry_max_combo,
		"balls_left": gm.balls,
		"seconds_used": snappedf(gm.telemetry_elapsed, 0.1),
		"score_10s": gm.telemetry_score_10s,
	}
	print("CHAOS_RESULT " + JSON.stringify(out))
