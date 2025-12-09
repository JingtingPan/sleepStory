extends Node3D

signal event_started(name)
signal event_ended(name)

@onready var event_ui: EventUI = get_node("/root/child_room/CanvasLayer/EventUI")
@onready var balcony_audio : AudioStreamPlayer3D = get_node("/root/child_room/EventManager/balconyEvent/AudioStreamPlayer3D")
@onready var blackout: ColorRect = get_node("/root/child_room/CanvasLayer/BlackOut")

@onready var player_stand: StandingPlayer = get_node("/root/child_room/player_stand")
@onready var player_stand_camera : Camera3D = get_node("/root/child_room/player_stand/Camera3D")
@onready var player_sleep: SleepingPlayer = get_node("/root/child_room/player_sleep")
@onready var transition_manager: Node3D = get_node("/root/child_room/TransitionManager")
@onready var sink_player: AnimationPlayer = get_node("/root/child_room/toilet_room1/sink/AnimationPlayer")
@onready var task_hint_manager = get_node("/root/child_room/CanvasLayer/TaskHintManager")
@onready var living_room_audio: AudioStreamPlayer3D = get_node("/root/child_room/EventManager/livingroomEvent/AudioStreamPlayer3D")
#slender sitation
@onready var slender_bedroom: Node3D = get_node("/root/child_room/child_room/slender")
@onready var slender_toilet: Node3D = get_node("/root/child_room/toilet_room1/Slender")
@onready var slender_livingroom: Node3D = get_node("/root/child_room/living_room/Slender")

@onready var light_manager: LightManager = get_node("/root/child_room/LightManager")
@onready var curtain_1_animation_player: AnimationPlayer = get_node("/root/child_room/child_room/bed/curtain1/AnimationPlayer")
@onready var sinkTrigger: Interactable = get_node("/root/child_room/EventManager/toiletEvent/SinkTrigger")
@onready var lightning_control: Node3D = get_node("/root/child_room/LightningControl")
@onready var curtain_1: Node3D = get_node("/root/child_room/child_room/bed/curtain1")
# 新增：特定灯光引用
@onready var toilet_light: Node3D = get_node("/root/child_room/toilet_room1/light")

#位置坐标
@onready var monster_from: Node3D = get_node("/root/child_room/EventManager/childroomEvent/Monster_from")
@onready var monster_to: Node3D = get_node("/root/child_room/EventManager/childroomEvent/Monster_to")
@onready var monster_lookat: Node3D = get_node("/root/child_room/EventManager/childroomEvent/Monster_lookat")
@onready var balcony_standPoint: Node3D = get_node("/root/child_room/EventManager/balconyEvent/balcony/standPoint")
@onready var balcony_lookat: Node3D = get_node("/root/child_room/EventManager/balconyEvent/balcony/lookPoint")
@onready var balcony_lookback: Node3D = get_node("/root/child_room/EventManager/balconyEvent/balcony/lookBackPoint")




# 用于记录已触发的事件
var TRAFFIC_IN_CITY_sound = "res://sfx/environment/traffic-in-city-309236.mp3"
const BIB_CLICK = preload("res://sfx/jumpscare/Bib-Click.wav")
const BIG_BANG = preload("res://sfx/jumpscare/Big Bang.wav")
const GASP = preload("res://sfx/player/gasp-sfx-351568.mp3")
const HEAVY_BREATHING = preload("res://sfx/player/heavy_breathing.mp3")
const FALLING_OF_HEAVY = preload("res://sfx/jumpscare/falling-of-heavy.mp3")
const ANKER = preload("res://sfx/jumpscare/Anker.wav")
const DRUM_REVERB = preload("res://sfx/jumpscare/Drum Reverb.wav")
const GHOST_BREATH = preload("res://sfx/monster/ghost-breath.mp3")
const RUN = preload("res://sfx/jumpscare/Run.wav")
var triggered_events: Dictionary = {}  # event_name -> bool
var event_dependencies: Dictionary = {
	"so_dark": ["go_to_bed_auto"],
	"balcony": ["thirsty"],
	"flashy": ["balcony"],
	"adjust": ["so_dark", "balcony"],
	"go_to_bed_player": [],
	"go_to_bed_auto":[],
	"use_the_toilet":[],
	"wash_hands":[]
}

