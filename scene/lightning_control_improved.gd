extends Node
class_name LightningSystemImproved

## ========================================
## 改进的闪电系统 - 基于窗户局部光源
## ========================================
## 特点:
## - 室内时只通过窗户照射光线
## - 阳台时可以看到天空闪电+增强效果
## - 支持多个窗户独立闪电
## - 更真实的光照效果
## ========================================

enum PlayerLocation {
	INDOOR,        # 室内（窗户封闭）
	INDOOR_WINDOW, # 室内靠近窗户
	BALCONY        # 阳台/半室外
}

## === 导出变量 ===
@export var lightning_enabled := false:
	set(value):
		if lightning_enabled != value:
			lightning_enabled = value
			if lightning_enabled:
				_start_lightning_system()
			else:
				_stop_lightning_system()

@export_group("场景引用")
@export var world_env: WorldEnvironment
@export var player: Node3D  # 用于检测玩家位置

@export_group("窗户光源")
## 窗户光源数组 - 在编辑器中添加对应每个窗户的SpotLight3D
@export var window_lights: Array[SpotLight3D] = []
## 阳台额外的天空光（定向光模拟远处闪电）
@export var sky_flash_light: DirectionalLight3D

@export_group("视觉效果")
## 窗帘/玻璃自发光材质（可选，用于增强窗户闪光）
@export var window_emissive_materials: Array[StandardMaterial3D] = []
## 天空闪电网格（在阳台可见的闪电视觉效果）
@export var sky_lightning_mesh: MeshInstance3D

@export_group("音效")
@export var thunder_sounds: Array[AudioStream] = []
@onready var audio_player := AudioStreamPlayer.new()

@export_group("闪电参数")
@export_range(2.0, 20.0) var min_interval := 5.0
@export_range(2.0, 20.0) var max_interval := 12.0
@export_range(1, 5) var pulse_count := 2
@export_range(0.0, 3.0) var thunder_delay_min := 0.2
@export_range(0.0, 3.0) var thunder_delay_max := 1.5

## 光照强度（根据位置调整）
@export_subgroup("光照强度")
@export var window_light_peak_energy := 80.0
@export var sky_light_peak_energy := 150.0
@export var env_brightness_boost := 0.3  # 阳台时的环境亮度提升（较小）

## === 私有变量 ===
var _is_active := false
var _is_playing := false
var _lightning_timer: Timer
var _current_location := PlayerLocation.INDOOR

# 原始值记录
var _original_window_energies: Array[float] = []
var _original_sky_energy := 0.0
var _original_env_brightness := 1.0
var _original_emissive_energies: Array[float] = []


## ========================================
## 初始化
## ========================================
func _ready():
	# 创建音频播放器
	if not has_node("AudioStreamPlayer"):
		add_child(audio_player)
	
	# 创建定时器
	_lightning_timer = Timer.new()
	_lightning_timer.one_shot = true
	add_child(_lightning_timer)
	_lightning_timer.timeout.connect(_on_lightning_timer_timeout)
	
	# 记录原始光照值
	_store_original_values()
	
	# 初始化闪电网格（隐藏）
	if sky_lightning_mesh:
		sky_lightning_mesh.visible = false
	
	# 自动启动
	if lightning_enabled:
		_start_lightning_system()


func _store_original_values():
	"""存储所有光源和材质的原始值"""
	_original_window_energies.clear()
	for light in window_lights:
		if light:
			_original_window_energies.append(light.light_energy)
	
	if sky_flash_light:
		_original_sky_energy = sky_flash_light.light_energy
	
	if world_env and world_env.environment:
		_original_env_brightness = world_env.environment.adjustment_brightness
	
	_original_emissive_energies.clear()
	for mat in window_emissive_materials:
		if mat:
			_original_emissive_energies.append(mat.emission_energy_multiplier)


## ========================================
## 系统控制
## ========================================
func _start_lightning_system():
	if _is_active:
		return
	_is_active = true
	print("🌩️ 闪电系统启动")
	_schedule_next_lightning()


