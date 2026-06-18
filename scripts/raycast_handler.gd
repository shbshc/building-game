extends Node3D

@onready var block_manager: Node3D = $"../Blocks"
@onready var camera: Camera3D = $"../CameraRig/Camera3D"
@onready var camera_rig: Node3D = $"../CameraRig"
@onready var inventory = $"../UI/UIContainer/InventoryBar"

var highlight: MeshInstance3D

func _ready():
	_create_highlight()
	highlight.visible = false

func _create_highlight():
	highlight = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.05, 1.05, 1.05)
	highlight.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.3)
	highlight.material_override = mat
	add_child(highlight)

func _input(event):
	if not camera_rig.mouse_captured:
		highlight.visible = false
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if inventory.selected_slot >= 0:
				var result = _raycast()
				if result:
					var grid_pos = _world_to_grid(result.position, result.normal)
					if grid_pos != null and block_manager.can_place_at(grid_pos):
						block_manager.place_block(grid_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var result = _raycast()
			if result and result.collider:
				var parent = result.collider.get_parent()
				if parent is MeshInstance3D:
					var pos = parent.position
					var grid_pos = Vector3i(int(pos.x - 0.5), int(pos.y), int(pos.z - 0.5))
					block_manager.remove_block(grid_pos)
	
	if event is InputEventMouseMotion:
		_update_highlight()

func _raycast() -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_position
	var end = origin - camera.global_transform.basis.z * 10.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	return space_state.intersect_ray(query)

func _world_to_grid(hit_pos: Vector3, hit_normal: Vector3) -> Vector3i:
	var place_pos = hit_pos + hit_normal * 0.5
	return Vector3i(floor(place_pos.x), round(place_pos.y), floor(place_pos.z))

func _update_highlight():
	var result = _raycast()
	if result and inventory.selected_slot >= 0:
		var grid_pos = _world_to_grid(result.position, result.normal)
		if grid_pos != null and block_manager.can_place_at(grid_pos):
			highlight.visible = true
			highlight.position = Vector3(grid_pos) + Vector3(0.5, 0, 0.5)
		else:
			highlight.visible = false
	else:
		highlight.visible = false
