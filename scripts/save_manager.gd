extends Node

const SAVE_PATH := "user://save.json"

func save(block_manager, inventory_bar, ground_node) -> bool:
    var data := {
        "version": 1,
        "blocks": [],
        "inventory": [],
        "ground_color": [0.85, 0.85, 0.85],
        "grid_color": [0.4, 0.4, 0.4]
    }
    for pos in block_manager.blocks:
        var b = block_manager.blocks[pos]
        data["blocks"].append({
            "x": pos.x, "y": pos.y, "z": pos.z,
            "color": [b["color"].r, b["color"].g, b["color"].b]
        })
    for c in inventory_bar.inventory_colors:
        data["inventory"].append([c.r, c.g, c.b])
    if ground_node:
        data["ground_color"] = [ground_node.ground_color.r, ground_node.ground_color.g, ground_node.ground_color.b]
        data["grid_color"] = [ground_node.grid_color.r, ground_node.grid_color.g, ground_node.grid_color.b]
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        return true
    return false

func load(block_manager, inventory_bar, ground_node) -> bool:
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
        var c = Color(b["color"][0], b["color"][1], b["color"][2])
        block_manager.selected_color = c
        block_manager.place_block(Vector3i(b["x"], b["y"], b["z"]))
    var inv = data.get("inventory", [])
    for i in min(inv.size(), inventory_bar.SLOT_COUNT):
        var c = inv[i]
        inventory_bar.set_slot_color(i, Color(c[0], c[1], c[2]))
    if ground_node and data.has("ground_color"):
        var gc = data["ground_color"]
        var gridc = data["grid_color"]
        ground_node.update_colors(Color(gc[0], gc[1], gc[2]), Color(gridc[0], gridc[1], gridc[2]))
    return true