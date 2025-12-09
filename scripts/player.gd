class_name StandingPlayer
extends CharacterBody3D

@onready var camera = $Camera3D
@onready var origCamPos : Vector3 = camera.position
@onready var floorcast: RayCast3D = $FloorDetectRayCast
@onready var player_footstep_sound: AudioStreamPlayer3D = $FootStepSound
@onready var interact_raycast: RayCast3D = $Camera3D/InteractRayCast
@onready var jump_land_sound: AudioStreamPlayer3D = $JumpLandSound
@onready var jump_start_sound: AudioStreamPlayer3D = $JumpStartSound
@onready var interact_label: Label = $CanvasLayer/InteractLabel
@onready var crosshair: Label = $CanvasLayer/Crosshair
@onready var urine_raycast: RayCast3D = $UrineStream/UrineRayCast
@onready var splash_sound: AudioStreamPlayer3D = $UrineStream/UrineSound
@onready var splash_particles: GPUParticles3D = $UrineStream/SplashParticles
@onready var mesh_instance_3d: MeshInstance3D = $UrineStream/MeshInstance3D
@onready var urine_stream: GPUParticles3D = $UrineStream
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var sound_breathing: AudioStreamPlayer = $PlayerSound_breathing
@onready var sound_heartbeat: AudioStreamPlayer = $PlayerSound_heartbeat
@onready var heartbeat_timer: Timer = $Heartbeat_Timer
@onready var player_sound: AudioStreamPlayer = $PlayerSound
@onready var character_animation_player: AnimationPlayer = $kid/AnimationPlayer
@onready var skeleton: Skeleton3D = $kid/Armature_001/Skeleton3D
@onready var body_node: Node3D = $kid # 身体节点
@onready var hint_label: Control = get_node("/root/child_room/CanvasLayer/TaskHintManager")


@export var max_head_turn := 60.0
@export var max_head_pitch := 30.0
@export var backward_threshold := 90.0  # 超过这个角度进入倒退
@export var body_turn_speed := 6.0  # 身体旋转平滑度
@export var allow_interact := true  # 是否允许交互，事件可以动态改
@export var interact_anim_speed := 2.0
@export var walk_anim_speed := 0.6
@export var walk_step_distance := 2.2 #玩家行走时触发脚步的距离
@export var sprint_step_distance := 3
@export var barefoot := false #玩家是否光脚行走
@export var urine_duration := 5.0  # 尿3秒后切换状态
@export var speed = 2.5
@export var sprint_speed = 6.0
@export var JUMP_VELOCITY = 4.5
@export var mouse_sen = 0.6
@export var camBobSpeed := 7 #玩家移动时相机晃动速度
@export var camBobUpDown := 0.81	 #玩家移动时相机晃动范围
@export var camBobIdleUpDown := 0.05 #玩家站立时相机晃动范围
@export var camBobIdleSpeed := 0.8	#玩家站立时相机晃动速度
@export var interact_cooldown := 0.5
@export var last_interact_time := -1.0
@export var jump_land_sounds = [
	preload("res://sfx/player/footstep/Footsteps_Wood/Footsteps_Wood_Jump/Footsteps_Wood_Jump_Start_01.wav"),
	preload("res://sfx/player/footstep/Footsteps_Wood/Footsteps_Wood_Jump/Footsteps_Wood_Jump_Land_02.wav")
]
enum PlayerState { NORMAL, FROZEN, HALLUCINATING, DIALOGUE, PEE }
var current_state = PlayerState.NORMAL
var direction: Vector3
var _delta := 0.0
var step_distance_accumulator := 0.0
var last_played_group := ""
var was_on_floor_last_frame := true
var mouse_can_move = true  # 默认可以移动
var movement_enabled := true

var last_surface = ""
var pee_cooldown = 0.5
var last_play_time = 0.0
var particle_emitting = false
var sound_playing = false
var is_urinating := false
var urine_start_time := 0.0

var shake_time = 0.0
var shake_intensity = 0.05
var shake_timer = 0.0
var original_cam_pos = Vector3.ZERO

var heartbeat_time_passed := 0.0
var heartbeat_total_duration := 0.0
var heartbeat_start_rate := 90.0
var heartbeat_end_rate := 60.0
var heartbeat_active := false
var heartbeat_ramp_duration := 0.0
var heartbeat_sustain := false  # 是否在爬升结束后持续保持 end_bpm
var current_anim = ""
var is_playing_interact := false

