extends PopupPanel

signal texture_applied(face_data: Array)

const TEX_SIZE := 16
const SCALE := 8          # 64*8=512, 48*8=384 fits panel
const GRID_W := 4         # 4 faces wide
const GRID_H := 3         # 3 faces tall
const CANVAS_W := GRID_W * TEX_SIZE
const CANVAS_H := GRID_H * TEX_SIZE

# Face positions in the unfolded cube layout (in 16px-cell coords)
#         ┌────┐
#         │ 顶 │
# ┌────┬──┴────┴──┬────┐
# │ 左 │   前    │ 右 │ 背 │
# └────┴─────────┴────┘
#         ┌────┐
#         │ 底 │
#         └────┘
const FACE_POS := {
	"top":    Vector2i(1, 0),
	"bottom": Vector2i(1, 2),
	"front":  Vector2i(1, 1),
	"back":   Vector2i(3, 1),
	"left":   Vector2i(0, 1),
	"right":  Vector2i(2, 1),
}
const FACE_ORDER := ["top", "bottom", "front", "back", "left", "right"]

var face_data: Array[Image] = []
var brush_color := Color.WHITE
var pen_size := 1
var _clipboard: Image = null
var _clipboard_face := -1   # which face was copied
var _model_id := "stone"    # set by main.gd before opening
var _active_face := 0       # last face user hovered/painted on

@onready var edit_canvas := $EditView/EditCanvas
@onready var edit_label := $EditView/EditTop/EditLabel
@onready var color_preview := $EditView/EditTools/ColorPreview

var _palette_colors := [
	Color.BLACK, Color.WHITE,
	Color.RED, Color(1,0.3,0), Color.YELLOW,
	Color.GREEN, Color.CYAN, Color.BLUE,
	Color.MAGENTA, Color.PINK, Color.PURPLE,
	Color(0.5,0.5,0.5), Color(0.3,0.3,0.3), Color(0.7,0.7,0.7),
	Color(0.55,0.27,0.07), Color(0.3,0.65,0.31), Color(0.96,0.82,0.25),
	Color(0.75,0.22,0.17), Color(0.84,0.86,0.86), Color.BROWN,
	Color.ORANGE_RED, Color.SPRING_GREEN, Color.DEEP_SKY_BLUE,
]


func _ready():
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	add_theme_stylebox_override("panel", bg)

	_init_faces()

	# Hide old select view
	if has_node("SelectView"):
		$SelectView.visible = false

	$EditView.visible = true
	edit_label.text = "Cube Net Editor (RMB=pick color)"

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
	$EditView/EditTools/ResetBtn.pressed.connect(_on_reset)

	# Color picker button
	var picker_btn := Button.new()
	picker_btn.text = "🎨"
	picker_btn.custom_minimum_size = Vector2(32, 28)
	picker_btn.pressed.connect(_on_color_picker)
	$EditView/EditTools.add_child(picker_btn)
	$EditView/EditTools.move_child(picker_btn, 5)  # after 4px btn

	# Palette
	var pal := HBoxContainer.new()
	pal.name = "Palette"
	for c in _palette_colors:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(20, 20)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				brush_color = c
				color_preview.color = c
		)
		pal.add_child(r)
	$EditView.add_child(pal)
	$EditView.move_child(pal, 2)

	color_preview.color = brush_color
	edit_canvas.queue_redraw()


# Build 6 face images, sharing Image objects for faces that map to the same texture key
func _resolve_shared_faces(existing: Array = []):
	var model_node = get_node("/root/Main/BlockModel")
	var resolved = model_node.resolve(_model_id)
	var face_keys = resolved.get("faces", {})

	# Map: texture_key → Image (so shared faces share one Image)
	var key_image := {}
	face_data.clear()
	for i in range(6):
		var tex_key = face_keys.get(FACE_ORDER[i], "stone")
		if key_image.has(tex_key):
			face_data.append(key_image[tex_key])  # share the same Image
		else:
			var img: Image
			if existing != null and i < existing.size() and existing[i] != null:
				img = existing[i].duplicate()
			else:
				img = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
				img.fill(Color(0.5, 0.5, 0.5))
			key_image[tex_key] = img
			face_data.append(img)


