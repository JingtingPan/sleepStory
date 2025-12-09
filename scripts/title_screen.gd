extends Control

@onready var new_game: Button = $VBoxContainer/NewGame

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_game.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_new_game_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # 捕获鼠标
	get_tree().change_scene_to_file("res://scene/child_room.tscn")  # 替换为你的游戏场景路径


func _on_load_game_pressed() -> void:
	pass # Replace with function body.


func _on_exit_game_pressed() -> void:
	get_tree().quit()
