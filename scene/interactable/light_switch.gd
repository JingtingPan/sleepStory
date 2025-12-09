extends Interactable
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export_node_path("OmniLight3D") var light_path
@export var normal_light_energy = 4.0
@export var is_on := true
@onready var lamps_02: MeshInstance3D = $"../Lamps_02"
@onready var lamps_06: MeshInstance3D = $"../Lamps_06"
@export var light_id: String = ""  # 灯的唯一ID，供事件管理器识别
@onready var light_manager: LightManager = get_node("/root/child_room/LightManager")
var mat1 
var mat2 
var light
var can_interact := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if light_path!=null:
		light = get_node(light_path)
	var mat1 := lamps_02.get_active_material(1).duplicate()
	var mat2 := lamps_06.get_active_material(1).duplicate()
	if mat1:
		lamps_02.set_surface_override_material(1, mat1)
			
	if mat2:
		lamps_06.set_surface_override_material(1, mat2)
	_update_state()	
		# 自动注册状态到 LightManager
	if light_manager and light_id != "":
		light_manager._on_light_state_changed(light_id, is_on)
		
func _update_state():
	if is_on:
		light.light_energy = normal_light_energy
		#mat1.emission_energy = 1.0
		#mat2.emission_energy = 1.0
	else:
		light.light_energy = 0.0
		#mat1.emission_energy = 0.0
		#mat2.emission_energy = 0.0
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func action_use():
	if can_interact:
		if is_on:
			close()
		else:
			open()
		
		
func open():
	animation_player.play("light_on")
	can_interact = false
	is_on = true
	_update_state()
	if light_manager:
		light_manager._on_light_state_changed(light_id, true)

	
func close():
	animation_player.play("light_off")
	can_interact = false
	is_on = false
	_update_state()
	if light_manager:
		light_manager._on_light_state_changed(light_id, false)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	can_interact = true
