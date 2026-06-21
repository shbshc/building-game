extends Node3D

@onready var item_types_node = $"../ItemTypes"
@onready var func_types = $"../FunctionalTypes"

var blocks := {}  # Dictionary: Vector3i -> BlockData
var _is_moving: Dictionary = {}  # 正在动画中的方块

class BlockData:
	var item_id: int = -1
	var color: Color = Color.RED
	var node: MeshInstance3D = null
	var func_type: int = 0
	var direction: int = 2
	var face_textures: Array = []
	var powered: bool = false
	var switch_on: bool = false

var selected_color := Color.RED


func can_place_at(grid_pos: Vector3i) -> bool:
	if blocks.has(grid_pos):
		return false
	if grid_pos.y == 0:
		return true
	var neighbors := [
		grid_pos + Vector3i.UP,
		grid_pos + Vector3i.DOWN,
		grid_pos + Vector3i.LEFT,
		grid_pos + Vector3i.RIGHT,
		grid_pos + Vector3i.FORWARD,
		grid_pos + Vector3i.BACK,
	]
	for n in neighbors:
		if blocks.has(n):
			return true
	return false


func place_block(grid_pos: Vector3i, item_id: int = -1, custom_color = null, func_type: int = 0, direction: int = 2, textures: Array = []) -> bool:
	if not can_place_at(grid_pos):
		return false

	var color := selected_color
	if custom_color != null:
		color = custom_color
	elif func_type > 0:
		color = func_types.get_func_type_color(func_type)
	elif item_id >= 0 and item_types_node:
		var t = item_types_node.get_type(item_id)
		if t:
			color = t.color

	# 电路方块：简单 BoxMesh + material_override（支持发光切换）
	var is_circuit = (func_type == func_types.FuncType.POWER or func_type == func_types.FuncType.SWITCH
					  or func_type == func_types.FuncType.WIRE or func_type == func_types.FuncType.LAMP)
	
	var mesh := MeshInstance3D.new()
	if is_circuit:
		if func_type == func_types.FuncType.WIRE:
			mesh.mesh = _build_wire_mesh(grid_pos)
		else:
			mesh.mesh = BoxMesh.new()
	else:
		mesh.mesh = _build_cube_mesh(textures, color)
	mesh.position = Vector3(grid_pos) + Vector3(0.5, 0.5, 0.5)

	var mat := StandardMaterial3D.new()
	if is_circuit:
		mat.albedo_color = color
		mesh.material_override = mat
	elif textures.size() != 6 or textures[0] == null:
		mat.albedo_color = color
		mesh.material_override = mat

	if func_type > 0 and func_type < func_types.FuncType.POWER:
		_add_direction_indicator(mesh, direction)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(1, 1, 1)
	body.add_child(col)
	mesh.add_child(body)

	add_child(mesh)

	var bd := BlockData.new()
	bd.item_id = item_id
	bd.color = color
	bd.node = mesh
	bd.func_type = func_type
	bd.direction = direction
	if textures.size() == 6:
		bd.face_textures = textures.duplicate()
	blocks[grid_pos] = bd
	
	# 刷新相邻导线连接
	if func_type == func_types.FuncType.WIRE:
		_refresh_adjacent_wires(grid_pos)
	
	return true


