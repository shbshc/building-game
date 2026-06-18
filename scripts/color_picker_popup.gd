extends PopupPanel

signal color_confirmed(color: Color)

var current_color := Color.RED

func _ready():
    $VBox/ColorPicker.color_changed.connect(_on_picker_changed)
    $VBox/HBox/RSpin.value_changed.connect(_on_rgb_changed)
    $VBox/HBox/GSpin.value_changed.connect(_on_rgb_changed)
    $VBox/HBox/BSpin.value_changed.connect(_on_rgb_changed)
    $VBox/Confirm.pressed.connect(_on_confirm)
    $VBox/Cancel.pressed.connect(_on_cancel)
    popup_hide.connect(_on_cancel)

func open_with_color(color: Color):
    current_color = color
    $VBox/ColorPicker.color = color
    _update_spinboxes(color)
    popup_centered()

func _on_picker_changed(c: Color):
    current_color = c
    _update_spinboxes(c)

func _on_rgb_changed(_val: float):
    var c := Color(
        $VBox/HBox/RSpin.value / 255.0,
        $VBox/HBox/GSpin.value / 255.0,
        $VBox/HBox/BSpin.value / 255.0
    )
    current_color = c
    $VBox/ColorPicker.color = c

func _update_spinboxes(c: Color):
    $VBox/HBox/RSpin.value = int(c.r * 255)
    $VBox/HBox/GSpin.value = int(c.g * 255)
    $VBox/HBox/BSpin.value = int(c.b * 255)

func _on_confirm():
    color_confirmed.emit(current_color)
    hide()

func _on_cancel():
    hide()
