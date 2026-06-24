extends Node
# ui_theme.gd — 9-slice UI builder from tilemap (AutoLoad)

const TILE_SIZE := 16
const TILE_DIR := "res://ui sucai"

# ── Panel tile groups (9-slice) ──
# Each: [top_left, top, top_right, left, center, right, bottom_left, bottom, bottom_right]
const PANELS := {
    "yellow":     ["tile_003_48_0.png","tile_004_64_0.png","tile_005_80_0.png",
                   "tile_021_48_16.png","tile_022_64_16.png","tile_023_80_16.png",
                   "tile_039_48_32.png","tile_040_64_32.png","tile_041_80_32.png"],
    "red":        ["tile_006_96_0.png","tile_007_112_0.png","tile_008_128_0.png",
                   "tile_024_96_16.png","tile_025_112_16.png","tile_026_128_16.png",
                   "tile_042_96_32.png","tile_043_112_32.png","tile_044_128_32.png"],
    "purple":     ["tile_009_144_0.png","tile_010_160_0.png","tile_011_176_0.png",
                   "tile_027_144_16.png","tile_028_160_16.png","tile_029_176_16.png",
                   "tile_045_144_32.png","tile_046_160_32.png","tile_047_176_32.png"],
    "orange":     ["tile_012_192_0.png","tile_013_208_0.png","tile_014_224_0.png",
                   "tile_030_192_16.png","tile_031_208_16.png","tile_032_224_16.png",
                   "tile_048_192_32.png","tile_049_208_32.png","tile_050_224_32.png"],
    "blue":       ["tile_015_240_0.png","tile_016_256_0.png","tile_017_272_0.png",
                   "tile_033_240_16.png","tile_034_256_16.png","tile_035_272_16.png",
                   "tile_051_240_32.png","tile_052_256_32.png","tile_053_272_32.png"],
}

# ── Horizontal button tile groups (3-slice) ──
const BUTTONS := {
    "orange": ["tile_061_112_48.png", "tile_062_128_48.png", "tile_063_144_48.png"],
    "blue":   ["tile_065_176_48.png", "tile_066_192_48.png", "tile_067_208_48.png"],
}

# ── Font tiles ──
const FONT_DIGITS := {
    "0":"tile_093_48_80.png","1":"tile_094_64_80.png","2":"tile_095_80_80.png",
    "3":"tile_096_96_80.png","4":"tile_097_112_80.png","5":"tile_098_128_80.png",
    "6":"tile_099_144_80.png","7":"tile_100_160_80.png","8":"tile_101_176_80.png",
    "9":"tile_102_192_80.png",
}
const FONT_LETTERS := {
    "A":"tile_108_0_96.png","B":"tile_109_16_96.png","C":"tile_110_32_96.png",
    "D":"tile_111_48_96.png","E":"tile_112_64_96.png","F":"tile_113_80_96.png",
    "G":"tile_114_96_96.png","H":"tile_115_112_96.png","I":"tile_116_128_96.png",
    "J":"tile_117_144_96.png","K":"tile_118_160_96.png","L":"tile_119_176_96.png",
    "M":"tile_120_192_96.png","N":"tile_126_0_112.png","O":"tile_127_16_112.png",
    "P":"tile_128_32_112.png","Q":"tile_129_48_112.png","R":"tile_130_64_112.png",
    "S":"tile_131_80_112.png","T":"tile_132_96_112.png","U":"tile_133_112_112.png",
    "V":"tile_134_128_112.png","W":"tile_135_144_112.png","X":"tile_136_160_112.png",
    "Y":"tile_137_176_112.png","Z":"tile_138_192_112.png",
}

# ── Icons ──
const ICONS := {
    "x_close":  "tile_072_0_64.png",
    "x_big":    "tile_073_16_64.png",
    "plus":     "tile_091_16_80.png",
    "minus":    "tile_092_32_80.png",
    "arrow_up": "tile_074_32_64.png",
    "house":    "tile_056_32_48.png",
    "gem":      "tile_054_0_48.png",
    "cloud":    "tile_077_80_64.png",
}