# 6 面独立材质的立方体
func _build_cube_mesh(textures: Array, default_color: Color) -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()
	# 每面 4 顶点 2 三角形
	var face_verts := [
		# +Y Top (0)
		[Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5)],
		# -Y Bottom (1)
		[Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5)],
		# +Z Front (2)
		[Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)],
		# -Z Back (3)
		[Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5)],
		# +X Right (4)
		[Vector3(0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5)],
		# -X Left (5)
		[Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, 0.5, -0.5)],
	]
	var uvs := [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]

	for i in range(6):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: Vector3 = (face_verts[i][1] - face_verts[i][0]).cross(face_verts[i][3] - face_verts[i][0]).normalized()
		# Tri 1: v0, v1, v2
		st.set_normal(n); st.set_uv(uvs[0]); st.add_vertex(face_verts[i][0])
		st.set_normal(n); st.set_uv(uvs[1]); st.add_vertex(face_verts[i][1])
		st.set_normal(n); st.set_uv(uvs[2]); st.add_vertex(face_verts[i][2])
		# Tri 2: v0, v2, v3
		st.set_normal(n); st.set_uv(uvs[0]); st.add_vertex(face_verts[i][0])
		st.set_normal(n); st.set_uv(uvs[2]); st.add_vertex(face_verts[i][2])
		st.set_normal(n); st.set_uv(uvs[3]); st.add_vertex(face_verts[i][3])
		st.generate_normals()
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # 双面渲染
		if textures.size() == 6 and i < textures.size() and textures[i] != null:
			var img: Image = textures[i]
			if img.get_size() != Vector2i(16, 16):
				img = img.duplicate()
				img.resize(16, 16, Image.INTERPOLATE_NEAREST)
			mat.albedo_texture = ImageTexture.create_from_image(img)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		else:
			mat.albedo_color = default_color
		st.set_material(mat)
		st.commit(arr_mesh)
	return arr_mesh


# 导线 mesh：中心小方块 + 到相邻导线的连接线
func _build_wire_mesh(grid_pos: Vector3i) -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 中心小方块 (0.2×0.2×0.2)
	var s := 0.1
	var verts := [
		Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
		Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s),
	]
	_add_box_faces(st, verts)
	
	# 检查6个邻居，有导线就连线 (0.05粗的梁)
	for i in range(6):
		var d = func_types.DIRECTION_VECTORS[i]
		var npos = grid_pos + d
		var nb = blocks.get(npos, null)
		if nb != null and nb.func_type == func_types.FuncType.WIRE:
			var beam_s := 0.05
			var bv := [
				Vector3(-beam_s, -beam_s, 0), Vector3(beam_s, -beam_s, 0),
				Vector3(beam_s, beam_s, 0), Vector3(-beam_s, beam_s, 0),
				Vector3(-beam_s, -beam_s, 0.5), Vector3(beam_s, -beam_s, 0.5),
				Vector3(beam_s, beam_s, 0.5), Vector3(-beam_s, beam_s, 0.5),
			]
			# 旋转 beam 到正确方向 (beam 默认沿 +Z)
			var rot := Basis()
			match i:
				0: rot = Basis(Vector3.UP, PI/2)       # +X
				1: rot = Basis(Vector3.UP, -PI/2)      # -X
				2: rot = Basis(Vector3.RIGHT, -PI/2)   # +Y
				3: rot = Basis(Vector3.RIGHT, PI/2)    # -Y
				4: rot = Basis()                        # +Z (默认)
				5: rot = Basis(Vector3.UP, PI)          # -Z
			var rv: Array[Vector3] = []
			for v in bv:
				rv.append(rot * v)
			_add_box_faces(st, rv)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.WIRE)
	st.set_material(mat)
	st.commit(arr_mesh)
	return arr_mesh


func _add_box_faces(st: SurfaceTool, v: Array):
	# 6 faces: order same as cube (front,back,left,right,top,bottom)
	var faces := [[0,1,2,3], [5,4,7,6], [4,0,3,7], [1,5,6,2], [3,2,6,7], [4,5,1,0]]
	for f in faces:
		var a: Vector3 = v[f[0]]; var b: Vector3 = v[f[1]]; var c: Vector3 = v[f[2]]; var d: Vector3 = v[f[3]]
		var n: Vector3 = (b-a).cross(d-a).normalized()
		st.set_normal(n); st.set_uv(Vector2(0,0)); st.add_vertex(a)
		st.set_normal(n); st.set_uv(Vector2(1,0)); st.add_vertex(b)
		st.set_normal(n); st.set_uv(Vector2(1,1)); st.add_vertex(c)
		st.set_normal(n); st.set_uv(Vector2(0,0)); st.add_vertex(a)
		st.set_normal(n); st.set_uv(Vector2(1,1)); st.add_vertex(c)
		st.set_normal(n); st.set_uv(Vector2(0,1)); st.add_vertex(d)


func _refresh_adjacent_wires(grid_pos: Vector3i):
	for d in func_types.DIRECTION_VECTORS:
		var n = grid_pos + d
		var nb = blocks.get(n, null)
		if nb != null and nb.func_type == func_types.FuncType.WIRE:
			nb.node.mesh = _build_wire_mesh(n)
			nb.node.material_override.albedo_color = func_types.get_func_type_color(func_types.FuncType.WIRE)


