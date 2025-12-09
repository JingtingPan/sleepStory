extends Area3D
@export var pathToNextLevel : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_body_entered(body: Node3D) -> void:
	if body is StandingPlayer and pathToNextLevel!="":
		get_tree().change_scene_to_file(pathToNextLevel)
	else:
		assert(!pathToNextLevel == "","path to next level is empty")
		
