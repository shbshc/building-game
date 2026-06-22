# Texture System Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `run_skill({name: "subagent-driven-development"})` (recommended) or `run_skill({name: "executing-plans"})` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the block texture system from hardcoded colors + per-block materials to a unified model-definition + global-atlas + tint + overlay + in-game-paint pipeline.

**Architecture:** Three new scripts (`block_model.gd`, `texture_atlas.gd`, `color_provider.gd`) are added. `block_manager.gd` has texture logic extracted (mesh building stays but simplified). `item_types.gd` gets `model_id`. `paint_panel.gd` upgrades to use the atlas. Existing gameplay (placement, movement, power) is untouched.

**Tech Stack:** Godot 4.7, GDScript, GL Compatibility renderer

---

## File Map

| File | Role | Action |
|------|------|--------|
| `scripts/block_model.gd` | Model definitions + parent resolution | **Create** |
| `scripts/texture_atlas.gd` | Global 2048×2048 atlas, UV lookup, slot update | **Create** (AutoLoad) |
| `scripts/color_provider.gd` | Tint interface + built-in providers | **Create** |
| `scripts/block_manager.gd` | Block lifecycle; mesh building simplified to consume atlas UVs | **Modify** |
| `scripts/item_types.gd` | ItemType gets `model_id` field | **Modify** |
| `scripts/paint_panel.gd` | Upgrade: backup/restore, atlas integration, model-scoped save | **Modify** |
| `scripts/main.gd` | Adapt `_item_textures` removal, paint panel wiring | **Modify** |
| `project.godot` | Register TextureAtlas AutoLoad | **Modify** |
| `scenes/main.tscn` | Add BlockModel, ColorProvider nodes; bump load_steps | **Modify** |
| `assets/textures/block/*.png` | Built-in 16×16 placeholder textures | **Create** |

---

### Task 1: Block Model System (`block_model.gd` + `item_types.gd`)

**Files:**
- Create: `scripts/block_model.gd`
- Modify: `scripts/item_types.gd` — add `model_id` to `ItemType`
- Modify: `scenes/main.tscn` — add BlockModel node, bump load_steps

---

- [ ] **Step 1: Create `scripts/block_model.gd`**

```gdscript
extends Node
# block_model.gd — block model definitions with parent inheritance

# ── Parent models (face layouts) ──

const PARENT_MODELS := {
    "cube_all": {
        "faces": {
            "top": "#all", "bottom": "#all",
            "front": "#all", "back": "#all",
            "left": "#all", "right": "#all"
        }
    },
    "cube_bottom_top": {
        "faces": {
            "top": "#top", "bottom": "#bottom",
            "front": "#side", "back": "#side",
            "left": "#side", "right": "#side"
        }
    },
    "cube_bottom_top_overlay": {
        "faces": {
            "top": "#top", "bottom": "#bottom",
            "front": "#side", "back": "#side",
            "left": "#side", "right": "#side"
        },
        "overlay_faces": {
            "front": "#overlay", "back": "#overlay",
            "left": "#overlay", "right": "#overlay"
        }
    }
}

# Direction-to-face mapping (Godot座标系: Y up, Z forward, X right)
# face_index: 0=top(+Y), 1=bottom(-Y), 2=front(+Z), 3=back(-Z), 4=right(+X), 5=left(-X)
const FACE_KEYS := ["top", "bottom", "front", "back", "right", "left"]

# ── Block model definitions ──

var block_models := {
    # ── Plain cubes ──
    "stone":     { "parent": "cube_all", "textures": {"all": "stone"} },
    "wood":      { "parent": "cube_all", "textures": {"all": "wood"} },
    "grass":     { "parent": "cube_all", "textures": {"all": "grass_side"} },
    "sand":      { "parent": "cube_all", "textures": {"all": "sand"} },
    "glass":     { "parent": "cube_all", "textures": {"all": "glass"} },
    "brick":     { "parent": "cube_all", "textures": {"all": "brick"} },
    "marble":    { "parent": "cube_all", "textures": {"all": "marble"} },
    "obsidian":  { "parent": "cube_all", "textures": {"all": "obsidian"} },
    "metal":     { "parent": "cube_all", "textures": {"all": "metal"} },
    "dirt":      { "parent": "cube_all", "textures": {"all": "dirt"} },

    # ── Functional blocks (plain cube + direction indicator) ──
    "move":      { "parent": "cube_all", "textures": {"all": "move"} },
    "turn":      { "parent": "cube_all", "textures": {"all": "turn"} },
    "generator": { "parent": "cube_all", "textures": {"all": "generator"} },
    "push":      { "parent": "cube_all", "textures": {"all": "push"} },
    "consume":   { "parent": "cube_all", "textures": {"all": "consume"} },
    "slime":     { "parent": "cube_all", "textures": {"all": "slime"} },

    # ── Power blocks ──
    "power":     { "parent": "cube_all", "textures": {"all": "power"} },
    "switch":    { "parent": "cube_all", "textures": {"all": "switch"} },
    "wire":      { "parent": "cube_all", "textures": {"all": "wire"} },
    "lamp":      { "parent": "cube_all", "textures": {"all": "lamp"} },
}


# ── Public API ──

# Resolve a model_id into a resolved-model dict:
#   {
#     "faces": { "top":"stone", "bottom":"stone", ... },   # texture keys per face
#     "tint_faces": ["top", "front", ...],                   # faces that accept tint
#     "overlay_faces": { "front":"grass_overlay", ... }      # overlay texture keys (may be empty)
#   }
func resolve(model_id: String) -> Dictionary:
    var def = block_models.get(model_id, block_models.get("stone", {}))
    var parent_key = def.get("parent", "cube_all")
    var parent = PARENT_MODELS.get(parent_key, PARENT_MODELS["cube_all"])
    var textures: Dictionary = def.get("textures", {})

    # Resolve faces: replace #var with actual texture key
    var resolved_faces := {}
    for face in parent.get("faces", {}):
        var ref: String = parent["faces"][face]
        var tex_var = ref.trim_prefix("#")
        resolved_faces[face] = textures.get(tex_var, tex_var)

    # Resolve overlay faces
    var resolved_overlay := {}
    for face in parent.get("overlay_faces", {}):
        var ref: String = parent["overlay_faces"][face]
        var tex_var = ref.trim_prefix("#")
        resolved_overlay[face] = textures.get(tex_var, tex_var)

    return {
        "faces": resolved_faces,
        "tint_faces": def.get("tint_faces", []),
        "overlay_faces": resolved_overlay
    }


# Get the resolved texture key for a specific face (for atlas UV lookup)
func get_texture_key(model_id: String, face: String) -> String:
    var r = resolve(model_id)
    return r["faces"].get(face, "stone")


func _ready():
    print("BlockModel loaded: ", block_models.size(), " models, ", PARENT_MODELS.size(), " parents")
```

