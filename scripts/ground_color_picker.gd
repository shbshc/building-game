extends PopupPanel

var ground_color: Color
var grid_color: Color
var target_node: Node

func _ready():
    $Scroll/VBox/GroundPicker.color_changed.connect(_on_ground_color_changed)
    $Scroll/VBox/GridPicker.color_changed.connect(_on_grid_color_changed)
    $Scroll/VBox/Apply.pressed.connect(_on_apply)

func open_with_colors(node, gc: Color, gridc: Color):
    target_node = node
    ground_color = gc
    grid_color = gridc
    $Scroll/VBox/GroundPicker.color = gc
    $Scroll/VBox/GridPicker.color = gridc
    popup_centered()

func _on_ground_color_changed(c: Color):
    ground_color = c

func _on_grid_color_changed(c: Color):
    grid_color = c

func _on_apply():
    if target_node:
        target_node.update_colors(ground_color, grid_color)
    hide()