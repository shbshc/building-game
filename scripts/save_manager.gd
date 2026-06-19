extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 4

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
            "direction": b.direction
        })
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
        block_manager.place_block(
            Vector3i(b["x"], b["y"], b["z"]),
            item_id,
            null,
            func_type,
            direction
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
