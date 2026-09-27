extends CanvasLayer

## HUD：关卡 / 时间 / 球数 / 分数 / 连击 / 蓄力条 / 结算 / 局间三选一。
## 按 Tab 打开属性面板：查看当前累积强化，并可直接跳到已解锁的关卡。

@onready var level_label: Label = $LevelLabel
@onready var time_label: Label = $TimeLabel
@onready var balls_label: Label = $BallsLabel
@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var charge_bar: ProgressBar = $ChargeBar
@onready var settle_button: Button = $SettleButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var buff_button_1: Button = $ResultPanel/BuffButton1
@onready var buff_button_2: Button = $ResultPanel/BuffButton2
@onready var buff_button_3: Button = $ResultPanel/BuffButton3
@onready var retry_button: Button = $ResultPanel/RetryButton
@onready var stats_panel: Panel = $StatsPanel
@onready var stats_label: Label = $StatsPanel/StatsLabel
@onready var level_scroll: ScrollContainer = $StatsPanel/LevelScroll
# 关卡按钮容器在运行时创建，避免 tscn 里给 ScrollContainer 定义子节点出问题
var level_list: HBoxContainer = null

var _gm = null
var _launcher = null
var _buff_ids: Array = [0, 1, 2]


func _ready() -> void:
	_gm = get_node_or_null("/root/Main/GameManager")
	_launcher = get_node_or_null("/root/Main/Launcher")
	if _gm == null:
		push_error("HUD 找不到 GameManager 节点（应为 /root/Main/GameManager）")
		return

	# 关卡列表容器运行时挂到滚动容器里
	if level_scroll != null and level_list == null:
		level_list = HBoxContainer.new()
		level_list.name = "LevelList"
		level_scroll.add_child(level_list)

	result_panel.visible = false
	stats_panel.visible = false
	charge_bar.visible = false
	_gm.balls_changed.connect(_on_balls_changed)
	_gm.score_changed.connect(_on_score_changed)
	_gm.combo_changed.connect(_on_combo_changed)
	_gm.level_changed.connect(_on_level_changed)
	_gm.time_changed.connect(_on_time_changed)
	_gm.round_result.connect(_on_round_result)
	settle_button.pressed.connect(_on_settle_pressed)
	buff_button_1.pressed.connect(_on_buff_selected.bind(0))
	buff_button_2.pressed.connect(_on_buff_selected.bind(1))
	buff_button_3.pressed.connect(_on_buff_selected.bind(2))
	retry_button.pressed.connect(_on_retry_pressed)

	_on_balls_changed(_gm.balls)
	_on_score_changed(_gm.score)
	_on_combo_changed(_gm.combo)
	_on_level_changed(_gm.level)
	_on_time_changed(_gm.time_left)


func _process(_delta: float) -> void:
	if _launcher != null and charge_bar != null:
		charge_bar.visible = _launcher._charging
		charge_bar.value = _launcher._charge * 100.0


func _input(event: InputEvent) -> void:
	# Tab 打开 / 关闭属性面板
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			stats_panel.visible = not stats_panel.visible
			if stats_panel.visible:
				_refresh_stats()
			get_viewport().set_input_as_handled()


func _refresh_stats() -> void:
	if _gm == null:
		return
	stats_label.text = _stats_text()
	_refresh_level_buttons()


func _stats_text() -> String:
	var lines := [
		"当前属性（累积强化）",
		"弹射力      +%.0f" % _gm.bonus_impulse,
		"蓄力速度    %+.2fs" % _gm.bonus_charge_time,
		"洞里回球    +%d" % _gm.bonus_reward,
		"起始球数    +%d" % _gm.bonus_start_balls,
		"图钉分      +%d" % _gm.bonus_peg_score,
		"连击上限    +%.1f" % _gm.bonus_combo_max,
		"连击窗口    %+.1fs" % _gm.bonus_combo_window,
		"每关时间    +%.0fs" % _gm.bonus_time,
		"瞄准抖动    x%.2f" % _gm.bonus_jitter_mult,
		"洞口分值    x%.2f" % _gm.bonus_score_mult,
		"巨球        +%.0f%%" % (_gm.bonus_ball_scale * 100.0),
		"分裂发射    +%d 颗" % _gm.bonus_split,
		"洞口变宽    +%.0f%%" % (_gm.bonus_bucket_width * 100.0),
		"进洞延时    +%.1fs" % _gm.bonus_time_on_bucket,
		"图钉赏金    +%d" % _gm.bonus_break_score,
		"",
		"本局剩余图钉：%s" % _pegs_text(),
		"已解锁关卡：第 1 - %d 关" % _gm.max_unlocked_level,
	]
	return "\n".join(lines)


func _pegs_text() -> String:
	var board := get_node_or_null("/root/Main/PegBoard")
	if board == null:
		return "—"
	return "脆钉 %d / %d（硬钉 %d 打不碎）" % [
		board.get_alive_pegs(), board.get_total_pegs(), board.get_hard_pegs()]