func _init_faces():
	_resolve_shared_faces()


func _init_faces_from(existing: Array):
	_resolve_shared_faces(existing)


# Convert canvas pixel position → (face_index, pixel_x, pixel_y) or (-1, 0, 0)
func _pos_to_face(canvas_pos: Vector2) -> Dictionary:
	var cx := int(canvas_pos.x / SCALE)
	var cy := int(canvas_pos.y / SCALE)
	if cx < 0 or cx >= CANVAS_W or cy < 0 or cy >= CANVAS_H:
		return {"face": -1, "px": 0, "py": 0}

	# Which cell in the 4×3 grid
	var gx := cx / TEX_SIZE
	var gy := cy / TEX_SIZE
	var px := cx % TEX_SIZE
	var py := cy % TEX_SIZE

	for i in range(6):
		var fp = FACE_POS[FACE_ORDER[i]]
		if fp.x == gx and fp.y == gy:
			return {"face": i, "px": px, "py": py}
	return {"face": -1, "px": 0, "py": 0}


func _on_canvas_input(event: InputEvent):
	if event is InputEventMouseButton:
		var hit = _pos_to_face(event.position)
		if hit["face"] >= 0:
			_active_face = hit["face"]
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_paint(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_pick(event.position)
	if event is InputEventMouseMotion:
		var hit = _pos_to_face(event.position)
		if hit["face"] >= 0 and hit["face"] != _active_face:
			_active_face = hit["face"]
			edit_canvas.queue_redraw()  # update golden highlight
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_paint(event.position)


func _paint(pos: Vector2):
	var hit = _pos_to_face(pos)
	if hit["face"] < 0:
		return
	var f = hit["face"]
	var r := pen_size - 1
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var nx: int = hit["px"] + dx
			var ny: int = hit["py"] + dy
			if nx >= 0 and nx < TEX_SIZE and ny >= 0 and ny < TEX_SIZE:
				face_data[f].set_pixel(nx, ny, brush_color)
	edit_canvas.queue_redraw()


func _pick(pos: Vector2):
	var hit = _pos_to_face(pos)
	if hit["face"] < 0:
		return
	brush_color = face_data[hit["face"]].get_pixel(hit["px"], hit["py"])
	color_preview.color = brush_color


func _on_color_picker():
	var picker := ColorPicker.new()
	picker.color = brush_color
	picker.color_changed.connect(func(c: Color):
		brush_color = c
		color_preview.color = c
	)
	var popup := PopupPanel.new()
	popup.add_child(picker)
	add_child(popup)
	popup.popup_centered(Vector2i(300, 400))


func _on_canvas_draw():
	# Draw checkerboard background per face
	for fi in range(6):
		var fp = FACE_POS[FACE_ORDER[fi]]
		var ox = fp.x * TEX_SIZE * SCALE
		var oy = fp.y * TEX_SIZE * SCALE
		for x in range(TEX_SIZE):
			for y in range(TEX_SIZE):
				var bg = Color(0.25, 0.25, 0.25) if (x + y) % 2 == 0 else Color(0.35, 0.35, 0.35)
				edit_canvas.draw_rect(Rect2(ox + x * SCALE, oy + y * SCALE, SCALE, SCALE), bg)

	# Draw face pixels
	for fi in range(6):
		var fp = FACE_POS[FACE_ORDER[fi]]
		var ox = fp.x * TEX_SIZE * SCALE
		var oy = fp.y * TEX_SIZE * SCALE
		var img = face_data[fi]
		for x in range(TEX_SIZE):
			for y in range(TEX_SIZE):
				edit_canvas.draw_rect(Rect2(ox + x * SCALE, oy + y * SCALE, SCALE, SCALE), img.get_pixel(x, y))

	# Draw pixel grid (subtle)
	var grid_c := Color(0.4, 0.4, 0.4, 0.3)
	for fi in range(6):
		var fp = FACE_POS[FACE_ORDER[fi]]
		var ox = fp.x * TEX_SIZE * SCALE
		var oy = fp.y * TEX_SIZE * SCALE
		for i in range(TEX_SIZE + 1):
			edit_canvas.draw_line(Vector2(ox + i * SCALE, oy), Vector2(ox + i * SCALE, oy + TEX_SIZE * SCALE), grid_c, 0.5)
			edit_canvas.draw_line(Vector2(ox, oy + i * SCALE), Vector2(ox + TEX_SIZE * SCALE, oy + i * SCALE), grid_c, 0.5)

	# Draw face boundary boxes (thick, colored)
	var face_colors := [
		Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.CYAN, Color.MAGENTA
	]
	for fi in range(6):
		var fp = FACE_POS[FACE_ORDER[fi]]
		var ox = fp.x * TEX_SIZE * SCALE
		var oy = fp.y * TEX_SIZE * SCALE
		var sz = TEX_SIZE * SCALE
		var fc = face_colors[fi]
		fc.a = 0.7
		edit_canvas.draw_rect(Rect2(ox, oy, sz, sz), fc, false, 2.0)

	# Highlight active face (thick golden border)
	var afp = FACE_POS[FACE_ORDER[_active_face]]
	var aox = afp.x * TEX_SIZE * SCALE
	var aoy = afp.y * TEX_SIZE * SCALE
	var asz = TEX_SIZE * SCALE
	edit_canvas.draw_rect(Rect2(aox - 1, aoy - 1, asz + 2, asz + 2), Color.GOLD, false, 3.0)

	# Draw face labels in corners
	var face_names := ["Top", "Bottom", "Front", "Back", "Left", "Right"]
	for fi in range(6):
		var fp = FACE_POS[FACE_ORDER[fi]]
		var ox = fp.x * TEX_SIZE * SCALE + 4
		var oy = fp.y * TEX_SIZE * SCALE + 2
		edit_canvas.draw_string(ThemeDB.fallback_font, Vector2(ox, oy + 12), face_names[fi], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


func _on_copy():
	_clipboard = face_data[_active_face].duplicate()
	_clipboard_face = _active_face


func _on_paste():
	if _clipboard == null:
		return
	face_data[_active_face] = _clipboard.duplicate()
	edit_canvas.queue_redraw()


func _on_clear():
	face_data[_active_face].fill(Color(0.5, 0.5, 0.5))
	edit_canvas.queue_redraw()


func _on_reset():
	face_data[_active_face].fill(Color(0.5, 0.5, 0.5))
	edit_canvas.queue_redraw()


func _on_fill():
	face_data[_active_face].fill(brush_color)
	edit_canvas.queue_redraw()


func _on_save():
	DirAccess.make_dir_absolute("user://textures")
	for i in range(6):
		var path = "user://textures/face_%d.png" % i
		if FileAccess.file_exists(path):
			var backup_path = "user://textures/face_%d_backup.png" % i
			DirAccess.copy_absolute(path, backup_path)
		face_data[i].save_png(path)


func _on_load():
	for i in range(6):
		var path = "user://textures/face_%d.png" % i
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img:
				img.resize(TEX_SIZE, TEX_SIZE)
				face_data[i] = img
	edit_canvas.queue_redraw()


func _on_apply():
	var atlas = get_node("/root/TextureAtlas")
	var model_node = get_node("/root/Main/BlockModel")
	var resolved = model_node.resolve(_model_id)
	var face_keys = resolved.get("faces", {})

	# Push to atlas — deduplicate: shared-key faces push once
	var pushed := {}
	for i in range(6):
		var tex_key = face_keys.get(FACE_ORDER[i], "stone")
		if pushed.has(tex_key):
			continue
		pushed[tex_key] = true
		atlas.update_slot(tex_key, face_data[i])

	texture_applied.emit(face_data)
