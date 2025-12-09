# EventUI.gd
extends Control
class_name EventUI
@onready var tip_tween = get_tree().create_tween()
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

@onready var timer: Timer = $Timer
@onready var label = $RichTextLabel
@onready var continue_tip = $ContinueTip
@onready var tween = get_tree().create_tween()
@export var sound := ""
@export var dialoguePath := ""
@export var textSpeed := 0.03

var input_cooldown := false 
var dialogue : Array
var phraseNum := 0
var finished := false
var waiting := false
signal has_finished

func _ready() -> void:
	if sound!="":
		audio.stream = load(sound)
	timer.wait_time = textSpeed
	dialogue = getDialogue()
	assert(dialogue, "Dialogue not find")
	#nextPhrase()

func getDialogue():
	var f = FileAccess.open(dialoguePath,FileAccess.READ)
	assert(f.file_exists(dialoguePath),"File Path not exist")
	var json = f.get_as_text()
	var output = JSON.parse_string(json)
	if typeof(output) == TYPE_ARRAY:
		return output
	else:
		return []
		

	
func nextPhrase():
	if phraseNum >= len(dialogue):
		emit_signal("has_finished")
		queue_free()
		return
	finished = true
	label.bbcode_text = dialogue[phraseNum]["Text"]
	label.visible_characters = 0
	while label.visible_characters < len(label.text):
		label.visible_characters +=1
		timer.start()
		audio.pitch_scale = randf_range(.1,.4)
		audio.play()
		await timer.timeout
	finished = true
	phraseNum += 1
	return	
	
func show_text_and_wait(text: String) -> void:
	waiting = false  # 防止 _unhandled_input 立即触发
	await get_tree().process_frame  # 等待一帧确保输入不会立即被捕获
	await show_text(text)
	await wait_for_continue()
	
func show_text(text: String):
	label.bbcode_text = text
	label.visible = true
	label.visible_characters = 0
	while label.visible_characters < len(label.text):
		label.visible_characters +=1
		timer.start()
		audio.pitch_scale = randf_range(.1,.4)
		audio.play()
		await timer.timeout
	finished = true
	continue_tip.visible = true
	start_continue_tip_float()
	waiting = true
	label.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	await tween.finished  # <--- 等待淡入完成

func wait_for_continue():
	while waiting:
		await get_tree().process_frame
		
#continue tip float up and down
func start_continue_tip_float():
	tip_tween.kill()  # 先清除旧动画
	tip_tween = get_tree().create_tween()
	tip_tween.set_loops()  # 无限循环
	tip_tween.tween_property(continue_tip, "position:y", continue_tip.position.y - 10, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tip_tween.tween_property(continue_tip, "position:y", continue_tip.position.y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unhandled_input(event):
	if waiting and event.is_action_pressed("interact"):
		label.visible = false
		continue_tip.visible = false
		tip_tween.kill()
		waiting = false
