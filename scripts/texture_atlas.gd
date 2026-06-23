extends Node
# texture_atlas.gd — global texture atlas (AutoLoad)
# All block textures packed into one 2048x2048 ImageTexture.
# Blocks share this single texture; only UV coords differ.

const ATLAS_SIZE := 2048
const TEX_SIZE := 16
const TEX_PER_ROW := ATLAS_SIZE / TEX_SIZE  # 128

var atlas_image: Image
var atlas_texture: ImageTexture
var texture_map := {}   # "stone" -> Rect2(uv_x, uv_y, uv_w, uv_h)
var slot_map := {}      # "stone" -> Vector2i(pixel_x, pixel_y)  for update_slot
var _next_x := 0
var _next_y := 0


func _ready():
	atlas_image = Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(1, 0, 1, 1))  # magenta = uninitialized
	atlas_texture = ImageTexture.create_from_image(atlas_image)
	print("TextureAtlas ready: ", ATLAS_SIZE, "x", ATLAS_SIZE)


# Register a texture from file path. Returns UV Rect2.
# If already registered, returns the existing UV.
func register_texture(key: String, path: String) -> Rect2:
	if texture_map.has(key):
		return texture_map[key]

	var img := Image.load_from_file(path)
	if img == null:
		printerr("TextureAtlas: failed to load ", path)
		return Rect2()

	img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_NEAREST)
	return _pack(key, img)


# Register a texture from an in-memory Image (for paint panel)
func register_image(key: String, img: Image) -> Rect2:
	if texture_map.has(key):
		return texture_map[key]

	var dup := img.duplicate()
	dup.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_NEAREST)
	return _pack(key, dup)


# Update an existing slot in-place (for paint panel live edit)
func update_slot(key: String, new_image: Image):
	if not slot_map.has(key):
		# Slot doesn't exist yet - register it instead
		register_image(key, new_image)
		return

	var px: Vector2i = slot_map[key]
	var img := new_image.duplicate()
	img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_NEAREST)

	# Blit into atlas
	for x in range(TEX_SIZE):
		for y in range(TEX_SIZE):
			atlas_image.set_pixel(px.x + x, px.y + y, img.get_pixel(x, y))

	atlas_texture.update(atlas_image)


# Query UV for a texture key
func get_uv(key: String) -> Rect2:
	return texture_map.get(key, Rect2())


# Query the shared atlas texture (used by all block materials)
func get_atlas_texture() -> ImageTexture:
	return atlas_texture


# Export atlas to user:// for visual inspection
func export_atlas_png():
	atlas_image.save_png("user://atlas_debug.png")


# -- Internal --

func _pack(key: String, img: Image) -> Rect2:
	# Simple row-packing: fill left-to-right, wrap to next row
	if _next_x + TEX_SIZE > ATLAS_SIZE:
		_next_x = 0
		_next_y += TEX_SIZE
	if _next_y + TEX_SIZE > ATLAS_SIZE:
		printerr("TextureAtlas: atlas full! Expand not yet implemented.")
		return Rect2()

	var px := Vector2i(_next_x, _next_y)

	for x in range(TEX_SIZE):
		for y in range(TEX_SIZE):
			atlas_image.set_pixel(px.x + x, px.y + y, img.get_pixel(x, y))

	var uv := Rect2(
		float(px.x) / ATLAS_SIZE,
		float(px.y) / ATLAS_SIZE,
		float(TEX_SIZE) / ATLAS_SIZE,
		float(TEX_SIZE) / ATLAS_SIZE
	)

	texture_map[key] = uv
	slot_map[key] = px

	_next_x += TEX_SIZE
	atlas_texture.update(atlas_image)

	return uv
