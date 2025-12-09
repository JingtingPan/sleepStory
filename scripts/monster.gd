extends Node3D
@onready var anim_player: AnimationPlayer = $pivot/slender/AnimationPlayer
@onready var audio_stream: AudioStreamPlayer3D = $AudioStreamPlayer3D
@export var appear_duration := 5.0
@export var disappear_duration := 1.0

func appear_and_move(from_pos: Vector3, to_pos: Vector3, appear_duration: float) -> void:
	global_position = from_pos
	visible = true
	look_at(to_pos)
	var tween = create_tween()
	play_animation("walk")
	tween.tween_property(self, "global_position", to_pos, appear_duration)
	await tween.finished

func play_animation(name: String) -> void:
	if anim_player and anim_player.has_animation(name):
		anim_player.play(name)
	else:
		print("Animation not found:", name)

func disappear(disappear_to = null) -> void:
	if disappear_to != null:
		var tween = create_tween()
		tween.tween_property(self, "global_position", disappear_to, disappear_duration)
		await tween.finished
	visible = false
