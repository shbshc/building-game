extends Panel
# paint_panel.gd — 16×16 方块六面绘图面板

const TEX_SIZE := 16
const SCALE := 18  # 每像素在屏幕上的大小

signal texture_applied(face_data: Array)  # Array[Image] × 6

var face_data: Array[Image] = []  # 6 个面的 Image
var current_face := 0  # 0=Top, 1=Bottom, 2=Front, 3=Back, 4=Left, 5=Right
var brush_color := Color.WHITE
var mouse_drawing := false
var last_pixel := Vector2i(-1, -1)

@onready var canvas := $Canvas
@onready var face_btns := [
    $FaceBar/TopBtn, $FaceBar/BottomBtn,
    $FaceBar/FrontBtn, $FaceBar/BackBtn,
    $FaceBar/LeftBtn, $FaceBar/RightBtn,
]
@onready var color_rect := $Toolbar/ColorRect
@onready var copy_btn := $Toolbar/CopyBtn


func _ready():
    size = Vector2(520, 430)
    _init_faces()
    _update_canvas()
    color_rect.color = brush_color
    # 连线信号
    canvas.gui_input.connect(_on_canvas_gui_input)
    canvas.draw.connect(_on_canvas_draw)
    for i in range(6):
        face_btns[i].pressed.connect(_on_face_selected.bind(i))
    $Toolbar/ColorBtn.pressed.connect(_on_open_color_picker)
    $Toolbar/CopyBtn.pressed.connect(_on_copy_face)
    $Toolbar/PasteBtn.pressed.connect(_on_paste_face)
    $Toolbar/ClearBtn.pressed.connect(_on_clear)
    $Toolbar/SaveBtn.pressed.connect(_on_save)
    $Toolbar/LoadBtn.pressed.connect(_on_load)
    $Toolbar/ApplyBtn.pressed.connect(_on_apply)


func _on_open_color_picker():
    # 复用主场景的调色盘
    var main = get_tree().root.get_node("Main")
    if main.has_method("open_color_picker"):
        main.open_color_picker(0)  # 暂用 slot 0 的颜色


func _init_faces():
    for i in range(6):
        var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.5, 0.5, 0.5))  # 默认灰色
        face_data.append(img)


func load_from_block(textures: Array):
    """从方块加载已有贴图"""
    if textures.size() == 6:
        for i in range(6):
            if textures[i] != null:
                face_data[i] = textures[i]


func _update_canvas():
    canvas.queue_redraw()
    # 高亮当前面
    for i in range(6):
        var btn = face_btns[i]
        if i == current_face:
            btn.add_theme_color_override("font_color", Color.YELLOW)
        else:
            btn.add_theme_color_override("font_color", Color.WHITE)


func _on_face_selected(index: int):
    current_face = index
    _update_canvas()


func _on_color_pick(color: Color):
    brush_color = color
    color_rect.color = color


func _on_copy_face():
    """复制当前面贴图到剪贴板（内部）"""
    _clipboard = face_data[current_face].duplicate()


var _clipboard: Image = null


func _on_paste_face():
    """粘贴到当前面"""
    if _clipboard != null:
        face_data[current_face] = _clipboard.duplicate()
        _update_canvas()


func _on_save():
    """保存贴图到文件"""
    DirAccess.make_dir_absolute("user://textures")
    for i in range(6):
        var path = "user://textures/face_%d.png" % i
        face_data[i].save_png(path)
    print("Textures saved to user://textures/")


func _on_load():
    """从文件加载贴图"""
    for i in range(6):
        var path = "user://textures/face_%d.png" % i
        if FileAccess.file_exists(path):
            var img := Image.load_from_file(path)
            if img != null:
                img.resize(TEX_SIZE, TEX_SIZE)
                face_data[i] = img
    _update_canvas()


func _on_apply():
    texture_applied.emit(face_data)
    hide()


# --- Canvas Drawing ---

func _on_canvas_gui_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_drawing = event.pressed
            if event.pressed:
                _paint_at(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _pick_color(event.position)
    
    if event is InputEventMouseMotion and mouse_drawing:
        _paint_at(event.position)


func _paint_at(screen_pos: Vector2):
    var px := int(screen_pos.x / SCALE)
    var py := int(screen_pos.y / SCALE)
    if px < 0 or px >= TEX_SIZE or py < 0 or py >= TEX_SIZE:
        return
    if Vector2i(px, py) == last_pixel:
        return
    last_pixel = Vector2i(px, py)
    face_data[current_face].set_pixel(px, py, brush_color)
    canvas.queue_redraw()


func _pick_color(screen_pos: Vector2):
    var px := int(screen_pos.x / SCALE)
    var py := int(screen_pos.y / SCALE)
    if px < 0 or px >= TEX_SIZE or py < 0 or py >= TEX_SIZE:
        return
    brush_color = face_data[current_face].get_pixel(px, py)
    color_rect.color = brush_color


func _on_canvas_draw():
    var img := face_data[current_face]
    for x in range(TEX_SIZE):
        for y in range(TEX_SIZE):
            var c := img.get_pixel(x, y)
            canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), c)
            canvas.draw_rect(Rect2(x * SCALE, y * SCALE, SCALE, SCALE), Color.BLACK, false, 1.0)


func _on_clear():
    face_data[current_face].fill(Color(0.5, 0.5, 0.5))
    _update_canvas()
