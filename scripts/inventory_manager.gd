extends Node

const ItemTypesScript = preload("res://scripts/item_types.gd")

var hotbar: Array = []
var backpack: Array = []
var held_item = null
var selected_slot := 0
var slot_colors: Array = []  # custom colors per hotbar slot
const HOTBAR_SIZE := 10
const BACKPACK_SIZE := 27

func _ready():
	for i in range(HOTBAR_SIZE):
		hotbar.append(ItemTypesScript.ItemSlot.new())
		slot_colors.append(null)
	for i in range(BACKPACK_SIZE):
		backpack.append(ItemTypesScript.ItemSlot.new())
	hotbar[0].add(0, 64, 64)   # Stone
	hotbar[1].add(1, 64, 64)   # Wood
	hotbar[2].add(2, 64, 64)   # Grass
	hotbar[3].add(3, 64, 64)   # Sand
	hotbar[4].add(5, 64, 64)   # Brick
	# 移动方块 (id 6-11)
	hotbar[5].add(8, 64, 64)   # Move+Y
	hotbar[6].add(9, 64, 64)   # Move-Y
	hotbar[7].add(6, 64, 64)   # Move+X
	hotbar[8].add(7, 64, 64)   # Move-X
	hotbar[9].add(10, 64, 64)  # Move+Z
	# 背包填充
	backpack[0].add(4, 64, 64)   # Glass
	backpack[1].add(11, 64, 64)  # Move-Z
	backpack[2].add(12, 64, 64)  # Turn+X
	backpack[3].add(13, 64, 64)  # Turn-X
	backpack[4].add(14, 64, 64)  # Turn+Y
	backpack[5].add(15, 64, 64)  # Turn-Y
	backpack[6].add(16, 64, 64)  # Turn+Z
	backpack[7].add(17, 64, 64)  # Turn-Z

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
