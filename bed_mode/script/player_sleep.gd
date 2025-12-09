# Godot 4.x 版本
# 控制在床上第一人称的基础交互：翻身、盖被子、探头看门/床底
class_name SleepingPlayer
extends CharacterBody3D
# 翻身方向
enum TurnDirection { LEFT, RIGHT }
@export var interact_action := "interact"  
@export var interact_distance := 2.0              # 床上交互最大距离

@onready var sound_breathing: AudioStreamPlayer = $PlayerSound_breathing
@onready var sound_heartbeat: AudioStreamPlayer = $PlayerSound_heartbeat
@onready var heartbeat_timer: Timer = $Heartbeat_Timer
@onready var player_sound: AudioStreamPlayer = $PlayerSound
@onready var character_animation_player: AnimationPlayer = $kid/AnimationPlayer
@onready var skeleton: Skeleton3D = $kid/Armature_001/Skeleton3D
@onready var body_node: Node3D = $kid # 身体节点
@onready var interact_raycast: RayCast3D = $HeadPivot/CameraPivot/InteractRayCast
@onready var interact_label: Label = $CanvasLayer/InteractLabel
@onready var crosshair: Label = $CanvasLayer/Crosshair
@onready var animation_player: AnimationPlayer = $HeadPivot/kid/AnimationPlayer

signal context_interact_started
signal context_interact_finished

var ctx_enabled := false
var ctx_hint := "Interact [E]"
var ctx_duration := 0.8
var ctx_allowed_view := 2        # 左侧视角索引（你的 fixed_rotations 里左边是 2）
var ctx_busy := false

# 玩家状态
var sleep_interact_enabled := false               # 是否启用床上交互
var is_covered: bool = false
var current_view_index = 0
var yaw = 0.0
var pitch = 0.0
var target_yaw: float = 0.0
var target_pitch: float = 0.0
# 输入锁
var is_turning: bool = false
var is_peeking: bool = false
var can_toggle_eye := false
var auto_mode = false

var can_turn := true  # 是否允许翻身

var heartbeat_time_passed := 0.0
var heartbeat_total_duration := 0.0
var heartbeat_start_rate := 90.0
var heartbeat_end_rate := 60.0
var heartbeat_active := false
var heartbeat_ramp_duration := 0.0
var heartbeat_sustain := false  # 是否在爬升结束后持续保持 end_bpm

#固定视角
var fixed_rotations = [
	Vector3(90, 90, 0),      # 正前方
	Vector3(15, 0, -90),    # 右边
	Vector3(15, 180, 90)      # 左边
]
var ideal_view_vectors = [
	Vector3(0, 0, -1),  # 前
	Vector3(1, 0, 0),  # 右
	Vector3(-1, 0, 0)    # 左
]

# 交互参数
@export var turn_speed: float = 2.0
@export var max_peek_angle: float = 30.0 # 探头最大角度（度）
@export var max_yaw = 15.0 # 左右角度限制
@export var max_pitch_up = 25.0 # 上下角度限制
@export var max_pitch_down = -80.0 # 上下角度限制
@export var mouse_sensitivity = 0.2

# 节点引用
@onready var camera: Camera3D = $HeadPivot/CameraPivot/Camera3D
@onready var blanket: MeshInstance3D = $blanket
@onready var state = PlayerStateController
@onready var eye_mask = $CanvasLayer/EyeMask
@onready var eye_overlay = $CanvasLayer/EyeMask/ColorRect
@onready var noise_texture: ColorRect = $CanvasLayer/EyeMask/NoiseTexture
@onready var head_pivot = $HeadPivot
@onready var camera_pivot = $HeadPivot/CameraPivot
func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	blanket.visible = false

	# 交互射线初始化
	interact_raycast.enabled = false
	interact_raycast.target_position = Vector3(0, 0, -interact_distance)  # 相机前方
	
func _process(delta):
	if not is_turning and not is_peeking:
		handle_basic_input()
		update_free_look()
		
	# 更新噪粒效果（eye_mask）
	if eye_mask.visible:
		var shader_mat := noise_texture.material
		if shader_mat and shader_mat is ShaderMaterial:
			shader_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
			shader_mat.set_shader_parameter("strength", 0.3)  # 可在 runtime 动态调节
			shader_mat.set_shader_parameter("density", 300.0)  # 控制颗粒分布
	
	if heartbeat_active:
		update_heartbeat_dynamic(delta)  # ✅ 你已有方法，但之前没调用
	
		
		# —— 极简“看左侧就能交互”的提示与触发 —— 
	if ctx_enabled and not ctx_busy:
		if current_view_index == ctx_allowed_view:
			interact_label.text = ctx_hint
			interact_label.visible = true
			crosshair.visible = false
			if Input.is_action_just_pressed(interact_action):
				_start_ctx_interact()
		else:
			# 没看向指定方向就隐藏提示
			interact_label.visible = false
			crosshair.visible = true
