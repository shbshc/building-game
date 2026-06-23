extends Node3D

@onready var block_mgr = $"../Blocks"
@onready var bp_data = $"../BlueprintData"
@onready var camera = $"../CameraRig/Camera3D"

var _active := false
var _wireframe: Node3D = null
var _wireframe_pos: Vector3i
var _wireframe_size := 4
var _placing_mode := false  # true = left-click will place wireframe


func activate():
	_active = true
	_placing_mode = true


func deactivate():
	_active = false
	_placing_mode = false


func is_active() -> bool:
	return _active


func _input(event):
	if not _active:
		return
	var cam_rig = $"../CameraRig"
	if not cam_rig.mouse_captured:
		return

	# Number keys to switch wireframe size
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_4:
			_wireframe_size = 4
		elif event.keycode == KEY_8:
			_wireframe_size = 8

	# Left-click: place wireframe (if no wireframe exists) or normal block placement inside
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _placing_mode:
			# Place the wireframe cage
			var pos = _get_grid_pos()
			_place_wireframe(pos, _wireframe_size)
			_placing_mode = false

	# Right-click on wireframe: compress
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _wireframe != null:
			_on_compress()
			get_viewport().set_input_as_handled()  # prevent raycast_handler break


func _get_grid_pos() -> Vector3i:
	var space = get_world_3d().direct_space_state
	var origin = camera.global_position
	var end = origin - camera.global_transform.basis.z * 20.0
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [$"../CameraRig"]
	var result = space.intersect_ray(query)
	if result:
		return Vector3i(floor(result.position.x), floor(result.position.y), floor(result.position.z))
	return Vector3i.ZERO


func _place_wireframe(pos: Vector3i, sz: int):
	_remove_wireframe()
	_wireframe = Node3D.new()
	_wireframe.name = "Wireframe"
	add_child(_wireframe)
	_wireframe_pos = pos
	_wireframe_size = sz

	var s = float(sz)
	var c := [
		Vector3(0, 0, 0), Vector3(s, 0, 0), Vector3(s, 0, s), Vector3(0, 0, s),
		Vector3(0, s, 0), Vector3(s, s, 0), Vector3(s, s, s), Vector3(0, s, s),
	]
	var ep := [
		[0,1], [1,2], [2,3], [3,0], [4,5], [5,6], [6,7], [7,4],
		[0,4], [1,5], [2,6], [3,7],
	]
	var arr_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.8
	st.set_material(mat)
	for e in ep:
		st.add_vertex(Vector3(pos) + c[e[0]])
		st.add_vertex(Vector3(pos) + c[e[1]])
	st.commit(arr_mesh)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = arr_mesh
	_wireframe.add_child(mesh_inst)


func _remove_wireframe():
	if _wireframe != null:
		_wireframe.queue_free()
		_wireframe = null


func _on_compress():
	if _wireframe == null:
		return
	var pos = _wireframe_pos
	var sz = _wireframe_size
	var blocks := []
	for x in range(pos.x, pos.x + sz):
		for y in range(pos.y, pos.y + sz):
			for z in range(pos.z, pos.z + sz):
				var bp = Vector3i(x, y, z)
				var bd = block_mgr.get_block_data(bp)
				if bd != null:
					blocks.append({
						"x": x - pos.x, "y": y - pos.y, "z": z - pos.z,
						"i": bd.item_id,
						"f": bd.func_type,
						"d": bd.direction,
						"m": bd.model_id
					})
	if blocks.is_empty():
		print("Wireframe area is empty, nothing to compress")
		return
	var bp_id = bp_data.save_blueprint("Blueprint", Vector3i(sz, sz, sz), blocks)
	# Add blueprint item to inventory
	var inv_mgr = $"../InventoryManager"
	var backpack = inv_mgr.backpack
	var added = false
	for slot in backpack:
		if slot.is_empty():
			slot.add(1000 + bp_id, 1, 64)
			added = true
			break
	if not added:
		for slot in inv_mgr.hotbar:
			if slot.is_empty():
				slot.add(1000 + bp_id, 1, 64)
				added = true
				break
	_remove_wireframe()
	print("Blueprint ", bp_id, " created with ", blocks.size(), " blocks")


# ── Miniature & Expand (unchanged) ──

func build_miniature_mesh(bp_id: int) -> ArrayMesh:
	var data = bp_data.load_blueprint(bp_id)
	if data.is_empty():
		return null
	var size_arr = data["size"]
	var grid_n = size_arr[0]
	var scale = 1.0 / grid_n
	var blocks_arr = data["blocks"]
	
	var arr_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0)
	st.set_material(mat)
	
	var half = scale * 0.5
	for b in blocks_arr:
		var cx = (b["x"] + 0.5) * scale - 0.5
		var cy = (b["y"] + 0.5) * scale - 0.5
		var cz = (b["z"] + 0.5) * scale - 0.5
		var s = half
		var verts = [
			Vector3(cx-s, cy+s, cz+s), Vector3(cx+s, cy+s, cz+s), Vector3(cx+s, cy+s, cz-s), Vector3(cx-s, cy+s, cz-s),
			Vector3(cx-s, cy-s, cz-s), Vector3(cx+s, cy-s, cz-s), Vector3(cx+s, cy-s, cz+s), Vector3(cx-s, cy-s, cz+s),
			Vector3(cx-s, cy-s, cz+s), Vector3(cx+s, cy-s, cz+s), Vector3(cx+s, cy+s, cz+s), Vector3(cx-s, cy+s, cz+s),
			Vector3(cx+s, cy-s, cz-s), Vector3(cx-s, cy-s, cz-s), Vector3(cx-s, cy+s, cz-s), Vector3(cx+s, cy+s, cz-s),
			Vector3(cx+s, cy-s, cz+s), Vector3(cx+s, cy-s, cz-s), Vector3(cx+s, cy+s, cz-s), Vector3(cx+s, cy+s, cz+s),
			Vector3(cx-s, cy-s, cz-s), Vector3(cx-s, cy-s, cz+s), Vector3(cx-s, cy+s, cz+s), Vector3(cx-s, cy+s, cz-s),
		]
		for fi in range(6):
			var v = verts[fi*4]
			var v2 = verts[fi*4+1]
			var v3 = verts[fi*4+3]
			var normal = (v2-v).cross(v3-v).normalized()
			st.set_normal(normal); st.add_vertex(verts[fi*4])
			st.set_normal(normal); st.add_vertex(verts[fi*4+1])
			st.set_normal(normal); st.add_vertex(verts[fi*4+2])
			st.set_normal(normal); st.add_vertex(verts[fi*4])
			st.set_normal(normal); st.add_vertex(verts[fi*4+2])
			st.set_normal(normal); st.add_vertex(verts[fi*4+3])
	
	st.commit(arr_mesh)
	return arr_mesh


func expand_blueprint(bp_id: int, origin: Vector3i):
	var data = bp_data.load_blueprint(bp_id)
	if data.is_empty():
		return
	for b in data["blocks"]:
		var pos = origin + Vector3i(b["x"], b["y"], b["z"])
		if not block_mgr.blocks.has(pos):
			block_mgr.place_block(pos, b["i"], null, b["f"], b["d"])


func place_miniature(bp_id: int, world_pos: Vector3i) -> MeshInstance3D:
	var mesh_data = build_miniature_mesh(bp_id)
	if mesh_data == null:
		return null
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_data
	mesh.position = Vector3(world_pos) + Vector3(0.5, 0.5, 0.5)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(1, 1, 1)
	body.add_child(col)
	mesh.add_child(body)
	mesh.add_to_group("blueprint_miniature")
	return mesh
