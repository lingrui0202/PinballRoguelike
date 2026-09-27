extends Node

## 游戏状态。球数与分数是两件完全不同的事：
##   球数 = 资源，发射消耗、进洞回球，归零就出局；
##   分数 = 成绩，击中图钉和进洞得分，达到本关目标才算过关。
## 每过一关，目标分数提高、时间缩短，难度递增。

signal balls_changed(value: int)
signal score_changed(value: int)
signal combo_changed(value: int)
signal level_changed(value: int)
signal time_changed(value: float)
signal phase_changed(phase_name: String)
signal round_result(success: bool, score: int, level: int)
signal round_started()
signal buffs_changed()

enum Phase { PLAYING, SETTLED }

## 强化种类总数。HUD 抽三选一时按这个数建池，新增强化记得 +1
const BUFF_COUNT := 15

@export var start_balls: int = 50
@export var fire_cost: int = 1
@export var auto_settle_delay: float = 3.0

## 难度曲线
## 数值依据：2026-09-27 实测，无脑连发 90 发约 6 万分；目标分定在"中等水平打满一局能过"的位置
@export var base_target_score: int = 24000
@export var target_score_step: int = 5000
@export var base_round_seconds: float = 90.0
@export var round_seconds_step: float = 5.0
@export var min_round_seconds: float = 45.0

## 分数达到目标的这个倍数时，立刻自动过关
@export var auto_advance_multiplier: float = 2.0

## 计分
@export var peg_score: int = 10
@export var combo_step: float = 0.15
@export var combo_max: float = 3.0
@export var combo_window: float = 3.5

## 十五种局间强化的步长（编号含义见 apply_buff 上方的注释）
@export var buff_impulse_step: float = 100.0
@export var buff_charge_step: float = 0.12
@export var buff_reward_step: int = 1
@export var buff_balls_step: int = 5
@export var buff_peg_step: int = 5
@export var buff_combo_max_step: float = 0.5
@export var buff_combo_window_step: float = 1.5
@export var buff_time_step: float = 10.0
@export var buff_jitter_step: float = 0.7
@export var buff_score_step: float = 0.2
## 10 巨球：每级球半径放大的比例
@export var buff_ball_scale_step: float = 0.12
## 11 分裂发射：每级额外多射出几颗球（不额外消耗库存）
@export var buff_split_step: int = 1
## 12 洞口变宽：每级洞口宽度放大的比例
@export var buff_bucket_width_step: float = 0.15
## 13 进洞延时：每次进洞额外加多少秒
@export var buff_time_on_bucket_step: float = 0.3
## 14 图钉赏金：击碎一颗图钉额外加多少分
@export var buff_break_score_step: int = 25

var phase: Phase = Phase.PLAYING
var level: int = 1
## 已解锁的最高关卡（过关后解锁下一关）
var max_unlocked_level: int = 1
var balls: int = 50
var score: int = 0
var target_score: int = 3000
var time_left: float = 90.0
var combo: int = 0
var combo_timer: float = 0.0

# 局间强化累积
var bonus_impulse: float = 0.0
var bonus_charge_time: float = 0.0
var bonus_reward: int = 0
var bonus_start_balls: int = 0
var bonus_peg_score: int = 0
var bonus_combo_max: float = 0.0
var bonus_combo_window: float = 0.0
var bonus_time: float = 0.0
var bonus_jitter_mult: float = 1.0
var bonus_score_mult: float = 1.0
var bonus_ball_scale: float = 0.0
var bonus_split: int = 0
var bonus_bucket_width: float = 0.0
var bonus_time_on_bucket: float = 0.0
var bonus_break_score: int = 0

var _auto_settle_timer: float = -1.0


func _ready() -> void:
	start_round()


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return

	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		time_changed.emit(time_left)
		settle()
		return
	time_changed.emit(time_left)

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(combo)

	if _auto_settle_timer > 0.0:
		_auto_settle_timer -= delta
		if _auto_settle_timer <= 0.0:
			_auto_settle_timer = -1.0
			settle()


func _apply_level_difficulty() -> void:
	target_score = base_target_score + (level - 1) * target_score_step
	time_left = maxf(min_round_seconds, base_round_seconds - float(level - 1) * round_seconds_step + bonus_time)


