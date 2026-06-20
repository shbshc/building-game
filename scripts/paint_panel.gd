extends PopupPanel

signal texture_applied(face_data: Array)

const TEX_SIZE := 16
const SCALE := 8  # 128/16

var face_data: Array[Image] = []
var brush_color := Color.WHITE
var mouse_drawing := false
var _clipboard: Image = null
var _last_canvas := -1

const FACE_NAMES := ["Top", "Bottom", "Front", "Back", "Left", "Right"]

@onready var canvases := [
    $FaceGrid/TopCanvas, $FaceGrid/BottomCanvas,
    $FaceGrid/FrontCanvas, $FaceGrid/BackCanvas,
    $FaceGrid/LeftCanvas, $FaceGrid/RightCanvas,
]
@onready var color_preview := $ToolPanel/ColorPreview
@onready var active_label := $ToolPanel/ActiveLabel


func _ready():
    _init_faces()
    for i in range(6):
        canvases[i].gui_input.connect(_on_face_input.bind(i))
        canvases[i].draw.connect(_on_face_draw.bind(i))
        canvases[i].mouse_entered.connect(_on_hover.bind(i))
    $ToolPanel/ColorBtn.pressed.connect(_on_color_btn)
    $ToolPanel/CopyBtn.pressed.connect(_on_copy)
    $ToolPanel/PasteBtn.pressed.connect(_on_paste)
    $ToolPanel/ClearBtn.pressed.connect(_on_clear)
    $ToolPanel/FillBtn.pressed.connect(_on_fill)
    $ToolPanel/SaveBtn.pressed.connect(_on_save)
    $ToolPanel/LoadBtn.pressed.connect(_on_load)
    $ToolPanel/ApplyBtn.pressed.connect(_on_apply)
    color_preview.color = brush_color


func _init_faces():
    face_data.clear()
    for i in range(6):
        var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.5, 0.5, 0.5))
        face_data.append(img)


func _update_all():
    color_preview.color = brush_color
    for c in canvases:
        c.queue_redraw()


func _on_hover(index: int):
    _last_canvas = index
    active_label.text = "Active: " + FACE_NAMES[index]


func _on_face_input(event: InputEvent, index: int):
    _last_canvas = index
    active_label.text = "Editing: " + FACE_NAMES[index]
    
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_drawing = event.pressed
            if event.pressed:
                _paint(canvases[index], index, event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _pick(index, event.position)
    
    if event is InputEventMouseMotion and mouse_drawing:
        _paint(canvases[index], index, event.position)


func _paint(canvas: Control, index: int, screen_pos: Vector2):
    var px := int(screen_pos.x / SCALE)
    var py := int(screen_pos.y / SCALE)
    if px >= 0 and px < TEX_SIZE and py >= 0 and py < TEX_SIZE:
        face_data[index].set_pixel(px, py, brush_color)
        canvas.queue_redraw()


func _pick(index: int, screen_pos: Vector2):
    var px := int(screen_pos.x / SCALE)
    var py := int(screen_pos.y / SCALE)
    if px >= 0 and px < TEX_SIZE and py >= 0 and py < TEX_SIZE:
        brush_color = face_data[index].get_pixel(px, py)
        color_preview.color = brush_color


func _on_face_draw(index: int):
    var canvas = canvases[index]
    var img = face_data[index]
    # 棋盘格背景
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            var bg = Color(0.25, 0.25, 0.25) if (x + y) % 2 == 0 else Color(0.35, 0.35, 0.35)
            canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), bg)
    # 像素
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), img.get_pixel(x, y))
    # 网格线
    for i in range(TEX_SIZE + 1):
        canvas.draw_line(Vector2(i * SCALE, 0), Vector2(i * SCALE, TEX_SIZE * SCALE), Color(0.5, 0.5, 0.5), 0.5)
        canvas.draw_line(Vector2(0, i * SCALE), Vector2(TEX_SIZE * SCALE, i * SCALE), Color(0.5, 0.5, 0.5), 0.5)
    # 标签
    var font = ThemeDB.fallback_font
    canvas.draw_string(font, Vector2(2, 12), FACE_NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


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
    if _last_canvas >= 0:
        _clipboard = face_data[_last_canvas].duplicate()


func _on_paste():
    if _clipboard and _last_canvas >= 0:
        face_data[_last_canvas] = _clipboard.duplicate()
        _update_all()


func _on_clear():
    if _last_canvas >= 0:
        face_data[_last_canvas].fill(Color(0.5, 0.5, 0.5))
        _update_all()


func _on_fill():
    if _last_canvas >= 0:
        face_data[_last_canvas].fill(brush_color)
        _update_all()


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
    _update_all()


func _on_apply():
    texture_applied.emit(face_data)
    hide()
