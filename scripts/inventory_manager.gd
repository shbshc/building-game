extends Node

const ItemTypesScript = preload("res://scripts/item_types.gd")

var hotbar: Array = []
var backpack: Array = []
var held_item = null
var selected_slot := 0
var slot_colors: Array = []  # custom colors per hotbar slot
const HOTBAR_SIZE := 10
const BACKPACK_SIZE := 100

func _ready():
	for i in range(HOTBAR_SIZE):
		hotbar.append(ItemTypesScript.ItemSlot.new())
		slot_colors.append(null)
	for i in range(BACKPACK_SIZE):
		backpack.append(ItemTypesScript.ItemSlot.new())
	hotbar[0].add(0, 1, 64)   # Stone
	hotbar[1].add(1, 1, 64)   # Wood
	hotbar[2].add(2, 1, 64)   # Grass
	hotbar[3].add(3, 1, 64)   # Sand
	hotbar[4].add(5, 1, 64)   # Brick
	# 移动方块 (id 6-11)
	hotbar[5].add(8, 1, 64)   # Move+Y
	hotbar[6].add(9, 1, 64)   # Move-Y
	hotbar[7].add(6, 1, 64)   # Move+X
	hotbar[8].add(7, 1, 64)   # Move-X
	hotbar[9].add(10, 1, 64)  # Move+Z
	# 背包——包含所有方块，防止物品栏被替换后找不到
	backpack[0].add(0, 1, 64)    # Stone
	backpack[1].add(1, 1, 64)    # Wood
	backpack[2].add(2, 1, 64)    # Grass
	backpack[3].add(3, 1, 64)    # Sand
	backpack[4].add(4, 1, 64)    # Glass
	backpack[5].add(5, 1, 64)    # Brick
	backpack[6].add(6, 1, 64)    # Move+X
	backpack[7].add(7, 1, 64)    # Move-X
	backpack[8].add(8, 1, 64)    # Move+Y
	backpack[9].add(9, 1, 64)    # Move-Y
	backpack[10].add(10, 1, 64)  # Move+Z
	backpack[11].add(11, 1, 64)  # Move-Z
	backpack[12].add(12, 1, 64)  # Turn+X
	backpack[13].add(13, 1, 64)  # Turn-X
	backpack[14].add(14, 1, 64)  # Turn+Y
	backpack[15].add(15, 1, 64)  # Turn-Y
	backpack[16].add(16, 1, 64)  # Turn+Z
	backpack[17].add(17, 1, 64)  # Turn-Z
	backpack[18].add(18, 1, 64)  # Gen+X
	backpack[19].add(19, 1, 64)  # Gen-X
	backpack[20].add(20, 1, 64)  # Gen+Y
	backpack[21].add(21, 1, 64)  # Gen-Y
	backpack[22].add(22, 1, 64)  # Gen+Z
	backpack[23].add(23, 1, 64)  # Gen-Z
	backpack[24].add(24, 1, 64)  # Push+X
	backpack[25].add(25, 1, 64)  # Push-X
	backpack[26].add(26, 1, 64)  # Push+Y
	backpack[27].add(27, 1, 64)  # Push-Y
	backpack[28].add(28, 1, 64)  # Push+Z
	backpack[29].add(29, 1, 64)  # Push-Z

func get_selected_slot():
	return hotbar[selected_slot]

func get_selected_type() -> int:
	return hotbar[selected_slot].item_id

func get_selected_color(item_types_node) -> Color:
	var c = slot_colors[selected_slot]
	if c != null:
		return c
	var t = item_types_node.get_type(get_selected_type())
	if t:
		return t.color
	return Color.RED

func pickup_from(slot):
	if slot.is_empty():
		return
	if held_item == null:
		held_item = ItemTypesScript.ItemSlot.new()
	var tmp_id = held_item.item_id
	var tmp_count = held_item.count
	held_item.item_id = slot.item_id
	held_item.count = slot.count
	slot.item_id = tmp_id
	slot.count = tmp_count
	if slot.is_empty():
		slot.clear()

func place_into(slot, item_types_node):
	if held_item == null or held_item.is_empty():
		return
	if slot.is_empty():
		slot.item_id = held_item.item_id
		slot.count = held_item.count
		held_item.clear()
	elif slot.item_id == held_item.item_id:
		var t = item_types_node.get_type(slot.item_id)
		var max_s = t.max_stack if t else 64
		var remaining = slot.add(held_item.item_id, held_item.count, max_s)
		if remaining > 0:
			held_item.count = remaining
		else:
			held_item.clear()
	else:
		var tmp_id = slot.item_id
		var tmp_count = slot.count
		slot.item_id = held_item.item_id
		slot.count = held_item.count
		held_item.item_id = tmp_id
		held_item.count = tmp_count

func pickup_half(slot):
	if slot.is_empty():
		return
	if held_item == null:
		held_item = ItemTypesScript.ItemSlot.new()
	var half = ceil(slot.count / 2.0)
	held_item.item_id = slot.item_id
	held_item.count = int(half)
	slot.count -= int(half)
	if slot.count <= 0:
		slot.clear()

func place_one(slot, item_types_node):
	if held_item == null or held_item.is_empty():
		return
	if slot.is_empty():
		slot.item_id = held_item.item_id
		slot.count = 1
		held_item.count -= 1
		if held_item.count <= 0:
			held_item.clear()
	elif slot.item_id == held_item.item_id:
		var t = item_types_node.get_type(slot.item_id)
		var max_s = t.max_stack if t else 64
		if slot.count < max_s:
			slot.count += 1
			held_item.count -= 1
			if held_item.count <= 0:
				held_item.clear()
