extends Node3D

@onready var item_types_node = $"../ItemTypes"
@onready var func_types = $"../FunctionalTypes"

var blocks := {}  # Dictionary: Vector3i -> BlockData
var _is_moving: Dictionary = {}  # 正在动画中的方块

class BlockData:
	var item_id: int = -1
	var color: Color = Color.RED
	var node: Node3D = null          # 容器节点
	var faces: Array[MeshInstance3D] = []  # 6 个面的 mesh
	var func_type: int = 0
	var direction: int = 2
	var face_textures: Array = []    # 6 个面的 Image 贴图

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

	# 容器
	var container := Node3D.new()
	container.position = Vector3(grid_pos) + Vector3(0.5, 0.5, 0.5)

	var faces: Array[MeshInstance3D] = []
	var face_defs := [
		[Vector3(0, 0.5, 0), Vector3(-PI/2, 0, 0)],   # +Y Top
		[Vector3(0, -0.5, 0), Vector3(PI/2, 0, 0)],     # -Y Bottom
		[Vector3(0, 0, 0.5), Vector3(0, 0, 0)],          # +Z Front
		[Vector3(0, 0, -0.5), Vector3(0, PI, 0)],        # -Z Back
		[Vector3(0.5, 0, 0), Vector3(0, PI/2, 0)],       # +X Right
		[Vector3(-0.5, 0, 0), Vector3(0, -PI/2, 0)],     # -X Left
	]

	for i in range(6):
		var fm := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1, 1)
		fm.mesh = plane
		fm.position = face_defs[i][0]
		fm.rotation = face_defs[i][1]

		var mat := StandardMaterial3D.new()
		if textures.size() > i and textures[i] != null:
			var tex := ImageTexture.create_from_image(textures[i])
			mat.albedo_texture = tex
		else:
			mat.albedo_color = color
		fm.material_override = mat

		container.add_child(fm)
		faces.append(fm)

	if func_type > 0:
		_add_direction_indicator(container, direction)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(1, 1, 1)
	body.add_child(col)
	container.add_child(body)

	add_child(container)

	var bd := BlockData.new()
	bd.item_id = item_id
	bd.color = color
	bd.node = container
	bd.faces = faces
	bd.func_type = func_type
	bd.direction = direction
	if textures.size() == 6:
		bd.face_textures = textures.duplicate()
	blocks[grid_pos] = bd
	return true


func _add_direction_indicator(container: Node3D, dir_idx: int):
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
	container.add_child(indicator)


func remove_block(grid_pos: Vector3i) -> bool:
	if not blocks.has(grid_pos):
		return false
	blocks[grid_pos].node.queue_free()
	blocks.erase(grid_pos)
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
				# 粘液方块连通任意邻居，功能方块连通功能方块
				var slime_link = (bd_p != null and bd_p.func_type == func_types.FuncType.SLIME) \
							  or (bd_n != null and bd_n.func_type == func_types.FuncType.SLIME)
				var func_link = (bd_p != null and bd_p.func_type > 0) \
							 and (bd_n != null and bd_n.func_type > 0)
				if slime_link or func_link:
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
