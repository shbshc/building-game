extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground
@onready var raycast_handler = $RayCastHandler

var color_picker_popup: PopupPanel
var ground_color_popup: PopupPanel

func _ready():
    print("Building game started")
    
    color_picker_popup = preload("res://scenes/ui/color_picker_popup.tscn").instantiate()
    $UI.add_child(color_picker_popup)
    
    ground_color_popup = preload("res://scenes/ui/ground_color_popup.tscn").instantiate()
    $UI.add_child(ground_color_popup)
    
    inventory_bar.slot_selected.connect(_on_slot_selected)
    inventory_bar.slot_right_clicked.connect(_on_slot_right_clicked)
    color_picker_popup.color_confirmed.connect(_on_color_confirmed)
    
    $UI/TopBar/SaveButton.pressed.connect(_on_save_pressed)
    $UI/TopBar/LoadButton.pressed.connect(_on_load_pressed)
    $UI/TopBar/GroundColorButton.pressed.connect(_on_ground_color_pressed)
    
    block_manager.selected_color = inventory_bar.get_selected_color()

func _on_slot_selected(index: int):
    block_manager.selected_color = inventory_bar.get_selected_color()

func _on_slot_right_clicked(index: int):
    inventory_bar.selected_slot = index
    inventory_bar._update_selection_highlight()
    var current = inventory_bar.inventory_colors[index]
    color_picker_popup.open_with_color(current)

func _on_color_confirmed(color: Color):
    var idx = inventory_bar.selected_slot
    inventory_bar.set_slot_color(idx, color)
    block_manager.selected_color = color

func _on_save_pressed():
    if save_manager.save(block_manager, inventory_bar, ground):
        print("Saved OK")
    else:
        print("Save failed")

func _on_load_pressed():
    if save_manager.load(block_manager, inventory_bar, ground):
        print("Loaded OK")
    else:
        print("Load failed")

func _on_ground_color_pressed():
    ground_color_popup.open_with_colors(ground, ground.ground_color, ground.grid_color)