var is_backpedaling := false#玩家模型和头部朝向是否超过一定角度

var input_enabled := true #是否接受操作
#视角锁参数
var view_lock_enabled := false
var lock_center_yaw := 0.0      # 弧度
var lock_half_yaw := 999.0
var lock_center_pitch := 0.0    # 弧度
var lock_half_pitch := 999.0

var barefoot_sounds:=preload_all_audio("res://sfx/player/footstep/footsteps_barefoot/")

var surface_sounds := {
	"WoodTerrain": preload_all_audio("res://sfx/player/footstep/Footsteps_Wood/Footsteps_Wood_Walk/"), 
	"MetalTerrain": [],
	"TileTerrain": preload_all_audio("res://sfx/player/footstep/slipper_footstep/")
	#"GrassTerrain": preload()
}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
		
#角色移动、碰撞检测 
func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	# 原逻辑…
	if current_state == PlayerState.NORMAL:
		mouse_can_move = true
		set_movement_enabled(true)
		player_movement(delta)
		#update_body_rotation(delta)  
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif current_state == PlayerState.PEE:
		mouse_can_move = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		urine_check()
		var now = Time.get_ticks_msec() / 1000.0
		if now - urine_start_time >= urine_duration:
			end_urinating()
	elif current_state == PlayerState.DIALOGUE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_movement_enabled(false)  # 不能走
		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # 释放鼠标
	elif current_state == PlayerState.FROZEN:
		mouse_can_move = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # 释放鼠标
		#camera.current = false  # 停止摄像机跟随

	
#画面表现、非关键逻辑
func _process(delta):
	prompt_interactable()
	if not input_enabled:
		return
	# 原逻辑…
	if current_state == PlayerState.NORMAL:
		camera_movement(delta)
		handle_footstep_logic(delta) 
		handle_jump_sound()
		#update_head_rotation()
		if direction.length() > 0.1 and is_on_floor():
			play_anim("walk",walk_anim_speed)
		else:
			play_anim("idle")
	
	#elif current_state == PlayerState.PEE:
	name = str(Engine.get_frames_per_second())
	if heartbeat_active:
		update_heartbeat_dynamic(delta)
	
#外部直接关闭玩家操作的接口	
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	mouse_can_move = enabled  # 你已有的旗标，顺手同步
	

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled

func preload_all_audio(folder: String) -> Array:
	var result: Array = []
	var dir = DirAccess.open(folder)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.get_extension() in ["wav", "mp3", "ogg"]:
				result.append(load(folder + "/" + f))
			f = dir.get_next()
		dir.list_dir_end()
	return result

# ----------------- 脚步声处理 -----------------
func handle_footstep_logic(delta):
	if not is_on_floor():
		return

	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	if horizontal_speed < 0.1:
		return

	# 根据冲刺或走路决定步频
	var step_threshold = sprint_step_distance if Input.is_action_pressed("sprint") else walk_step_distance
	step_distance_accumulator += horizontal_speed * delta

	if step_distance_accumulator >= step_threshold:
		step_distance_accumulator = 0.0
		var terrain_group = detect_floor_group()
		if terrain_group != "":
			if not barefoot:
				play_random_footstep(terrain_group)
			else:
				play_random_footstep("")
			


	
func detect_floor_group() -> String:
	if floorcast.is_colliding():
		var collider = floorcast.get_collider().get_parent()
		if collider and collider.has_method("get_groups"):
			for group_name in collider.get_groups():
				if group_name in surface_sounds:
					return group_name
	return ""

func play_random_footstep(group: String):
	if surface_sounds.has(group):
		var sfx_list = surface_sounds[group]
		if not sfx_list.is_empty():
			var selected = sfx_list[randi() % sfx_list.size()]
			player_footstep_sound.volume_db = 0
			player_footstep_sound.stream = selected
			player_footstep_sound.pitch_scale = randf_range(0.9, 1.1)
			player_footstep_sound.play()
	else:
		var sfx_list = barefoot_sounds
		if not sfx_list.is_empty():
			var selected = sfx_list[randi() % sfx_list.size()]
			player_footstep_sound.stream = selected
			player_footstep_sound.pitch_scale = randf_range(0.9, 1.1)
			player_footstep_sound.volume_db = 15
			player_footstep_sound.play()
			