# -------------------------
# 处理输入：翻身、盖被、探头、闭眼
# -------------------------
func handle_basic_input():
	if can_turn:
		if Input.is_action_just_pressed("left"):
			start_turn(TurnDirection.LEFT)
		elif Input.is_action_just_pressed("right"):
			start_turn(TurnDirection.RIGHT)
	if Input.is_action_pressed("F"):
		toggle_eyes()
	#elif Input.is_action_just_pressed("cover_toggle"):
		#toggle_blanket()
	#elif Input.is_action_pressed("peek"):
		#start_peek()
	#elif Input.is_action_just_released("peek"):
		#stop_peek()
	

# -------------------------
# 翻身逻辑（切换视角）
# -------------------------
func start_turn(direction: TurnDirection):
	is_turning = true
		# 根据方向改变索引
	if direction == TurnDirection.LEFT:
		current_view_index -= 1
	else:
		current_view_index += 1

	# 循环回绕视角索引，防止越界
	current_view_index = (current_view_index + fixed_rotations.size()) % fixed_rotations.size()
	# 同步状态控制器中当前视角信息
	state.set_view_index(current_view_index)  # ← 同步状态
	# 启动平滑旋转动画
	var target_rotation = fixed_rotations[current_view_index]
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", target_rotation, 1.0 / turn_speed)
	tween.connect("finished", Callable(self, "_on_turn_finished"))
# 翻身完成后解锁输入

func _on_turn_finished():
	is_turning = false
	
# -------------------------
# 盖被子或掀被子逻辑
# -------------------------
func toggle_blanket():
	is_covered = not is_covered
	blanket.visible = is_covered
	state.set_covered(is_covered)  # ← 同步状态
	
# -------------------------
# 探头开始（按住 Shift + 左/右）
# -------------------------
func start_peek():
	is_peeking = true
	var peek_angle = max_peek_angle if Input.is_action_pressed("move_right") else -max_peek_angle
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:x", peek_angle, 0.3)

# 探头停止（松开按键）
func stop_peek():
	is_peeking = false
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:x", 0, 0.3)

# -------------------------
# 闭眼/睁眼状态切换（影响入睡度增长）
# ------------------------
func toggle_eyes():
	if not can_toggle_eye:
		return
	can_toggle_eye = false
	if state.is_eye_closed:
		open_eyes()
	else:
		close_eyes()

func close_eyes():
	if state.is_eye_closed:
		return
	state.set_eye_closed(true)
	eye_mask.visible = true
	create_tween().tween_property(eye_overlay, "modulate:a", 1.0, 0.5).connect("finished", Callable(self, "_on_eye_closed"))

func _on_eye_closed():
	can_toggle_eye = true
	
func open_eyes():
	if not state.is_eye_closed:
		return
	state.set_eye_closed(false)
	create_tween().tween_property(eye_overlay, "modulate:a", 0.0, 0.5).connect("finished", Callable(self, "_on_eye_opened"))

func _on_eye_opened():
	eye_mask.visible = false
	can_toggle_eye = true
	
func enable_eye_toggle_after_delay():
	await get_tree().create_timer(0.3).timeout
	can_toggle_eye = true

func _input(event):
	if event is InputEventMouseMotion and not is_turning and not is_peeking:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch -= event.relative.y * mouse_sensitivity
		# 限制角度在你设定的范围内
		target_yaw = clamp(target_yaw, -max_yaw, max_yaw)
		target_pitch = clamp(target_pitch, max_pitch_down, max_pitch_up)
		
func update_free_look():
	head_pivot.rotation_degrees.y = target_yaw
	camera_pivot.rotation_degrees.x = target_pitch
	
