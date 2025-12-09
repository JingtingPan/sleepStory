extends Interactable
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var actual_key
var is_opened := false
var can_interact := true
@onready var omni: OmniLight3D = $OmniLight3D
@onready var omni_3: OmniLight3D = $OmniLight3D3
@onready var omni_2: OmniLight3D = $OmniLight3D2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func action_use():
	if can_interact:
		if is_opened:
			close()
		else:
			open()
		
		
func open():
	animation_player.play("door_open")
	can_interact = false
	is_opened = true
	omni.visible = true
	omni_2.visible = true
	omni_3.visible = true
	
func close():
	animation_player.play("door_close")
	can_interact = false
	is_opened = false
	omni.visible = false
	omni_2.visible = false
	omni_3.visible = false
	



func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	can_interact = true
