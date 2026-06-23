# Multi-Save System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `run_skill({name: "subagent-driven-development"})` (recommended) or `run_skill({name: "executing-plans"})` to implement this plan task-by-task.

**Goal:** Replace single save.json with dynamic multi-save system: folder-based slots, naming, popup list UI for save/load.

**Architecture:** `save_manager.gd` extended with multi-slot API (list/create/delete). Two new popup panels (SavePanel, LoadPanel) managed by main.gd. Old save.json auto-migrated to slot_0001.

**Tech Stack:** Godot 4.7, GDScript, GL Compatibility

---

### Task 1: save_manager.gd — Multi-Slot API

**Files:**
- Modify: `scripts/save_manager.gd`

---

- [ ] **Step 1: Rewrite `scripts/save_manager.gd`**

Full replacement — add slot management alongside existing save/load:

```gdscript
extends Node

const SAVES_DIR := "user://saves"
const INDEX_PATH := "user://saves/index.json"
const DATA_FILE := "data.json"
const SAVE_VERSION := 5


# ── Slot management ──

func list_saves() -> Array:
    if not FileAccess.file_exists(INDEX_PATH):
        return []
    var f = FileAccess.open(INDEX_PATH, FileAccess.READ)
    if not f:
        return []
    var json = JSON.new()
    var err = json.parse(f.get_as_text())
    f.close()
    if err != OK:
        return []
    return json.data  # Array of {id, name, created_at, updated_at}


func _save_index(saves: Array):
    DirAccess.make_dir_absolute(SAVES_DIR)
    var f = FileAccess.open(INDEX_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(saves, "\t"))
        f.close()


func _next_id() -> int:
    var saves = list_saves()
    var max_id = 0
    for s in saves:
        if s["id"] > max_id:
            max_id = s["id"]
    return max_id + 1


func create_save(name: String) -> int:
    var sid = _next_id()
    var now = Time.get_datetime_string_from_system()
    var saves = list_saves()
    saves.append({"id": sid, "name": name, "created_at": now, "updated_at": now})
    _save_index(saves)
    var dir = SAVES_DIR + "/slot_%04d" % sid
    DirAccess.make_dir_absolute(dir)
    return sid


func delete_save(slot_id: int):
    var saves = list_saves()
    var new_saves = []
    for s in saves:
        if s["id"] != slot_id:
            new_saves.append(s)
    _save_index(new_saves)
    var dir = SAVES_DIR + "/slot_%04d" % slot_id
    DirAccess.remove_absolute(dir + "/" + DATA_FILE)
    DirAccess.remove_absolute(dir)


func rename_save(slot_id: int, new_name: String):
    var saves = list_saves()
    for s in saves:
        if s["id"] == slot_id:
            s["name"] = new_name
            s["updated_at"] = Time.get_datetime_string_from_system()
    _save_index(saves)


# ── Save / Load ──

func save(slot_id: int, block_manager, inventory_manager, ground_node, camera_rig) -> bool:
    var dir = SAVES_DIR + "/slot_%04d" % slot_id
    DirAccess.make_dir_absolute(dir)
    var data := {
        "version": SAVE_VERSION,
        "blocks": [],
        "inventory": [],
        "ground_color": [0.85, 0.85, 0.85],
        "grid_color": [0.4, 0.4, 0.4],
        "player_position": [0, 0, 0],
        "player_rotation": [0, 0, 0]
    }
    for pos in block_manager.blocks:
        var b = block_manager.blocks[pos]
        data["blocks"].append({
            "x": pos.x, "y": pos.y, "z": pos.z,
            "item_id": b.item_id,
            "func_type": b.func_type,
            "direction": b.direction,
            "model_id": b.model_id
        })
        if b.custom_textures.size() == 6 and b.custom_textures[0] != null:
            DirAccess.make_dir_absolute("user://textures")
            for i in range(6):
                var path = "user://textures/%s_face_%d.png" % [b.model_id, i]
                b.custom_textures[i].save_png(path)

    for slot in inventory_manager.hotbar:
        data["inventory"].append({
            "item_id": slot.item_id,
            "count": slot.count
        })

    if ground_node:
        data["ground_color"] = [ground_node.ground_color.r, ground_node.ground_color.g, ground_node.ground_color.b]
        data["grid_color"] = [ground_node.grid_color.r, ground_node.grid_color.g, ground_node.grid_color.b]

    if camera_rig:
        var p = camera_rig.global_position
        var r = camera_rig.rotation
        data["player_position"] = [p.x, p.y, p.z]
        data["player_rotation"] = [r.x, r.y, r.z]

    var file := FileAccess.open(dir + "/" + DATA_FILE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        # Update index timestamp
        rename_save(slot_id, _get_save_name(slot_id))
        return true
    return false


func _get_save_name(slot_id: int) -> String:
    var saves = list_saves()
    for s in saves:
        if s["id"] == slot_id:
            return s["name"]
    return ""


func load(slot_id: int, block_manager, inventory_manager, ground_node, camera_rig, main_node) -> bool:
    var dir = SAVES_DIR + "/slot_%04d" % slot_id
    var path = dir + "/" + DATA_FILE
    if not FileAccess.file_exists(path):
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return false
    var json := JSON.new()
    var err = json.parse(file.get_as_text())
    file.close()
    if err != OK:
        return false
    var data = json.data

    block_manager.clear_all()

    var face_names := ["top", "bottom", "front", "back", "right", "left"]
    var model = main_node.get_node("BlockModel")
    var atlas = get_node("/root/TextureAtlas")

    for b in data.get("blocks", []):
        var item_id = b.get("item_id", -1)
        var func_type = b.get("func_type", 0)
        var direction = b.get("direction", 2)
        var model_id = b.get("model_id", "stone")

        var resolved = model.resolve(model_id)
        var face_keys = resolved.get("faces", {})
        var textures: Array = []
        for face_idx in range(6):
            var tpath = "user://textures/%s_face_%d.png" % [model_id, face_idx]
            if FileAccess.file_exists(tpath):
                var img = Image.load_from_file(tpath)
                if img:
                    img.resize(16, 16, Image.INTERPOLATE_NEAREST)
                    textures.append(img)
                    var tex_key = face_keys.get(face_names[face_idx], "stone")
                    atlas.update_slot(tex_key, img)
                else:
                    textures.append(null)
            else:
                textures.append(null)

        block_manager.place_block(
            Vector3i(b["x"], b["y"], b["z"]),
            item_id, null, func_type, direction, textures
        )

    var inv = data.get("inventory", [])
    for i in min(inv.size(), inventory_manager.HOTBAR_SIZE):
        var slot_data = inv[i]
        if slot_data is Dictionary:
            inventory_manager.hotbar[i].item_id = slot_data.get("item_id", -1)
            inventory_manager.hotbar[i].count = slot_data.get("count", 0)

    if ground_node and data.has("ground_color"):
        var gc = data["ground_color"]
        var gridc = data["grid_color"]
        ground_node.update_colors(Color(gc[0], gc[1], gc[2]), Color(gridc[0], gridc[1], gridc[2]))

    if camera_rig and data.has("player_position"):
        var pp = data["player_position"]
        camera_rig.global_position = Vector3(pp[0], pp[1], pp[2])
        if data.has("player_rotation"):
            var pr = data["player_rotation"]
            camera_rig.rotation = Vector3(pr[0], pr[1], pr[2])

    return true


# ── Migration ──

func migrate_old_save():
    var old_path = "user://save.json"
    if not FileAccess.file_exists(old_path):
        return
    if FileAccess.file_exists(INDEX_PATH):
        return  # already migrated
    DirAccess.make_dir_absolute(SAVES_DIR)
    var sid = create_save("Migrated Save")
    var dir = SAVES_DIR + "/slot_%04d" % sid
    DirAccess.copy_absolute(old_path, dir + "/" + DATA_FILE)
```