# 将6张16×16贴图合并为 Atlas (3列×2行, 48×32)
func _make_atlas(textures: Array) -> Image:
	var atlas := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.GRAY)
	# 布局: (0,0)=Top (16,0)=Bottom (32,0)=Front
	#        (0,16)=Back (16,16)=Left (32,16)=Right
	var layout := [
		[0, 0], [16, 0], [32, 0],
		[0, 16], [16, 16], [32, 16],
	]
	for i in range(6):
		if i < textures.size() and textures[i] != null:
			var img: Image = textures[i]
			if img.get_size() != Vector2i(16, 16):
				img = img.duplicate()
				img.resize(16, 16)
			var dst_x = layout[i][0]
			var dst_y = layout[i][1]
			for x in range(16):
				for y in range(16):
					atlas.set_pixel(dst_x + x, dst_y + y, img.get_pixel(x, y))
	return atlas


func _add_direction_indicator(mesh: MeshInstance3D, dir_idx: int):
	var indicator := MeshInstance3D.new()
	indicator.mesh = BoxMesh.new()
	indicator.mesh.size = Vector3(0.3, 0.3, 0.15)
	indicator.position = Vector3(func_types.DIRECTION_VECTORS[dir_idx]) * 0.55
	indicator.set_meta("is_direction_indicator", true)
	
	# Rotate so thin axis (local Z) points along direction
	match dir_idx:
		0: indicator.rotation = Vector3(0, PI/2, 0)      # +X
		1: indicator.rotation = Vector3(0, -PI/2, 0)     # -X
		2: indicator.rotation = Vector3(-PI/2, 0, 0)     # +Y
		3: indicator.rotation = Vector3(PI/2, 0, 0)      # -Y
		4: indicator.rotation = Vector3.ZERO              # +Z
		5: indicator.rotation = Vector3(0, PI, 0)         # -Z
	
	var ind_mat := StandardMaterial3D.new()
	ind_mat.albedo_color = Color.WHITE
	ind_mat.emission_enabled = true
	ind_mat.emission = Color.WHITE
	ind_mat.emission_energy_multiplier = 0.5
	indicator.material_override = ind_mat
	mesh.add_child(indicator)


func remove_block(grid_pos: Vector3i) -> bool:
	if not blocks.has(grid_pos):
		return false
	var was_wire = blocks[grid_pos].func_type == func_types.FuncType.WIRE
	blocks[grid_pos].node.queue_free()
	blocks.erase(grid_pos)
	if was_wire:
		_refresh_adjacent_wires(grid_pos)
	return true


func get_block_data(grid_pos: Vector3i):
	return blocks.get(grid_pos, null)


func get_all_blocks() -> Dictionary:
	return blocks


func clear_all():
	for pos in blocks:
		blocks[pos].node.queue_free()
	blocks.clear()


# 移动方块：平滑动画移动，返回移动向量（用于带动玩家）
func move_block(from_pos: Vector3i, to_pos: Vector3i) -> Vector3:
	if not blocks.has(from_pos):
		return Vector3.ZERO
	if from_pos == to_pos:
		return Vector3.ZERO
	if _is_moving.has(from_pos):
		return Vector3.ZERO  # 正在动画中，跳过
	
	var bd = blocks[from_pos]  # 获取引用
	
	# 目标格被占据则无法移动
	if blocks.has(to_pos):
		return Vector3.ZERO
	
	blocks.erase(from_pos)
	var end_pos = Vector3(to_pos) + Vector3(0.5, 0.5, 0.5)
	var delta = Vector3(to_pos) - Vector3(from_pos)
	
	# 标记正在移动
	_is_moving[from_pos] = true
	blocks[to_pos] = bd  # 提前占位
	
	# 平滑动画
	var tween = create_tween()
	tween.tween_property(bd.node, "position", end_pos, 0.5).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_on_move_done.bind(from_pos, to_pos, bd))
	
	return delta