# Cached StyleBoxes
var _styleboxes := {}
var _icon_textures := {}


func _ready():
    for key in PANELS:
        _styleboxes[key] = _build_nine_slice(PANELS[key])
    for key in BUTTONS:
        _styleboxes["btn_" + key] = _build_three_slice(BUTTONS[key])
    for key in ICONS:
        var img = Image.load_from_file(TILE_DIR + "/" + ICONS[key])
        if img:
            _icon_textures[key] = ImageTexture.create_from_image(img)
    print("UITheme ready — ", PANELS.size(), " panels, ", BUTTONS.size(), " buttons")


# ── Public API ──

func style_panel(ctrl, color := "yellow"):
    var sb = _styleboxes.get(color)
    if sb:
        ctrl.add_theme_stylebox_override("panel", sb)


func make_button(text: String, color := "orange") -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 36)
    btn.add_theme_font_size_override("font_size", 14)
    btn.add_theme_color_override("font_color", Color(1, 1, 1))
    btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.7))
    var sb = _styleboxes.get("btn_" + color)
    if sb:
        btn.add_theme_stylebox_override("normal", sb)
        btn.add_theme_stylebox_override("hover", sb)
        btn.add_theme_stylebox_override("pressed", sb)
    return btn


func get_icon(name: String) -> ImageTexture:
    return _icon_textures.get(name)


# ── Internal ──

func _build_nine_slice(tiles: Array) -> StyleBoxTexture:
    var w = TILE_SIZE * 3
    var h = TILE_SIZE * 3
    var atlas := Image.create(w, h, false, Image.FORMAT_RGBA8)
    _blit_tile(atlas, tiles[0], 0, 0)
    _blit_tile(atlas, tiles[1], TILE_SIZE, 0)
    _blit_tile(atlas, tiles[2], TILE_SIZE*2, 0)
    _blit_tile(atlas, tiles[3], 0, TILE_SIZE)
    _blit_tile(atlas, tiles[4], TILE_SIZE, TILE_SIZE)
    _blit_tile(atlas, tiles[5], TILE_SIZE*2, TILE_SIZE)
    _blit_tile(atlas, tiles[6], 0, TILE_SIZE*2)
    _blit_tile(atlas, tiles[7], TILE_SIZE, TILE_SIZE*2)
    _blit_tile(atlas, tiles[8], TILE_SIZE*2, TILE_SIZE*2)
    return _make_stylebox(atlas, TILE_SIZE)


func _build_three_slice(tiles: Array) -> StyleBoxTexture:
    var w = TILE_SIZE * 3
    var h = TILE_SIZE
    var atlas := Image.create(w, h, false, Image.FORMAT_RGBA8)
    _blit_tile(atlas, tiles[0], 0, 0)
    _blit_tile(atlas, tiles[1], TILE_SIZE, 0)
    _blit_tile(atlas, tiles[2], TILE_SIZE*2, 0)
    var sb := StyleBoxTexture.new()
    sb.texture = ImageTexture.create_from_image(atlas)
    sb.patch_margin_left = TILE_SIZE
    sb.patch_margin_right = TILE_SIZE
    return sb


func _make_stylebox(atlas: Image, margin: int) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = ImageTexture.create_from_image(atlas)
    sb.patch_margin_left = margin
    sb.patch_margin_right = margin
    sb.patch_margin_top = margin
    sb.patch_margin_bottom = margin
    return sb


func _blit_tile(atlas: Image, filename: String, dx: int, dy: int):
    var img = Image.load_from_file(TILE_DIR + "/" + filename)
    if img == null:
        return
    for x in range(TILE_SIZE):
        for y in range(TILE_SIZE):
            atlas.set_pixel(dx + x, dy + y, img.get_pixel(x, y))