func _refresh_level_buttons() -> void:
	if level_list == null:
		return
	for c in level_list.get_children():
		c.queue_free()
	for i in range(1, _gm.max_unlocked_level + 1):
		var btn := Button.new()
		btn.text = "第 %d 关" % i
		btn.custom_minimum_size = Vector2(96, 64)
		btn.pressed.connect(_on_level_jump.bind(i))
		level_list.add_child(btn)


func _on_level_jump(n: int) -> void:
	if _gm == null:
		return
	_gm.jump_to_level(n)
	stats_panel.visible = false
	result_panel.visible = false


func _on_level_changed(value: int) -> void:
	level_label.text = "第 %d 关 · %s" % [value, _gm.get_level_desc(value)]


func _on_balls_changed(value: int) -> void:
	balls_label.text = "球数 %d" % value


func _on_score_changed(value: int) -> void:
	score_label.text = "分数 %d / %d" % [value, _gm.target_score]


func _on_combo_changed(value: int) -> void:
	if value <= 0:
		combo_label.text = ""
	else:
		combo_label.text = "连击 %d 连  x%.2f" % [value, _gm.get_combo_multiplier()]


func _on_time_changed(value: float) -> void:
	time_label.text = "剩余 %d s" % int(ceil(value))


func _on_settle_pressed() -> void:
	if _gm != null:
		_gm.settle()


func _on_round_result(success: bool, score: int, level: int) -> void:
	result_panel.visible = true
	if success:
		result_label.text = "过关！\n分数 %d / 目标 %d\n下一关：第 %d 关\n挑一个带走：" % [score, _gm.target_score, level]
		_roll_buffs()
	else:
		result_label.text = "本局失败\n分数 %d / 目标 %d\n再试一次第 %d 关" % [score, _gm.target_score, _gm.level]

	buff_button_1.visible = success
	buff_button_2.visible = success
	buff_button_3.visible = success
	retry_button.visible = not success

	if success:
		buff_button_1.text = _buff_text(_buff_ids[0])
		buff_button_2.text = _buff_text(_buff_ids[1])
		buff_button_3.text = _buff_text(_buff_ids[2])


## 每局从全部强化里随机抽 3 种
func _roll_buffs() -> void:
	var pool := []
	for i in range(_gm.get_buff_count()):
		pool.append(i)
	pool.shuffle()
	_buff_ids = [pool[0], pool[1], pool[2]]


func _buff_text(id: int) -> String:
	match id:
		0:
			return "强力弹射  +%.0f 力度（当前 +%.0f）" % [_gm.buff_impulse_step, _gm.bonus_impulse]
		1:
			return "快速蓄力  -%.2fs（当前 %+.2f）" % [_gm.buff_charge_step, _gm.bonus_charge_time]
		2:
			return "金洞回本  +%d 球/洞（当前 +%d）" % [_gm.buff_reward_step, _gm.bonus_reward]
		3:
			return "厚积薄发  +%d 起始球（当前 +%d）" % [_gm.buff_balls_step, _gm.bonus_start_balls]
		4:
			return "图钉精通  +%d 图钉分（当前 +%d）" % [_gm.buff_peg_step, _gm.bonus_peg_score]
		5:
			return "连击大师  上限 +%.1f（当前 +%.1f）" % [_gm.buff_combo_max_step, _gm.bonus_combo_max]
		6:
			return "持久连击  窗口 +%.1fs（当前 %+.1f）" % [_gm.buff_combo_window_step, _gm.bonus_combo_window]
		7:
			return "时间延长  +%.0fs（当前 +%.0f）" % [_gm.buff_time_step, _gm.bonus_time]
		8:
			return "精准瞄准  抖动 x%.1f（当前 x%.2f）" % [_gm.buff_jitter_step, _gm.bonus_jitter_mult]
		9:
			return "洞中暴富  分值 +%.0f%%（当前 x%.2f）" % [_gm.buff_score_step * 100.0, _gm.bonus_score_mult]
		10:
			return "巨球  半径 +%.0f%%（当前 +%.0f%%）" % [_gm.buff_ball_scale_step * 100.0, _gm.bonus_ball_scale * 100.0]
		11:
			return "分裂发射  每发多 %d 颗（当前 +%d）" % [_gm.buff_split_step, _gm.bonus_split]
		12:
			return "洞口变宽  +%.0f%%（当前 +%.0f%%）" % [_gm.buff_bucket_width_step * 100.0, _gm.bonus_bucket_width * 100.0]
		13:
			return "进洞延时  +%.1fs/洞（当前 +%.1f）" % [_gm.buff_time_on_bucket_step, _gm.bonus_time_on_bucket]
		14:
			return "图钉赏金  +%d 分/颗（当前 +%d）" % [_gm.buff_break_score_step, _gm.bonus_break_score]
	return "强化"


func _on_buff_selected(index: int) -> void:
	if _gm == null:
		return
	_gm.apply_buff(_buff_ids[index])
	result_panel.visible = false
	_gm.start_round()


func _on_retry_pressed() -> void:
	result_panel.visible = false
	if _gm != null:
		_gm.start_round()