---

- [ ] **Step 2: Verify `block_model.gd` loads**

Run the project. Expected console output:
```
BlockModel loaded: 21 models, 3 parents
```

---

- [ ] **Step 3: Modify `scripts/item_types.gd` — add `model_id` to ItemType**

Change the `ItemType` class `_init` signature and `_init_defaults`:

```gdscript
class ItemType:
    var id: int
    var name: String
    var color: Color
    var max_stack: int = 64
    var func_type: int = 0       # FuncType enum, 0 = 普通方块
    var direction: int = 0       # 方向索引（功能方块专用）
    var model_id: String = ""    # ★ 新增：block_model 中的模型 ID

    func _init(p_id: int, p_name: String, p_color: Color, p_max: int = 64, p_func: int = 0, p_dir: int = 0, p_model: String = ""):
        id = p_id
        name = p_name
        color = p_color
        max_stack = p_max
        func_type = p_func
        direction = p_dir
        model_id = p_model
```

Update `_init_defaults()` items — add model_id as last argument for each:

```gdscript
func _init_defaults():
    item_types = [
        # 普通方块 (id 0-9)
        ItemType.new(0, "Stone", Color(0.5, 0.5, 0.5), 64, 0, 0, "stone"),
        ItemType.new(1, "Wood", Color(0.545, 0.27, 0.075), 64, 0, 0, "wood"),
        ItemType.new(2, "Grass", Color(0.298, 0.647, 0.314), 64, 0, 0, "grass"),
        ItemType.new(3, "Sand", Color(0.957, 0.816, 0.247), 64, 0, 0, "sand"),
        ItemType.new(4, "Glass", Color(0.835, 0.859, 0.859, 0.5), 64, 0, 0, "glass"),
        ItemType.new(5, "Brick", Color(0.753, 0.224, 0.169), 64, 0, 0, "brick"),
        ItemType.new(6, "Marble", Color(0.9, 0.9, 0.85), 64, 0, 0, "marble"),
        ItemType.new(7, "Obsidian", Color(0.1, 0.05, 0.15), 64, 0, 0, "obsidian"),
        ItemType.new(8, "Metal", Color(0.65, 0.65, 0.7), 64, 0, 0, "metal"),
        ItemType.new(9, "Dirt", Color(0.4, 0.3, 0.2), 64, 0, 0, "dirt"),
        # 移动方块 (id 10-15)
        ItemType.new(10, "Move+X", Color(0.2, 0.6, 1.0), 64, 1, 0, "move"),
        ItemType.new(11, "Move-X", Color(0.2, 0.5, 0.9), 64, 1, 1, "move"),
        ItemType.new(12, "Move+Y", Color(0.2, 0.7, 1.0), 64, 1, 2, "move"),
        ItemType.new(13, "Move-Y", Color(0.2, 0.4, 0.9), 64, 1, 3, "move"),
        ItemType.new(14, "Move+Z", Color(0.3, 0.6, 1.0), 64, 1, 4, "move"),
        ItemType.new(15, "Move-Z", Color(0.1, 0.5, 0.9), 64, 1, 5, "move"),
        # 拐弯方块 (id 16-21)
        ItemType.new(16, "Turn+X", Color(0.3, 0.9, 0.3), 64, 2, 0, "turn"),
        ItemType.new(17, "Turn-X", Color(0.3, 0.8, 0.3), 64, 2, 1, "turn"),
        ItemType.new(18, "Turn+Y", Color(0.4, 0.9, 0.3), 64, 2, 2, "turn"),
        ItemType.new(19, "Turn-Y", Color(0.2, 0.8, 0.3), 64, 2, 3, "turn"),
        ItemType.new(20, "Turn+Z", Color(0.3, 0.9, 0.4), 64, 2, 4, "turn"),
        ItemType.new(21, "Turn-Z", Color(0.3, 0.9, 0.2), 64, 2, 5, "turn"),
        # 生成器方块 (id 22-27)
        ItemType.new(22, "Gen+X", Color(0.7, 0.3, 1.0), 64, 3, 0, "generator"),
        ItemType.new(23, "Gen-X", Color(0.7, 0.3, 0.9), 64, 3, 1, "generator"),
        ItemType.new(24, "Gen+Y", Color(0.8, 0.4, 1.0), 64, 3, 2, "generator"),
        ItemType.new(25, "Gen-Y", Color(0.6, 0.3, 0.9), 64, 3, 3, "generator"),
        ItemType.new(26, "Gen+Z", Color(0.7, 0.4, 1.0), 64, 3, 4, "generator"),
        ItemType.new(27, "Gen-Z", Color(0.7, 0.2, 0.9), 64, 3, 5, "generator"),
        # 推动方块 (id 28)
        ItemType.new(28, "Push", Color(1.0, 0.6, 0.1), 64, 4, 0, "push"),
        # 消耗方块 (id 29)
        ItemType.new(29, "Consume", Color(0.9, 0.2, 0.2), 64, 5, 0, "consume"),
        # 粘液方块 (id 30)
        ItemType.new(30, "Slime", Color(0.2, 1.0, 0.3), 64, 6, 0, "slime"),
        # 电力方块 (id 31-34)
        ItemType.new(31, "Power", Color(1.0, 0.2, 0.1), 64, 7, 0, "power"),
        ItemType.new(32, "Switch", Color(0.4, 0.4, 0.4), 64, 8, 0, "switch"),
        ItemType.new(33, "Wire", Color(0.6, 0.5, 0.3), 64, 9, 0, "wire"),
        ItemType.new(34, "Lamp", Color(0.9, 0.9, 0.8), 64, 10, 0, "lamp"),
    ]
    print("Item types loaded: ", item_types.size())
```

