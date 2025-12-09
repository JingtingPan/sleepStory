extends Node
@export var lightning_on = false:
	set(value):
		if lightning_on != value:
			lightning_on = value
			if lightning_on:
				_start_lightning_system()
			else:
				_stop_lightning_system()
@export var world_env: WorldEnvironment
@export var flash_light: DirectionalLight3D
@export var thunder_sounds: Array[AudioStream] = []
@onready var audio = AudioStreamPlayer.new()

@export var env_brightness_boost := 2.0   # 每次闪电临时叠加的环境亮度
@export var env_exposure_boost  := 1.2   # 每次闪电临时叠加的曝光
@export var light_peak_energy   := 400.0 # 闪电光能量峰值
@export var pulses              := 2     # 闪电抖动次数（1~3 推荐）
var _is_playing := false  # 防止并发重入
var _lightning_timer: Timer  # 用于控制闪电间隔的计时器
var _is_lightning_active := false  # 跟踪闪电系统是否正在运行
func _ready():
		# 如果场景中没有audio节点，则创建
	if not has_node("AudioStreamPlayer"):
		audio = AudioStreamPlayer.new()
		add_child(audio)
	
	# 创建闪电计时器
	_lightning_timer = Timer.new()
	_lightning_timer.one_shot = true
	add_child(_lightning_timer)
	_lightning_timer.timeout.connect(_on_lightning_timer_timeout)
	
	# 初始状态同步
	if lightning_on:
		_start_lightning_system()

func _exit_tree():
	_stop_lightning_system()

# 启动闪电系统
func _start_lightning_system():
	if _is_lightning_active:
		return
	
	_is_lightning_active = true
	print("闪电系统启动")
	_start_next_lightning()


# 停止闪电系统
func _stop_lightning_system():
	_is_lightning_active = false
	if _lightning_timer:
		_lightning_timer.stop()
	print("闪电系统停止")
	
# 开始下一个闪电的计时
func _start_next_lightning():
	if not _is_lightning_active or not lightning_on:
		return
	
	var delay := randf_range(3.0, 10.0)
	_lightning_timer.start(delay)

# 计时器超时时的回调
func _on_lightning_timer_timeout():
	if not _is_lightning_active or not lightning_on:
		return
	
	# 播放一次闪电
	await play_lightning_once()
	
	# 准备下一次闪电
	_start_next_lightning()
	

# 只播放一次闪电：
# thunder_delay: float 固定秒 or Vector2(min,max) 随机区间；传 null 则默认 0.5~3.0
# sound_index: 传入音效索引（0..N-1）；传 -1 则随机；越界会回退到随机
func play_lightning_once(thunder_delay = null, sound_index: int = -1) -> void:
	if _is_playing:
		return
	_is_playing = true

	if world_env == null or world_env.environment == null or flash_light == null:
		push_warning("Lightning: 环境或光源未设置")
		_is_playing = false
		return

	var env := world_env.environment
	var orig_brightness := env.adjustment_brightness
	var orig_exposure  := env.tonemap_exposure
	var orig_light_energy := flash_light.light_energy

	# —— 环境脉冲 —— 
	var t_env := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_env.parallel().tween_property(env, "adjustment_brightness",
		orig_brightness + env_brightness_boost, 0.06)
	t_env.parallel().tween_property(env, "tonemap_exposure",
		orig_exposure + env_exposure_boost, 0.06)
	t_env.tween_interval(0.06)
	t_env.parallel().tween_property(env, "adjustment_brightness", orig_brightness, 0.12)
	t_env.parallel().tween_property(env, "tonemap_exposure",  orig_exposure,  0.12)

	# —— 闪电光抖动 —— 
	for i in range(pulses):
		var t_light := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t_light.tween_property(flash_light, "light_energy", light_peak_energy, 0.05)
		t_light.tween_property(flash_light, "light_energy", 0.0, 0.08)
		await t_light.finished
		await get_tree().create_timer(randf_range(0.02, 0.06)).timeout
	flash_light.light_energy = orig_light_energy

	# —— 雷声延迟 —— 
	var delay_sec := 0.0
	if typeof(thunder_delay) == TYPE_FLOAT:
		delay_sec = max(0.0, float(thunder_delay))
	elif thunder_delay is Vector2:
		delay_sec = randf_range(thunder_delay.x, thunder_delay.y)
	else:
		delay_sec = randf_range(0.5, 3.0)
	await get_tree().create_timer(delay_sec).timeout

	# —— 选音并播放（按索引）——
	var stream := _pick_sound_by_index(sound_index)
	if stream != null:
		audio.stream = stream
		audio.pitch_scale = randf_range(0.95, 1.05)
		audio.play()

	_is_playing = false

func _pick_sound_by_index(idx: int) -> AudioStream:
	if thunder_sounds.is_empty():
		push_warning("Lightning: thunder_sounds 为空")
		return null
	if idx >= 0 and idx < thunder_sounds.size():
		return thunder_sounds[idx]
	# 索引非法时回退为随机
	return thunder_sounds.pick_random()
	
# 提供一个公共方法来手动触发闪电（可选）
func trigger_lightning_immediately():
	if not _is_playing:
		play_lightning_once(0.1, -1)  # 立即触发，短暂延迟后打雷
