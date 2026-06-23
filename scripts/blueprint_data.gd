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
