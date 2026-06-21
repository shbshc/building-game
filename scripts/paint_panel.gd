extends PopupPanel

signal texture_applied(face_data: Array)

const TEX_SIZE := 16
const SCALE := 20  # 320/16

var face_data: Array[Image] = []
var brush_color := Color.WHITE
var pen_size := 1
var _clipboard: Image = null
var _edit_face := 0

const FACE_NAMES := ["Top", "Bottom", "Front", "Back", "Left", "Right"]

@onready var select_view := $SelectView
@onready var edit_view := $EditView
@onready var face_btns := [
    $SelectView/FaceGrid/TopBtn, $SelectView/FaceGrid/BottomBtn,
    $SelectView/FaceGrid/FrontBtn, $SelectView/FaceGrid/BackBtn,
    $SelectView/FaceGrid/LeftBtn, $SelectView/FaceGrid/RightBtn,
]
@onready var edit_canvas := $EditView/EditCanvas
@onready var edit_label := $EditView/EditTop/EditLabel
@onready var color_preview := $EditView/EditTools/ColorPreview

var _palette_colors := [
    Color.BLACK, Color.WHITE,
    Color.RED, Color(1,0.5,0), Color.YELLOW,
    Color.GREEN, Color.CYAN, Color.BLUE,
    Color.MAGENTA, Color(0.5,0.5,0.5), Color(0.3,0.3,0.3),
    Color(0.545,0.27,0.075), Color(0.298,0.647,0.314), Color(0.957,0.816,0.247),
    Color(0.753,0.224,0.169),
]


func _ready():
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.15, 0.15, 0.18, 1.0)
    add_theme_stylebox_override("panel", bg)

    _init_faces()
    for i in range(6):
        face_btns[i].pressed.connect(_on_face_selected.bind(i))
    $EditView/EditTop/BackBtn.pressed.connect(_on_back)
    edit_canvas.gui_input.connect(_on_canvas_input)
    edit_canvas.draw.connect(_on_canvas_draw)
    $EditView/EditTools/Pen1Btn.pressed.connect(func(): pen_size = 1)
    $EditView/EditTools/Pen2Btn.pressed.connect(func(): pen_size = 2)
    $EditView/EditTools/Pen4Btn.pressed.connect(func(): pen_size = 4)
    $EditView/EditTools/CopyBtn.pressed.connect(_on_copy)
    $EditView/EditTools/PasteBtn.pressed.connect(_on_paste)
    $EditView/EditTools/ClearBtn.pressed.connect(_on_clear)
    $EditView/EditTools/FillBtn.pressed.connect(_on_fill)
    $EditView/EditTools/SaveBtn.pressed.connect(_on_save)
    $EditView/EditTools/LoadBtn.pressed.connect(_on_load)
    $EditView/EditTools/ApplyBtn.pressed.connect(_on_apply)
    
    # 调色盘
    var pal := HBoxContainer.new()
    for c in _palette_colors:
        var r := ColorRect.new()
        r.color = c
        r.custom_minimum_size = Vector2(24, 24)
        r.mouse_filter = Control.MOUSE_FILTER_STOP
        r.gui_input.connect(func(event: InputEvent):
            if event is InputEventMouseButton and event.pressed:
                brush_color = c
                color_preview.color = c
        )
        pal.add_child(r)
    $EditView.add_child(pal)
    $EditView.move_child(pal, 2)
    
    _show_select()
    color_preview.color = brush_color


func _init_faces():
    face_data.clear()
    for i in range(6):
        var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.5, 0.5, 0.5))
        face_data.append(img)


func _init_faces_from(existing: Array):
    face_data.clear()
    for i in range(6):
        if i < existing.size() and existing[i] != null:
            face_data.append(existing[i].duplicate())
        else:
            var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
            img.fill(Color(0.5, 0.5, 0.5))
            face_data.append(img)


func _show_select():
    select_view.visible = true
    edit_view.visible = false
    for i in range(6):
        _draw_face_btn(i)


func _draw_face_btn(i: int):
    var btn = face_btns[i]
    var img = face_data[i]
    var s: float = btn.size.x / TEX_SIZE
    # 用 StyleBox 模拟按钮背景
    btn.text = ""
    # 强制重绘——用 icon
    # Godot Button 不支持动态纹理，用 _draw 替代
    # 改用 Control 代替 Button
    # 这里我们用一个简单的方案：set icon
    var tex := ImageTexture.create_from_image(img)
    btn.icon = tex
    btn.expand_icon = true
    btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    btn.text = FACE_NAMES[i]


func _on_face_selected(index: int):
    _edit_face = index
    edit_label.text = "Editing: " + FACE_NAMES[index]
    select_view.visible = false
    edit_view.visible = true
    edit_canvas.queue_redraw()


func _on_back():
    _show_select()


func _on_canvas_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _paint(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _pick(event.position)
    if event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _paint(event.position)


func _paint(pos: Vector2):
    var px := int(pos.x / SCALE)
    var py := int(pos.y / SCALE)
    var r := pen_size - 1
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            var nx := px + dx
            var ny := py + dy
            if nx >= 0 and nx < TEX_SIZE and ny >= 0 and ny < TEX_SIZE:
                face_data[_edit_face].set_pixel(nx, ny, brush_color)
    edit_canvas.queue_redraw()
    _draw_face_btn(_edit_face)


func _pick(pos: Vector2):
    var px := int(pos.x / SCALE)
    var py := int(pos.y / SCALE)
    if px >= 0 and px < TEX_SIZE and py >= 0 and py < TEX_SIZE:
        brush_color = face_data[_edit_face].get_pixel(px, py)
        color_preview.color = brush_color


func _on_canvas_draw():
    var img = face_data[_edit_face]
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            var bg = Color(0.25, 0.25, 0.25) if (x + y) % 2 == 0 else Color(0.35, 0.35, 0.35)
            edit_canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), bg)
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            edit_canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), img.get_pixel(x, y))
    for i in range(TEX_SIZE + 1):
        edit_canvas.draw_line(Vector2(i * SCALE, 0), Vector2(i * SCALE, TEX_SIZE * SCALE), Color(0.4, 0.4, 0.4), 0.5)
        edit_canvas.draw_line(Vector2(0, i * SCALE), Vector2(TEX_SIZE * SCALE, i * SCALE), Color(0.4, 0.4, 0.4), 0.5)


func _on_copy():
    _clipboard = face_data[_edit_face].duplicate()


func _on_paste():
    if _clipboard:
        face_data[_edit_face] = _clipboard.duplicate()
        edit_canvas.queue_redraw()
        _draw_face_btn(_edit_face)


func _on_clear():
    face_data[_edit_face].fill(Color(0.5, 0.5, 0.5))
    edit_canvas.queue_redraw()
    _draw_face_btn(_edit_face)


func _on_fill():
    face_data[_edit_face].fill(brush_color)
    edit_canvas.queue_redraw()
    _draw_face_btn(_edit_face)


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
    _show_select()


func _on_apply():
    texture_applied.emit(face_data)
    hide()