# ----------------- 跳跃声处理 -----------------
func handle_jump_sound():
	if not was_on_floor_last_frame and is_on_floor():
		var sfx_list = jump_land_sounds
		if not sfx_list.is_empty():
			var selected = sfx_list[randi() % sfx_list.size()]
			jump_land_sound.stream = selected
			jump_land_sound.play()
	was_on_floor_last_frame = is_on_floor()

	
#移动时和站立时相机晃动的速度和范围
func camera_movement(delta):
	_delta+=delta
	var cam_bob
	var objCam
	if direction != Vector3.ZERO:
		#玩家移动时
		cam_bob = floor(abs(direction.z) + abs(direction.x)) * _delta * camBobSpeed
		objCam = origCamPos + Vector3.UP * sin(cam_bob) * camBobUpDown 
	else:
		cam_bob = 2.0 * _delta * camBobIdleSpeed
		objCam = origCamPos + Vector3.UP * sin(cam_bob) * camBobIdleUpDown 
		
	camera.position = camera.position.lerp(objCam,delta)
	
	
	
	
#handle player basic movement: walk,sprint,jump
func player_movement(delta):
	
	if not movement_enabled:
		# 冻住水平移动，但仍保留重力/落地（或你也可把重力也关掉）
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		move_and_slide()
		return
	# ……原来的移动逻辑……
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		# 判断冲刺是否激活
	var is_sprinting := Input.is_action_pressed("sprint")
	var current_speed = sprint_speed if is_sprinting else speed
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
func prompt_interactable():
		# hint_label 只在自由行动时显示
	if hint_label and is_instance_valid(hint_label):
		hint_label.visible = (
			current_state == PlayerState.NORMAL and 
			allow_interact and 
			input_enabled and 
			not is_playing_interact
		)
	if current_state != PlayerState.NORMAL or not allow_interact or not input_enabled:
		interact_label.visible = false
		#crosshair.visible = true
		return
	if interact_raycast.is_colliding():
		if is_instance_valid(interact_raycast.get_collider()):
			if interact_raycast.get_collider().is_in_group("Interactable"):
				interact_label.text = interact_raycast.get_collider().type
				interact_label.visible = true
				crosshair.visible = false
			else:
				interact_label.visible = false
				crosshair.visible = true
	else:
		interact_label.visible = false
		crosshair.visible = true

#handle player view moment through mouse
func _input(event):
	if not input_enabled:
		return
	if not mouse_can_move:
		return  # 禁用视角控制
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sen))
		camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sen))
		camera.rotation.x  = clamp(camera.rotation.x, deg_to_rad(-89),deg_to_rad(89)) #player up and down view limit
		if view_lock_enabled:
			_apply_view_lock_now()
	if Input.is_action_just_pressed("interact"):
		if not can_interact(): 
			return  # 不允许交互时直接返回
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_interact_time < interact_cooldown:
			return  # 忽略短时间的重复触发
		last_interact_time = now
		var interacted = interact_raycast.get_collider()
		if interacted != null and interacted.is_in_group("Interactable") and interacted.has_method("action_use"):
			is_playing_interact = true
			play_anim("interact",interact_anim_speed)
			interacted.action_use()
			await character_animation_player.animation_finished
			is_playing_interact = false
			play_anim("idle")
	if (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED) and event is InputEventMouseButton: 
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		

func start_urinating():
	is_urinating = true
	urine_raycast.enabled = true
	urine_stream.emitting = true
	urine_start_time = Time.get_ticks_msec() / 1000.0

	
func end_urinating():
	is_urinating = false
	urine_raycast.enabled = false
	urine_stream.emitting = false
	splash_sound.stop()
	
