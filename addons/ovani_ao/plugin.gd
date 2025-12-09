@tool
extends EditorPlugin

var _es : EditorSelection
var editor_selection : EditorSelection:
	get:
		if _es == null:
			_es = EditorInterface.get_selection()
			if !_es.selection_changed.is_connected(on_selection_changed):
				_es.selection_changed.connect(on_selection_changed)
		return _es

func _enter_tree() -> void:
	editor_selection;

var selectees : Array[AudioOccluder] = []
var selectee_visuals : Array[Node] = []

func on_selection_changed():
	var selection := editor_selection.get_selected_nodes()
	for node in selection:
		if node is AudioOccluder:
			selectees.append(node)
			startup_selection(node)
	var i : int = 0
	for node in selectees:
		if node != null && is_instance_valid(node) && node.is_inside_tree():
			if !selection.has(node):
				selectees.erase(node)
				shutdown_selection(node)
		else:
			selectees.remove_at(i)
		i+=1

func _exit_tree() -> void:
	if editor_selection != null && editor_selection.selection_changed.is_connected(on_selection_changed):
		editor_selection.selection_changed.disconnect(on_selection_changed)
	for t in selectees:
		if t != null && is_instance_valid(t) && t.is_inside_tree():
			shutdown_selection(t)
	selectees = []

var _vs = null
var visual_script:
	get:
		if _vs == null:
			_vs = load("res://addons/ovani_ao/ovani_oa_visual.gd")
		return _vs

func startup_selection(targ : AudioOccluder):
	var new : Node3D = visual_script.new()
	targ.add_child(new, false, Node.INTERNAL_MODE_FRONT)
	selectee_visuals.append(new)
	new.tree_exited.connect(func():
		selectee_visuals.erase(new)
		)

func _process(delta: float) -> void:
	for vis in selectee_visuals:
		vis._process(delta)

func shutdown_selection(targ : AudioOccluder):
	for chil in targ.get_children(true):
		if chil.get_script() == visual_script:
			targ.remove_child(chil)
			selectee_visuals.erase(chil)
