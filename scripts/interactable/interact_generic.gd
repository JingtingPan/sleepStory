class_name Interactable
extends Area3D

@export var type : String = "Interactable"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func action_use():
	print("interacted")