func start_round() -> void:
	balls = start_balls + bonus_start_balls
	score = 0
	combo = 0
	combo_timer = 0.0
	phase = Phase.PLAYING
	_auto_settle_timer = -1.0
	_apply_level_difficulty()
	balls_changed.emit(balls)
	score_changed.emit(score)
	combo_changed.emit(combo)
	time_changed.emit(time_left)
	level_changed.emit(level)
	phase_changed.emit("PLAYING")
	round_started.emit()


## 直接跳到某个已解锁的关卡
func jump_to_level(n: int) -> void:
	level = clampi(n, 1, max_unlocked_level)
	start_round()


func can_fire() -> bool:
	return phase == Phase.PLAYING and balls >= fire_cost


func consume_fire() -> bool:
	if not can_fire():
		return false
	balls -= fire_cost
	balls_changed.emit(balls)
	return true


func add_balls(amount: int) -> void:
	balls += amount
	balls_changed.emit(balls)


## 分数的统一入口：任何加分都必须走这里，保证 HUD 与提前过关判定同步
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	_check_auto_advance()


## mult 是倍率，重球撞钉按双倍算
func on_peg_hit(mult: int = 1) -> void:
	add_score((peg_score + bonus_peg_score) * maxi(1, mult))


func on_bucket_enter(base_score: int) -> int:
	combo += 1
	combo_timer = combo_window + bonus_combo_window
	combo_changed.emit(combo)
	if bonus_time_on_bucket > 0.0:
		time_left += bonus_time_on_bucket
		time_changed.emit(time_left)
	var gained: int = int(float(base_score) * get_combo_multiplier() * bonus_score_mult)
	add_score(gained)
	return gained


func get_combo_multiplier() -> float:
	return minf(1.0 + float(combo) * combo_step, combo_max + bonus_combo_max)


func _check_auto_advance() -> void:
	if phase != Phase.PLAYING:
		return
	if score >= int(float(target_score) * auto_advance_multiplier):
		settle()


func settle() -> void:
	if phase == Phase.SETTLED:
		return
	phase = Phase.SETTLED
	_auto_settle_timer = -1.0
	var success := score >= target_score
	if success:
		level += 1
		max_unlocked_level = maxi(max_unlocked_level, level)
		level_changed.emit(level)
	phase_changed.emit("SETTLED")
	round_result.emit(success, score, level)


func notify_ball_removed() -> void:
	call_deferred("_check_auto_settle")


func _check_auto_settle() -> void:
	if phase != Phase.PLAYING:
		return
	if balls >= fire_cost:
		_auto_settle_timer = -1.0
		return
	var remaining := get_tree().get_nodes_in_group("balls").size()
	if remaining == 0 and _auto_settle_timer < 0.0:
		_auto_settle_timer = auto_settle_delay


func get_buff_count() -> int:
	return BUFF_COUNT


## 十五种局间强化，每次结算随机抽三种
## 0 弹射力 / 1 蓄力速度 / 2 洞里回球 / 3 起始球数 / 4 图钉分
## 5 连击上限 / 6 连击窗口 / 7 每关时间 / 8 瞄准精度 / 9 洞口分值
## 10 巨球 / 11 分裂发射 / 12 洞口变宽 / 13 进洞延时 / 14 图钉赏金
func apply_buff(index: int) -> void:
	match index:
		0:
			bonus_impulse += buff_impulse_step
		1:
			bonus_charge_time = maxf(-0.6, bonus_charge_time - buff_charge_step)
		2:
			bonus_reward += buff_reward_step
		3:
			bonus_start_balls += buff_balls_step
		4:
			bonus_peg_score += buff_peg_step
		5:
			bonus_combo_max += buff_combo_max_step
		6:
			bonus_combo_window += buff_combo_window_step
		7:
			bonus_time += buff_time_step
		8:
			bonus_jitter_mult = maxf(0.2, bonus_jitter_mult * buff_jitter_step)
		9:
			bonus_score_mult += buff_score_step
		10:
			bonus_ball_scale += buff_ball_scale_step
		11:
			bonus_split += buff_split_step
		12:
			bonus_bucket_width += buff_bucket_width_step
		13:
			bonus_time_on_bucket += buff_time_on_bucket_step
		14:
			bonus_break_score += buff_break_score_step
		_:
			pass
	buffs_changed.emit()


## 关卡描述（HUD 显示，让玩家知道这一关变在哪）
func get_level_desc(lv: int) -> String:
	match lv:
		1:
			return "新手台面"
		2:
			return "图钉变密"
		3:
			return "图钉开始移动"
		4:
			return "移动更快"
		5:
			return "高速台面"
		_:
			return "极限台面"
