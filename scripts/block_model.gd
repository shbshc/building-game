extends Node
# block_model.gd — block model definitions with parent inheritance

# ── Parent models (face layouts) ──

const PARENT_MODELS := {
    "cube_all": {
        "faces": {
            "top": "#all", "bottom": "#all",
            "front": "#all", "back": "#all",
            "left": "#all", "right": "#all"
        }
    },
    "cube_bottom_top": {
        "faces": {
            "top": "#top", "bottom": "#bottom",
            "front": "#side", "back": "#side",
            "left": "#side", "right": "#side"
        }
    },
    "cube_bottom_top_overlay": {
        "faces": {
            "top": "#top", "bottom": "#bottom",
            "front": "#side", "back": "#side",
            "left": "#side", "right": "#side"
        },
        "overlay_faces": {
            "front": "#overlay", "back": "#overlay",
            "left": "#overlay", "right": "#overlay"
        }
    }
}

# Direction-to-face mapping (Godot coordinate system: Y up, Z forward, X right)
const FACE_KEYS := ["top", "bottom", "front", "back", "right", "left"]

# ── Block model definitions ──

var block_models := {
    # ── Plain cubes ──
    "stone":     { "parent": "cube_all", "textures": {"all": "stone"} },
    "wood":      { "parent": "cube_all", "textures": {"all": "wood"} },
    "grass":     { "parent": "cube_all", "textures": {"all": "grass_side"} },
    "sand":      { "parent": "cube_all", "textures": {"all": "sand"} },
    "glass":     { "parent": "cube_all", "textures": {"all": "glass"} },
    "brick":     { "parent": "cube_all", "textures": {"all": "brick"} },
    "marble":    { "parent": "cube_all", "textures": {"all": "marble"} },
    "obsidian":  { "parent": "cube_all", "textures": {"all": "obsidian"} },
    "metal":     { "parent": "cube_all", "textures": {"all": "metal"} },
    "dirt":      { "parent": "cube_all", "textures": {"all": "dirt"} },

    # ── Functional blocks (plain cube + direction indicator) ──
    "move":      { "parent": "cube_all", "textures": {"all": "move"} },
    "turn":      { "parent": "cube_all", "textures": {"all": "turn"} },
    "generator": { "parent": "cube_all", "textures": {"all": "generator"} },
    "push":      { "parent": "cube_all", "textures": {"all": "push"} },
    "consume":   { "parent": "cube_all", "textures": {"all": "consume"} },
    "slime":     { "parent": "cube_all", "textures": {"all": "slime"} },

    # ── Power blocks ──
    "power":     { "parent": "cube_all", "textures": {"all": "power"} },
    "switch":    { "parent": "cube_all", "textures": {"all": "switch"} },
    "wire":      { "parent": "cube_all", "textures": {"all": "wire"} },
    "lamp":      { "parent": "cube_all", "textures": {"all": "lamp"} },
}


# ── Public API ──

# Resolve a model_id into a resolved-model dict:
#   {
#     "faces": { "top":"stone", "bottom":"stone", ... },
#     "tint_faces": ["top", "front", ...],
#     "overlay_faces": { "front":"grass_overlay", ... }
#   }
func resolve(model_id: String) -> Dictionary:
    var def = block_models.get(model_id, block_models.get("stone", {}))
    var parent_key = def.get("parent", "cube_all")
    var parent = PARENT_MODELS.get(parent_key, PARENT_MODELS["cube_all"])
    var textures: Dictionary = def.get("textures", {})

    # Resolve faces: replace #var with actual texture key
    var resolved_faces := {}
    for face in parent.get("faces", {}):
        var ref: String = parent["faces"][face]
        var tex_var = ref.trim_prefix("#")
        resolved_faces[face] = textures.get(tex_var, tex_var)

    # Resolve overlay faces
    var resolved_overlay := {}
    for face in parent.get("overlay_faces", {}):
        var ref: String = parent["overlay_faces"][face]
        var tex_var = ref.trim_prefix("#")
        resolved_overlay[face] = textures.get(tex_var, tex_var)

    return {
        "faces": resolved_faces,
        "tint_faces": def.get("tint_faces", []),
        "overlay_faces": resolved_overlay
    }


# Get the resolved texture key for a specific face
func get_texture_key(model_id: String, face: String) -> String:
    var r = resolve(model_id)
    return r["faces"].get(face, "stone")


func _ready():
    print("BlockModel loaded: ", block_models.size(), " models, ", PARENT_MODELS.size(), " parents")
