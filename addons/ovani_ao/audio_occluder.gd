@tool
@icon("./icon.png")
extends Node3D
class_name AudioOccluder

## This Node will Muffle & Filter its own AudioStreamPlayer3D's sounds through the Environment,
## by determining the path Audio Waves would take to the Listeners ears. 

## Maximum distance the Audio will be heard from.
@export_range(.25, 20) var audio_range : float = 7:
	get():
		return audio_range
	set(value):
		audio_range = value

## Linear volume of the Audio Source
@export_range(0,1) var volume : float = 1;

## What collision groups audio will bounce off of.
@export_flags_3d_physics var collision_mask : int = 1

## Each detected Voxel can be configured in detection size
## via this collision margin property.
@export_range(.25, 1) var collision_margin : float = 1:
	get():
		return collision_margin
	set(value):
		collision_margin = value

## Audio Bus the controlled AudioStreamPlayer3D will play into.
@export var AudioBus : StringName = "Master"

## Script Available property to exclusively ignore certain RIDs.
var ignored_rids : Array[RID] = []

## Whether or not to draw voxels in the editor.
## Does nothing ingame.
@export var voxel_preview : bool

## The AudioStreamPlayer3D this node "Occludes".
## Usually assigned to the first AudioStreamPlayer3D in its children.
## If none are found, one is created.
var audio_player : AudioStreamPlayer3D:
	get:
		if audio_player != null && audio_player.get_parent() != self:
			audio_player = null
		if audio_player == null:
			var ap_chil = find_children("", "AudioStreamPlayer3D")
			if len(ap_chil) != 0:
				audio_player = ap_chil.front()
			else:
				audio_player = AudioStreamPlayer3D.new()
				add_child(audio_player, true)
				audio_player.owner = owner
		return audio_player

var _lastRange : float
var _localCalcNum : int
var _localScannedPositions : Array[Vector3]:
	get():
		if _localScannedPositions == null:
			_localScannedPositions = []
		
		if _lastRange != audio_range:
			_lastRange = audio_range
			var o : Array[Vector3] = []
			var r := range(-_lastRange, _lastRange)
			
			for x in r:
				for y in r:
					for z in r:
						var p := Vector3(x,y,z)
						if p.distance_to(Vector3.ZERO) < _lastRange:
							o.append(p)
			_localScannedPositions = o
			_localCalcNum += 1
			_regenMaze()
		return _localScannedPositions

var _lastWorldPos : Vector3
var _lastWorldFidelity : float
var _worldFidelity : float:
	get():
		return to_global(Vector3.UP).distance_to(to_global(Vector3.ZERO))
var _worldCalcNum : int
var _worldScannedPositions : Array[Vector3]:
	get():
		var clc : int = _localCalcNum
		if _worldScannedPositions == null:
			_worldScannedPositions = []
		if len(_worldScannedPositions) != len(_localScannedPositions) or _lastWorldPos.distance_to(global_position) > _worldFidelity/3 or clc != _localCalcNum or _lastWorldFidelity != _worldFidelity :
			_lastWorldFidelity = _worldFidelity
			_lastWorldPos = global_position
			_worldScannedPositions = []
			
			for local_pos in _localScannedPositions:
				_worldScannedPositions.append(to_global(local_pos))
			_worldCalcNum += 1
		return _worldScannedPositions

var _maze : Dictionary[Vector3, Loc3D]
#var _localCenter : Vector3

func _regenMaze():
	_maze.clear()
	#_localCenter = Vector3.ONE * 999;
	for locPos in _localScannedPositions:
		#if Vector3.ZERO.distance_to(locPos) < Vector3.ZERO.distance_to(_localCenter):
		#	_localCenter = locPos
		var np : Loc3D = Loc3D.new()
		np._myPos = locPos
		np._src = self
		_maze.set(locPos, np)

var _selected : bool = false
var _scanning : bool = false
func _detect_cols(delta: float) -> void:
	_scanning = true
	var _col_params = PhysicsShapeQueryParameters3D.new()
	_col_params.collision_mask = collision_mask
	_col_params.exclude = ignored_rids
	_col_params.margin = collision_margin - 1
	_col_params.shape = BoxShape3D.new()
	var gt := global_transform
	var state := get_world_3d().direct_space_state
	var i = 0;
	for wp in _worldScannedPositions:
		if i % 200 == 0:
			var id := _worldCalcNum
			await get_tree().process_frame
			if id != _worldCalcNum:
				_scanning = false
				return
		
		gt.origin = wp
		
		_col_params.transform = gt
		
		var hits := state.collide_shape(_col_params, 1)
		
		if hits != null && len(hits) != 0:
			_maze[_localScannedPositions[i]]._wall = true
		else:
			_maze[_localScannedPositions[i]]._wall = false
		i += 1
	_scanning = false
	#print("done")
	VoxelsUpdated.emit()

## Emitted each time the audio's voxel grid is updated.
signal VoxelsUpdated


## Internal Class for audio Simulation.
class Loc3D:
	var _src : AudioOccluder
	var _myPos : Vector3
	var _wall : bool
	var _goal : bool
	var _checked : bool
	func _getNeighbors() -> Array:
		return [
			AudioOccluder._notWall(_src._maze.get(_myPos + Vector3(1,0,0))),
			AudioOccluder._notWall(_src._maze.get(_myPos + Vector3(-1,0,0))),
			AudioOccluder._notWall(_src._maze.get(_myPos + Vector3(0,1,0))),
			AudioOccluder._notWall(_src._maze.get(_myPos + Vector3(0,-1,0))),
			AudioOccluder._notWall(_src._maze.get(_myPos + Vector3(0,0,1))),
			AudioOccluder._notWall(_src._maze.get(_myPos + Vector3(0,0,-1))),
		].filter(func(i): return i != null)

