extends Interactable

@onready var event_ui: EventUI = get_node("/root/child_room/CanvasLayer/EventUI")
@onready var light_manager: LightManager = get_node("/root/child_room/LightManager")
@onready var toilet_light: Interactable = get_node("/root/child_room/toilet_room1/light/light_switch")
@export var event_name := ""
@export var prompt : String
@export var light_check : bool
var is_processing: bool = false  # 新增：防止重复处理标志
# 记录当前灯光状态
var is_light_on: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func action_use():
	# 如果正在处理中，直接返回
	if is_processing:
		return
	
	# 设置处理中标志
	is_processing = true
	
	# 检查灯光条件
	if not toilet_light.is_on:
		await event_ui.show_text_and_wait("I need to turn on the light first...")
		# 处理完成后重置标志
		is_processing = false
		return
	
	# 检查事件触发条件
	if not EventManager.can_trigger(event_name):
		await event_ui.show_text_and_wait(prompt)
		# 处理完成后重置标志
		is_processing = false
		return

	type = ""
	EventManager.start_event(event_name)
	
	# 处理完成后重置标志
	is_processing = false
