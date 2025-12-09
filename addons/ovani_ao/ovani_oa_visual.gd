extends Node3D


# Called when the node enters the scene tree for the first time.

var stream_player : AudioOccluder
var range_display : MeshInstance3D
var range_disp_mat : Material = preload("res://addons/ovani_ao/selected_range_mat.tres")

func _enter_tree() -> void:
	stream_player = get_parent()
	stream_player._selected = true
	stream_player._scanning = false
	
	range_display = MeshInstance3D.new()
	get_parent().add_child(range_display)
	range_display.mesh = SphereMesh.new()
	range_display.material_override = range_disp_mat
	
	stream_player.VoxelsUpdated.connect(on_voxels_updated)

func on_voxels_updated():
	voxels_updated = true

var voxels_updated : bool
var onchange_count : int = -1
var points_display_root : Node3D
var old_disp : Node3D
var box := BoxMesh.new()
func _process(delta: float) -> void:
	range_display.scale = Vector3.ONE * 2 * stream_player.audio_range
	
	stream_player._worldScannedPositions
	
	if points_display_root != null:
		for c : Node3D in points_display_root.get_children():
			c.scale = Vector3.ONE * stream_player.collision_margin
	
	if !_vox_updating:
		if stream_player.voxel_preview:
			vox_update()
		else:
			_vox_updating = false
			if points_display_root != null:
				points_display_root.queue_free()
				points_display_root = null
			if old_disp != null:
				old_disp.queue_free()
				old_disp = null
	

var _vox_updating : bool = false
func vox_update():
	if voxels_updated or onchange_count != stream_player._worldCalcNum:
		_vox_updating = true
		voxels_updated = false
		onchange_count = stream_player._worldCalcNum
		
		old_disp = points_display_root
			
		points_display_root = Node3D.new()
		points_display_root.visible = false
		add_child(points_display_root)
		
		var i = 0;
		for pos in stream_player._localScannedPositions:
			
			if !self.is_inside_tree():
				_vox_updating = false
				return
			
			if stream_player._maze[pos]._wall:
				var newVis := MeshInstance3D.new()
				newVis.material_override = preload("res://addons/ovani_ao/voxel_debug_mat.tres")
				newVis.mesh = box
				newVis.scale = Vector3.ONE
				points_display_root.add_child(newVis)
				newVis.global_position = stream_player._worldScannedPositions[i]
			if i % 200 == 0:
				await get_tree().create_timer(.01).timeout
			i+=1
		
		if old_disp != null:
			old_disp.queue_free()
		points_display_root.visible = true
		
		_vox_updating = false

func _exit_tree() -> void:
	if range_display != null:
		range_display.queue_free()
	if stream_player != null:
		stream_player._selected = false
	stream_player.VoxelsUpdated.disconnect(on_voxels_updated)