func _ready():
	await get_tree().process_frame  # 等一帧，确保所有子节点就绪
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(event_ui):
		start_event("thirsty")
	else:
		push_error("event_ui 为空！")
	light_manager.connect("all_lights_off", Callable(self, "_on_ready_to_sleep"))
	transition_manager.player_switch_to_standing_mode()
	switch_to_player_bed_trigger()

func start_event(event_name: String) -> void:
	if triggered_events.has(event_name):
		print("事件已触发过:", event_name)
		return
	if event_dependencies.has(event_name):
		for prereq in event_dependencies[event_name]:
			if not triggered_events.has(prereq):
				print("事件未满足依赖条件:", event_name)
				return
	triggered_events[event_name] = true
	print("开始事件:", event_name)
	emit_signal("event_started", event_name)

	match event_name:
		"drink_water":
			await _drink_water_event()
		"so_dark":
			await  so_dark()
		"thirsty":
			await thirsty()
		"adjust":
			await  fade_from_black()
		"balcony":
			await balcony()
		"flashy":
			await flashy()
		"go_to_bed_player":
			await go_to_bed_player()
		"go_to_bed_auto":
			await go_to_bed_auto()
		"use_the_toilet":
			await  use_the_toilet()
		"wash_hands":
			await wash_hands()
		_:
			print("未知事件:", event_name)
	update_task_hint(event_name)
	emit_signal("event_ended", event_name)

func can_trigger(name: String) -> bool:
	if not event_dependencies.has(name):
		return true  # 如果没写依赖，默认允许触发

	for prereq in event_dependencies[name]:
		if not triggered_events.has(prereq):
			return false
	return true

func update_task_hint(event_name: String) -> void:
	match event_name:
		"thirsty":
			task_hint_manager.show_hint("Find something to drink in the kitchen")
		"drink_water":
			task_hint_manager.show_hint("Found out what happened at the balcony")
		"balcony":
			task_hint_manager.show_hint("Get some rest")
		"go_to_bed_auto":
			task_hint_manager.show_hint("I need to use the toilet")
		"use_the_toilet":
			task_hint_manager.show_hint("Wash your hands")
		"wash_hands":
			task_hint_manager.show_hint("Back to sleep, again")
		_:
			task_hint_manager.hide_hint()
	
func fade_from_black():
	blackout.visible = true
	blackout.color = Color(0, 0, 0, 1.0)  # 全黑
	var tween = create_tween()
	tween.tween_property(blackout, "modulate:a", 0.1, 4.0)  # 4秒淡出
	await tween.finished
	blackout.visible = false
	
func switch_to_player_sleep_trigger():
	var auto_trigger = get_node_or_null("/root/child_room/EventManager/childroomEvent/BedTrigger")
	var player_trigger = get_node_or_null("/root/child_room/EventManager/childroomEvent/SleepTrigger")

	if auto_trigger:
		auto_trigger.get_node("CollisionShape3D").disabled = true

	if player_trigger:
		player_trigger.get_node("CollisionShape3D").disabled = false

	print("✅ 已切换至玩家交互睡觉模式")
	
func switch_to_player_bed_trigger():
	var auto_trigger = get_node_or_null("/root/child_room/EventManager/childroomEvent/BedTrigger")
	var player_trigger = get_node_or_null("/root/child_room/EventManager/childroomEvent/SleepTrigger")

	if auto_trigger:
		auto_trigger.get_node("CollisionShape3D").disabled = false

	if player_trigger:
		player_trigger.get_node("CollisionShape3D").disabled = true

	#print("✅ 已切换至玩家交互睡觉模式")
#events

func _on_ready_to_sleep():
	pass
	#event_ui.show_text("finally")
	#start_event("go_to_bed")

