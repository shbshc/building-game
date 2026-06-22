extends Node
# color_provider.gd — dynamic tint interface for block faces

# Default: no tint (white = texture is as-is)
func get_tint(block_data, face: String) -> Color:
	return Color.WHITE


# ── Built-in providers ──

# Fixed tint — always returns the same color
class FixedTintProvider:
	var tint_color: Color

	func _init(c: Color):
		tint_color = c

	func get_tint(_block_data, _face: String) -> Color:
		return tint_color


# Biome tint — varies by world coordinates (simulated: uses x,z hash)
class BiomeTintProvider:
	func get_tint(block_data, _face: String) -> Color:
		var pos = block_data.node.position
		var h = fmod(abs(pos.x * 7.3 + pos.z * 13.7), 1.0)
		var g = lerp(0.7, 1.3, h)
		return Color(1.0, g, 0.8)


# Signal tint — varies by block's powered state (for lamp brightness)
class SignalTintProvider:
	func get_tint(block_data, _face: String) -> Color:
		if block_data.get("powered") == true:
			return Color(1.0, 1.0, 0.95)  # warm white
		return Color(0.3, 0.3, 0.3)  # dim


func _ready():
	print("ColorProvider ready")
