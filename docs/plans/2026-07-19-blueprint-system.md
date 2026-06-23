# Blueprint System — Implementation Plan

> **For agentic workers:** Use `run_skill({name: "subagent-driven-development"})` to implement.

**Goal:** Blueprint tool: drag-select a cuboid region, compress into a reusable blueprint block with miniature 6-face projection and expand-on-place.

**Architecture:** `blueprint_data.gd` handles JSON save/load. `blueprint_tool.gd` handles selection UX and compress/expand. `main.gd` wires the tool into inventory.

**Tech Stack:** Godot 4.7, GDScript

---

### Task 1: Blueprint Data Layer

**Files:**
- Create: `scripts/blueprint_data.gd`

---

- [ ] **Step 1: Create `scripts/blueprint_data.gd`**

```gdscript
extends Node

const BP_DIR := "user://blueprints"
var _next_id := 1


func save_blueprint(name: String, size: Vector3i, blocks: Array) -> int:
    DirAccess.make_dir_absolute(BP_DIR)
    var bp_id = _next_id
    _next_id += 1
    var path = BP_DIR + "/bp_%04d.json" % bp_id
    var data := {
        "name": name,
        "size": [size.x, size.y, size.z],
        "blocks": blocks
    }
    var f = FileAccess.open(path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data, "\t"))
        f.close()
    return bp_id


func load_blueprint(bp_id: int) -> Dictionary:
    var path = BP_DIR + "/bp_%04d.json" % bp_id
    if not FileAccess.file_exists(path):
        return {}
    var f = FileAccess.open(path, FileAccess.READ)
    if not f:
        return {}
    var json = JSON.new()
    var err = json.parse(f.get_as_text())
    f.close()
    if err != OK:
        return {}
    return json.data


func list_blueprints() -> Array:
    if not DirAccess.dir_exists_absolute(BP_DIR):
        return []
    var result = []
    var dir = DirAccess.open(BP_DIR)
    if dir:
        dir.list_dir_begin()
        var fn = dir.get_next()
        while fn != "":
            if fn.begins_with("bp_") and fn.ends_with(".json"):
                var sid = fn.trim_prefix("bp_").trim_suffix(".json").to_int()
                result.append(sid)
            fn = dir.get_next()
    result.sort()
    return result
```

- [ ] **Step 2: Add BlueprintData node to `scenes/main.tscn`**

Bump load_steps, add ext_resource, add node.

- [ ] **Step 3: Commit** `feat: blueprint_data.gd — JSON save/load for blueprint blocks`

---

### Task 2: Blueprint Tool — Selection & Compression

**Files:**
- Create: `scripts/blueprint_tool.gd`
- Modify: `scripts/main.gd` — add tool to inventory, wire input

---

- [ ] **Step 1: Create `scripts/blueprint_tool.gd`**

```gdscript
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
            var size = _get_size()
            if size.x > 0 and size.x in VALID_SIZES:
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
    var size = _get_size()
    if size.x != size.y or size.y != size.z or size.x not in VALID_SIZES:
        _highlight.visible = false
        return
    var mn := Vector3i(min(_p1.x, _p2.x), min(_p1.y, _p2.y), min(_p1.z, _p2.z))
    var center = Vector3(mn) + Vector3(size) * 0.5
    _highlight.position = center
    _highlight.mesh.size = Vector3(size)
    _highlight.visible = true


func _on_compress():
    var size = _get_size()
    var mn := Vector3i(min(_p1.x, _p2.x), min(_p1.y, _p2.y), min(_p1.z, _p2.z))
    var blocks := []
    for x in range(mn.x, mn.x + size.x):
        for y in range(mn.y, mn.y + size.y):
            for z in range(mn.z, mn.z + size.z):
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
    var bp_id = bp_data.save_blueprint("Blueprint", size, blocks)
    # Add blueprint item to inventory
    var inv_mgr = $"../InventoryManager"
    var backpack = inv_mgr.backpack
    for slot in backpack:
        if slot.is_empty():
            slot.add(1000 + bp_id, 1, 64)  # item_id 1000+ = blueprint
            break
    _highlight.visible = false
    deactivate()
```

