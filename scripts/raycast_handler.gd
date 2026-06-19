extends Node3D

@onready var block_manager: Node3D = $"../Blocks"
@onready var camera: Camera3D = $"../CameraRig/Camera3D"
@onready var inv_mgr = $"../InventoryManager"

var highlight: MeshInstance3D
var place_timer: float = 0.0
var break_timer: float = 0.0
var mouse_left_held: bool = false
var mouse_right_held: bool = false
const ACTION_INTERVAL := 0.2

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

func _process(delta):
	if mouse_left_held:
		place_timer -= delta
		if place_timer <= 0:
			place_timer = ACTION_INTERVAL
			_try_place()
	if mouse_right_held:
		break_timer -= delta
		if break_timer <= 0:
			break_timer = ACTION_INTERVAL
			_try_break()

func _input(event):
	var cam_rig = $"../CameraRig"
	var main_node = $".."
	if not cam_rig.mouse_captured or (main_node.has_method("is_backpack_open") and main_node.is_backpack_open()):
		if not cam_rig.mouse_captured:
			highlight.visible = false
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_left_held = true
				place_timer = 0.0
			else:
				mouse_left_held = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Check if pointing at a functional block for direction rotation
				var result = _raycast()
				var interacted = false
				if result and result.collider:
					var parent = result.collider.get_parent()
					if parent is MeshInstance3D:
						var pos = parent.position
						var grid_pos = Vector3i(int(pos.x - 0.5), int(pos.y - 0.5), int(pos.z - 0.5))
						var bd = block_manager.get_block_data(grid_pos)
						if bd != null and bd.func_type > 0:
							# Right-click functional block: rotate direction
							var ft = $"../FunctionalTypes"
							var new_dir = ft.next_direction_index(bd.direction)
							block_manager.set_block_direction(grid_pos, new_dir)
							interacted = true
				# If not interacting, break block as normal
				if not interacted:
					mouse_right_held = true
					break_timer = 0.0
			else:
				mouse_right_held = false
	
	if event is InputEventMouseMotion:
		_update_highlight()

func _try_place():
	var selected_id = inv_mgr.get_selected_type()
	if selected_id < 0:
		return
	var result = _raycast()
	if result:
		var grid_pos = _world_to_grid(result.position, result.normal)
		if grid_pos != null and block_manager.can_place_at(grid_pos):
			if not _is_player_cell(grid_pos):
				var item_types_node = $"../ItemTypes"
				var t = item_types_node.get_type(selected_id)
				var func_type = t.func_type if t else 0
				# 功能方块用物品预设方向，普通方块忽略方向
				var direction = t.direction if func_type > 0 else 2
				var color = inv_mgr.get_selected_color(item_types_node) if func_type == 0 else null
				block_manager.place_block(grid_pos, selected_id, color, func_type, direction)

func _is_player_cell(gp: Vector3i) -> bool:
	var p = $"../CameraRig".global_position
	var px = int(floor(p.x))
	var py = int(floor(p.y - 1.3))
	var pz = int(floor(p.z))
	if gp.x == px and gp.z == pz:
		if gp.y >= py and gp.y <= py + 2:
			return true
	return false

func _try_break():
	var result = _raycast()
	if result and result.collider:
		var parent = result.collider.get_parent()
		if parent is MeshInstance3D:
			var pos = parent.position
			var grid_pos = Vector3i(int(pos.x - 0.5), int(pos.y - 0.5), int(pos.z - 0.5))
			block_manager.remove_block(grid_pos)

func _raycast() -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_position
	var end = origin - camera.global_transform.basis.z * 10.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [$"../CameraRig"]
	return space_state.intersect_ray(query)

func _world_to_grid(hit_pos: Vector3, hit_normal: Vector3) -> Vector3i:
	var place_pos = hit_pos + hit_normal * 0.5
	return Vector3i(floor(place_pos.x), floor(place_pos.y), floor(place_pos.z))

func _face_to_direction(normal: Vector3) -> int:
	var n = Vector3i(int(round(normal.x)), int(round(normal.y)), int(round(normal.z)))
	return $"../FunctionalTypes".dir_vec_to_index(n)

func _update_highlight():
	var result = _raycast()
	if result and inv_mgr.get_selected_type() >= 0:
		var grid_pos = _world_to_grid(result.position, result.normal)
		if grid_pos != null and block_manager.can_place_at(grid_pos):
			highlight.visible = true
			highlight.position = Vector3(grid_pos) + Vector3(0.5, 0.5, 0.5)
		else:
			highlight.visible = false
	else:
		highlight.visible = false
