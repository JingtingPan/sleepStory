# DebugStatusOverlay.gd
# 用于显示玩家当前的各种状态信息，便于调试和测试游戏机制
# 挂载到 CanvasLayer 下的 Control 节点上

extends Control

@onready var sleep_label: Label = $VBoxContainer/SleepLabel
@onready var sanity_label: Label = $VBoxContainer/SanityLabel
@onready var covered_label: Label = $VBoxContainer/CoveredLabel
@onready var view_label: Label = $VBoxContainer/ViewLabel
@onready var view_time_label: Label = $VBoxContainer/ViewTimeLabel
@onready var eye_label: Label = $VBoxContainer/EyeLabel
@onready var safe_label: Label = $VBoxContainer/SafeLabel

@onready var sleep_bar: ProgressBar = $VBoxContainer/SleepBar
@onready var sanity_bar: ProgressBar = $VBoxContainer/SanityBar
func _process(_delta):
	var state = PlayerStateController

	# 显示入睡度
	sleep_label.text = "入睡度: %.1f" % state.sleepiness
	sleep_bar.value = state.sleepiness
	# 显示理智值
	sanity_label.text = "理智值: %.1f" % state.sanity
	sanity_bar.value = state.sanity
	# 是否盖被子
	covered_label.text = "是否盖被: %s" % ("是" if state.is_covered else "否")

	# 当前视角
	var dir
	match state.current_view_index:
		0: dir= "正前方"
		1: dir="右侧"
		2: dir="左侧"
	view_label.text = "当前视角: %s" % dir

	# 当前视角保持时间
	view_time_label.text = "视角持续: %.1f 秒" % state.view_hold_time

	# 是否闭眼
	eye_label.text = "是否闭眼: %s" % ("是" if state.is_eye_closed else "否")

	# 当前是否安全
	safe_label.text = "安全状态: %s" % ("安全" if state.is_in_safe_state else "危险")
