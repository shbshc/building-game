extends PopupPanel

signal texture_applied(face_data: Array)

const TEX_SIZE := 16
const SCALE := 16  # 256/16

var face_data: Array[Image] = []
var brush_color := Color.WHITE
var pen_size := 1
var _clipboard: Image = null
var _last_face := 0

const FACE_NAMES := ["Top", "Bottom", "Front", "Back", "Left", "Right"]

@onready var canvases := [
    $Margin/VBox/FaceGrid/TopCanvas, $Margin/VBox/FaceGrid/BottomCanvas,
    $Margin/VBox/FaceGrid/FrontCanvas, $Margin/VBox/FaceGrid/BackCanvas,
    $Margin/VBox/FaceGrid/LeftCanvas, $Margin/VBox/FaceGrid/RightCanvas,
]
@onready var color_preview := $Margin/VBox/ToolBar/ColorPreview
@onready var active_label := $Margin/VBox/ToolBar/ActiveLabel


func _ready():
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.15, 0.15, 0.18, 1.0)
    add_theme_stylebox_override("panel", bg)

    _init_faces()
    for i in range(6):
        canvases[i].gui_input.connect(_on_face_input.bind(i))
        canvases[i].draw.connect(_on_face_draw.bind(i))
        canvases[i].mouse_entered.connect(_on_hover.bind(i))
    $Margin/VBox/ToolBar/ColorBtn.pressed.connect(_on_color_btn)
    $Margin/VBox/ToolBar/Pen1Btn.pressed.connect(func(): pen_size = 1)
    $Margin/VBox/ToolBar/Pen2Btn.pressed.connect(func(): pen_size = 2)
    $Margin/VBox/ToolBar/Pen4Btn.pressed.connect(func(): pen_size = 4)
    $Margin/VBox/ToolBar/CopyBtn.pressed.connect(_on_copy)
    $Margin/VBox/ToolBar/PasteBtn.pressed.connect(_on_paste)
    $Margin/VBox/ToolBar/ClearBtn.pressed.connect(_on_clear)
    $Margin/VBox/ToolBar/FillBtn.pressed.connect(_on_fill)
    $Margin/VBox/ToolBar/SaveBtn.pressed.connect(_on_save)
    $Margin/VBox/ToolBar/LoadBtn.pressed.connect(_on_load)
    $Margin/VBox/ToolBar/ApplyBtn.pressed.connect(_on_apply)
    color_preview.color = brush_color


func _init_faces():
    face_data.clear()
    for i in range(6):
        var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.5, 0.5, 0.5))
        face_data.append(img)


func _on_hover(index: int):
    _last_face = index
    active_label.text = "Face: " + FACE_NAMES[index]


func _on_face_input(event: InputEvent, index: int):
    _last_face = index
    active_label.text = "Face: " + FACE_NAMES[index]

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _paint(index, event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _pick(index, event.position)

    if event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _paint(index, event.position)


func _paint(index: int, pos: Vector2):
    var px := int(pos.x / SCALE)
    var py := int(pos.y / SCALE)
    var r := pen_size - 1
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            var nx := px + dx
            var ny := py + dy
            if nx >= 0 and nx < TEX_SIZE and ny >= 0 and ny < TEX_SIZE:
                face_data[index].set_pixel(nx, ny, brush_color)
    canvases[index].queue_redraw()


func _pick(index: int, pos: Vector2):
    var px := int(pos.x / SCALE)
    var py := int(pos.y / SCALE)
    if px >= 0 and px < TEX_SIZE and py >= 0 and py < TEX_SIZE:
        brush_color = face_data[index].get_pixel(px, py)
        color_preview.color = brush_color


func _on_face_draw(index: int):
    var canvas = canvases[index]
    var img = face_data[index]
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            var bg = Color(0.25, 0.25, 0.25) if (x + y) % 2 == 0 else Color(0.35, 0.35, 0.35)
            canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), bg)
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), img.get_pixel(x, y))
    var font = ThemeDB.fallback_font
    canvas.draw_string(font, Vector2(2, 14), FACE_NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _on_color_btn():
    var main = get_tree().root.get_node("Main")
    if main.has_method("_get_color_picker_popup"):
        var popup = main._get_color_picker_popup()
        if not popup.color_confirmed.is_connected(_set_color):
            popup.color_confirmed.connect(_set_color, CONNECT_ONE_SHOT)
        popup.popup_centered()


func _set_color(c: Color):
    brush_color = c
    color_preview.color = c


func _on_copy():
    _clipboard = face_data[_last_face].duplicate()


func _on_paste():
    if _clipboard:
        face_data[_last_face] = _clipboard.duplicate()
        canvases[_last_face].queue_redraw()


func _on_clear():
    face_data[_last_face].fill(Color(0.5, 0.5, 0.5))
    canvases[_last_face].queue_redraw()


func _on_fill():
    face_data[_last_face].fill(brush_color)
    canvases[_last_face].queue_redraw()


func _on_save():
    DirAccess.make_dir_absolute("user://textures")
    for i in range(6):
        face_data[i].save_png("user://textures/face_%d.png" % i)


func _on_load():
    for i in range(6):
        var path = "user://textures/face_%d.png" % i
        if FileAccess.file_exists(path):
            var img := Image.load_from_file(path)
            if img:
                img.resize(TEX_SIZE, TEX_SIZE)
                face_data[i] = img
    for c in canvases:
        c.queue_redraw()


func _on_apply():
    texture_applied.emit(face_data)
    hide()
