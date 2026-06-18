extends Node3D

var blocks := {}
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

func place_block(grid_pos: Vector3i) -> bool:
    if not can_place_at(grid_pos):
        return false
    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.position = Vector3(grid_pos) + Vector3(0.5, 0, 0.5)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = selected_color
    mesh.material_override = mat
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    col.shape = BoxShape3D.new()
    body.add_child(col)
    mesh.add_child(body)
    add_child(mesh)
    blocks[grid_pos] = {"color": selected_color, "node": mesh}
    return true

func remove_block(grid_pos: Vector3i) -> bool:
    if not blocks.has(grid_pos):
        return false
    blocks[grid_pos]["node"].queue_free()
    blocks.erase(grid_pos)
    return true

func clear_all():
    for pos in blocks:
        blocks[pos]["node"].queue_free()
    blocks.clear()

func get_all_blocks() -> Dictionary:
    return blocks