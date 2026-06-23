extends Node3D

@onready var block_mgr = $"../Blocks"
@onready var bp_data = $"../BlueprintData"
@onready var camera = $"../CameraRig/Camera3D"

var _active := false
var _p1: Vector3i
var _p2: Vector3i
var _highlight: MeshInstance3D
var _drag_active := false

const VALID_SIZES := [4, 8]


func _ready():
    _create_highlight()


func _create_highlight():
    _highlight = MeshInstance3D.new()
    _highlight.mesh = BoxMesh.new()
    _highlight.mesh.size = Vector3(1, 1, 1)
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.3, 0.6, 1.0, 0.3)
    _highlight.material_override = mat
    _highlight.visible = false
    add_child(_highlight)


func activate():
    _active = true


func deactivate():
    _active = false
    _highlight.visible = false
    _drag_active = false


func _input(event):
    if not _active:
        return
    var cam_rig = $"../CameraRig"
    if not cam_rig.mouse_captured:
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        if event.pressed:
            _p1 = _get_grid_pos()
            _p2 = _p1
            _drag_active = true
        else:
            _drag_active = false
            _p2 = _get_grid_pos()
            var sz = _get_size()
            if sz.x > 0 and sz.x in VALID_SIZES and sz.x == sz.y and sz.y == sz.z:
                _on_compress()

    if event is InputEventMouseMotion and _drag_active:
        _p2 = _get_grid_pos()
        _update_highlight()


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


func _get_size() -> Vector3i:
    var mn := Vector3i(min(_p1.x, _p2.x), min(_p1.y, _p2.y), min(_p1.z, _p2.z))
    var mx := Vector3i(max(_p1.x, _p2.x), max(_p1.y, _p2.y), max(_p1.z, _p2.z))
    return mx - mn + Vector3i(1, 1, 1)


func _update_highlight():
    var sz = _get_size()
    if sz.x != sz.y or sz.y != sz.z or sz.x not in VALID_SIZES:
        _highlight.visible = false
        return
    var mn := Vector3i(min(_p1.x, _p2.x), min(_p1.y, _p2.y), min(_p1.z, _p2.z))
    var center = Vector3(mn) + Vector3(sz) * 0.5
    _highlight.position = center
    _highlight.mesh.size = Vector3(sz)
    _highlight.visible = true


func _on_compress():
    var sz = _get_size()
    var mn := Vector3i(min(_p1.x, _p2.x), min(_p1.y, _p2.y), min(_p1.z, _p2.z))
    var blocks := []
    for x in range(mn.x, mn.x + sz.x):
        for y in range(mn.y, mn.y + sz.y):
            for z in range(mn.z, mn.z + sz.z):
                var pos = Vector3i(x, y, z)
                var bd = block_mgr.get_block_data(pos)
                if bd != null:
                    blocks.append({
                        "x": x - mn.x, "y": y - mn.y, "z": z - mn.z,
                        "i": bd.item_id,
                        "f": bd.func_type,
                        "d": bd.direction,
                        "m": bd.model_id
                    })
    if blocks.is_empty():
        return
    var bp_id = bp_data.save_blueprint("Blueprint", sz, blocks)
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
        # Try hotbar
        for slot in inv_mgr.hotbar:
            if slot.is_empty():
                slot.add(1000 + bp_id, 1, 64)
                added = true
                break
    _highlight.visible = false
    deactivate()
    print("Blueprint ", bp_id, " created with ", blocks.size(), " blocks")


# Build a 1x1x1 miniature 3D model from blueprint blocks
func build_miniature_mesh(bp_id: int) -> ArrayMesh:
    var data = bp_data.load_blueprint(bp_id)
    if data.is_empty():
        return null
    var size_arr = data["size"]
    var n = size_arr[0]  # 4 or 8
    var scale = 1.0 / n
    var blocks_arr = data["blocks"]
    
    var arr_mesh := ArrayMesh.new()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    # Simple shared material per color group
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.3, 0.7, 1.0)
    st.set_material(mat)
    
    var half = scale * 0.5
    for b in blocks_arr:
        var cx = (b["x"] + 0.5) * scale - 0.5
        var cy = (b["y"] + 0.5) * scale - 0.5
        var cz = (b["z"] + 0.5) * scale - 0.5
        # Tiny box at (cx, cy, cz) with size scale×scale×scale
        var s = half
        var verts = [
            Vector3(cx-s, cy+s, cz+s), Vector3(cx+s, cy+s, cz+s), Vector3(cx+s, cy+s, cz-s), Vector3(cx-s, cy+s, cz-s),  # top
            Vector3(cx-s, cy-s, cz-s), Vector3(cx+s, cy-s, cz-s), Vector3(cx+s, cy-s, cz+s), Vector3(cx-s, cy-s, cz+s),  # bottom
            Vector3(cx-s, cy-s, cz+s), Vector3(cx+s, cy-s, cz+s), Vector3(cx+s, cy+s, cz+s), Vector3(cx-s, cy+s, cz+s),  # front
            Vector3(cx+s, cy-s, cz-s), Vector3(cx-s, cy-s, cz-s), Vector3(cx-s, cy+s, cz-s), Vector3(cx+s, cy+s, cz-s),  # back
            Vector3(cx+s, cy-s, cz+s), Vector3(cx+s, cy-s, cz-s), Vector3(cx+s, cy+s, cz-s), Vector3(cx+s, cy+s, cz+s),  # right
            Vector3(cx-s, cy-s, cz-s), Vector3(cx-s, cy-s, cz+s), Vector3(cx-s, cy+s, cz+s), Vector3(cx-s, cy+s, cz-s),  # left
        ]
        for fi in range(6):
            var v = verts[fi*4]
            var v2 = verts[fi*4+1]
            var v3 = verts[fi*4+3]
            var n = (v2-v).cross(v3-v).normalized()
            st.set_normal(n); st.add_vertex(verts[fi*4])
            st.set_normal(n); st.add_vertex(verts[fi*4+1])
            st.set_normal(n); st.add_vertex(verts[fi*4+2])
            st.set_normal(n); st.add_vertex(verts[fi*4])
            st.set_normal(n); st.add_vertex(verts[fi*4+2])
            st.set_normal(n); st.add_vertex(verts[fi*4+3])
    
    st.generate_normals()
    st.commit(arr_mesh)
    return arr_mesh


# Expand blueprint back into world at given origin
func expand_blueprint(bp_id: int, origin: Vector3i):
    var data = bp_data.load_blueprint(bp_id)
    if data.is_empty():
        return
    for b in data["blocks"]:
        var pos = origin + Vector3i(b["x"], b["y"], b["z"])
        if not block_mgr.blocks.has(pos):
            block_mgr.place_block(pos, b["i"], null, b["f"], b["d"])
    print("Blueprint ", bp_id, " expanded: ", data["blocks"].size(), " blocks")


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