- [ ] **Step 2: Verify** — Run the game, expected console output from existing code unchanged. No runtime errors on startup.

- [ ] **Step 3: Commit**

```bash
git add scripts/save_manager.gd
git commit -m "feat: save_manager — multi-slot API, index.json, migrate_old_save"
```

---

### Task 2: Save Panel (`save_panel.gd` + `save_panel.tscn`)

**Files:**
- Create: `scripts/save_panel.gd`
- Create: `scenes/ui/save_panel.tscn`

---

- [ ] **Step 1: Create `scenes/ui/save_panel.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/save_panel.gd" id="1_sp"]

[node name="SavePanel" type="PopupPanel"]
size = Vector2i(400, 420)
script = ExtResource("1_sp")

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 12.0
offset_top = 8.0
offset_right = 388.0
offset_bottom = 412.0

[node name="TitleBar" type="HBoxContainer" parent="VBox"]
[node name="Title" type="Label" parent="VBox/TitleBar"]
text = "Save Game"
[node name="CloseBtn" type="Button" parent="VBox/TitleBar"]
text = "X"
custom_minimum_size = Vector2(32, 28)

[node name="NameRow" type="HBoxContainer" parent="VBox"]
[node name="NameLabel" type="Label" parent="VBox/NameRow"]
text = "Name:"
[node name="NameInput" type="LineEdit" parent="VBox/NameRow"]
custom_minimum_size = Vector2(260, 28)

[node name="Scroll" type="ScrollContainer" parent="VBox"]
custom_minimum_size = Vector2(0, 260)

[node name="SlotList" type="VBoxContainer" parent="VBox/Scroll"]

[node name="NewBtn" type="Button" parent="VBox"]
text = "New Save"
custom_minimum_size = Vector2(0, 34)
```