- [ ] **Step 2: Add BlueprintData node to main.tscn**

- [ ] **Step 3: Commit** `feat: blueprint_tool — drag-select, compress to JSON, add to inventory`

---

### Task 3: Miniature Texture Generation

**Files:**
- Modify: `scripts/blueprint_tool.gd` — add render-to-texture

---

- [ ] **Step 1: Add `_render_miniature()` to blueprint_tool.gd**

Generate 6-face 16×16 projections using a temporary SubViewport. For each face direction, position a camera facing the compressed blocks, render to 16×16, capture as Image.

```gdscript
func _render_miniature(bp_id: int) -> Array:
    var data = bp_data.load_blueprint(bp_id)
    if data.is_empty():
        return []
    var size_arr = data["size"]
    var size_v = Vector3(size_arr[0], size_arr[1], size_arr[2])
    var blocks_arr = data["blocks"]
    
    # Build temp blocks in isolated viewport
    var vp := SubViewport.new()
    vp.size = Vector2i(16, 16)
    vp.transparent_bg = true
    add_child(vp)
    
    var cam := Camera3D.new()
    cam.size = max(size_v.x, size_v.y, size_v.z) * 1.5
    cam.projection = Camera3D.PROJECTION_ORTHOGONAL
    vp.add_child(cam)
    
    var tmp_blocks := Node3D.new()
    vp.add_child(tmp_blocks)
    
    for b in blocks_arr:
        var mesh := MeshInstance3D.new()
        mesh.mesh = BoxMesh.new()
        mesh.position = Vector3(b["x"], b["y"], b["z"]) + Vector3(0.5, 0.5, 0.5)
        var mat := StandardMaterial3D.new()
        var item_node = $"../ItemTypes"
        var t = item_node.get_type(b["i"])
        mat.albedo_color = t.color if t else Color.GRAY
        mesh.material_override = mat
        tmp_blocks.add_child(mesh)
    
    var center = Vector3(size_v) * 0.5
    var dist = max(size_v.x, size_v.y, size_v.z) * 2
    
    var faces := [
        {"dir": Vector3(0, 1, 0), "up": Vector3(0, 0, -1)},
        {"dir": Vector3(0, -1, 0), "up": Vector3(0, 0, 1)},
        {"dir": Vector3(0, 0, 1), "up": Vector3(0, 1, 0)},
        {"dir": Vector3(0, 0, -1), "up": Vector3(0, 1, 0)},
        {"dir": Vector3(1, 0, 0), "up": Vector3(0, 1, 0)},
        {"dir": Vector3(-1, 0, 0), "up": Vector3(0, 1, 0)},
    ]
    
    var result: Array = []
    for fc in faces:
        cam.global_position = center + fc["dir"] * dist
        cam.look_at(center, fc["up"])
        await get_tree().process_frame
        var img = vp.get_texture().get_image()
        img.resize(16, 16, Image.INTERPOLATE_LANCZOS)
        result.append(img)
    
    vp.queue_free()
    return result
```

- [ ] **Step 2: Commit** `feat: blueprint miniature — 6-face projection to 16×16 textures`

---

### Task 4: Expand on Place

**Files:**
- Modify: `scripts/blueprint_tool.gd` — add expand function
- Modify: `scripts/raycast_handler.gd` — blueprint item placement

---

- [ ] **Step 1: Add expand function to blueprint_tool.gd**

```gdscript
func expand_blueprint(bp_id: int, origin: Vector3i):
    var data = bp_data.load_blueprint(bp_id)
    if data.is_empty():
        return
    for b in data["blocks"]:
        var pos = origin + Vector3i(b["x"], b["y"], b["z"])
        if not block_mgr.blocks.has(pos):
            block_mgr.place_block(pos, b["i"], null, b["f"], b["d"])
```

- [ ] **Step 2: Wire blueprint item placement in raycast_handler.gd**

When selected item_id >= 1000 → it's a blueprint. Left-click → expand at position instead of placing a normal block.

- [ ] **Step 3: Commit** `feat: blueprint expand — place compressed blocks back into world`