func tilt_camera_left():
	var tween = create_tween()
	var target_rot = camera_pivot.rotation_degrees
	target_rot.y += 70  # 向左看 10 度（你可以调得更小，例如 5）
	tween.tween_property(camera_pivot, "rotation_degrees", target_rot, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
func reset_camera_tilt():
	var tween = create_tween()
	tween.tween_property(camera_pivot, "rotation_degrees:y", 0.0, 1.0)
	
# 立即调整玩家视角到指定预设角度
func set_view_index(index: int):
	index = clamp(index, 0, fixed_rotations.size() - 1)
	current_view_index = index
	rotation_degrees = fixed_rotations[index]
	state.set_view_index(current_view_index)  # 同步状态
	
#作用：立即以固定频率开始心跳。
#适用场景：
#非渐变式心跳：比如你想模拟一个角色在受到稳定压迫状态下维持固定的心跳节奏。
#怪物靠近时突然开启“快速心跳”，不需要渐变。
#UI 警示节奏（例如“危险区域进入”）
func start_heartbeat(rate_hz := 90):
	heartbeat_timer.stop()  # restart to ensure clean timing
	heartbeat_timer.wait_time = 60.0 / rate_hz
	heartbeat_timer.start()
	
	
#作用：将一个 stress 值（0~1）映射成 BPM，并用 start_heartbeat() 启动。
#适用场景：
#即时反馈式心跳频率变化（非渐变），根据状态实时调整。
#如果你想每一帧都根据“理智值”、“恐惧值”等动态调节节奏。
#快速构建原型或调试压力系统映射时很方便。
func update_heartbeat_by_stress_level(stress: float):  # stress 0.0~1.0
	var bpm = lerp(60, 150, stress)
	start_heartbeat(bpm)
	
	
## 5 秒从 110 → 130，之后一直保持 130，直到手动停
# player_sleep.start_dynamic_heartbeat(110.0, 130.0, 5.0, true)
# 启动：从 start_bpm 爬到 end_bpm，ramp_duration 秒完成；
# 若 sustain=true，则之后一直保持 end_bpm；直到 stop_heartbeat() 被调用
func start_dynamic_heartbeat(start_bpm: float, end_bpm: float, ramp_duration: float, sustain := true) -> void:
	# 保险：保证定时器有回调（只需在 _ready 里连一次也行）
	if not heartbeat_timer.timeout.is_connected(_on_heartbeat_timer_timeout):
		heartbeat_timer.timeout.connect(_on_heartbeat_timer_timeout)

	heartbeat_timer.stop()
	heartbeat_start_rate = start_bpm
	heartbeat_end_rate   = end_bpm
	heartbeat_ramp_duration = max(0.01, ramp_duration)
	heartbeat_time_passed = 0.0
	heartbeat_active = true
	heartbeat_sustain = sustain

	# 立刻打一声
	if sound_heartbeat.stream != null:
		sound_heartbeat.play()

	# 设置第一跳的间隔
	heartbeat_timer.one_shot = false
	heartbeat_timer.wait_time = 60.0 / max(1.0, heartbeat_start_rate)
	heartbeat_timer.start()
	set_process(true)


# 每帧只负责推进时间；不再在这里 stop（除非你想无持续地结束）
func update_heartbeat_dynamic(delta: float) -> void:
	if not heartbeat_active:
		return
	heartbeat_time_passed += delta
	# 如果不需要持续，并且已超过爬升时长，则停掉
	if not heartbeat_sustain and heartbeat_time_passed >= heartbeat_ramp_duration:
		heartbeat_timer.stop()
		heartbeat_active = false


# 每一下心跳由计时器驱动；这里根据进度更新下一次 wait_time
func _on_heartbeat_timer_timeout() -> void:
	if not heartbeat_active:
		return

	# 播放这一跳
	if sound_heartbeat.stream != null:
		sound_heartbeat.pitch_scale = randf_range(0.98, 1.02)  # 可删
		sound_heartbeat.play()

	# 计算当前 BPM：爬升阶段线性插值；爬升完成后固定 end_bpm（若 sustain）
	var bpm := heartbeat_end_rate
	
	if heartbeat_time_passed < heartbeat_ramp_duration:
		var t: float = clamp(heartbeat_time_passed / heartbeat_ramp_duration, 0.0, 1.0)
		bpm = lerp(heartbeat_start_rate, heartbeat_end_rate, t)
	elif not heartbeat_sustain:
		# 不持续：超时后下一帧 update_heartbeat_dynamic 会停，这里随便设
		bpm = heartbeat_end_rate

	# 更新下一跳间隔
	heartbeat_timer.wait_time = 60.0 / max(1.0, bpm)


# 手动停止（可选带淡出）
func stop_heartbeat(fade_out := 0.0) -> void:
	if fade_out > 0.0 and sound_heartbeat != null:
		var tw := create_tween()
		tw.tween_property(sound_heartbeat, "volume_db", -60.0, fade_out)
		await tw.finished
	# 彻底停止
	heartbeat_timer.stop()
	heartbeat_active = false
		
		

func enable_context_interact(hint: String, duration: float = 0.8, allowed_view: int = 2) -> void:
	ctx_enabled = true
	ctx_hint = hint
	ctx_duration = duration
	ctx_allowed_view = allowed_view
	# 可选：关闭 RayCast 提示，避免干扰
	sleep_interact_enabled = false
	interact_raycast.enabled = false
	interact_label.visible = false
	crosshair.visible = true

func disable_context_interact() -> void:
	ctx_enabled = false
	interact_label.visible = false
	crosshair.visible = true

func _start_ctx_interact() -> void:
	if ctx_busy: return
	ctx_busy = true
	emit_signal("context_interact_started")
	# 这里可以加进度UI/小动画；先最简等待
	await get_tree().create_timer(ctx_duration).timeout
	ctx_busy = false
	emit_signal("context_interact_finished")
	
#创建一个播放动画的辅助函数（避免重复切换）
func play_anim(name: String, speed: float = 1.0):
	if animation_player.has_animation(name):
		animation_player.play(name, -1, speed)
