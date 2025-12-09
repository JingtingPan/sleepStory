extends Node3D
# 管理整晚流程（阶段、胜负判断、时间管理）
# 应作为 Autoload 单例或挂载在全局场景入口
signal night_started
signal night_phase_changed(phase: String)
signal night_ended(success: bool)
# ------------------------
# 配置参数
# ------------------------
@export var total_duration: float = 90.0  # 总持续时间（秒）
@export var phase_1_time: float = 30.0    # 清醒期结束时间点
@export var phase_2_time: float = 60.0    # 半梦期结束时间点
@export var game_over_label: Label 
@export var fall_asleep_label: Label

@onready var state = PlayerStateController

# ------------------------
# 内部状态
# ------------------------
var timer: float = 0.0
var current_phase: String = "awake"  # "awake", "half_dream", "deep_dream"
var is_running: bool = false

func _ready():
	if has_node("/root/main/CanvasLayer/game_over"):
		game_over_label = get_node("/root/main/CanvasLayer/game_over")
	else:
		push_error("找不到 game_over Label")

	if has_node("/root/main/CanvasLayer/fall_asleep"):
		fall_asleep_label = get_node("/root/main/CanvasLayer/fall_asleep")
	else:
		push_error("找不到 fall_asleep Label")
	start_night()

func _process(delta):
	if not is_running:
		return

	timer += delta
	 #_update_phase()

	if timer >= total_duration or PlayerStateController.is_fully_asleep():
		end_night(PlayerStateController.is_fully_asleep())

func start_night():
	timer = 0.0
	current_phase = "awake"
	is_running = true
	emit_signal("night_started")
	#emit_signal("night_phase_changed", current_phase)
	print("[Night] 新的一晚开始")

func end_night(success: bool):
	is_running = false
	emit_signal("night_ended", success)
	if success:
		fall_asleep_label.visible = true
	else:
		game_over_label.visible = true
		
	print("[Night] 一晚结束，成功: %s" % success)

func _update_phase():
	if timer >= phase_2_time and current_phase != "deep_dream":
		current_phase = "deep_dream"
		emit_signal("night_phase_changed", current_phase)
		print("[Night] 进入深度梦境阶段")
	elif timer >= phase_1_time and current_phase != "half_dream":
		current_phase = "half_dream"
		emit_signal("night_phase_changed", current_phase)
		print("[Night] 进入半梦半醒阶段")