- [ ] **Step 2: Create `scripts/save_panel.gd`**

```gdscript
extends PopupPanel

@onready var name_input := $VBox/NameRow/NameInput
@onready var slot_list := $VBox/Scroll/SlotList
@onready var save_manager = $"../../SaveManager"

var _selected_slot := -1
var _block_manager
var _inventory_manager
var _ground_node
var _camera_rig
var _slot_rows: Array = []


func open_panel(block_mgr, inv_mgr, ground, cam):
    _block_manager = block_mgr
    _inventory_manager = inv_mgr
    _ground_node = ground
    _camera_rig = cam
    _selected_slot = -1
    _refresh_list()
    name_input.text = ""
    popup_centered()


func _refresh_list():
    for row in _slot_rows:
        row.queue_free()
    _slot_rows.clear()

    var saves = save_manager.list_saves()
    for s in saves:
        _add_slot_row(s["id"], s["name"], s["updated_at"].split(" ")[0], false)
    # Empty new-slot row at end
    _add_slot_row(-1, "(new)", "", true)


func _add_slot_row(sid: int, sname: String, sdate: String, is_new: bool):
    var row := HBoxContainer.new()
    var btn := Button.new()
    btn.text = "%s   %s" % [sname, sdate] if not is_new else sname
    btn.custom_minimum_size = Vector2(300, 32)
    btn.pressed.connect(_on_slot_clicked.bind(sid))
    row.add_child(btn)

    if not is_new:
        var del := Button.new()
        del.text = "X"
        del.custom_minimum_size = Vector2(32, 32)
        del.pressed.connect(_on_delete.bind(sid))
        row.add_child(del)

    slot_list.add_child(row)
    _slot_rows.append(row)


func _on_slot_clicked(sid: int):
    if sid < 0:
        # New slot
        var name = name_input.text.strip_edges()
        if name == "":
            name = "Save %d" % save_manager._next_id()
        sid = save_manager.create_save(name)
    _selected_slot = sid
    # Confirm overwrite if existing
    _do_save()


func _do_save():
    if _selected_slot < 0:
        return
    var name = name_input.text.strip_edges()
    if name == "":
        name = "Save %d" % _selected_slot
    save_manager.rename_save(_selected_slot, name)
    save_manager.save(_selected_slot, _block_manager, _inventory_manager, _ground_node, _camera_rig)
    _refresh_list()
    hide()


func _on_delete(sid: int):
    save_manager.delete_save(sid)
    _refresh_list()


func _ready():
    $VBox/TitleBar/CloseBtn.pressed.connect(func(): hide())
    $VBox/NewBtn.pressed.connect(_on_slot_clicked.bind(-1))
```

- [ ] **Step 3: Commit**

```bash
git add scripts/save_panel.gd scenes/ui/save_panel.tscn
git commit -m "feat: save_panel — popup list with naming, overwrite, delete, new"
```

---

### Task 3: Load Panel (`load_panel.gd` + `load_panel.tscn`)

**Files:**
- Create: `scripts/load_panel.gd`
- Create: `scenes/ui/load_panel.tscn`

