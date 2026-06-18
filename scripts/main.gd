extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground

var color_picker_popup: PopupPanel
var ground_color_popup: PopupPanel

func _ready():
    print("=== Game started ===")
    _create_buttons()
    _create_popups()
    _connect_signals()
    block_manager.selected_color = inventory_bar.get_selected_color()

func _create_buttons():
    var save_btn := Button.new()
    save_btn.text = "Save"
    save_btn.position = Vector2(8, 6)
    save_btn.size = Vector2(70, 34)
    save_btn.pressed.connect(_on_save_pressed)
    $UI.add_child(save_btn)
    
    var load_btn := Button.new()
    load_btn.text = "Load"
    load_btn.position = Vector2(82, 6)
    load_btn.size = Vector2(70, 34)
    load_btn.pressed.connect(_on_load_pressed)
    $UI.add_child(load_btn)
    
    var ground_btn := Button.new()
    ground_btn.text = "Ground"
    ground_btn.position = Vector2(156, 6)
    ground_btn.size = Vector2(70, 34)
    ground_btn.pressed.connect(_on_ground_color_pressed)
    $UI.add_child(ground_btn)

func _create_popups():
    print("Loading popups...")
    color_picker_popup = preload("res://scenes/ui/color_picker_popup.tscn").instantiate()
    $UI.add_child(color_picker_popup)
    print("Color picker loaded: ", color_picker_popup)
    
    ground_color_popup = preload("res://scenes/ui/ground_color_popup.tscn").instantiate()
    $UI.add_child(ground_color_popup)
    print("Ground picker loaded: ", ground_color_popup)

func _connect_signals():
    inventory_bar.slot_selected.connect(_on_slot_selected)
    inventory_bar.slot_right_clicked.connect(_on_slot_right_clicked)
    color_picker_popup.color_confirmed.connect(_on_color_confirmed)
    print("Signals connected")

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
    print(">>> SAVE pressed")
    var dir = DirAccess.open("user://")
    if dir == null:
        DirAccess.make_dir_absolute("user://")
        print("Created user dir")
    
    var block_count = block_manager.blocks.size()
    print("Saving ", block_count, " blocks")
    
    var ok = save_manager.save(block_manager, inventory_bar, ground)
    if ok:
        print("<<< Save OK")
    else:
        print("<<< Save FAILED")

func _on_load_pressed():
    print(">>> LOAD pressed")
    var ok = save_manager.load(block_manager, inventory_bar, ground)
    if ok:
        print("<<< Load OK, blocks: ", block_manager.blocks.size())
    else:
        print("<<< Load FAILED (no save file?)")

func _on_ground_color_pressed():
    print(">>> GROUND pressed, popup=", ground_color_popup)
    ground_color_popup.open_with_colors(ground, ground.ground_color, ground.grid_color)