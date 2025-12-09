extends Node3D
var flicker_cooldown := 0.0
@onready var lamp = $OmniLight3D
@onready var flicker_sound: AudioStreamPlayer3D = $flickering
@onready var bg_sound: AudioStreamPlayer3D = $background
var state = "idle"

# 时间参数（你可以按需调整）
@export var fade_duration := 2.0
@export var play_duration := 5.0
@export var silence_duration := 3.0
func _ready():
	start_audio_cycle()
	flicker_cooldown = randf_range(5.0, 20.0)
func _process(delta):
	# 倒计时
	
	if flicker_cooldown > 0:
		flicker_cooldown -= delta
		return
	
	# 触发闪烁
	start_flicker_sequence()
	# 设置下一次闪烁的时间（比如 1~4 秒之间）
	flicker_cooldown = randf_range(10.0, 20.0)
	
func start_audio_cycle():
	bg_sound.volume_db = -80  # 开始静音
	bg_sound.play()
	fade_in()

func fade_in():
	var tween = create_tween()
	tween.tween_property(bg_sound, "volume_db", 0, fade_duration)
	tween.tween_interval(play_duration)
	tween.tween_callback(Callable(self, "fade_out"))
	
func fade_out():
	var tween = create_tween()
	tween.tween_property(bg_sound, "volume_db", -80, fade_duration)
	tween.tween_interval(silence_duration)
	tween.tween_callback(Callable(self, "fade_in"))
	
func start_flicker_sequence():
	
	var tween = create_tween()
	var original = lamp.light_energy
	
	# 生成 3~6 次闪烁，每次亮度和时间随机
	var flash_count = randi_range(10,25)
	flicker_sound.play()
	for i in range(flash_count):
		var flash_energy = randf_range(0.1, 1.0)
		var flash_duration = randf_range(0.03, 0.1)
		var flash_delay = randf_range(0.01, 0.05)
		tween.tween_property(lamp, "light_energy", flash_energy, flash_duration)
		tween.tween_interval(flash_delay)  # 加一个小延迟作为“闪烁间隔”
		
	# 最后恢复到原始亮度
	tween.tween_property(lamp, "light_energy", original, 0.1)
	tween.tween_callback(Callable(self, "_on_flicker_finished"))

func _on_flicker_finished():
	flicker_sound.stop()