func _stop_lightning_system():
	_is_active = false
	if _lightning_timer:
		_lightning_timer.stop()
	_reset_all_lights()
	print("🌩️ 闪电系统停止")


func _schedule_next_lightning():
	if not _is_active or not lightning_enabled:
		return
	var delay := randf_range(min_interval, max_interval)
	_lightning_timer.start(delay)


func _on_lightning_timer_timeout():
	if not _is_active or not lightning_enabled:
		return
	await play_lightning()
	_schedule_next_lightning()


## ========================================
## 玩家位置检测
## ========================================
func update_player_location(location: PlayerLocation):
	"""手动更新玩家位置（从外部调用）"""
	_current_location = location


func _auto_detect_player_location() -> PlayerLocation:
	"""自动检测玩家位置（如果设置了player节点）"""
	if not player:
		return PlayerLocation.INDOOR
	
	# 这里可以用Area3D或射线检测
	# 示例：简单的位置判断
	var player_pos = player.global_position
	
	# 你需要根据场景设置这些区域
	# 示例：
	# if player_pos.z > 10.0:  # 假设阳台在z>10的位置
	#     return PlayerLocation.BALCONY
	# elif player_pos.distance_to(window_position) < 3.0:
	#     return PlayerLocation.INDOOR_WINDOW
	
	return _current_location  # 默认返回当前设置


## ========================================
## 核心闪电播放
## ========================================
func play_lightning(custom_thunder_delay: Variant = null, custom_thunder_sound: int = -1):
	"""
	播放一次完整的闪电效果
	
	参数:
	  custom_thunder_delay: 自定义雷声延迟
		- float: 固定延迟秒数 (例如: 0.5)
		- Vector2: 随机范围 (例如: Vector2(0.2, 1.0))
		- null: 使用默认设置 (thunder_delay_min ~ thunder_delay_max)
	  custom_thunder_sound: 自定义雷声音效索引
		- -1: 随机选择（默认）
		- 0, 1, 2...: 使用指定索引的音效
	"""
	if _is_playing:
		return
	_is_playing = true
	
	var location = _auto_detect_player_location()
	
	match location:
		PlayerLocation.INDOOR:
			await _play_indoor_lightning(custom_thunder_delay, custom_thunder_sound)
		PlayerLocation.INDOOR_WINDOW:
			await _play_window_lightning(custom_thunder_delay, custom_thunder_sound)
		PlayerLocation.BALCONY:
			await _play_balcony_lightning(custom_thunder_delay, custom_thunder_sound)
	
	_is_playing = false


## ========================================
## 室内闪电（只有窗户光）
## ========================================
func _play_indoor_lightning(custom_thunder_delay: Variant = null, custom_thunder_sound: int = -1):
	"""室内闪电 - 只通过窗户照射"""
	# 选择所有窗户都闪光
	var active_windows: Array[int] = []
	for i in range(window_lights.size()):
		active_windows.append(i)
	
	# 窗户光脉冲
	for _pulse in range(pulse_count):
		await _flash_window_lights(active_windows, 0.05, 0.1)
		await get_tree().create_timer(randf_range(0.02, 0.08)).timeout
	
	# 窗帘/玻璃发光效果（可选）
	if not window_emissive_materials.is_empty():
		await _flash_emissive_materials(0.05, 0.08)
	
	# 雷声
	await _play_thunder(custom_thunder_delay, custom_thunder_sound)


## ========================================
## 窗边闪电（窗户光+轻微环境光）
## ========================================
func _play_window_lightning(custom_thunder_delay: Variant = null, custom_thunder_sound: int = -1):
	"""靠近窗户的闪电 - 稍强的效果"""
	var active_windows = _get_random_windows(randi_range(2, min(3, window_lights.size())))
	
	# 更强的窗户光
	for _pulse in range(pulse_count):
		await _flash_window_lights(active_windows, 0.06, 0.12, 1.3)
		await get_tree().create_timer(randf_range(0.02, 0.06)).timeout
	
	# 发光材质
	if not window_emissive_materials.is_empty():
		await _flash_emissive_materials(0.06, 0.1)
	
	# 轻微环境增亮
	if world_env and world_env.environment:
		var env = world_env.environment
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(env, "adjustment_brightness", 
			_original_env_brightness + env_brightness_boost * 0.3, 0.06)
		tween.tween_property(env, "adjustment_brightness", 
			_original_env_brightness, 0.15)
	
	await _play_thunder(custom_thunder_delay, custom_thunder_sound)


