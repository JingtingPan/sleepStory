extends Interactable

@onready var event_ui: EventUI = get_node("/root/child_room/CanvasLayer/EventUI")
@onready var light_manager: LightManager = get_node("/root/child_room/LightManager")
@export var event_name := ""
@export var prompt : String
@export var light_check : bool
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func action_use():
	#print("🟡 当前触发器名: ", type, " | event_name:", event_name)
	if not EventManager.can_trigger(event_name):
		#print("事件未解锁：", event_name)
		await event_ui.show_text_and_wait(prompt)
		return
	if light_check:
		if light_manager and not light_manager.are_all_lights_off():
				await event_ui.show_text_and_wait("I need to turn off all the lights first...")
				return
	type = ""
	EventManager.start_event(event_name)
	