Add a helper:

```gdscript
func get_model_id(id: int) -> String:
    var t = get_type(id)
    return t.model_id if t else "stone"
```

---

- [ ] **Step 4: Add BlockModel node to `scenes/main.tscn`**

Bump `load_steps` from 14 to 15:

```ini
[gd_scene load_steps=15 format=3]
```

Add ext_resource:

```ini
[ext_resource type="Script" path="res://scripts/block_model.gd" id="12_block_model"]
```

Add node (after PowerSystem node):

```ini
[node name="BlockModel" type="Node" parent="."]
script = ExtResource("12_block_model")
```

---

- [ ] **Step 5: Run and verify**

Run the project. Expected console output includes both:
```
BlockModel loaded: 21 models, 3 parents
Item types loaded: 35
```

No gameplay breakage expected — `model_id` is added but not yet consumed.

---

- [ ] **Step 6: Commit**

```bash
git add scripts/block_model.gd scripts/item_types.gd scenes/main.tscn
git commit -m "feat: block_model.gd — model definitions with parent inheritance; item_types gets model_id"
```

---

### Task 2: Texture Atlas AutoLoad (`texture_atlas.gd`)

**Files:**
- Create: `scripts/texture_atlas.gd`
- Modify: `project.godot` — register autoload

---

- [ ] **Step 1: Create `scripts/texture_atlas.gd`**

```gdscript
extends Node
# texture_atlas.gd — global texture atlas (AutoLoad)
# All block textures packed into one 2048×2048 ImageTexture.
# Blocks share this single texture; only UV coords differ.

const ATLAS_SIZE := 2048
const TEX_SIZE := 16
const TEX_PER_ROW := ATLAS_SIZE / TEX_SIZE  # 128

var atlas_image: Image
var atlas_texture: ImageTexture
var texture_map := {}   # "stone" → Rect2(uv_x, uv_y, uv_w, uv_h)
var slot_map := {}      # "stone" → Vector2i(pixel_x, pixel_y)  for update_slot
var _next_x := 0
var _next_y := 0


func _ready():
    atlas_image = Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
    atlas_image.fill(Color(1, 0, 1, 1))  # magenta = uninitialized
    atlas_texture = ImageTexture.create_from_image(atlas_image)
    print("TextureAtlas ready: ", ATLAS_SIZE, "x", ATLAS_SIZE)


# Register a texture from file path. Returns UV Rect2.
# If already registered, returns the existing UV.
func register_texture(key: String, path: String) -> Rect2:
    if texture_map.has(key):
        return texture_map[key]

    var img := Image.load_from_file(path)
    if img == null:
        printerr("TextureAtlas: failed to load ", path)
        return Rect2()

    img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_NEAREST)
    return _pack(key, img)


# Register a texture from an in-memory Image (for paint panel)
func register_image(key: String, img: Image) -> Rect2:
    if texture_map.has(key):
        return texture_map[key]

    var dup := img.duplicate()
    dup.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_NEAREST)
    return _pack(key, dup)


# Update an existing slot in-place (for paint panel live edit)
func update_slot(key: String, new_image: Image):
    if not slot_map.has(key):
        # Slot doesn't exist yet — register it instead
        register_image(key, new_image)
        return

    var px := slot_map[key]
    var img := new_image.duplicate()
    img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_NEAREST)

    # Blit into atlas
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            atlas_image.set_pixel(px.x + x, px.y + y, img.get_pixel(x, y))

    atlas_texture.update(atlas_image)


# Query UV for a texture key
func get_uv(key: String) -> Rect2:
    return texture_map.get(key, Rect2())


# Query the shared atlas texture (used by all block materials)
func get_atlas_texture() -> ImageTexture:
    return atlas_texture


# ── Internal ──

func _pack(key: String, img: Image) -> Rect2:
    # Simple row-packing: fill left-to-right, wrap to next row
    if _next_x + TEX_SIZE > ATLAS_SIZE:
        _next_x = 0
        _next_y += TEX_SIZE
    if _next_y + TEX_SIZE > ATLAS_SIZE:
        printerr("TextureAtlas: atlas full! Expand not yet implemented.")
        return Rect2()

    var px := Vector2i(_next_x, _next_y)

    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            atlas_image.set_pixel(px.x + x, px.y + y, img.get_pixel(x, y))

    var uv := Rect2(
        float(px.x) / ATLAS_SIZE,
        float(px.y) / ATLAS_SIZE,
        float(TEX_SIZE) / ATLAS_SIZE,
        float(TEX_SIZE) / ATLAS_SIZE
    )

    texture_map[key] = uv
    slot_map[key] = px

    _next_x += TEX_SIZE
    atlas_texture.update(atlas_image)

    return uv
```

