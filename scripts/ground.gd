extends MeshInstance3D

@export var ground_color := Color(0.85, 0.85, 0.85)
@export var grid_color := Color(0.4, 0.4, 0.4)

func _ready():
    mesh = PlaneMesh.new()
    mesh.size = Vector2(100, 100)
    mesh.orientation = PlaneMesh.FACE_Y
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://shaders/grid_ground.gdshader")
    mat.set_shader_parameter("ground_color", ground_color)
    mat.set_shader_parameter("grid_color", grid_color)
    material_override = mat
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    col.shape = BoxShape3D.new()
    col.shape.size = Vector3(100, 0.01, 100)
    col.position = Vector3(0, -0.005, 0)
    body.add_child(col)
    add_child(body)

func update_colors(new_ground: Color, new_grid: Color):
    ground_color = new_ground
    grid_color = new_grid
    material_override.set_shader_parameter("ground_color", new_ground)
    material_override.set_shader_parameter("grid_color", new_grid)