# PlayerStateController.gd
# 用于管理玩家的全局状态，包括入睡度、理智值、当前视角、被子状态等
# 可挂载在玩家节点上，或独立作为 Autoload（单例）使用

extends Node

# 发出信号，供 UI 或其他系统监听变化
signal sanity_changed(new_value)
signal sleepiness_changed(new_value)

# -------------------------
# 玩家状态变量
# -------------------------
var sleepiness: float = 0.0      # 入睡度 0-100
var sanity: float = 100.0         # 理智值 0-100
var is_covered: bool = false      # 是否盖被子
var is_eye_closed: bool = false     # 是否闭眼（影响sleep增长）
var is_in_safe_state: bool = true   # 是否处于理智恢复状态
var current_view_index: int = 0   # 当前视角（0:前, 1:左, 2:右）
var view_hold_time: float = 0.0   # 当前朝向持续时间（用于触发盯视类怪物）

# -------------------------
# 参数配置（可导出调试）
# -------------------------
@export var sleep_gain_rate := 4.0     # 每秒闭眼状态下增长入睡度速度
@export var sleep_loss_rate := 0.8     # 醒着时降低入睡度速度
@export var sanity_decay_rate := 0.5   # 每秒自然下降（焦虑）
@export var sanity_restore_rate := 3.0 # 安全状态下恢复速度
@export var sanity_floor: float = 20.0       # 低于此值开始触发幻觉
@export var cover_rate : float = 1.2 #盖被子时的变化速率


func _process(delta):
	update_sleepiness(delta)
	update_sanity(delta)
	update_view_hold(delta)

# -------------------------
# 入睡度更新逻辑
# -------------------------
func update_sleepiness(delta):
	if is_eye_closed:
		if is_covered:
			sleepiness += (sleep_gain_rate + cover_rate) * delta # 闭眼盖被入睡度显著增加
		else:
			sleepiness += sleep_gain_rate * delta # 闭眼没盖被入睡度正常上升
	else:
		if is_covered:
			sleepiness -= (cover_rate - sleep_loss_rate) * delta # 睁眼时盖被入睡度下降缓慢
		else:
			sleepiness -= sleep_loss_rate * delta #睁眼时没盖被入睡度正常下降
	sleepiness = clamp(sleepiness, 0, 100)
	emit_signal("sleepiness_changed", sleepiness)
	

# -------------------------
# 理智值更新逻辑
# -------------------------
func update_sanity(delta):
	#if is_in_safe_state:
		#sanity += sanity_restore_rate * delta # 安全时恢复理智
	#else:
		#sanity -= sanity_decay_rate * delta # 恐惧中理智下降
	if is_eye_closed:
		if is_covered:
			sanity -= (cover_rate - sanity_decay_rate) * delta # 闭眼盖被理智值缓慢降低
		else:
			sanity -= sanity_decay_rate * delta # 闭眼不盖被理智值正常降低
	else:
		if is_covered:
			sanity += (sanity_restore_rate + cover_rate) * delta # 睁眼时盖被理智值显著增加
		else:
			sanity += sanity_restore_rate * delta # 睁眼时不盖被理智值正常增加
			
		#sanity -= sanity_decay_rate * delta # 恐惧中理智下降
	sanity = clamp(sanity, 0, 100)
	emit_signal("sanity_changed", sanity)


# -------------------------
# 当前视角保持时间更新
# ------------------------
func update_view_hold(delta):
	view_hold_time += delta # 持续计时，用于触发盯视类怪物等机制

# -------------------------
# 切换视角时重置计时器
# -------------------------
func reset_view_hold():
	view_hold_time = 0.0

# -------------------------
# 设置当前视角（翻身时调用）
# -------------------------
func set_view_index(new_index: int):
	if new_index != current_view_index:
		current_view_index = new_index
		reset_view_hold()

# -------------------------
# 设置是否盖被子（由玩家操作调用）
# -------------------------
func set_covered(state: bool):
	is_covered = state

# -------------------------
# 设置是否闭眼（用于入睡机制）
# -------------------------
func set_eye_closed(state: bool):
	is_eye_closed = state

# -------------------------
# 设置是否处于安全状态（供怪物系统调用）
# -------------------------
func set_safe_state(state: bool):
	is_in_safe_state = state

# -------------------------
# 检测是否触发幻觉
# -------------------------
func is_hallucinating() -> bool:
	return sanity <= sanity_floor
	
# -------------------------
# 检测玩家是否完全入睡
# -------------------------
func is_fully_asleep() -> bool:
	return sleepiness >= 100.0

func get_player_status() -> Dictionary:
	return {
		"sleepiness": sleepiness,
		"sanity": sanity,
		"is_covered": is_covered,
		"is_eye_closed": is_eye_closed,
		"current_view_index": current_view_index,
		"is_in_safe_state": is_in_safe_state
	}