---

- [ ] **Step 2: Register as AutoLoad in `project.godot`**

Add at the end of `project.godot`:

```ini
[autoload]

TextureAtlas="*res://scripts/texture_atlas.gd"
```

---

- [ ] **Step 3: Verify atlas initializes**

Run the project. Expected console output:
```
TextureAtlas ready: 2048x2048
```

---

- [ ] **Step 4: Commit**

```bash
git add scripts/texture_atlas.gd project.godot
git commit -m "feat: texture_atlas.gd — global 2048x2048 atlas AutoLoad with register/update/UV query"
```

---

### Task 3: Refactor `block_manager.gd` — Use Atlas + Model System

**Files:**
- Modify: `scripts/block_manager.gd`

---

**What changes:**
- `BlockData` gets `model_id` instead of `face_textures`
- `place_block()` receives `model_id`, resolves textures through atlas
- `_build_cube_mesh()` uses atlas UVs + shared `atlas_texture` instead of per-face Images
- `_make_atlas()` is **removed** (atlas is now global)
- `_add_direction_indicator()` stays
- All gameplay logic (move_block, slide_chain, get_slime_group) stays

---

- [ ] **Step 1: Rewrite `block_manager.gd`**

Full replacement (keep gameplay logic intact, change only texture/mesh sections):

