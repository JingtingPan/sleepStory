extends Node3D

func _ready():
	print("扫描所有 .fbx 文件...")
	var dir = DirAccess.open("res://")
	scan_directory(dir)

func scan_directory(dir: DirAccess):
	if dir == null:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if dir.current_is_dir():
			scan_directory(DirAccess.open(dir.get_current_dir().path_join(file)))
		elif file.ends_with(".fbx"):
			var path = dir.get_current_dir().path_join(file)
			var f = FileAccess.open(path, FileAccess.READ)
			if f == null:
				print("⚠️ 无法打开 FBX 文件: ", path)
			else:
				var first_line = f.get_line()
				if first_line.strip_edges() == "":
					print("⚠️ FBX 文件可能是空的: ", path)
			f.close()
		file = dir.get_next()
	dir.list_dir_end()
