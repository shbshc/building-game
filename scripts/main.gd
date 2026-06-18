extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/UIContainer/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground

var color_picker_popup: PopupPanel
var ground_color_popup: PopupPanel
var save_btn: Button
var load_btn: Button
var ground_btn: Button

func _ready():
    print("=== Game started ===")
    _setup_ui()
    _create_popups()
    _connect_signals()
    block_manager.selected_color = inventory_bar.get_selected_color()
    get_tree().root.size_changed.connect(_on_window_resize)

func _setup_ui():
    var ui_root = $UI/UIContainer
    
    save_btn = Button.new()
    save_btn.text = "Save"
    save_btn.pressed.connect(_on_save_pressed)
    ui_root.add_child(save_btn)
    
    load_btn = Button.new()
    load_btn.text = "Load"
    load_btn.pressed.connect(_on_load_pressed)
    ui_root.add_child(load_btn)
    
    ground_btn = Button.new()
    ground_btn.text = "Ground"
    ground_btn.pressed.connect(_on_ground_color_pressed)
    ui_root.add_child(ground_btn)
    
    _position_buttons()

func _position_buttons():
    var margin = 8
    var btn_w = 70
    var btn_h = 34
    var btns = [save_btn, load_btn, ground_btn]
    for i in range(btns.size()):
        btns[i].position = Vector2(margin + i * (btn_w + 4), margin)
        btns[i].size = Vector2(btn_w, btn_h)

func _on_window_resize():
    _position_buttons()

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