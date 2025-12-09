extends Node3D

@onready var mesh_instance: MeshInstance3D = $SubViewport/MeshInstance3D
@export var vertical_lock_angle_threshold := 2
@export var max_mirror_cam_distance := 1.0  # 相机距离镜面不能超过多少米
@export var max_distance_from_mirror := 0.0  # 最大可允许的穿透深度
@export var offset_toward_player := 1  # 单位：米，可调整
@export var sub_viewport: SubViewport
@export var mirror_camera: Camera3D 
@export var mirror_plane: Sprite3D
@export var toilet_room_1: Node3D
@export var player_dummy: Node3D
@export var real_player: Node3D
@export var real_camera: Camera3D
@export var vertical_unlock_margin := 0.0  # 防抖恢复范围
@export var yaw_limit_angle := 75.0  # 镜中允许的最大 yaw 偏转角度
var locked_reflected_yaw: Vector3 = Vector3.ZERO  # 初始锁定时的 yaw
var is_vert_angle_locked := false
var is_hor_angle_locked := false
var locked_reflected_forward: Vector3 = Vector3.ZERO
func  _ready() -> void:
		# ✅ 先让 SubViewport 中的相机成为当前摄像机
	#mirror_camera.current = true
	await get_tree().process_frame
	sub_viewport.world_3d = get_world_3d()
	# ✅ 等待一帧后再把主视角相机设为当前摄像机（恢复主游戏画面）
	#await get_tree().process_frame
	#real_camera.current = true
	#setup_mirror_world()
	mirror_plane.texture = sub_viewport.get_texture()
		# 同步摄像机参数
	mirror_camera.fov = real_camera.fov*0.9
	mirror_camera.near = real_camera.near
	mirror_camera.far = real_camera.far
	mirror_camera.keep_aspect = real_camera.keep_aspect
	#print("SubViewport World3D: ", sub_viewport.world_3d)
	#print("SubViewport World3D: ", get_world_3d())
	mirror_plane.scale.x *= -1.0
func _process(_delta):
	if not mirror_camera or not real_camera or not mirror_plane:
		return

		# 镜面空间数据
	var mirror_transform: Transform3D = mirror_plane.global_transform
	var mirror_pos: Vector3 = mirror_transform.origin
	var mirror_normal: Vector3 = -mirror_transform.basis.z.normalized()  # 镜子朝外方向

	# --------- 镜像位置计算（相对于镜面） ---------
	var cam_pos: Vector3 = real_camera.global_transform.origin
	var to_mirror: Vector3 = cam_pos - mirror_pos
	var dist: float = mirror_normal.dot(to_mirror)
	var reflected_pos: Vector3 = cam_pos - 2.0 * dist * mirror_normal
	# ✅ 加一点偏移，使镜像相机稍微朝玩家靠近（防止太远）
	var offset = clamp(offset_toward_player, 0.0, dist * 0.9)
	reflected_pos -= mirror_normal * offset_toward_player * offset
	#var depth = mirror_normal.dot(reflected_pos - mirror_pos)
	#if depth < -max_distance_from_mirror:
		#reflected_pos = mirror_pos - mirror_normal * max_distance_from_mirror
	# 计算镜中相机实际“反向”距离
	var mirror_cam_distance := mirror_normal.dot(reflected_pos - mirror_pos)

	# 如果太深，拉回来
	if mirror_cam_distance > max_mirror_cam_distance:
		reflected_pos = mirror_pos + mirror_normal * max_mirror_cam_distance
	mirror_camera.global_transform.origin = reflected_pos

	# --------- 镜像方向计算（摄像头朝向） ---------
	#var cam_forward: Vector3 = -real_camera.global_transform.basis.z.normalized()
	#var vertical_angle = rad_to_deg(cam_forward.angle_to(Vector3(0, 0, -1)))
	#print(vertical_angle)
	##if vertical_angle > 22.0:
		### 超过俯视阈值，夹角太大，修正 forward
		##cam_forward = cam_forward.slerp(Vector3(0, 0, -1), 1)
	#if vertical_angle > vertical_lock_angle_threshold:
		#is_angle_locked = true
	#elif vertical_angle < vertical_lock_angle_threshold - 5.0:  # 添加回弹范围，避免抖动
		#is_angle_locked = false
