extends Node

## 存档 + 排行榜（同学试玩建议：加个存档和排行榜）。
##
## 存档     user://save.json       —— 当前关卡、已解锁关卡、局间强化累积、历史最高分
## 排行榜   user://leaderboard.json —— 按分数排序的前 10 局
##
## user:// 在 Windows 上是 %APPDATA%\Godot\app_userdata\<项目名>\
## 所以关掉游戏再打开，进度和榜单都还在。
##
## 设计取舍：只存"局外进度"（关卡 + 强化 + 最高分），不存"局内状态"
## （当前球数、剩余时间、场上球的位置）。原因：局内状态每帧都在变，
## 存它需要把整个物理场景序列化，对本项目（每局 90 秒、随时可重开）不划算，
## 玩家真正想留住的是"打到第几关、攒了哪些强化"。

const SAVE_PATH := "user://save.json"
const BOARD_PATH := "user://leaderboard.json"
const BOARD_MAX := 10

## 强化字段的默认值：键名与 GameManager._buffs_dict() 一一对应
const EMPTY_BUFFS := {
	"impulse": 0.0,
	"charge_time": 0.0,
	"reward": 0,
	"start_balls": 0,
	"peg_score": 0,
	"combo_max": 0.0,
	"combo_window": 0.0,
	"time": 0.0,
	"jitter_mult": 1.0,
	"score_mult": 1.0,
	"ball_scale": 0.0,
	"split": 0,
	"bucket_width": 0.0,
	"time_on_bucket": 0.0,
	"break_score": 0,
}

const EMPTY_STATE := {
	"level": 1,
	"max_unlocked_level": 1,
	"best_score": 0,
	"buffs": {},
	"updated_at": "",
}

var state: Dictionary = {}
var board: Array = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	state = _load_dict(SAVE_PATH)
	if state.is_empty():
		state = EMPTY_STATE.duplicate(true)
	for key in EMPTY_STATE.keys():
		if not state.has(key):
			state[key] = EMPTY_STATE[key]
	# buffs 缺字段时按默认值补齐，避免改版本后读旧档报错
	var buffs: Dictionary = {} if not (state.get("buffs", null) is Dictionary) else state.get("buffs", {}) as Dictionary
	for key in EMPTY_BUFFS.keys():
		if not buffs.has(key):
			buffs[key] = EMPTY_BUFFS[key]
	state["buffs"] = buffs
	board = _load_array(BOARD_PATH)
	print("SAVE_MANAGER 载入：关卡 %d / 最高分 %d / 榜单 %d 条" % [
		int(state.get("level", 1)), int(state.get("best_score", 0)), board.size()
	])


## 是否有"值得恢复"的进度：不是第 1 关、有强化、或有历史最高分
func has_progress() -> bool:
	if int(state.get("level", 1)) > 1:
		return true
	if int(state.get("best_score", 0)) > 0:
		return true
	var buffs: Dictionary = {} if not (state.get("buffs", null) is Dictionary) else state.get("buffs", {}) as Dictionary
	for key in EMPTY_BUFFS.keys():
		var cur: Variant = buffs.get(key, EMPTY_BUFFS[key])
		if str(cur) != str(EMPTY_BUFFS[key]):
			return true
	return false


## 写入存档（由 GameManager 结算 / 退出时调用）
func save_state(next: Dictionary) -> void:
	for key in next.keys():
		state[key] = next[key]
	state["updated_at"] = now_text()
	_write_json(SAVE_PATH, state)


## 记录一局成绩，返回是否刷新了历史最高分
func record_run(entry: Dictionary) -> bool:
	entry["date"] = now_text()
	board.append(entry)
	board.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if board.size() > BOARD_MAX:
		board = board.slice(0, BOARD_MAX)
	var score := int(entry.get("score", 0))
	var is_record := score > int(state.get("best_score", 0))
	if is_record:
		state["best_score"] = score
	_write_json(BOARD_PATH, board)
	_write_json(SAVE_PATH, state)
	return is_record


func board_text() -> String:
	var lines := ["排行榜 · 最好的 %d 局" % mini(BOARD_MAX, board.size())]
	if board.is_empty():
		lines.append("")
		lines.append("还没有记录，先打一局。")
	else:
		for i in range(board.size()):
			var e: Dictionary = board[i]
			lines.append("%2d. %6d 分  第 %d 关  %s  %s" % [
				i + 1,
				int(e.get("score", 0)),
				int(e.get("level", 1)),
				"过关" if bool(e.get("success", false)) else "失败",
				str(e.get("date", "")),
			])
	lines.append("")
	lines.append("历史最高：%d 分" % int(state.get("best_score", 0)))
	var updated := str(state.get("updated_at", ""))
	if updated != "":
		lines.append("存档时间：%s" % updated)
	return "\n".join(lines)


## 清空存档与排行榜（排行榜面板上的按钮）
func clear_all() -> void:
	state = EMPTY_STATE.duplicate(true)
	state["buffs"] = EMPTY_BUFFS.duplicate(true)
	board = []
	_remove_file(SAVE_PATH)
	_remove_file(BOARD_PATH)


func now_text() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%02d-%02d %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


func _load_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Array else []


func _write_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("写入失败：" + path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _remove_file(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
