extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/UIContainer/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground

var color_picker_popup: PopupPanel
var ground_color_popup: PopupPanel

func _ready():
    print("=== Game started ===")
    _setup_ui()
    _create_popups()
    _connect_signals()
    block_manager.selected_color = inventory_bar.get_selected_color()

func _setup_ui():
    var ui_root = $UI/UIContainer
    var save_btn = _make_button("Save", Vector2(8, 6))
    save_btn.pressed.connect(_on_save_pressed)
    ui_root.add_child(save_btn)
    
    var load_btn = _make_button("Load", Vector2(82, 6))
    load_btn.pressed.connect(_on_load_pressed)
    ui_root.add_child(load_btn)
    
    var ground_btn = _make_button("Ground", Vector2(156, 6))
    ground_btn.pressed.connect(_on_ground_color_pressed)
    ui_root.add_child(ground_btn)

func _make_button(txt: String, pos: Vector2) -> Button:
    var btn := Button.new()
    btn.text = txt
    btn.position = pos
    btn.size = Vector2(70, 34)
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.15, 0.15, 0.15, 0.85)
    s.corner_radius_top_left = 4
    s.corner_radius_top_right = 4
    s.corner_radius_bottom_left = 4
    s.corner_radius_bottom_right = 4
    btn.add_theme_stylebox_override("normal", s)
    return btn

func _create_popups():
    color_picker_popup = preload("res://scenes/ui/color_picker_popup.tscn").instantiate()
    $UI/UIContainer.add_child(color_picker_popup)
    ground_color_popup = preload("res://scenes/ui/ground_color_popup.tscn").instantiate()
    $UI/UIContainer.add_child(ground_color_popup)

func _connect_signals():
    inventory_bar.slot_selected.connect(_on_slot_selected)
    inventory_bar.slot_right_clicked.connect(_on_slot_right_clicked)
    color_picker_popup.color_confirmed.connect(_on_color_confirmed)

func _on_slot_selected(index: int):
    block_manager.selected_color = inventory_bar.get_selected_color()

func _on_slot_right_clicked(index: int):
    inventory_bar.selected_slot = index
    inventory_bar._update_selection_highlight()
    color_picker_popup.open_with_color(inventory_bar.inventory_colors[index])

func _on_color_confirmed(color: Color):
    var idx = inventory_bar.selected_slot
    inventory_bar.set_slot_color(idx, color)
    block_manager.selected_color = color

func _on_save_pressed():
    print("SAVE")
    DirAccess.make_dir_absolute("user://")
    print(save_manager.save(block_manager, inventory_bar, ground))

func _on_load_pressed():
    print("LOAD")
    print(save_manager.load(block_manager, inventory_bar, ground))

func _on_ground_color_pressed():
    print("GROUND")
    ground_color_popup.open_with_colors(ground, ground.ground_color, ground.grid_color)