#
	#var final_forward: Vector3
	#if is_angle_locked:
		#final_forward = locked_forward_dir
	#else:
		## 正常反射 forward
		#var dot_f = mirror_normal.dot(cam_forward)
		#final_forward = cam_forward - 2.0 * dot_f * mirror_normal
	##var dot_f = mirror_normal.dot(cam_forward)
	##var reflected_forward: Vector3 = cam_forward - 2.0 * dot_f * mirror_normal
	#var target: Vector3 = reflected_pos + final_forward
	#mirror_camera.look_at(target, Vector3.UP)
		# 距离玩家 → 镜面
	var cam_forward: Vector3 = -real_camera.global_transform.basis.z.normalized()
	# 水平朝向（Yaw）= 相机方向在 XZ 平面上的投影
	var yaw_forward = Vector3(cam_forward.x, 0, cam_forward.z).normalized()
	# 可选：设定一个“参考朝向”（如镜子正前方）
	var mirror_forward := -mirror_plane.global_transform.basis.z.normalized()
	var mirror_yaw := Vector3(mirror_forward.x, 0, mirror_forward.z).normalized()
	var pitch_y = cam_forward.y
	# 当前 yaw 偏移角度（相对于镜子方向）
	var yaw_angle := rad_to_deg(yaw_forward.angle_to(mirror_yaw))
	#print("📏 当前相机 Yaw 角偏移: ", yaw_angle)
	var vertical_angle = rad_to_deg(cam_forward.angle_to(yaw_forward))
	#print(vertical_angle)
	# 判断竖直角度是否锁定
	if not is_vert_angle_locked and vertical_angle > vertical_lock_angle_threshold:
		# 超过阈值，锁定当前反射朝向
		var dot_f = mirror_normal.dot(cam_forward)
		var reflected_pitch = cam_forward - 2.0 * dot_f * mirror_normal
		locked_reflected_forward = reflected_pitch.normalized()
		is_vert_angle_locked = true

	elif is_vert_angle_locked and vertical_angle < vertical_lock_angle_threshold - vertical_unlock_margin:
		# 恢复正常追踪
		is_vert_angle_locked = false
	#判断横向角度是否锁定	
	if not is_hor_angle_locked and yaw_angle > yaw_limit_angle:
		# 超过阈值，锁定当前反射朝向
		var dot_yaw = mirror_normal.dot(yaw_forward)
		var reflected_yaw = yaw_forward - 2.0 * dot_yaw * mirror_normal
		locked_reflected_yaw = reflected_yaw.normalized()
		is_hor_angle_locked = true

	elif is_hor_angle_locked and yaw_angle < yaw_limit_angle:
		# 恢复正常追踪
		is_hor_angle_locked = false

	var final_forward: Vector3
	if is_hor_angle_locked and is_vert_angle_locked:
		final_forward = Vector3(
			locked_reflected_yaw.x,
			locked_reflected_forward.y,
			locked_reflected_yaw.z
		).normalized()

	elif is_hor_angle_locked:
		final_forward = Vector3(
			locked_reflected_yaw.x,
			cam_forward.y,  # 实时 pitch
			locked_reflected_yaw.z
		).normalized()

	elif is_vert_angle_locked:
		var dot_yaw = mirror_normal.dot(yaw_forward)
		var reflected_yaw = yaw_forward - 2.0 * dot_yaw * mirror_normal
		final_forward = Vector3(
			reflected_yaw.x,
			locked_reflected_forward.y,
			reflected_yaw.z
		).normalized()
	else:
		var dot_f = mirror_normal.dot(cam_forward)
		final_forward = cam_forward - 2.0 * dot_f * mirror_normal

	mirror_camera.look_at(reflected_pos + final_forward, Vector3.UP)

	# 同步 Dummy 位置
	if player_dummy:
		player_dummy.global_transform = real_camera.get_parent().global_transform
