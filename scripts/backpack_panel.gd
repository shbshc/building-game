extends Panel

@onready var inv_mgr = $"../../../InventoryManager"
@onready var item_types_node = $"../../../ItemTypes"
@onready var grid = $Grid
var slot_buttons: Array = []

func _ready():
	size = Vector2(480, 220)
	for i in range(inv_mgr.BACKPACK_SIZE):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.pressed.connect(_on_slot_clicked.bind(i))
		btn.gui_input.connect(_on_slot_input.bind(i))
		grid.add_child(btn)
		slot_buttons.append(btn)
	hide()

func _refresh():
	for i in range(inv_mgr.BACKPACK_SIZE):
		var btn = slot_buttons[i]
		var slot = inv_mgr.backpack[i]
		var style := StyleBoxFlat.new()
		if slot.is_empty():
			style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		else:
			var t = item_types_node.get_type(slot.item_id)
			style.bg_color = t.color if t else Color.GRAY
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		# 显示物品名字
		if slot.is_empty():
			btn.text = ""
		else:
			btn.text = item_types_node.get_item_name(slot.item_id)
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color.BLACK)
			btn.add_theme_color_override("font_outline_color", Color.WHITE)
			btn.add_theme_constant_override("outline_size", 1)

func _on_slot_clicked(index: int):
	var slot = inv_mgr.backpack[index]
	if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
		inv_mgr.place_into(slot, item_types_node)
	else:
		inv_mgr.pickup_from(slot)

func _on_slot_input(event: InputEvent, index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var slot = inv_mgr.backpack[index]
			if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
				inv_mgr.place_one(slot, item_types_node)
			else:
				inv_mgr.pickup_half(slot)

func _process(_delta):
	_refresh()