func _on_move_done(from_pos: Vector3i, to_pos: Vector3i, bd: BlockData):
	_is_moving.erase(from_pos)
	_refresh_direction_indicator(bd)


# 推动链：把从 start_pos 沿 dir 方向的一排方块整体推 1 格，遇到消耗方块则推动者消失
# 推动链：所有方块都可推，链中碰到粘液组则整组+中间方块一起推
func slide_chain(start_pos: Vector3i, dir: Vector3i) -> bool:
	# 1. 扫描找到停止点
	var end = start_pos
	var found_stop = false
	var hit_consume = false
	while true:
		end += dir
		if end.y < 0:
			return false
		if not blocks.has(end):
			found_stop = true
			break
		if blocks[end].func_type == func_types.FuncType.CONSUME:
			hit_consume = true
			break
		if blocks[end].func_type == func_types.FuncType.NONE:
			return false  # 普通方块不可推动，整链失败
	if not found_stop and not hit_consume:
		return false
	
	# 2. 收集链上所有方块
	var to_move: Dictionary = {}
	var queue: Array = []
	var pos = start_pos
	while pos != end:
		if blocks.has(pos) and not to_move.has(pos):
			to_move[pos] = blocks[pos]
			queue.append(pos)
		pos += dir
	
	# 3. BFS 扩展：相邻的功能方块一起推
	while not queue.is_empty():
		var p = queue.pop_front()
		var bd_p = blocks.get(p)
		for d in func_types.DIRECTION_VECTORS:
			var n = p + d
			if blocks.has(n) and not to_move.has(n):
				var bd_n = blocks.get(n)
				# 只有粘液方块连通邻居
				var slime_link = (bd_p != null and bd_p.func_type == func_types.FuncType.SLIME) \
							  or (bd_n != null and bd_n.func_type == func_types.FuncType.SLIME)
				if slime_link:
					to_move[n] = bd_n
					queue.append(n)
	
	# 4. 消耗方块处理
	if hit_consume:
		var doomed = end - dir
		if to_move.has(doomed):
			to_move.erase(doomed)
			remove_block(doomed)
	
	# 5. 检查目标格
	for old_p in to_move:
		var new_p = old_p + dir
		if new_p.y < 0:
			return false
		if blocks.has(new_p) and not to_move.has(new_p):
			return false
	
	# 6. 全部取出再写入
	for old_p in to_move:
		blocks.erase(old_p)
	for old_p in to_move:
		var bd = to_move[old_p]
		var new_p = old_p + dir
		bd.node.position = Vector3(new_p) + Vector3(0.5, 0.5, 0.5)
		_refresh_direction_indicator(bd)
		blocks[new_p] = bd
	
	return true


# 粘液连通组件：从 start_pos 出发，通过粘液方块找到所有粘连的方块
func get_slime_group(start_pos: Vector3i) -> Array:
	var visited := {}
	var queue := [start_pos]
	var result: Array = []
	visited[start_pos] = true
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		result.append(pos)
		var bd = blocks.get(pos, null)
		if bd == null:
			continue
		# 粘液方块：把6个邻居全拉进组；普通方块：也检查邻居是否粘液（入口检测）
		if bd.func_type == func_types.FuncType.SLIME:
			for dir in func_types.DIRECTION_VECTORS:
				var n = pos + dir
				if not visited.has(n) and blocks.has(n):
					visited[n] = true
					queue.append(n)
		# 非粘液方块也找相邻粘液，防止遗漏入口
		for dir in func_types.DIRECTION_VECTORS:
			var n = pos + dir
			if not visited.has(n) and blocks.has(n) and blocks[n].func_type == func_types.FuncType.SLIME:
				visited[n] = true
				queue.append(n)
	
	return result


func _refresh_direction_indicator(bd: BlockData):
	for child in bd.node.get_children():
		if child.has_meta("is_direction_indicator"):
			child.queue_free()
	_add_direction_indicator(bd.node, bd.direction)


# 设置方块方向
func set_block_direction(grid_pos: Vector3i, new_direction: int) -> bool:
	var bd = blocks.get(grid_pos, null)
	if bd == null or bd.func_type == 0:
		return false
	bd.direction = new_direction
	_refresh_direction_indicator(bd)
	return true
