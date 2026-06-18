extends Node3D

var blocks := {}  # Dictionary: Vector3i -> {color: Color, node: MeshInstance3D}
var selected_color := Color(1.0, 0.2, 0.2)  # Ä¬ÈÏºìÉ«

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

func place_block(grid_pos: Vector3i, color: Color = Color(1.0, 0.2, 0.2)) -> bool:
    if not can_place_at(grid_pos):
        return false
    
    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.mesh.size = Vector3(1, 1, 1)
    mesh.position = Vector3(grid_pos)
    
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = mat
    
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    col.shape = BoxShape3D.new()
    col.shape.size = Vector3(1, 1, 1)
    body.add_child(col)
    mesh.add_child(body)
    
    add_child(mesh)
    blocks[grid_pos] = {"color": color, "node": mesh}
    return true

func remove_block(grid_pos: Vector3i) -> bool:
    if not blocks.has(grid_pos):
        return false
    blocks[grid_pos]["node"].queue_free()
    blocks.erase(grid_pos)
    return true

func get_block(grid_pos: Vector3i):
    return blocks.get(grid_pos, null)

func get_all_blocks() -> Dictionary:
    return blocks

func clear_all():
    for pos in blocks:
        blocks[pos]["node"].queue_free()
    blocks.clear()

func load_blocks(block_data: Array):
    clear_all()
    for b in block_data:
        place_block(Vector3i(b["x"], b["y"], b["z"]), Color(b["color"][0], b["color"][1], b["color"][2]))
