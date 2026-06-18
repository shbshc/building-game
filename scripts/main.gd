extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground
@onready var raycast_handler = $RayCastHandler

var color_picker_popup: PopupPanel

func _ready():
    print("建筑游戏启动")
    
    # 实例化调色盘弹窗
    color_picker_popup = preload("res://scenes/ui/color_picker_popup.tscn").instantiate()
    $UI.add_child(color_picker_popup)
    
    # 连接物品栏信号
    inventory_bar.slot_selected.connect(_on_slot_selected)
    inventory_bar.slot_right_clicked.connect(_on_slot_right_clicked)
    
    # 连接调色盘信号
    color_picker_popup.color_confirmed.connect(_on_color_confirmed)
    
    # 连接保存/加载按钮
    $UI/TopBar/SaveButton.pressed.connect(_on_save_pressed)
    $UI/TopBar/LoadButton.pressed.connect(_on_load_pressed)
    
    # 初始选中颜色
    block_manager.selected_color = inventory_bar.get_selected_color()

func _on_slot_selected(index: int):
    block_manager.selected_color = inventory_bar.get_selected_color()
    print("选中物品栏槽位: ", index)

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
        print("保存成功")
    else:
        print("保存失败")

func _on_load_pressed():
    if save_manager.load(block_manager, inventory_bar, ground):
        print("加载成功")
    else:
        print("加载失败（无存档或格式错误）")
