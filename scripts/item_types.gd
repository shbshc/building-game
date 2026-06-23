extends Node

class ItemType:
	var id: int
	var name: String
	var color: Color
	var max_stack: int = 64
	var func_type: int = 0       # FuncType enum, 0 = 普通方块
	var direction: int = 0       # 方向索引（功能方块专用）
	var model_id: String = ""

	func _init(p_id: int, p_name: String, p_color: Color, p_max: int = 64, p_func: int = 0, p_dir: int = 0, p_model: String = ""):
		id = p_id
		name = p_name
		color = p_color
		max_stack = p_max
		func_type = p_func
		direction = p_dir
		model_id = p_model


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
		# 反转器 (id 35)
		ItemType.new(35, "NOT Gate", Color(0.9, 0.3, 0.5), 64, 11, 0, "not_gate"),
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

func get_model_id(id: int) -> String:
	var t = get_type(id)
	return t.model_id if t else "stone"