func urine_check():
	urine_raycast.force_raycast_update()
	if urine_raycast.is_colliding():
		var hit_position = urine_raycast.get_collision_point()
		var hit_object = urine_raycast.get_collider()
		var surface_type = ""
			
		# 将水花粒子放到碰撞点
		#splash_particles.global_position = hit_position + Vector3(0, 0.2, 0)
		splash_sound.global_position = hit_position
				# 检测表面类型
		if hit_object.is_in_group("toilet_surface"):
			surface_type = "toilet"
		elif hit_object.is_in_group("floor_surface"):
			surface_type = "floor"
		else:
			surface_type = "unknown"
		
		# 如果表面类型发生变化
		if surface_type != last_surface:
			last_surface = surface_type

			match surface_type:
				"toilet":
					splash_sound.stream = preload("res://sfx/long-pee-67138.mp3")
					splash_sound.play()
					splash_sound.pitch_scale = randf_range(0.95, 1.05)
				"floor":
					splash_sound.stream = preload("res://sfx/spilling-water-on-the-floor-7004.mp3")
					splash_sound.play()
					splash_sound.pitch_scale = randf_range(0.95, 1.15)
				_:
					splash_sound.stop()  # 如果换到未知表面就停掉声音

func trigger_scare_effect(config := {}):
	# 播放呼吸声
	var breathing_volume = config.get("breathing_volume", -5)
	var breathing_pitch = config.get("breathing_pitch", 1.2)
	if sound_breathing:
		sound_breathing.pitch_scale = breathing_pitch
		sound_breathing.volume_db = breathing_volume
		sound_breathing.play()
		
		# 心跳渐变参数
	var hb_start_bpm = config.get("heartbeat_start_bpm", 90.0)
	var hb_end_bpm = config.get("heartbeat_end_bpm", 60.0)
	var hb_duration = config.get("heartbeat_duration", 3.0)
	start_dynamic_heartbeat(hb_start_bpm, hb_end_bpm, hb_duration)
	
	
	# 转头动画（整合摄像头转动配置）
	var look_yaw = config.get("look_yaw", 180.0)
	var look_pitch = config.get("look_pitch", 0.0)
	var look_duration = config.get("look_duration", 0.4)
	var look_overshoot = config.get("look_overshoot", 1.1)
	var look_return = config.get("look_return", true)
	var look_return_duration = config.get("look_return_duration", 0.3)
	
	await camera_turn_around(
		look_yaw,
		look_pitch,
		look_duration,
		look_overshoot,
		look_return,
		look_return_duration
	)

	
	# 转头动画
	var player_angle = config.get("turn_angle", 180.0)
	var player_turn_duration = config.get("turn_duration", 0.4)
	await player_turn_around(player_angle, player_turn_duration)
	
	# 抖动
	var shake_dur = config.get("shake_duration", 0.4)
	var shake_val = config.get("shake_intensity", 0.05)
	start_camera_shake(shake_val, shake_dur)

