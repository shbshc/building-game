extends Node3D

@onready var item_types_node = $"../ItemTypes"
@onready var func_types = $"../FunctionalTypes"

var blocks := {}  # Dictionary: Vector3i -> BlockData

class BlockData:
    var item_id: int = -1
    var color: Color = Color.RED
    var node: MeshInstance3D = null
    var func_type: int = 0     # FuncType enum
    var direction: int = 2     # direction index (默认 +Y)

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


func place_block(grid_pos: Vector3i, item_id: int = -1, custom_color = null, func_type: int = 0, direction: int = 2) -> bool:
    if not can_place_at(grid_pos):
        return false

    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.position = Vector3(grid_pos) + Vector3(0.5, 0.5, 0.5)

    var mat := StandardMaterial3D.new()
    var color := selected_color
    if custom_color != null:
        color = custom_color
    elif func_type > 0:
        color = func_types.get_func_type_color(func_type)
    elif item_id >= 0 and item_types_node:
        var t = item_types_node.get_type(item_id)
        if t:
            color = t.color
    mat.albedo_color = color
    mesh.material_override = mat

    # 添加方向箭头指示器（功能方块专有）
    if func_type > 0:
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
    blocks[grid_pos] = bd
    return true


func _add_direction_indicator(mesh: MeshInstance3D, dir_idx: int):
    var dir_vec = func_types.DIRECTION_VECTORS[dir_idx]
    var indicator := MeshInstance3D.new()
    indicator.mesh = BoxMesh.new()
    indicator.mesh.size = Vector3(0.3, 0.3, 0.15)
    indicator.position = Vector3(dir_vec) * 0.55
    # 根据方向旋转指示器
    if dir_vec.x != 0:
        indicator.rotation = Vector3(0, 0, PI/2 if dir_vec.x > 0 else -PI/2)
    elif dir_vec.z != 0:
        indicator.rotation = Vector3(PI/2, 0, 0 if dir_vec.z > 0 else PI)
    # +Y 和 -Y 默认朝上
    if dir_vec.y < 0:
        indicator.rotation = Vector3(PI, 0, 0)
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


# 移动方块：将方块从 from_pos 移到 to_pos
func move_block(from_pos: Vector3i, to_pos: Vector3i) -> bool:
    if not blocks.has(from_pos):
        return false
    # 检查目标位置是否为空（允许覆盖拐弯方块）
    var target = blocks.get(to_pos, null)
    if target != null:
        if target.func_type == func_types.FuncType.TURN:
            # 拐弯方块被消耗
            remove_block(to_pos)
        else:
            return false  # 被其他方块占据，移动失败

    var bd = blocks[from_pos]
    blocks.erase(from_pos)

    # 更新节点位置
    bd.node.position = Vector3(to_pos) + Vector3(0.5, 0.5, 0.5)

    # 重新创建方向指示器
    _refresh_direction_indicator(bd)

    blocks[to_pos] = bd
    return true


func _refresh_direction_indicator(bd: BlockData):
    # 移除旧指示器
    var children = bd.node.get_children()
    for child in children:
        if child is StaticBody3D:
            continue  # 保留碰撞体
        if child is MeshInstance3D:
            child.queue_free()
    # 添加新指示器
    _add_direction_indicator(bd.node, bd.direction)


# 设置方块方向
func set_block_direction(grid_pos: Vector3i, new_direction: int) -> bool:
    var bd = blocks.get(grid_pos, null)
    if bd == null or bd.func_type == 0:
        return false
    bd.direction = new_direction
    _refresh_direction_indicator(bd)
    return true
