extends PopupPanel

var _main_node
var _save_panel
var _load_panel
var _paint_panel
var _ground_color_popup
var _save_manager
var _camera_rig


func setup(main_node, save_panel, load_panel, paint_panel, ground_color_popup, save_mgr, camera_rig):
    _main_node = main_node
    _save_panel = save_panel
    _load_panel = load_panel
    _paint_panel = paint_panel
    _ground_color_popup = ground_color_popup
    _save_manager = save_mgr
    _camera_rig = camera_rig


func _ready():
    # Apply yellow panel background
    UITheme.style_panel(self)

    # Style title
    var title: Label = $VBox/Title
    title.add_theme_color_override("font_color", Color(1, 1, 0.85))
    title.add_theme_font_size_override("font_size", 20)

    $VBox/ResumeBtn.pressed.connect(_on_resume)
    $VBox/SaveBtn.pressed.connect(_on_save)
    $VBox/LoadBtn.pressed.connect(_on_load)
    $VBox/PaintBtn.pressed.connect(_on_paint)
    $VBox/GroundBtn.pressed.connect(_on_ground)
    $VBox/QuitBtn.pressed.connect(_on_quit)


func open_menu():
    popup_centered()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu():
    hide()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume():
    close_menu()


func _on_save():
    hide()
    _save_panel.open_panel(
        _main_node.block_manager,
        _main_node.get_node("InventoryManager"),
        _main_node.get_node("Ground"),
        _camera_rig,
        _save_manager
    )


func _on_load():
    hide()
    _load_panel.open_panel(
        _main_node.block_manager,
        _main_node.get_node("InventoryManager"),
        _main_node.get_node("Ground"),
        _camera_rig,
        _main_node,
        _save_manager
    )


func _on_paint():
    hide()
    var inv_mgr = _main_node.get_node("InventoryManager")
    var item_id = inv_mgr.get_selected_type()
    if item_id >= 0 and item_id < 1000:
        _main_node.open_paint_panel_for_item(item_id)


func _on_ground():
    hide()
    _ground_color_popup.open_with_colors(
        _main_node.get_node("Ground"),
        _main_node.get_node("Ground").ground_color,
        _main_node.get_node("Ground").grid_color
    )


func _on_quit():
    get_tree().quit()
