extends Control

var inventory_colors: Array[Color] = []
var selected_slot := 0
const SLOT_COUNT := 10
var slot_buttons: Array[Button] = []

signal slot_selected(index: int)
signal slot_right_clicked(index: int)
signal color_changed(index: int, color: Color)

func _ready():
    inventory_colors.resize(SLOT_COUNT)
    var defaults := [
        Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
        Color.ORANGE, Color.PURPLE, Color.CYAN, Color.WHITE,
        Color.BROWN, Color.PINK
    ]
    for i in SLOT_COUNT:
        inventory_colors[i] = defaults[i]
    _build_ui()
    get_tree().root.size_changed.connect(_on_resize)

func _build_ui():
    var hbox := HBoxContainer.new()
    hbox.name = "HBox"
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 4)
    add_child(hbox)
    for i in SLOT_COUNT:
        var btn := Button.new()
        btn.name = "Slot%d" % i
        btn.pressed.connect(_on_slot_pressed.bind(i))
        btn.gui_input.connect(_on_slot_gui_input.bind(i))
        hbox.add_child(btn)
        slot_buttons.append(btn)
    _on_resize()
    _update_selection_highlight()

func _on_resize():
    var vp_size = get_viewport().get_visible_rect().size
    var slot_size = min(48, int((vp_size.x - 60) / SLOT_COUNT))
    for btn in slot_buttons:
        btn.custom_minimum_size = Vector2(slot_size, slot_size)
    _update_selection_highlight()

func _update_slot_style(btn: Button, index: int):
    var style := StyleBoxFlat.new()
    style.bg_color = inventory_colors[index]
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_stylebox_override("hover", style)
    btn.add_theme_stylebox_override("pressed", style)

func _update_selection_highlight():
    for i in SLOT_COUNT:
        var btn = slot_buttons[i]
        if i == selected_slot:
            var sel := StyleBoxFlat.new()
            sel.bg_color = inventory_colors[i]
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
        else:
            _update_slot_style(btn, i)

func _on_slot_pressed(index: int):
    selected_slot = index
    _update_selection_highlight()
    slot_selected.emit(index)

func _on_slot_gui_input(event: InputEvent, index: int):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            slot_right_clicked.emit(index)

func set_slot_color(index: int, color: Color):
    inventory_colors[index] = color
    _update_slot_style(slot_buttons[index], index)
    if index == selected_slot:
        _update_selection_highlight()
    color_changed.emit(index, color)

func get_selected_color() -> Color:
    if selected_slot < 0 or selected_slot >= SLOT_COUNT:
        return Color.RED
    return inventory_colors[selected_slot]

func get_inventory_colors() -> Array[Color]:
    return inventory_colors