## ========================================
## 阳台闪电（完整效果：天空+窗户+环境）
## ========================================
func _play_balcony_lightning(custom_thunder_delay: Variant = null, custom_thunder_sound: int = -1):
	"""阳台闪电 - 完整的天空闪电效果"""
	
	# 1. 天空闪电网格显示
	if sky_lightning_mesh:
		_show_lightning_bolt()
	
	# 2. 天空光闪烁
	if sky_flash_light:
		for _pulse in range(pulse_count):
			var tween = create_tween().set_trans(Tween.TRANS_SINE)
			tween.tween_property(sky_flash_light, "light_energy", sky_light_peak_energy, 0.05)
			tween.tween_property(sky_flash_light, "light_energy", _original_sky_energy, 0.1)
			await tween.finished
			await get_tree().create_timer(0.1).timeout
	
	# 3. 窗户也会被照亮
	var active_windows: Array[int] = []
	for i in range(window_lights.size()):
		active_windows.append(i)
	await _flash_window_lights(active_windows, 0.04, 0.08, 0.8)
	
	# 4. 环境亮度提升（阳台时更明显）
	if world_env and world_env.environment:
		var env = world_env.environment
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(env, "adjustment_brightness", 
			_original_env_brightness + env_brightness_boost, 0.06)
		tween.tween_property(env, "adjustment_brightness", 
			_original_env_brightness, 0.18)
	
	# 5. 雷声
	await _play_thunder(custom_thunder_delay, custom_thunder_sound)


## ========================================
## 辅助函数
## ========================================
func _get_random_windows(count: int) -> Array[int]:
	"""随机选择窗户索引"""
	if window_lights.is_empty():
		return []
	
	var available = range(window_lights.size())
	available.shuffle()
	var selected: Array[int] = []
	for i in min(count, available.size()):
		selected.append(available[i])
	return selected


func _flash_window_lights(window_indices: Array[int], flash_time: float, fade_time: float, intensity_mult: float = 1.0):
	"""闪烁指定窗户的光源"""
	var tweens: Array[Tween] = []
	
	for idx in window_indices:
		if idx >= window_lights.size():
			continue
		var light = window_lights[idx]
		if not light:
			continue
		
		var original = _original_window_energies[idx] if idx < _original_window_energies.size() else 0.0
		var peak = window_light_peak_energy * intensity_mult
		
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(light, "light_energy", peak, flash_time)
		tween.tween_property(light, "light_energy", original, fade_time)
		tweens.append(tween)
	
	# 等待所有tween完成
	for tween in tweens:
		await tween.finished


func _flash_emissive_materials(flash_time: float, fade_time: float):
	"""闪烁窗帘/玻璃的自发光材质"""
	var tweens: Array[Tween] = []
	
	for i in range(window_emissive_materials.size()):
		var mat = window_emissive_materials[i]
		if not mat:
			continue
		
		var original = _original_emissive_energies[i] if i < _original_emissive_energies.size() else 0.0
		var peak = original + 3.0  # 临时增加发光强度
		
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "emission_energy_multiplier", peak, flash_time)
		tween.tween_property(mat, "emission_energy_multiplier", original, fade_time)
		tweens.append(tween)
	
	for tween in tweens:
		await tween.finished


func _show_lightning_bolt():
	"""显示天空闪电网格（快速闪现）"""
	if not sky_lightning_mesh:
		return
	
	sky_lightning_mesh.visible = true
	
	# 随机变换位置/旋转（让每次闪电不同）
	#sky_lightning_mesh.rotation.z = randf_range(-15, 15)
	
	# 快速淡出
	var mat = sky_lightning_mesh.get_active_material(0) as StandardMaterial3D
	if mat and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		mat.albedo_color.a = 1.0
		var tween = create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 2.0)
		await tween.finished
	else:
		await get_tree().create_timer(0.1).timeout
	
	sky_lightning_mesh.visible = false


