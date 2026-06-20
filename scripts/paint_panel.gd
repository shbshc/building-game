extends Panel

signal texture_applied(face_data: Array)

const TEX_SIZE := 16
const SCALE := 8  # 编辑画布放大倍率

var face_data: Array[Image] = []
var current_face := 2  # 默认编辑 Front
var brush_color := Color.WHITE
var mouse_drawing := false
var _clipboard: Image = null
var _editing_item_id := -1

const FACE_NAMES := ["Top", "Bottom", "Front", "Back", "Left", "Right"]

@onready var face_controls := [
    $FaceGrid/TopFace, $FaceGrid/BottomFace,
    $FaceGrid/FrontFace, $FaceGrid/BackFace,
    $FaceGrid/LeftFace, $FaceGrid/RightFace,
]
@onready var edit_canvas := $EditCanvas
@onready var face_label := $Toolbar/FaceLabel
@onready var color_rect := $Toolbar/ColorRect


func _ready():
    size = Vector2(520, 480)
    _init_faces()
    # 连线
    edit_canvas.gui_input.connect(_on_canvas_input)
    edit_canvas.draw.connect(_on_canvas_draw)
    for i in range(6):
        face_controls[i].gui_input.connect(_on_face_click.bind(i))
        face_controls[i].draw.connect(_on_face_preview_draw.bind(i))
    $Toolbar/ColorBtn.pressed.connect(_on_color_btn)
    $Toolbar/CopyBtn.pressed.connect(_on_copy)
    $Toolbar/PasteBtn.pressed.connect(_on_paste)
    $Toolbar/ClearBtn.pressed.connect(_on_clear)
    $Toolbar/SaveBtn.pressed.connect(_on_save)
    $Toolbar/LoadBtn.pressed.connect(_on_load)
    $Toolbar/ApplyBtn.pressed.connect(_on_apply)
    _update_all()


func _init_faces():
    face_data.clear()
    for i in range(6):
        var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.5, 0.5, 0.5))
        face_data.append(img)


func _update_all():
    face_label.text = "Editing: " + FACE_NAMES[current_face]
    color_rect.color = brush_color
    for ctrl in face_controls:
        ctrl.queue_redraw()
    edit_canvas.queue_redraw()


func _on_face_click(event: InputEvent, index: int):
    if event is InputEventMouseButton and event.pressed:
        current_face = index
        _update_all()


# 预览小窗
func _on_face_preview_draw(index: int):
    var ctrl = face_controls[index]
    var img = face_data[index]
    var s = ctrl.size.x / TEX_SIZE
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            ctrl.draw_rect(Rect2(x*s, y*s, s, s), img.get_pixel(x, y))
    if index == current_face:
        ctrl.draw_rect(Rect2(0, 0, ctrl.size.x, ctrl.size.y), Color.YELLOW, false, 2)
    # 标签
    ctrl.draw_string(ThemeDB.fallback_font, Vector2(2, ctrl.size.y-4), FACE_NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 8)


# 编辑画布
func _on_canvas_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_drawing = event.pressed
            if event.pressed:
                _paint(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _pick(event.position)
    if event is InputEventMouseMotion and mouse_drawing:
        _paint(event.position)


func _paint(pos: Vector2):
    var px := int(pos.x / SCALE)
    var py := int(pos.y / SCALE)
    if px >= 0 and px < TEX_SIZE and py >= 0 and py < TEX_SIZE:
        face_data[current_face].set_pixel(px, py, brush_color)
        face_controls[current_face].queue_redraw()
        edit_canvas.queue_redraw()


func _pick(pos: Vector2):
    var px := int(pos.x / SCALE)
    var py := int(pos.y / SCALE)
    if px >= 0 and px < TEX_SIZE and py >= 0 and py < TEX_SIZE:
        brush_color = face_data[current_face].get_pixel(px, py)
        _update_all()


func _on_canvas_draw():
    var img = face_data[current_face]
    # 棋盘格背景
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            var bg = Color(0.3, 0.3, 0.3) if (x+y) % 2 == 0 else Color(0.4, 0.4, 0.4)
            edit_canvas.draw_rect(Rect2(x*SCALE, y*SCALE, SCALE, SCALE), bg)
    # 像素
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            edit_canvas.draw_rect(Rect2(x*SCALE, y*SCALE, SCALE, SCALE), img.get_pixel(x, y))
    # 网格线
    for i in range(TEX_SIZE + 1):
        edit_canvas.draw_line(Vector2(i*SCALE, 0), Vector2(i*SCALE, TEX_SIZE*SCALE), Color.BLACK, 0.5)
        edit_canvas.draw_line(Vector2(0, i*SCALE), Vector2(TEX_SIZE*SCALE, i*SCALE), Color.BLACK, 0.5)


func _on_color_btn():
    var main = get_tree().root.get_node("Main")
    if main.has_method("_get_color_picker_popup"):
        var popup = main._get_color_picker_popup()
        if not popup.color_confirmed.is_connected(_on_color):
            popup.color_confirmed.connect(_on_color, CONNECT_ONE_SHOT)
        popup.popup_centered()


func _on_color(c: Color):
    brush_color = c
    _update_all()


func _on_copy():
    _clipboard = face_data[current_face].duplicate()


func _on_paste():
    if _clipboard:
        face_data[current_face] = _clipboard.duplicate()
        _update_all()


func _on_clear():
    face_data[current_face].fill(Color(0.5, 0.5, 0.5))
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
