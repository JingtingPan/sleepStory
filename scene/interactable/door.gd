extends Interactable
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var is_locked := false
@export_node_path("Area3D") var key_path
var actual_key
var is_opened := false
var can_interact := true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if key_path!=null:
		actual_key = get_node(key_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func action_use():
	if is_locked and !is_instance_valid(actual_key):
		is_locked = false
		
	if !is_locked: 
		if can_interact:
			if is_opened:
				close()
			else:
				open()
	else:
		animation_player.play("door_locked")
		
		
func open():
	animation_player.play("door_open")
	can_interact = false
	is_opened = true
	
func close():
	animation_player.play("door_close")
	can_interact = false
	is_opened = false
	



func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	can_interact = true