func go_to_bed_player() -> void:
	
	await event_ui.show_text_and_wait("Back to bed...")
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await transition_manager.switch_to_player_mode()
	#在怪物出来前加一些自我独白和闪电
	await get_tree().create_timer(2.0).timeout
	await event_ui.show_text_and_wait("So bored...")
	await get_tree().create_timer(3.0).timeout
	lightning_control.lightning_on = false
	await get_tree().create_timer(2.0).timeout
	#打闪电
	await lightning_control.play_lightning_once(1.2,1)
	
	
	#播放悬疑音效
	player_sleep.player_sound.stream = ANKER
	player_sleep.player_sound.play()
	#怪物走向玩家、玩家触发心跳、呼吸声等
	player_sleep.start_dynamic_heartbeat(100, 150, 5.0,true)  

	await slender_bedroom.appear_and_move(monster_from.global_position, monster_to.global_position,8.0)
	slender_bedroom.play_animation("idle")
	# 获取当前朝向
	var start_rot = slender_bedroom.global_transform.basis.get_euler()

	# 获取目标朝向（先用 look_at 计算出来，但不直接赋值）
	var temp_transform = slender_bedroom.global_transform.looking_at(monster_lookat.global_position, Vector3.UP)
	var target_rot = temp_transform.basis.get_euler()
	slender_bedroom.audio_stream.stream = GHOST_BREATH
	slender_bedroom.audio_stream.play()
	# 用 Tween 在 1.5 秒内从当前旋到目标
	var tw = create_tween()
	tw.tween_property(slender_bedroom, "rotation", target_rot, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	var player_trigger = get_node_or_null("/root/child_room/EventManager/childroomEvent/SleepTrigger")
	player_trigger.get_node("CollisionShape3D").disabled = true
	player_sleep.enable_context_interact("Open curtain", 0.8, 2)
		# 接信号完成后做事（闪电 + 怪物消失等）
	if not player_sleep.is_connected("context_interact_finished", Callable(self, "_on_bed_curtain_open")):
		player_sleep.connect("context_interact_finished", Callable(self, "_on_bed_curtain_open"))
	
	#怪物抽搐
	slender_bedroom.play_animation("twitching")
	#玩家打开窗帘、播放打开窗帘动画
	#闪电、怪物消失
	
func _on_bed_curtain_open():
	# 闪电
	player_sleep.can_turn = false
	slender_bedroom.audio_stream.stop()
	await player_sleep.play_anim("interact",2.0)
	var curtain_anim = curtain_1.get_node("AnimationPlayer")
	player_sleep.player_sound.stream = DRUM_REVERB
	player_sleep.player_sound.play()
	curtain_anim.play("door_open")
	lightning_control.play_lightning_once(1.5, 0)
	# 例如：让窗帘动画播放、怪物消失
	# curtain_anim.play("open")   # 如果需要的话
	if slender_bedroom.has_method("disappear"):
		await slender_bedroom.disappear()
	else:
		slender_bedroom.visible = false
	

	# 这次交互结束后关闭上下文交互，避免再次触发
	player_sleep.disable_context_interact()
	player_sleep.can_turn = true
	await get_tree().create_timer(1.0).timeout
	player_sleep.sound_breathing.stream = HEAVY_BREATHING
	player_sleep.sound_breathing.play()
	player_sleep.start_dynamic_heartbeat(150,70,10.0,false)
	

func go_to_bed_auto():
	await event_ui.show_text_and_wait("Back to sleep...")
	await get_tree().process_frame
	await transition_manager.switch_to_auto_mode()
	await get_tree().create_timer(1.0).timeout
	#await event_ui.show_text_and_wait("testing testing")
	await transition_manager.auto_switch_to_standing_mode()
	await event_ui.show_text_and_wait("I need to pee...")
	switch_to_player_sleep_trigger()
	

func use_the_toilet():
	player_stand.current_state = player_stand.PlayerState.PEE
	await player_stand.start_urinating()
	await get_tree().create_timer(5.0).timeout
	await event_ui.show_text_and_wait("I need to wash my hands")
	player_stand.current_state = player_stand.PlayerState.NORMAL

func wash_hands():
	player_stand.current_state = player_stand.PlayerState.DIALOGUE
	player_stand.allow_interact = false
	
	var sink_standPoint = sinkTrigger.get_node("standPoint") 
	var sink_lookat = sinkTrigger.get_node("lookPoint")

	
	await player_stand.escort_to_spot(
		sink_standPoint,         # 移动目标位置
		sink_lookat,      # 看向目标位置
		1.0,                   # 移动时间1秒
		0.5,                   # 转向时间0.5秒
		20.0,                   # 水平视角锁定范围：0度（完全锁定）
		0.0,                   # 垂直中心角度：水平方向
		20.0                    # 垂直视角锁定范围：0度（完全锁定）
	)
	sink_player.play("open_tap")
	#加一个使玩家移动指定位置并面向指定方向，最后回头看向怪物方向
	#在怪物出现之前厕所的灯突然一闪一闪，然后再出现怪物
	
	
	await get_tree().create_timer(0.4).timeout
	sink_player.play("run_tap")
	#抬头
	#player_stand.camera_turn_around(
		#0,         # 不水平转，只抬头
		#30,        # 抬头30度
		#3.0,       # 动作时间
		#1.15,      # 惯性
		#true,      # 回正
		#0.4
	#)
	await get_tree().create_timer(2.0).timeout
	#记录灯的原亮度以便恢复
	var light_energy = 4.0
	#灯闪烁
	toilet_light.trigger_flicker(
	20,    # 闪烁次数
	0.1,   # 最小亮度
	4.0,   # 最大亮度
	2.0    # 恢复亮度
	)
	player_stand.player_sound.stream = RUN
	player_stand.player_sound.play()
	await get_tree().create_timer(3.0).timeout
	event_ui.show_text_and_wait("What...")
	player_stand.start_dynamic_heartbeat(80, 100, 5.0,false)
	toilet_light.trigger_flicker(
	25,    # 闪烁次数
	0.1,   # 最小亮度
	4.0,   # 最大亮度
	0.1    # 恢复亮度
	)
	await get_tree().create_timer(5.0).timeout
	#厕所怪物显形
	slender_toilet.visible = true
	#播放jumpscare音效
	player_stand.player_sound.stream = BIB_CLICK
	player_stand.player_sound.play()
	# ✅ 玩家镜头震动立刻执行
	player_stand.start_camera_shake(0.1, 0.3)  
	#播放倒吸音效
	player_stand.sound_breathing.stream = GASP
	player_stand.sound_breathing.play()
	# ✅ 心跳逐渐增强 130 -》 110 持续5s
	player_stand.start_dynamic_heartbeat(130, 110, 5.0,false)  
	await get_tree().create_timer(0.5).timeout  # 等震动播放完
	##
	##最好加一个怪物伸手抓向主角的动作
	##
		# ② 第二步：再抬头看 Slender（转头）
	player_stand.set_view_lock(false, 0, 0, 0, 0)
	player_stand.face_target_y(slender_toilet.global_position, 0.3)
	#player_stand.player_turn_around(180, 0.3)
	#播放玩家喘息声
	player_stand.sound_breathing.stream = HEAVY_BREATHING
	player_stand.sound_breathing.play()
	await get_tree().create_timer(2.0).timeout
	toilet_light.trigger_flicker(
	20,    # 闪烁次数
	0.1,   # 最小亮度
	3.0,   # 最大亮度
	light_energy    # 恢复亮度
	)
	#怪物消失
	slender_toilet.visible = false
	sink_player.play("run_tap")
	#玩家回头
	player_stand.face_target_y(sink_lookat.global_position, 1.5)
	await get_tree().create_timer(4.0).timeout
	sink_player.play("close_tap")
	await event_ui.show_text_and_wait("I should really go to bed now")
	
	
	player_stand.set_input_enabled(true)
	player_stand.unlock_and_enable_control()
	player_stand.allow_interact = true
	player_stand.current_state = player_stand.PlayerState.NORMAL
	
func flashy() -> void:
	await event_ui.show_text_and_wait("did I just saw something...")
	
func balcony() -> void:
	player_stand.current_state = player_stand.PlayerState.DIALOGUE
	player_stand.allow_interact = false
	# ① 交互触发成功 → 吸附到阳台位并面向阳台（同时限视角）
	await player_stand.escort_to_spot(balcony_standPoint, balcony_lookat, 1.0, 0.5, 20.0, 0.0, 20.0)
	await event_ui.show_text_and_wait("Just another traffic...")
	await get_tree().create_timer(1.0).timeout
	await event_ui.show_text_and_wait("...")
	await event_ui.show_text_and_wait("I've tried so hard...")
	await lightning_control.trigger_lightning_immediate(lightning_control.PlayerLocation.BALCONY, 0.0, 4)
	await event_ui.show_text_and_wait("Why can't they just be satisified for once...")
	await get_tree().create_timer(1.0).timeout
	living_room_audio.stream = FALLING_OF_HEAVY
	living_room_audio.play()
	await get_tree().create_timer(0.5).timeout
	#player_stand.player_sound.stream = BIB_CLICK
	#player_stand.player_sound.play()
	# ③ 惊吓后，强制回头看指定点
	# ③ 惊吓前——先关掉锁
	player_stand.set_view_lock(false, 0, 0, 0, 0)
	player_stand.face_target_y(balcony_lookback.global_position, 0.3)
	#player_stand.trigger_scare_effect({
	#"look_yaw": 0,
	#"look_pitch": 0,
	#"look_duration": 0.0,
	#"look_overshoot": 0.0,
	#"look_return": false,
	#"look_return_duration": 0.0,	
	#"turn_angle": 0.0,
	#"heartbeat_start_bpm": 130,
	#"heartbeat_end_bpm": 80,
	#"heartbeat_duration": 6.0,
	#"shake_intensity": 0.1,
	#"shake_duration": 0.5
#})
	# ✅ 心跳逐渐增强 130 -》 110 持续5s
	player_stand.start_dynamic_heartbeat(130, 80, 6.0,false)
	#镜头抖动，强度0.1，时间0.8s
	player_stand.start_camera_shake(0.1,0.8)
	
	await get_tree().create_timer(1.5).timeout
	await event_ui.show_text_and_wait("What was that...?")
	await event_ui.show_text_and_wait("I should go back to bed now")
	#slender.visible = true
	player_stand.unlock_and_enable_control()
	player_stand.allow_interact = true
	player_stand.current_state = player_stand.PlayerState.NORMAL
	
	
func thirsty() -> void:
	player_stand.current_state = player_stand.PlayerState.DIALOGUE
	await event_ui.show_text_and_wait("I'm so thirsty")
	await event_ui.show_text_and_wait("Need to get something to drink from the kitchen...")
	player_stand.current_state = player_stand.PlayerState.NORMAL


func so_dark() -> void:
	await event_ui.show_text_and_wait("So dark...")
	lightning_control.update_player_location(lightning_control.PlayerLocation.INDOOR)
	# 手动触发一次闪电
	lightning_control.trigger_lightning_immediate(lightning_control.PlayerLocation.INDOOR, 0.0,0)
	slender_livingroom.visible = true
	await get_tree().create_timer(0.3).timeout
	slender_livingroom.visible = false
	
		#玩家第一次起床后开始打雷
	lightning_control.lightning_enabled = true



func _drink_water_event() -> void:
	# 播放独白
	player_stand.current_state = player_stand.PlayerState.DIALOGUE
	player_stand.animation_player.play("drink_coke")

	await get_tree().create_timer(8.5).timeout
	await event_ui.show_text_and_wait("Wooo that was good")

	# 播放喝水动画/音效
	
	#player.play_drink_animation()
	
	balcony_audio.stream = load(TRAFFIC_IN_CITY_sound)
	balcony_audio.play()
	# 等待几秒让动画完成
	await get_tree().create_timer(1.0).timeout
	
	# 内心独白
	await event_ui.show_text_and_wait("Is there noise coming from the balcony?")
	player_stand.current_state = player_stand.PlayerState.NORMAL
