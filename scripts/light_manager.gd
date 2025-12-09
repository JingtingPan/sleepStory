extends Node3D
class_name LightManager

# 保存灯光状态，true表示开
var light_states := {}
# 保存灯光节点引用
var light_nodes := {}
# 灯状态变更时调用
func _on_light_state_changed(id: String, is_on: bool):
	light_states[id] = is_on
	print("Light changed: ", id, " -> ", is_on)
	check_conditions()

# 注册灯（可选，用于初始化）
func register_light(id: String, default_on: bool):
	light_states[id] = default_on

# 检查当前条件，是否满足剧情推进
func check_conditions():
	if are_all_lights_off():
		emit_signal("all_lights_off")
	if light_states.has("toilet_light") and light_states["toilet_light"]:
		emit_signal("toilet_light_on")

# 示例条件检查函数
func are_all_lights_off() -> bool:
	for key in light_states.keys():
		#print("灯状态：", key, " -> ", light_states[key])
		if light_states[key]:
			return false
	return true
	
func print_all_light_states():
	for id in light_states.keys():
		print("Light:", id, " | is_on:", light_states[id])

# 信号供其他系统订阅
signal all_lights_off
signal toilet_light_on
