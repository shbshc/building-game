extends Node

class ItemType:
    var id: int
    var name: String
    var color: Color
    var max_stack: int = 64
    var func_type: int = 0       # FuncType enum, 0 = 普通方块
    var direction: int = 0       # 方向索引（功能方块专用）

    func _init(p_id: int, p_name: String, p_color: Color, p_max: int = 64, p_func: int = 0, p_dir: int = 0):
        id = p_id
        name = p_name
        color = p_color
        max_stack = p_max
        func_type = p_func
        direction = p_dir


class ItemSlot:
    var item_id: int = -1
    var count: int = 0

    func is_empty() -> bool:
        return item_id < 0 or count <= 0

    func clear():
        item_id = -1
        count = 0

    func can_accept(id: int, max_stack: int) -> bool:
        if is_empty():
            return true
        return id == item_id and count < max_stack

    func add(id: int, amount: int, max_stack: int) -> int:
        if is_empty():
            item_id = id
            count = 0
        if id != item_id:
            return amount
        var space = max_stack - count
        var to_add = min(amount, space)
        count += to_add
        return amount - to_add

    func remove(amount: int) -> int:
        var to_remove = min(amount, count)
        count -= to_remove
        if count <= 0:
            clear()
        return to_remove


var item_types: Array = []

func _ready():
    _init_defaults()

func _init_defaults():
    item_types = [
        # 普通方块 (id 0-5)
        ItemType.new(0, "Stone", Color(0.5, 0.5, 0.5)),
        ItemType.new(1, "Wood", Color(0.545, 0.27, 0.075)),
        ItemType.new(2, "Grass", Color(0.298, 0.647, 0.314)),
        ItemType.new(3, "Sand", Color(0.957, 0.816, 0.247)),
        ItemType.new(4, "Glass", Color(0.835, 0.859, 0.859, 0.5)),
        ItemType.new(5, "Brick", Color(0.753, 0.224, 0.169)),
        # 移动方块 (id 6-11), 方向与 DIRECTION_VECTORS 索引一致
        ItemType.new(6,  "Move+X", Color(0.2, 0.6, 1.0), 64, 1, 0),
        ItemType.new(7,  "Move-X", Color(0.2, 0.5, 0.9), 64, 1, 1),
        ItemType.new(8,  "Move+Y", Color(0.2, 0.7, 1.0), 64, 1, 2),
        ItemType.new(9,  "Move-Y", Color(0.2, 0.4, 0.9), 64, 1, 3),
        ItemType.new(10, "Move+Z", Color(0.3, 0.6, 1.0), 64, 1, 4),
        ItemType.new(11, "Move-Z", Color(0.1, 0.5, 0.9), 64, 1, 5),
        # 拐弯方块 (id 12-17), 方向与 DIRECTION_VECTORS 索引一致
        ItemType.new(12, "Turn+X", Color(0.3, 0.9, 0.3), 64, 2, 0),
        ItemType.new(13, "Turn-X", Color(0.3, 0.8, 0.3), 64, 2, 1),
        ItemType.new(14, "Turn+Y", Color(0.4, 0.9, 0.3), 64, 2, 2),
        ItemType.new(15, "Turn-Y", Color(0.2, 0.8, 0.3), 64, 2, 3),
        ItemType.new(16, "Turn+Z", Color(0.3, 0.9, 0.4), 64, 2, 4),
        ItemType.new(17, "Turn-Z", Color(0.3, 0.9, 0.2), 64, 2, 5),
    ]
    print("Item types loaded: ", item_types.size())

func get_type(id: int):
    if id >= 0 and id < item_types.size():
        return item_types[id]
    return null

func get_item_name(id: int) -> String:
    var t = get_type(id)
    return t.name if t else "Unknown"

func is_functional(id: int) -> bool:
    var t = get_type(id)
    return t != null and t.func_type > 0

func get_func_type(id: int) -> int:
    var t = get_type(id)
    return t.func_type if t else 0

func get_direction(id: int) -> int:
    var t = get_type(id)
    return t.direction if t else 0