#only turning camera
#overshoot = 1.0	没有“过头”，直接精准转过去
#overshoot = 1.2	转多一点后弹回来，更“吓到”
#return_to_center = false	不回正，保持当前视角
#degrees_pitch = -20	抬头（负值），向上看
#degrees_pitch = 20	低头（正值），向下看
func camera_turn_around(
	degrees_yaw: float = 180.0,
	degrees_pitch: float = 0.0,
	duration: float = 0.4,
	overshoot: float = 1.1,
	return_to_center := true,
	return_duration := 0.3
):
	var current_rot = camera.rotation
	var overshoot_yaw = deg_to_rad(degrees_yaw * overshoot)
	var overshoot_pitch = deg_to_rad(degrees_pitch * overshoot)

	var target_rot = current_rot
	target_rot.y += overshoot_yaw
	target_rot.x += overshoot_pitch
	target_rot.x = clamp(target_rot.x, deg_to_rad(-89), deg_to_rad(89))

	# 第一段：惊吓转头（带惯性）
	var tween = create_tween()
	tween.tween_property(camera, "rotation", target_rot, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	# 第二段：轻微回弹（往回一点）
	var bounce_rot = camera.rotation
	bounce_rot.y -= deg_to_rad(degrees_yaw * (overshoot - 1.0))
	bounce_rot.x -= deg_to_rad(degrees_pitch * (overshoot - 1.0))
	bounce_rot.x = clamp(bounce_rot.x, deg_to_rad(-89), deg_to_rad(89))

	tween = create_tween()
	tween.tween_property(camera, "rotation", bounce_rot, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	# 第三段：镜头回中（仅 pitch，也可回 yaw）
	if return_to_center:
		var reset_rot = camera.rotation
		reset_rot.x = lerp(reset_rot.x, 0.0, 1.0)
		reset_rot.y = lerp(reset_rot.y, 0.0, 1.0)  # 可选：回正 yaw
		tween = create_tween()
		tween.tween_property(camera, "rotation", reset_rot, return_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		await tween.finished

	
#turning the whole player
func player_turn_around(degrees: float, duration: float):
	var current_rotation = global_rotation
	var target_rotation = current_rotation
	target_rotation.y += deg_to_rad(degrees)
	var tween = create_tween()
	tween.tween_property(self, "rotation:y", target_rotation.y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished	
	
func start_camera_shake(intensity := 0.05, duration := 0.4):
	shake_time = duration
	shake_intensity = intensity
	shake_timer = 0.0
	original_cam_pos = camera.transform.origin
	# 动态连接 process_frame 信号
	if not get_tree().is_connected("process_frame", Callable(self, "_on_camera_shake_frame")):
		get_tree().connect("process_frame", Callable(self, "_on_camera_shake_frame"))

func _on_camera_shake_frame():
	if shake_timer < shake_time:
		shake_timer += get_process_delta_time()
		var offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0
		)
		camera.transform.origin = original_cam_pos + offset
	else:
		camera.transform.origin = original_cam_pos
		shake_timer = 0.0
		get_tree().disconnect("process_frame", Callable(self, "_on_camera_shake_frame"))


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
		
		
#创建一个播放动画的辅助函数（避免重复切换）
func play_anim(name: String, speed: float = 1.0):
	if is_playing_interact and name != "interact":
		return  # 播放交互动画时禁止切换其他动画
	if current_anim == name:
		return
	current_anim = name
	if character_animation_player.has_animation(name):
		character_animation_player.play(name, -1, speed)
		
func can_interact() -> bool:
	# 状态限制
	if current_state in [PlayerState.DIALOGUE, PlayerState.FROZEN, PlayerState.PEE]:
		return false
	# 外部事件限制
	if not allow_interact:
		return false
	return true
#角色身体旋转逻辑，跟随移动方向
func update_body_rotation(delta):
	if direction.length() < 0.1:
		return  # 没有移动，不旋转

	# 当前相机（头部）朝向
	var camera_yaw = camera.global_transform.basis.get_euler().y
	# 移动方向朝向
	var move_yaw = atan2(-direction.x, -direction.z)
	
	# 计算夹角
	var diff = abs(ang_wrap(move_yaw - camera_yaw))  # wrap到 [-π, π]
	
	if rad_to_deg(diff) > backward_threshold:
		# 超过阈值 → 倒退
		is_backpedaling = true
		# 倒退时身体保持面向相机方向（不翻转）
		var target_rot = camera_yaw
		body_node.rotation.y = lerp_angle(body_node.rotation.y, target_rot, delta * body_turn_speed)
	else:
		# 正常前进
		is_backpedaling = false
		body_node.rotation.y = lerp_angle(body_node.rotation.y, move_yaw, delta * body_turn_speed)
		
		
func ang_wrap(angle):
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle
	
#视角锁函数，使玩家在一定范围内移动视角
func set_view_lock(enabled: bool, center_yaw_deg: float, half_yaw_deg: float, center_pitch_deg: float, half_pitch_deg: float) -> void:
	view_lock_enabled = enabled
	lock_center_yaw   = deg_to_rad(center_yaw_deg)
	lock_half_yaw     = deg_to_rad(max(0.0, half_yaw_deg))
	lock_center_pitch = deg_to_rad(center_pitch_deg)
	lock_half_pitch   = deg_to_rad(max(0.0, half_pitch_deg))
	_apply_view_lock_now()

func _apply_view_lock_now() -> void:
	if not view_lock_enabled:
		return
	rotation.y = clamp(rotation.y, lock_center_yaw - lock_half_yaw, lock_center_yaw + lock_half_yaw)
	camera.rotation.x = clamp(camera.rotation.x, lock_center_pitch - lock_half_pitch, lock_center_pitch + lock_half_pitch)
	
#平滑面向目标（只转水平朝向）	
func face_target_y(target: Vector3, duration := 0.5) -> void:
	# 用引擎的 looking_at 得到“应该朝向 target”的变换\
	var t := global_transform.looking_at(target, Vector3.UP)
	var target_yaw := t.basis.get_euler().y
	# 如果你的模型前方是 +Z（而非默认 -Z），加 PI 翻转一下：
	# target_yaw += PI

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rotation:y", target_yaw, duration)
	await tw.finished
	
	
# "吸附到站位并朝向目标"的万能函数
# 
# 参数说明：
# - spot: Node3D - 玩家要移动到的目标位置
# - look_target: Node3D - 玩家要看向的目标位置
# - move_time: float = 1.0 - 移动到目标位置所需时间（秒）
# - face_time: float = 0.5 - 转向目标方向所需时间（秒）
# - lock_yaw_half: float = 18.0 - 视角锁定：水平方向允许转动的半角范围（度）
#   （例如：20.0 表示可以在当前朝向左右各20度范围内转动）
# - lock_pitch_center: float = 0.0 - 视角锁定：垂直方向的中心角度（度）
#   （通常设为0，表示以水平方向为中心）
# - lock_pitch_half: float = 10.0 - 视角锁定：垂直方向允许转动的半角范围（度）
#   （例如：10.0 表示可以在中心角度上下各10度范围内转动）
#
# 功能说明：
# 1. 禁用玩家输入
# 2. 平滑移动到指定位置
# 3. 平滑转向看向指定目标
# 4. 应用视角锁定，限制玩家视角移动范围
# 5. 重新启用玩家输入（允许在锁定范围内移动视角）
#
# 使用示例：
# await escort_to_spot(standPoint, lookPoint, 1.0, 0.5, 20.0, 0.0, 20.0)
# 这将把玩家移动到standPoint，用1秒移动，0.5秒转向看向lookPoint，
# 然后限制视角在水平±20度、垂直±10度范围内移动
func escort_to_spot(spot: Node3D, look_target: Node3D, move_time := 1.0, face_time := 0.5, lock_yaw_half := 18.0, lock_pitch_center := 0.0, lock_pitch_half := 10.0) -> void:
	set_input_enabled(false)
	# 平滑移动到站位
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", spot.global_position, move_time)
	await tw.finished

	# 计算看向目标时需要的垂直角度
	var target_vector = look_target.global_position - camera.global_position
	var target_pitch = atan2(-target_vector.y, Vector2(target_vector.x, target_vector.z).length())
	target_pitch = clamp(target_pitch, deg_to_rad(-89), deg_to_rad(89))  # 限制在相机范围内

	# 同时平滑旋转水平朝向和垂直视角
	var tw2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.parallel().tween_method(face_target_y, global_position, look_target.global_position, face_time)
	tw2.parallel().tween_property(camera, "rotation:x", target_pitch, face_time)
	await tw2.finished

	# 锁定视角（以当前 yaw 和 pitch 为中心）
	_lock_view_around_current(lock_yaw_half, lock_pitch_half)
	
	# 重新启用输入，但保持视角锁定，允许在限制范围内移动视角
	set_input_enabled(true)

func _lock_view_around_current(yaw_half := 18.0, pitch_half := 10.0) -> void:
	var yaw_deg := rad_to_deg(rotation.y)
	var pitch_deg := rad_to_deg(camera.rotation.x)  # 使用当前相机的pitch值
	set_view_lock(true, yaw_deg, yaw_half, pitch_deg, pitch_half)
func unlock_and_enable_control() -> void:
	set_view_lock(false, 0, 999, 0, 999)
	
#角色头部旋转逻辑，跟随鼠标方向
func update_head_rotation():
	var head_bone = skeleton.find_bone("mixamorig_Head")
	if head_bone == -1:
		return

	# 相机与身体的相对旋转
	var relative_yaw = clamp(camera.rotation.y - body_node.rotation.y, deg_to_rad(-max_head_turn), deg_to_rad(max_head_turn))
	var relative_pitch = clamp(camera.rotation.x, deg_to_rad(-max_head_pitch), deg_to_rad(max_head_pitch))
	var target_rot = Quaternion.from_euler(Vector3(relative_pitch, relative_yaw, 0))

	# 更强烈跟随，减少插值延迟（0.5→0.8）
	var current_rot = skeleton.get_bone_pose_rotation(head_bone)
	var new_rot = current_rot.slerp(target_rot, 0.8)  # 越接近1越“跟手”
	skeleton.set_bone_pose_rotation(head_bone, new_rot)
	
func get_camera_relative_input() -> Vector3:
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var move_dir = (camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	return move_dir
	
	
