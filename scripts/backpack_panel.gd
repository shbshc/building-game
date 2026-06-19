extends Panel

@onready var inv_mgr = $"../../../InventoryManager"
@onready var item_types_node = $"../../../ItemTypes"
@onready var grid = $Scroll/Grid
var slot_buttons: Array = []

func _ready():
	size = Vector2(500, 350)
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
	# 创造模式：点击即选中，把背包物品复制到 hotbar 当前选中格
	var src_slot = inv_mgr.backpack[index]
	var dst_slot = inv_mgr.hotbar[inv_mgr.selected_slot]
	if src_slot.is_empty():
		return
	dst_slot.item_id = src_slot.item_id
	dst_slot.count = 1

func _on_slot_input(event: InputEvent, index: int):
	# 创造模式：右键和左键一样，选中物品到 hotbar
	if event is InputEventMouseButton and event.pressed:
		_on_slot_clicked(index)

func _process(_delta):
	_refresh()