static func _notWall(l : Loc3D) -> Loc3D:
	if l == null:
		return null
	elif l._wall:
		return null
	else:
		return l

func _ready() -> void:
	_scanning = false
	audio_player.bus = _bus_id
	audio_player.volume_linear = 0

var _smoothA : float
var _smoothB : float
func _process(delta: float) -> void:
	if !_solving:
		_solve_occulusion()
	#if Input.is_key_pressed(KEY_0):
	#	audio_range = 20
	#audio_player.unit_size = lerpf(audio_player.unit_size, _targ_unit_size, delta*2)
	audio_player.max_distance = ((audio_range * _worldFidelity))#*1.5
	audio_player.unit_size = 100
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	
	var listener : Node3D = _figure_listener();
	
	if listener != null:
		var nearDist := listener.global_position.distance_to(global_position)
		var farDist := 35 if (len(_solved_steps) == 0) else len(_solved_steps)

		_smoothA = lerpf(_smoothA, nearDist, delta)
		_smoothB = lerpf(_smoothB, farDist, delta);
		var x := clampf(_smoothA / (2 * audio_range), 0, .51)
		var y := clampf(_smoothB / (2 * audio_range), 0, 1)
		
		audio_player.volume_linear = 1
		var f : float = lerpf(1, lerpf(.5, .2, x), y) * volume
		var busIdx : int = AudioServer.get_bus_index(_bus_id)
		AudioServer.set_bus_volume_linear(busIdx, f)
		AudioServer.set_bus_send(busIdx, AudioBus)
		_filter.cutoff_hz = lerpf(22000, lerpf(1500, 10, x), y)
		

func _physics_process(delta: float) -> void:
	if !_scanning:
		_detect_cols(delta)

var _frontier : Array[Loc3D] = []
var _travels : Dictionary[Loc3D, Loc3D]
var _solved_steps : Array[Loc3D] = []

func _figure_listener() -> Node3D:
	var o : Node3D = get_tree().root.get_audio_listener_3d()
	if o == null:
		o = get_tree().root.get_camera_3d()
	return o;

var _solving : bool 
func _solve_occulusion():
	if (Engine.is_editor_hint()):
		return
	_solving = true
	#print("start")
	var c : int = 0
	_frontier.clear()
	_travels.clear() 
	for l : Loc3D in _maze.values():
		l._goal = false
		l._checked = false
	
	#figure start
	var listener : Node3D = _figure_listener()
	if listener == null:
		#print("no listener :(")
		_solving = false
		return
	
	if listener.global_position.distance_to(global_position) > (audio_range * _worldFidelity):
		#print("out of range! :(")
		_solving = false
		return;
	
	#print("finding nearest loc3D to camera")
	var nearest_2cam_idx : int = await _find_nearest(listener.global_position, _worldScannedPositions)
	
	var g : Loc3D = _maze[_localScannedPositions[nearest_2cam_idx]]
	if g._wall:
		g = g._getNeighbors().front()
		if g == null:
			print("deep in a wall :(")
			_solving = false
			return
	g._goal = true
	
	#print("finding nearest loc3D to source")
	var nearest_2src_idx : int = await _find_nearest(global_position, _worldScannedPositions)
	var start : Loc3D = _maze[_localScannedPositions[nearest_2src_idx]]
	
	#solve...
	var goal : Loc3D
	_frontier.append(start)
	c = 0
	var c2 = 0
	while goal == null:
		if len(_frontier) == 0:
			#print("no path from source to listener :(")
			_solving = false
			return;
		
		var oldFrontier : Array[Loc3D] = _frontier.duplicate()
		_frontier.clear()
		
		for current : Loc3D in oldFrontier:
			current._checked = true
		
		for current : Loc3D in oldFrontier:
			for neighbor : Loc3D in current._getNeighbors():
				if neighbor._checked || _frontier.has(neighbor):
					continue
				else:
					_frontier.append(neighbor)
					if neighbor._goal:
						goal = neighbor
					_travels[neighbor] = current
				if c > 300:
					c = 0
					c2 += 1;
					if (false):
						await get_tree().process_frame
					else:
						#print("updating camera Loc3D...")
						c2 = 0
						var npIdx : int = await _find_nearest(listener.global_position, _worldScannedPositions)
						var ng : Loc3D = _maze[_localScannedPositions[npIdx]]
						if ng != g:
							g._goal = false
							ng._goal = true
							if ng._checked:
								goal = ng
				c += 1
				if goal != null:
					break;
			if goal != null:
				break;
	
	
	_solved_steps.clear()
	_solved_steps.append(goal);
	var curStep : Loc3D = goal;
	while true:
		if _travels.has(curStep):
			curStep = _travels[curStep]
			_solved_steps.append(curStep)
		else:
			break;
	#print("solved! steps: " + str(len(_solved_steps)))
	_solving = false


func _find_nearest(pos : Vector3, arr : Array[Vector3]) -> int:
	var i : int = 0
	var c : int = 0
	var nearest : Vector3 = Vector3.ONE * 999
	var nearest_idx : int = -1
	for p in arr:
		c += 1
		if c > 400:
			await get_tree().process_frame
			#await get_tree().process_frame
			c = 0
		if p.distance_squared_to(pos) < nearest.distance_squared_to(pos):
			nearest = p
			nearest_idx = i
		i += 1
	return nearest_idx

var _bus_id : String
var _filter : AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	_bus_id = str(randi())
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count-1, _bus_id)
	var bus_idx := AudioServer.get_bus_index(_bus_id)
	AudioServer.add_bus_effect(bus_idx, _filter)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	AudioServer.remove_bus(AudioServer.get_bus_index(_bus_id))