---

- [ ] **Step 1: Create `scenes/ui/load_panel.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/load_panel.gd" id="1_lp"]

[node name="LoadPanel" type="PopupPanel"]
size = Vector2i(400, 380)
script = ExtResource("1_lp")

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 12.0
offset_top = 8.0
offset_right = 388.0
offset_bottom = 372.0

[node name="TitleBar" type="HBoxContainer" parent="VBox"]
[node name="Title" type="Label" parent="VBox/TitleBar"]
text = "Load Game"
[node name="CloseBtn" type="Button" parent="VBox/TitleBar"]
text = "X"
custom_minimum_size = Vector2(32, 28)

[node name="Scroll" type="ScrollContainer" parent="VBox"]
custom_minimum_size = Vector2(0, 300)

[node name="SlotList" type="VBoxContainer" parent="VBox/Scroll"]
```

- [ ] **Step 2: Create `scripts/load_panel.gd`**

```gdscript
extends PopupPanel

@onready var slot_list := $VBox/Scroll/SlotList
@onready var save_manager = $"../../SaveManager"

var _block_manager
var _inventory_manager
var _ground_node
var _camera_rig
var _main_node
var _slot_rows: Array = []


func open_panel(block_mgr, inv_mgr, ground, cam, main):
    _block_manager = block_mgr
    _inventory_manager = inv_mgr
    _ground_node = ground
    _camera_rig = cam
    _main_node = main
    _refresh_list()
    popup_centered()


func _refresh_list():
    for row in _slot_rows:
        row.queue_free()
    _slot_rows.clear()

    var saves = save_manager.list_saves()
    if saves.is_empty():
        var label := Label.new()
        label.text = "No saves found."
        slot_list.add_child(label)
        return

    for s in saves:
        var row := HBoxContainer.new()
        var btn := Button.new()
        btn.text = "%s   %s" % [s["name"], s["updated_at"].split(" ")[0]]
        btn.custom_minimum_size = Vector2(300, 32)
        btn.pressed.connect(_on_load.bind(s["id"]))
        row.add_child(btn)

        var del := Button.new()
        del.text = "X"
        del.custom_minimum_size = Vector2(32, 32)
        del.pressed.connect(_on_delete.bind(s["id"]))
        row.add_child(del)

        slot_list.add_child(row)
        _slot_rows.append(row)


func _on_load(sid: int):
    save_manager.load(sid, _block_manager, _inventory_manager, _ground_node, _camera_rig, _main_node)
    hide()


func _on_delete(sid: int):
    save_manager.delete_save(sid)
    _refresh_list()


func _ready():
    $VBox/TitleBar/CloseBtn.pressed.connect(func(): hide())
```

- [ ] **Step 3: Commit**

```bash
git add scripts/load_panel.gd scenes/ui/load_panel.tscn
git commit -m "feat: load_panel — popup list with load and delete"
```

---

### Task 4: main.gd Integration + Migration

**Files:**
- Modify: `scripts/main.gd`

---

- [ ] **Step 1: Add panel references and instantiation**

Add these `@onready` vars to main.gd (after existing ones):
```gdscript
var save_panel: PopupPanel
var load_panel: PopupPanel
```

In `_ready()`, instantiate (after `_setup_ui()`):
```gdscript
    save_panel = preload("res://scenes/ui/save_panel.tscn").instantiate()
    $UI/UIContainer.add_child(save_panel)

    load_panel = preload("res://scenes/ui/load_panel.tscn").instantiate()
    $UI/UIContainer.add_child(load_panel)

    save_manager.migrate_old_save()
```

- [ ] **Step 2: Replace save/load buttons**

Replace `_on_save_pressed()` body:
```gdscript
func _on_save_pressed():
    save_panel.open_panel(block_manager, $InventoryManager, ground, camera_rig)
```

Replace `_on_load_pressed()` body:
```gdscript
func _on_load_pressed():
    load_panel.open_panel(block_manager, $InventoryManager, ground, camera_rig, self)
```

- [ ] **Step 3: Verify** — Run, confirm old save.json migrates. Open Save panel, create named save. Place blocks, save again. Load a different save, verify blocks restored.

- [ ] **Step 4: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: integrate multi-save panels, migrate old save.json"
```