func _play_thunder(custom_delay: Variant = null, sound_index: int = -1):
	"""
	播放雷声（带随机延迟）
	
	参数:
	  custom_delay: 自定义延迟
		- float: 固定延迟秒数 (例如: 0.5)
		- Vector2: 随机范围 (例如: Vector2(0.2, 1.0))
		- null: 使用默认设置 (thunder_delay_min ~ thunder_delay_max)
	  sound_index: 雷声音效索引
		- -1: 随机选择（默认）
		- 0, 1, 2...: 使用指定索引的音效
	"""
	if thunder_sounds.is_empty():
		return
	
	# 计算延迟时间
	var delay := 0.0
	if custom_delay == null:
		# 使用默认范围
		delay = randf_range(thunder_delay_min, thunder_delay_max)
	elif custom_delay is float or custom_delay is int:
		# 固定延迟
		delay = float(custom_delay)
	elif custom_delay is Vector2:
		# 自定义范围
		delay = randf_range(custom_delay.x, custom_delay.y)
	else:
		push_warning("Lightning: custom_delay 参数类型错误，使用默认值")
		delay = randf_range(thunder_delay_min, thunder_delay_max)
	
	await get_tree().create_timer(max(0.0, delay)).timeout
	
	# 选择音效
	var sound: AudioStream = null
	if sound_index >= 0 and sound_index < thunder_sounds.size():
		# 使用指定索引的音效
		sound = thunder_sounds[sound_index]
	else:
		# 随机选择（索引无效或为-1时）
		sound = thunder_sounds.pick_random()
	
	if sound:
		audio_player.stream = sound
		audio_player.pitch_scale = randf_range(0.92, 1.08)
		audio_player.play()


func _reset_all_lights():
	"""重置所有光源到原始状态"""
	for i in range(window_lights.size()):
		if i < _original_window_energies.size() and window_lights[i]:
			window_lights[i].light_energy = _original_window_energies[i]
	
	if sky_flash_light:
		sky_flash_light.light_energy = _original_sky_energy
	
	if world_env and world_env.environment:
		world_env.environment.adjustment_brightness = _original_env_brightness


## ========================================
## 手动触发（用于剧情）
## ========================================
func trigger_lightning_immediate(location := PlayerLocation.INDOOR, custom_thunder_delay: Variant = null, custom_thunder_sound: int = -1):
	"""
	立即触发一次闪电（用于剧情脚本）
	
	参数:
	  location: 玩家位置类型
	  custom_thunder_delay: 自定义雷声延迟
		- float: 固定延迟秒数 (例如: 0.3 表示闪电后0.3秒打雷)
		- Vector2: 随机范围 (例如: Vector2(0.1, 0.5))
		- null: 使用默认设置
	  custom_thunder_sound: 自定义雷声音效索引
		- -1: 随机选择（默认）
		- 0, 1, 2...: 使用 thunder_sounds 数组中对应索引的音效
	
	使用示例:
	  # 立即闪电，0.3秒后打雷，随机音效
	  trigger_lightning_immediate(PlayerLocation.INDOOR, 0.3)
	  
	  # 立即闪电，0.3秒后打雷，使用第一个音效（索引0）
	  trigger_lightning_immediate(PlayerLocation.INDOOR, 0.3, 0)
	  
	  # 立即闪电，随机延迟，使用第二个音效（索引1）
	  trigger_lightning_immediate(PlayerLocation.BALCONY, Vector2(0.1, 0.5), 1)
	  
	  # 立即闪电，同步打雷，使用第三个音效（索引2）
	  trigger_lightning_immediate(PlayerLocation.INDOOR, 0.0, 2)
	"""
	if _is_playing:
		return
	
	_current_location = location
	await play_lightning(custom_thunder_delay, custom_thunder_sound)


## ========================================
## 调试
## ========================================
func _input(event):
	# 调试用：按L触发闪电
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		trigger_lightning_immediate(_current_location)
		print("🌩️ 手动触发闪电 - 位置: ", _current_location)
