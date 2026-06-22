extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 5

func save(block_manager, inventory_manager, ground_node) -> bool:
    var data := {
        "version": SAVE_VERSION,
        "blocks": [],
        "inventory": [],
        "ground_color": [0.85, 0.85, 0.85],
        "grid_color": [0.4, 0.4, 0.4]
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
        # 保存贴图 PNG
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
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        return true
    return false

func load(block_manager, inventory_manager, ground_node) -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return false
    var json := JSON.new()
    var err = json.parse(file.get_as_text())
    file.close()
    if err != OK:
        return false
    var data = json.data
    block_manager.clear_all()
    for b in data.get("blocks", []):
        var item_id = b.get("item_id", -1)
        var func_type = b.get("func_type", 0)
        var direction = b.get("direction", 2)
        var model_id = b.get("model_id", "stone")
        # Load custom textures for this model_id and push to atlas
        var face_names := ["top", "bottom", "front", "back", "right", "left"]
        var model = get_node("/root/Main/BlockModel")
        var resolved = model.resolve(model_id)
        var face_keys = resolved.get("faces", {})
        var atlas = get_node("/root/TextureAtlas")
        var textures: Array = []
        for face_idx in range(6):
            var path = "user://textures/%s_face_%d.png" % [model_id, face_idx]
            if FileAccess.file_exists(path):
                var img = Image.load_from_file(path)
                if img:
                    img.resize(16, 16, Image.INTERPOLATE_NEAREST)
                    textures.append(img)
                    # Push to atlas at the model's face key
                    var tex_key = face_keys.get(face_names[face_idx], "stone")
                    atlas.update_slot(tex_key, img)
                else:
                    textures.append(null)
            else:
                textures.append(null)

        block_manager.place_block(
            Vector3i(b["x"], b["y"], b["z"]),
            item_id,
            null,
            func_type,
            direction,
            textures
        )
    var inv = data.get("inventory", [])
    for i in min(inv.size(), inventory_manager.HOTBAR_SIZE):
        var slot_data = inv[i]
        if slot_data is Dictionary:
            inventory_manager.hotbar[i].item_id = slot_data.get("item_id", -1)
            inventory_manager.hotbar[i].count = slot_data.get("count", 0)
        elif slot_data is Array:
            # legacy v1 format: color array, skip
            inventory_manager.hotbar[i].clear()
    if ground_node and data.has("ground_color"):
        var gc = data["ground_color"]
        var gridc = data["grid_color"]
        ground_node.update_colors(Color(gc[0], gc[1], gc[2]), Color(gridc[0], gridc[1], gridc[2]))
    return true
