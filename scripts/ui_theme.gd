extends Node
# ui_theme.gd — Assembles tilemap tiles into 9-slice StyleBoxes (AutoLoad)

const TILE_SIZE := 16
const TILE_DIR := "res://ui sucai"

# Yellow panel 9-slice tile file names (0-padded tile index)
const YELLOW_TILES := {
    "top_left":     "tile_003_48_0.png",
    "top":          "tile_004_64_0.png",
    "top_right":    "tile_005_80_0.png",
    "left":         "tile_021_48_16.png",
    "center":       "tile_022_64_16.png",
    "right":        "tile_023_80_16.png",
    "bottom_left":  "tile_039_48_32.png",
    "bottom":       "tile_040_64_32.png",
    "bottom_right": "tile_041_80_32.png",
}

var yellow_stylebox: StyleBoxTexture


func _ready():
    yellow_stylebox = _build_nine_slice(YELLOW_TILES)
    print("UITheme ready — yellow panel stylebox built")


func _build_nine_slice(tiles: Dictionary) -> StyleBoxTexture:
    # Assemble 9 tiles into 3×3 grid image (48×48)
    var w = TILE_SIZE * 3
    var h = TILE_SIZE * 3
    var atlas := Image.create(w, h, false, Image.FORMAT_RGBA8)

    var positions := {
        "top_left":     Vector2i(0, 0),
        "top":          Vector2i(TILE_SIZE, 0),
        "top_right":    Vector2i(TILE_SIZE * 2, 0),
        "left":         Vector2i(0, TILE_SIZE),
        "center":       Vector2i(TILE_SIZE, TILE_SIZE),
        "right":        Vector2i(TILE_SIZE * 2, TILE_SIZE),
        "bottom_left":  Vector2i(0, TILE_SIZE * 2),
        "bottom":       Vector2i(TILE_SIZE, TILE_SIZE * 2),
        "bottom_right": Vector2i(TILE_SIZE * 2, TILE_SIZE * 2),
    }

    for role in tiles:
        var path = TILE_DIR + "/" + tiles[role]
        var img = Image.load_from_file(path)
        if img:
            var px = positions[role]
            for x in range(TILE_SIZE):
                for y in range(TILE_SIZE):
                    atlas.set_pixel(px.x + x, px.y + y, img.get_pixel(x, y))

    var tex := ImageTexture.create_from_image(atlas)
    var sb := StyleBoxTexture.new()
    sb.texture = tex
    sb.patch_margin_left = TILE_SIZE
    sb.patch_margin_right = TILE_SIZE
    sb.patch_margin_top = TILE_SIZE
    sb.patch_margin_bottom = TILE_SIZE
    return sb


# Apply yellow panel style to a control
func style_panel(ctrl: Control):
    ctrl.add_theme_stylebox_override("panel", yellow_stylebox)


# Create a styled button
func make_button(text: String) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(200, 36)
    btn.add_theme_font_size_override("font_size", 14)
    btn.add_theme_color_override("font_color", Color(1, 1, 1))
    btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.7))
    return btn
