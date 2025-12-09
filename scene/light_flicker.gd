extends Node3D

@onready var lamp = $OmniLight3D
@onready var flicker_sound: AudioStreamPlayer3D = $flicker_sound
@onready var bg_sound: AudioStreamPlayer3D = $background

# 闪烁控制参数
@export var auto_flicker_enabled := false  # 是否自动闪烁
@export var auto_flicker_min_delay := 10.0  # 自动闪烁最小延迟
@export var auto_flicker_max_delay := 20.0  # 自动闪烁最大延迟

# 闪烁序列参数
@export var min_flash_count := 10  # 最小闪烁次数
@export var max_flash_count := 25  # 最大闪烁次数
@export var min_flash_energy := 0.1  # 最小亮度
@export var max_flash_energy := 4.0  # 最大亮度
@export var min_flash_duration := 0.03  # 最短闪烁持续时间
@export var max_flash_duration := 0.1  # 最长闪烁持续时间
@export var min_flash_delay := 0.01  # 闪烁间最小延迟
@export var max_flash_delay := 0.05  # 闪烁间最大延迟
@export var restore_energy := 1.0  # 闪烁结束后恢复的亮度

# 音频循环参数
@export var fade_duration := 2.0
@export var play_duration := 5.0
@export var silence_duration := 3.0

var flicker_cooldown := 0.0
var state = "idle"
var current_tween: Tween

func _ready():
	if auto_flicker_enabled:
		flicker_cooldown = randf_range(auto_flicker_min_delay, auto_flicker_max_delay)
	#start_audio_cycle()

func _process(delta):
	if not auto_flicker_enabled:
		return
		
	if flicker_cooldown > 0:
		flicker_cooldown -= delta
		return
	
	# 触发闪烁
	start_flicker_sequence()
	flicker_cooldown = randf_range(auto_flicker_min_delay, auto_flicker_max_delay)

# 公共方法：手动触发闪烁
func trigger_flicker(
	flash_count: int = -1, 
	min_energy: float = -1.0, 
	max_energy: float = -1.0,
	restore_to: float = -1.0
):
	# 使用参数值或默认值
	var count = flash_count if flash_count != -1 else randi_range(min_flash_count, max_flash_count)
	var min_eng = min_energy if min_energy != -1.0 else min_flash_energy
	var max_eng = max_energy if max_energy != -1.0 else max_flash_energy
	var restore = restore_to if restore_to != -1.0 else restore_energy
	
	start_flicker_sequence_custom(count, min_eng, max_eng, restore)

# 公共方法：快速闪烁（更频繁更快）
func trigger_rapid_flicker():
	start_flicker_sequence_custom(
		randi_range(15, 30),  # 更多次数
		0.05,  # 更暗
		5.0,   # 更亮
		restore_energy,
		0.01,  # 更短的持续时间
		0.05,
		0.005, # 更短的延迟
		0.02
	)

# 公共方法：停止当前闪烁
func stop_flicker():
	if current_tween:
		current_tween.kill()
		current_tween = null
	flicker_sound.stop()
	lamp.light_energy = restore_energy

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

# 原有的闪烁序列
func start_flicker_sequence():
	start_flicker_sequence_custom(
		randi_range(min_flash_count, max_flash_count),
		min_flash_energy,
		max_flash_energy,
		restore_energy,
		min_flash_duration,
		max_flash_duration,
		min_flash_delay,
		max_flash_delay
	)

# 自定义闪烁序列
func start_flicker_sequence_custom(
	flash_count: int,
	min_energy: float,
	max_energy: float,
	restore_energy_to: float,
	flash_duration_min: float = min_flash_duration,
	flash_duration_max: float = max_flash_duration,
	flash_delay_min: float = min_flash_delay,
	flash_delay_max: float = max_flash_delay
):
	# 停止当前的闪烁
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	var original = lamp.light_energy
	
	# 播放闪烁声音
	flicker_sound.play()
	
	# 生成闪烁序列
	for i in range(flash_count):
		var flash_energy = randf_range(min_energy, max_energy)
		var flash_duration = randf_range(flash_duration_min, flash_duration_max)
		var flash_delay = randf_range(flash_delay_min, flash_delay_max)
		
		current_tween.tween_property(lamp, "light_energy", flash_energy, flash_duration)
		current_tween.tween_interval(flash_delay)  # 闪烁间隔
	
	# 最后恢复到指定亮度
	current_tween.tween_property(lamp, "light_energy", restore_energy_to, 0.1)
	current_tween.tween_callback(Callable(self, "_on_flicker_finished"))

func _on_flicker_finished():
	flicker_sound.stop()
	current_tween = null