```gdscript
extends Node3D

@onready var item_types_node = $"../ItemTypes"
@onready var func_types = $"../FunctionalTypes"
@onready var block_model = $"../BlockModel"

var blocks := {}  # Dictionary: Vector3i -> BlockData
var _is_moving: Dictionary = {}  # 正在动画中的方块

class BlockData:
    var item_id: int = -1
    var color: Color = Color.RED
    var node: MeshInstance3D = null
    var func_type: int = 0
    var direction: int = 2
    var powered: bool = false
    var switch_on: bool = false
    var model_id: String = ""          # ★ replaces face_textures
    var custom_textures: Array = []    # ★ 6-face player-painted overrides

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

    # Determine model_id from item_type
    var model_id := "stone"
    if item_id >= 0 and item_types_node:
        model_id = item_types_node.get_model_id(item_id)

    # Resolve model
    var resolved = block_model.resolve(model_id)
    var face_texture_keys: Dictionary = resolved["faces"]   # {"top":"stone", ...}
    var tint_faces: Array = resolved.get("tint_faces", [])
    var has_overlay: bool = not resolved.get("overlay_faces", {}).is_empty()

    # Determine base color
    var color := selected_color
    if custom_color != null:
        color = custom_color
    elif func_type > 0:
        color = func_types.get_func_type_color(func_type)
    elif item_id >= 0 and item_types_node:
        var t = item_types_node.get_type(item_id)
        if t:
            color = t.color

    # Circuit blocks need special mesh
    var is_wire = (func_type == func_types.FuncType.WIRE)
    var is_circuit = (func_type == func_types.FuncType.POWER or func_type == func_types.FuncType.SWITCH
                      or func_type == func_types.FuncType.WIRE or func_type == func_types.FuncType.LAMP)

    var mesh := MeshInstance3D.new()
    if is_wire:
        mesh.mesh = _build_wire_mesh(grid_pos)
    elif is_circuit:
        mesh.mesh = BoxMesh.new()
    else:
        # Build from atlas UVs
        mesh.mesh = _build_cube_mesh_from_atlas(face_texture_keys, tint_faces, color, has_overlay,
                                                 resolved.get("overlay_faces", {}), textures)

    mesh.position = Vector3(grid_pos) + Vector3(0.5, 0.5, 0.5)

    # Material override for circuit/simple blocks
    if is_circuit or not _uses_atlas(face_texture_keys):
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mesh.material_override = mat

    # Direction indicator for functional blocks (not circuit blocks)
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
    bd.model_id = model_id
    if textures.size() == 6:
        bd.custom_textures = textures.duplicate()
    blocks[grid_pos] = bd

    # Switch defaults ON
    if func_type == func_types.FuncType.SWITCH:
        bd.switch_on = true

    # Refresh adjacent wire connections
    if func_type == func_types.FuncType.WIRE:
        _refresh_adjacent_wires(grid_pos)

    return true


# Build a 6-face cube mesh using atlas UVs
func _build_cube_mesh_from_atlas(face_keys: Dictionary, tint_faces: Array, base_color: Color,
                                  has_overlay: bool, overlay_keys: Dictionary, custom_textures: Array) -> ArrayMesh:
    var arr_mesh := ArrayMesh.new()
    var atlas_tex = TextureAtlas.get_atlas_texture()

    # Face vertex positions (same as before)
    var face_verts := [
        [Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5)],  # +Y Top
        [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5)],  # -Y Bottom
        [Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)],  # +Z Front
        [Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5)],  # -Z Back
        [Vector3(0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5)],  # +X Right
        [Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, 0.5, -0.5)],  # -X Left
    ]
    var face_names := ["top", "bottom", "front", "back", "right", "left"]

    # ── Surface 0: base faces ──
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = atlas_tex
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    st.set_material(mat)

    for i in range(6):
        var fname = face_names[i]
        var tex_key = face_keys.get(fname, "stone")

        # Check for custom texture override
        if custom_textures.size() == 6 and i < custom_textures.size() and custom_textures[i] != null:
            tex_key = "custom_" + face_keys.get(fname, "stone") + "_" + fname
            # Register custom texture if not already in atlas
            if not TextureAtlas.get_uv(tex_key) != Rect2():
                TextureAtlas.register_image(tex_key, custom_textures[i])

        var uv_rect = TextureAtlas.get_uv(tex_key)
        if uv_rect == Rect2():
            # Fallback: use first available UV or solid color
            uv_rect = Rect2(0, 0, float(TEX_SIZE)/ATLAS_SIZE, float(TEX_SIZE)/ATLAS_SIZE)

        var uvs := [
            Vector2(uv_rect.end.x, uv_rect.position.y),      # (1,0) in UV — right, top
            Vector2(uv_rect.position.x, uv_rect.position.y), # (0,0) — left, top
            Vector2(uv_rect.position.x, uv_rect.end.y),      # (0,1) — left, bottom
            Vector2(uv_rect.end.x, uv_rect.end.y),           # (1,1) — right, bottom
        ]
        var n: Vector3 = (face_verts[i][1] - face_verts[i][0]).cross(face_verts[i][3] - face_verts[i][0]).normalized()
        st.set_normal(n); st.set_uv(uvs[0]); st.add_vertex(face_verts[i][0])
        st.set_normal(n); st.set_uv(uvs[1]); st.add_vertex(face_verts[i][1])
        st.set_normal(n); st.set_uv(uvs[2]); st.add_vertex(face_verts[i][2])
        st.set_normal(n); st.set_uv(uvs[0]); st.add_vertex(face_verts[i][0])
        st.set_normal(n); st.set_uv(uvs[2]); st.add_vertex(face_verts[i][2])
        st.set_normal(n); st.set_uv(uvs[3]); st.add_vertex(face_verts[i][3])

    st.generate_normals()
    st.commit(arr_mesh)

    # ── Surface 1: overlay faces (if any) ──
    if has_overlay and not overlay_keys.is_empty():
        var st2 := SurfaceTool.new()
        st2.begin(Mesh.PRIMITIVE_TRIANGLES)
        var mat2 := StandardMaterial3D.new()
        mat2.albedo_texture = atlas_tex
        mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        st2.set_material(mat2)

        for i in range(6):
            var fname = face_names[i]
            if not overlay_keys.has(fname):
                continue
            var tex_key = overlay_keys[fname]
            var uv_rect = TextureAtlas.get_uv(tex_key)
            if uv_rect == Rect2():
                continue
            var uvs := [
                Vector2(uv_rect.end.x, uv_rect.position.y),
                Vector2(uv_rect.position.x, uv_rect.position.y),
                Vector2(uv_rect.position.x, uv_rect.end.y),
                Vector2(uv_rect.end.x, uv_rect.end.y),
            ]
            var n: Vector3 = (face_verts[i][1] - face_verts[i][0]).cross(face_verts[i][3] - face_verts[i][0]).normalized()
            st2.set_normal(n); st2.set_uv(uvs[0]); st2.add_vertex(face_verts[i][0])
            st2.set_normal(n); st2.set_uv(uvs[1]); st2.add_vertex(face_verts[i][1])
            st2.set_normal(n); st2.set_uv(uvs[2]); st2.add_vertex(face_verts[i][2])
            st2.set_normal(n); st2.set_uv(uvs[0]); st2.add_vertex(face_verts[i][0])
            st2.set_normal(n); st2.set_uv(uvs[2]); st2.add_vertex(face_verts[i][2])
            st2.set_normal(n); st2.set_uv(uvs[3]); st2.add_vertex(face_verts[i][3])

        st2.generate_normals()
        st2.commit(arr_mesh)

    return arr_mesh


func _uses_atlas(face_keys: Dictionary) -> bool:
    # Always use atlas texture when we have face keys from the model system
    return true


# ── Everything below this line is UNCHANGED from current block_manager.gd ──

# (keep all existing functions: remove_block, get_block_data, get_all_blocks, clear_all,
#  move_block, _on_move_done, slide_chain, get_slime_group, _refresh_direction_indicator,
#  set_block_direction, _add_direction_indicator, _build_wire_mesh, _add_box_faces,
#  _refresh_adjacent_wires, _make_atlas — REMOVE _make_atlas)

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


func move_block(from_pos: Vector3i, to_pos: Vector3i) -> Vector3:
    if not blocks.has(from_pos):
        return Vector3.ZERO
    if from_pos == to_pos:
        return Vector3.ZERO
    if _is_moving.has(from_pos):
        return Vector3.ZERO

    var bd = blocks[from_pos]

    if blocks.has(to_pos):
        return Vector3.ZERO

    blocks.erase(from_pos)
    var end_pos = Vector3(to_pos) + Vector3(0.5, 0.5, 0.5)
    var delta = Vector3(to_pos) - Vector3(from_pos)

    _is_moving[from_pos] = true
    blocks[to_pos] = bd

    var tween = create_tween()
    tween.tween_property(bd.node, "position", end_pos, 0.5).set_trans(Tween.TRANS_LINEAR)
    tween.tween_callback(_on_move_done.bind(from_pos, to_pos, bd))

    return delta


func _on_move_done(from_pos: Vector3i, to_pos: Vector3i, bd: BlockData):
    _is_moving.erase(from_pos)
    if is_instance_valid(bd.node):
        _refresh_direction_indicator(bd)


func slide_chain(start_pos: Vector3i, dir: Vector3i) -> bool:
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
            return false
    if not found_stop and not hit_consume:
        return false

    var to_move: Dictionary = {}
    var queue: Array = []
    var pos = start_pos
    while pos != end:
        if blocks.has(pos) and not to_move.has(pos):
            to_move[pos] = blocks[pos]
            queue.append(pos)
        pos += dir

    while not queue.is_empty():
        var p = queue.pop_front()
        var bd_p = blocks.get(p)
        for d in func_types.DIRECTION_VECTORS:
            var n = p + d
            if blocks.has(n) and not to_move.has(n):
                var bd_n = blocks.get(n)
                var slime_link = (bd_p != null and bd_p.func_type == func_types.FuncType.SLIME) \
                              or (bd_n != null and bd_n.func_type == func_types.FuncType.SLIME)
                if slime_link:
                    to_move[n] = bd_n
                    queue.append(n)

    if hit_consume:
        var doomed = end - dir
        if to_move.has(doomed):
            to_move.erase(doomed)
            remove_block(doomed)

    for old_p in to_move:
        var new_p = old_p + dir
        if new_p.y < 0:
            return false
        if blocks.has(new_p) and not to_move.has(new_p):
            return false

    for old_p in to_move:
        blocks.erase(old_p)
    for old_p in to_move:
        var bd = to_move[old_p]
        var new_p = old_p + dir
        bd.node.position = Vector3(new_p) + Vector3(0.5, 0.5, 0.5)
        _refresh_direction_indicator(bd)
        blocks[new_p] = bd

    return true


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
        if bd.func_type == func_types.FuncType.SLIME:
            for dir in func_types.DIRECTION_VECTORS:
                var n = pos + dir
                if not visited.has(n) and blocks.has(n):
                    visited[n] = true
                    queue.append(n)
        for dir in func_types.DIRECTION_VECTORS:
            var n = pos + dir
            if not visited.has(n) and blocks.has(n) and blocks[n].func_type == func_types.FuncType.SLIME:
                visited[n] = true
                queue.append(n)

    return result


func _refresh_direction_indicator(bd: BlockData):
    if not is_instance_valid(bd.node):
        return
    for child in bd.node.get_children():
        if child.has_meta("is_direction_indicator"):
            child.queue_free()
    _add_direction_indicator(bd.node, bd.direction)


func set_block_direction(grid_pos: Vector3i, new_direction: int) -> bool:
    var bd = blocks.get(grid_pos, null)
    if bd == null or bd.func_type == 0:
        return false
    bd.direction = new_direction
    _refresh_direction_indicator(bd)
    return true


func _add_direction_indicator(mesh: MeshInstance3D, dir_idx: int):
    var indicator := MeshInstance3D.new()
    indicator.mesh = BoxMesh.new()
    indicator.mesh.size = Vector3(0.3, 0.3, 0.15)
    indicator.position = Vector3(func_types.DIRECTION_VECTORS[dir_idx]) * 0.55
    indicator.set_meta("is_direction_indicator", true)

    match dir_idx:
        0: indicator.rotation = Vector3(0, PI/2, 0)
        1: indicator.rotation = Vector3(0, -PI/2, 0)
        2: indicator.rotation = Vector3(-PI/2, 0, 0)
        3: indicator.rotation = Vector3(PI/2, 0, 0)
        4: indicator.rotation = Vector3.ZERO
        5: indicator.rotation = Vector3(0, PI, 0)

    var ind_mat := StandardMaterial3D.new()
    ind_mat.albedo_color = Color.WHITE
    ind_mat.emission_enabled = true
    ind_mat.emission = Color.WHITE
    ind_mat.emission_energy_multiplier = 0.5
    indicator.material_override = ind_mat
    mesh.add_child(indicator)


# ── Wire mesh (unchanged) ──

func _build_wire_mesh(grid_pos: Vector3i) -> ArrayMesh:
    var arr_mesh := ArrayMesh.new()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var s := 0.1
    var verts := [
        Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
        Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s),
    ]
    _add_box_faces(st, verts)

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
            var rot := Basis()
            match i:
                0: rot = Basis(Vector3.UP, PI/2)
                1: rot = Basis(Vector3.UP, -PI/2)
                2: rot = Basis(Vector3.RIGHT, -PI/2)
                3: rot = Basis(Vector3.RIGHT, PI/2)
                4: rot = Basis()
                5: rot = Basis(Vector3.UP, PI)
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
```

