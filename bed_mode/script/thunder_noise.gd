extends AudioStreamPlayer

@export var audio_clips: Array[AudioStream] = []

@onready var audio = $"."
@onready var timer = $"../Timer"


@export var min_delay := 10.0 # 最小间隔秒数
@export var max_delay := 30.0  # 最大间隔秒数
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	timer.start(randf_range(min_delay, max_delay))

func _on_timer_timeout():
	play_and_schedule_next()
	
func play_and_schedule_next():
	var clip = audio_clips.pick_random()
	audio.stream = clip
	audio.play()
	# 打印当前播放的音频资源路径（或名字）
	print("播放音频：", clip.resource_path)
	timer.start(randf_range(min_delay, max_delay))
