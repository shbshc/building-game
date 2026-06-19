extends Control

@onready var inv_mgr = $"../../../InventoryManager"
@onready var item_types_node = $"../../../ItemTypes"
var slot_buttons: Array = []
const SLOT_COUNT := 10
var tooltip_label: Label

func _ready():
	_build_ui()
	get_tree().root.size_changed.connect(_on_resize)

func _build_ui():
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)
	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.name = "Hotbar%d" % i
		btn.custom_minimum_size = Vector2(48, 48)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_slot_clicked.bind(i))
		btn.gui_input.connect(_on_slot_input.bind(i))
		btn.mouse_entered.connect(_on_slot_hover.bind(i))
		btn.mouse_exited.connect(_on_slot_unhover)
		btn.set_drag_forwarding(_get_drag_data.bind(i), _can_drop_data.bind(i), _drop_data.bind(i))
		hbox.add_child(btn)
		slot_buttons.append(btn)
	tooltip_label = Label.new()
	tooltip_label.visible = false
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(tooltip_label)
	_on_resize()

func _on_resize():
	var vp = get_viewport().get_visible_rect().size
	var s = min(48, int((vp.x - 80) / SLOT_COUNT))
	for btn in slot_buttons:
		btn.custom_minimum_size = Vector2(s, s)

func _refresh():
	for i in SLOT_COUNT:
		_draw_slot(i)

func _draw_slot(index: int):
	var btn = slot_buttons[index]
	var slot = inv_mgr.hotbar[index]
	var style := StyleBoxFlat.new()
	if slot.is_empty():
		style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	else:
		var cc = inv_mgr.slot_colors[index]
		if cc != null:
			style.bg_color = cc
		else:
			var t = item_types_node.get_type(slot.item_id)
			style.bg_color = t.color if t else Color.GRAY
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	if index == inv_mgr.selected_slot:
		var sel := StyleBoxFlat.new()
		sel.bg_color = style.bg_color
		sel.border_width_left = 3
		sel.border_width_right = 3
		sel.border_width_top = 3
		sel.border_width_bottom = 3
		sel.border_color = Color.GOLD
		sel.corner_radius_top_left = 4
		sel.corner_radius_top_right = 4
		sel.corner_radius_bottom_left = 4
		sel.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", sel)

func _on_slot_clicked(index: int):
	var slot = inv_mgr.hotbar[index]
	if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
		inv_mgr.place_into(slot, item_types_node)
	else:
		inv_mgr.pickup_from(slot)
	inv_mgr.selected_slot = index

func _on_slot_input(event: InputEvent, index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var slot = inv_mgr.hotbar[index]
			if not slot.is_empty():
				_open_color_picker(index)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			inv_mgr.selected_slot = index

func _open_color_picker(index: int):
	var main_node = $"../../.."
	if main_node.has_method("open_color_picker"):
		main_node.open_color_picker(index)

func _on_slot_hover(index: int):
	var slot = inv_mgr.hotbar[index]
	if not slot.is_empty():
		var t = item_types_node.get_type(slot.item_id)
		if t:
			tooltip_label.text = t.name + " x" + str(slot.count)
			tooltip_label.visible = true

func _on_slot_unhover():
	tooltip_label.visible = false

func _process(_delta):
	if tooltip_label.visible:
		tooltip_label.position = get_global_mouse_position() + Vector2(16, -16)
	_refresh()

func _get_drag_data(index: int, _at_position: Vector2):
	var slot = inv_mgr.hotbar[index]
	if slot.is_empty():
		return null
	inv_mgr.pickup_from(slot)
	var preview := Button.new()
	preview.text = ""
	var s := StyleBoxFlat.new()
	s.bg_color = item_types_node.get_type(slot.item_id).color
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	preview.add_theme_stylebox_override("normal", s)
	preview.size = Vector2(48, 48)
	set_drag_preview(preview)
	return {"source": "hotbar", "index": index}

func _can_drop_data(index: int, data, _at_position: Vector2) -> bool:
	if data == null or inv_mgr.held_item == null:
		return false
	return true

func _drop_data(index: int, data, _at_position: Vector2):
	var slot = inv_mgr.hotbar[index]
	inv_mgr.place_into(slot, item_types_node)