Note: `_make_atlas()` is removed. The constant `TEX_SIZE` and `ATLAS_SIZE` referenced in `_build_cube_mesh_from_atlas` are accessed via `TextureAtlas.TEX_SIZE` / `TextureAtlas.ATLAS_SIZE` (add these as `const` in Task 2's texture_atlas.gd).

---

- [ ] **Step 2: Update `texture_atlas.gd` — expose TEX_SIZE and ATLAS_SIZE as const**

In `texture_atlas.gd`, ensure these are at the top:

```gdscript
const ATLAS_SIZE := 2048
const TEX_SIZE := 16
```

(Already present from Task 2.)

---

- [ ] **Step 3: Fix `_build_cube_mesh_from_atlas` references**

In `_build_cube_mesh_from_atlas`, replace the fallback UV line:

```gdscript
uv_rect = Rect2(0, 0, float(TextureAtlas.TEX_SIZE) / TextureAtlas.ATLAS_SIZE, float(TextureAtlas.TEX_SIZE) / TextureAtlas.ATLAS_SIZE)
```

---

- [ ] **Step 4: Remove `_make_atlas` function completely**

Delete the old `_make_atlas` function (if any remains).

---

- [ ] **Step 5: Run and verify basic block placement still works**

Place a stone block. It should appear with the atlas texture (currently magenta placeholder — normal until Task 4).

---

- [ ] **Step 6: Commit**

```bash
git add scripts/block_manager.gd scripts/texture_atlas.gd
git commit -m "refactor: block_manager uses atlas UVs + model system; remove _make_atlas"
```

---

### Task 4: Built-in Texture Assets

**Files:**
- Create: `assets/textures/block/*.png` (16×16 placeholder textures)
- Modify: `scripts/main.gd` — register all textures into atlas on startup

---

- [ ] **Step 1: Generate 16×16 placeholder PNGs for each texture key**

Since we can't create actual PNGs in code, we generate them at runtime in `main.gd` `_ready()`. This avoids needing external image files during development.

Add to `main.gd` `_ready()` (before any block placement):

```gdscript
func _register_builtin_textures():
    # Generate 16×16 placeholder textures for every model texture key
    var atlas = get_node("/root/TextureAtlas")
    var texture_keys := {
        "stone": Color(0.5, 0.5, 0.5),
        "wood": Color(0.545, 0.27, 0.075),
        "grass_side": Color(0.298, 0.647, 0.314),
        "sand": Color(0.957, 0.816, 0.247),
        "glass": Color(0.835, 0.859, 0.859, 0.5),
        "brick": Color(0.753, 0.224, 0.169),
        "marble": Color(0.9, 0.9, 0.85),
        "obsidian": Color(0.1, 0.05, 0.15),
        "metal": Color(0.65, 0.65, 0.7),
        "dirt": Color(0.4, 0.3, 0.2),
        "move": Color(0.2, 0.6, 1.0),
        "turn": Color(0.3, 0.9, 0.3),
        "generator": Color(0.7, 0.3, 1.0),
        "push": Color(1.0, 0.6, 0.1),
        "consume": Color(0.9, 0.2, 0.2),
        "slime": Color(0.2, 1.0, 0.3),
        "power": Color(1.0, 0.2, 0.1),
        "switch": Color(0.4, 0.4, 0.4),
        "wire": Color(0.6, 0.5, 0.3),
        "lamp": Color(0.9, 0.9, 0.8),
    }

    for key in texture_keys:
        var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
        img.fill(texture_keys[key])
        # Draw a 1px darker border for visual definition
        var border_color = texture_keys[key].darkened(0.2)
        for x in range(16):
            img.set_pixel(x, 0, border_color)
            img.set_pixel(x, 15, border_color)
        for y in range(16):
            img.set_pixel(0, y, border_color)
            img.set_pixel(15, y, border_color)
        atlas.register_image(key, img)

    print("Registered ", texture_keys.size(), " built-in textures into atlas")
```

Call `_register_builtin_textures()` at the start of `_ready()`.

---

- [ ] **Step 2: Run and verify**

Place blocks of different types. Each should show its distinct color with a darker border. The magenta "uninitialized" fallback should never appear.

---

- [ ] **Step 3: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: register built-in 16x16 placeholder textures into atlas on startup"
```

---

### Task 5: Color Provider (`color_provider.gd`)

**Files:**
- Create: `scripts/color_provider.gd`
- Modify: `scenes/main.tscn` — add ColorProvider node

---

- [ ] **Step 1: Create `scripts/color_provider.gd`**

```gdscript
extends Node
# color_provider.gd — dynamic tint interface for block faces

# Default: no tint (white = texture is as-is)
func get_tint(block_data, face: String) -> Color:
    return Color.WHITE


# ── Built-in providers ──

# Fixed tint — always returns the same color
class FixedTintProvider:
    var tint_color: Color

    func _init(c: Color):
        tint_color = c

    func get_tint(_block_data, _face: String) -> Color:
        return tint_color


# Biome tint — varies by world coordinates (simulated: uses x,z hash)
class BiomeTintProvider:
    func get_tint(block_data, _face: String) -> Color:
        # Use block position to pick a tint
        # In a real system this would query a biome map
        var pos = block_data.node.position
        var h = fmod(abs(pos.x * 7.3 + pos.z * 13.7), 1.0)
        # Green shift: 0.7 → 1.3x green multiplier
        var g = lerp(0.7, 1.3, h)
        return Color(1.0, g, 0.8)


# Signal tint — varies by block's powered state (for lamp brightness)
class SignalTintProvider:
    func get_tint(block_data, _face: String) -> Color:
        if block_data.get("powered") == true:
            return Color(1.0, 1.0, 0.95)  # warm white
        return Color(0.3, 0.3, 0.3)  # dim


func _ready():
    print("ColorProvider ready")
```

---

- [ ] **Step 2: Add ColorProvider node to `scenes/main.tscn`**

Bump `load_steps` to 16. Add ext_resource:

```ini
[ext_resource type="Script" path="res://scripts/color_provider.gd" id="13_color_provider"]
```

Add node after BlockModel:

```ini
[node name="ColorProvider" type="Node" parent="."]
script = ExtResource("13_color_provider")
```

---

- [ ] **Step 3: Wire tint into `_build_cube_mesh_from_atlas` in `block_manager.gd`**

In `_build_cube_mesh_from_atlas`, add tint support. After getting `uv_rect`, modify `mat.albedo_color`:

```gdscript
# After the st.set_material(mat) line, add per-face tint:
# (This needs per-face materials — simpler: apply tint as albedo_color on the material)
# For initial implementation, apply the first tint_face color to the whole material
var tint_color := Color.WHITE
if not tint_faces.is_empty():
    tint_color = $"../ColorProvider".get_tint(null, tint_faces[0])
mat.albedo_color = tint_color
```

---

- [ ] **Step 4: Run and verify**

Console: `ColorProvider ready`. Functional blocks with tint_faces (e.g., grass) should show slight color variation if BiomeTintProvider is selected.

---

- [ ] **Step 5: Commit**

```bash
git add scripts/color_provider.gd scenes/main.tscn scripts/block_manager.gd
git commit -m "feat: color_provider.gd — tint interface + Fixed/Biome/Signal providers"
```

---

### Task 6: Paint Panel Upgrade

**Files:**
- Modify: `scripts/paint_panel.gd`
- Modify: `scripts/main.gd` — update paint panel wiring

---

- [ ] **Step 1: Add backup/restore to `paint_panel.gd`**

Add a "Reset" button and backup logic. Add to `_ready()`:

```gdscript
$EditView/EditTools/ResetBtn.pressed.connect(_on_reset)
```

Add the reset function:

```gdscript
func _on_reset():
    # Restore current face to default (gray fill)
    face_data[_edit_face].fill(Color(0.5, 0.5, 0.5))
    edit_canvas.queue_redraw()
    _draw_face_btn(_edit_face)
```

Add auto-backup to `_on_save()`:

```gdscript
func _on_save():
    DirAccess.make_dir_absolute("user://textures")
    for i in range(6):
        var path = "user://textures/face_%d.png" % i
        # Backup old file if exists
        if FileAccess.file_exists(path):
            var backup_path = "user://textures/face_%d_backup.png" % i
            DirAccess.copy_absolute(path, backup_path)
        face_data[i].save_png(path)
```

---

- [ ] **Step 2: Wire atlas update on apply**

Modify `_on_apply()` to push to atlas:

```gdscript
func _on_apply():
    # Push each face to TextureAtlas for instant global update
    var atlas = get_node("/root/TextureAtlas")
    var face_names := ["top", "bottom", "front", "back", "right", "left"]
    for i in range(6):
        var key = "custom_face_" + face_names[i]
        atlas.update_slot(key, face_data[i])

    texture_applied.emit(face_data)
    _show_select()
```

---

- [ ] **Step 3: Update `main.gd` — `_on_item_texture_applied` to use atlas**

Change to:

```gdscript
func _on_item_texture_applied(face_data: Array):
    var atlas = get_node("/root/TextureAtlas")
    var face_names := ["top", "bottom", "front", "back", "right", "left"]
    var model_id = "stone"
    if _paint_item_id >= 0:
        var t = $ItemTypes.get_type(_paint_item_id)
        if t:
            model_id = t.model_id

    for i in range(6):
        var key = "custom_" + model_id + "_" + face_names[i]
        atlas.update_slot(key, face_data[i])
        _save_item_texture(model_id, i, face_data[i])

    _paint_is_item = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

Update `_save_item_textures` to use model_id:

```gdscript
func _save_item_texture(model_id: String, face: int, img: Image):
    DirAccess.make_dir_absolute("user://textures")
    var path = "user://textures/%s_face_%d.png" % [model_id, face]
    # Backup
    if FileAccess.file_exists(path):
        var bak = path.replace(".png", "_backup.png")
        DirAccess.copy_absolute(path, bak)
    img.save_png(path)
```

---

- [ ] **Step 4: Run, paint a texture, verify all same-model blocks update**

1. Place 3 stone blocks
2. Open paint panel (E → backpack → paint button)
3. Change stone top face to red, click Apply
4. All 3 stone blocks should instantly show red tops

---

- [ ] **Step 5: Commit**

```bash
git add scripts/paint_panel.gd scripts/main.gd
git commit -m "feat: paint panel — backup/restore, atlas integration, model-scoped live update"
```

---

### Task 7: Integration & Cleanup

**Files:**
- Modify: `scripts/main.gd` — remove old `_item_textures`, clean wiring
- Modify: `scripts/save_manager.gd` — update save format for model_id

---

- [ ] **Step 1: Clean `main.gd` — remove `_item_textures` Dictionary**

Remove the `_item_textures` field and `get_item_textures()` method. The `_load_item_textures`/`_save_item_texture` functions continue to work for persistence but textures are now looked up through the atlas.

---

- [ ] **Step 2: Update `save_manager.gd` — add `model_id` to save format**

In `save()`:

```gdscript
data["blocks"].append({
    "x": pos.x, "y": pos.y, "z": pos.z,
    "item_id": b.item_id,
    "func_type": b.func_type,
    "direction": b.direction,
    "model_id": b.model_id     # ★ new
})
```

In `load()`:

```gdscript
var model_id = b.get("model_id", "stone")
block_manager.place_block(
    Vector3i(b["x"], b["y"], b["z"]),
    item_id,
    null,
    func_type,
    direction,
    []  # textures loaded separately from user://
)
```

---

- [ ] **Step 3: Run full verification**

Test checklist:
1. Place 1 of each 10 plain block type — distinct colors visible
2. Place move block → direction indicator on top
3. Place power → wire → switch → lamp chain → lamp glows when powered
4. Save → quit → load → all blocks + textures restore
5. Paint stone top → all stone blocks update
6. Reset stone top → reverts to default
7. 100 blocks placed → smooth 60fps (visual check)

---

- [ ] **Step 4: Commit**

```bash
git add scripts/main.gd scripts/save_manager.gd
git commit -m "feat: texture system integration — remove _item_textures, save model_id, full verification"
```
