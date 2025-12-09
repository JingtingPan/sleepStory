extends Node3D

# TransitionManager.gd
@onready var player_stand = $"../player_stand"
@onready var player_sleep= $"../player_sleep"
@onready var curtain_1_animation_player: AnimationPlayer = get_node("/root/child_room/child_room/bed/curtain1/AnimationPlayer")
func _ready() -> void:
	pass
	#player_switch_to_standing_mode()

func switch_to_player_mode():
	disable_player(player_stand)
	player_stand.current_state = player_stand.PlayerState.FROZEN
	player_stand.interact_label.visible = false
	enable_player(player_sleep)
	player_sleep.set_view_index(2)  # 左边
	player_sleep.enable_eye_toggle_after_delay()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# 设置床上摄像机为当前摄像机
	player_sleep.camera.current = true
	player_stand.camera.current = false
	await get_tree().create_timer(1.0).timeout
	curtain_1_animation_player.play("door_close")
	
func switch_to_auto_mode():
	disable_player(player_stand)
	player_stand.current_state = player_stand.PlayerState.FROZEN
	player_stand.interact_label.visible = false
	
	player_sleep.visible = true
		# 设置床上摄像机为当前摄像机
	player_sleep.camera.current = true
	player_stand.camera.current = false
	player_sleep.tilt_camera_left()
	await get_tree().create_timer(1.0).timeout
	curtain_1_animation_player.play("door_close")
	await get_tree().create_timer(1.0).timeout
	player_sleep.close_eyes()

func auto_switch_to_standing_mode():
	player_sleep.open_eyes()
	await get_tree().create_timer(1.0).timeout
	curtain_1_animation_player.play("door_open")
	await get_tree().create_timer(1.0).timeout
	player_sleep.reset_camera_tilt()
	await get_tree().create_timer(1.0).timeout
	player_sleep.visible = false

	enable_player(player_stand)
	player_stand.current_state = player_stand.PlayerState.NORMAL
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player_sleep.camera.current = false
	player_stand.camera.current = true
	
func player_switch_to_standing_mode():
	disable_player(player_sleep)
	enable_player(player_stand)
	player_stand.current_state = player_stand.PlayerState.NORMAL
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player_sleep.camera.current = false
	player_stand.camera.current = true

func disable_player(player):
	player.set_process(false)
	player.set_physics_process(false)
	player.visible = false
	
func enable_player(player):
	player.set_process(true)
	player.set_physics_process(true)
	player.visible = true
