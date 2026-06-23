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
    return json.data


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
        return true
    return false


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
        return
    DirAccess.make_dir_absolute(SAVES_DIR)
    var sid = create_save("Migrated Save")
    var dir = SAVES_DIR + "/slot_%04d" % sid
    DirAccess.copy_absolute(old_path, dir + "/" + DATA_FILE)
