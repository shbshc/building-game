extends Node3D

var mouse_pressed := false
var mouse_moved := false
var mouse_start_pos := Vector2.ZERO
const DRAG_THRESHOLD := 5.0

@onready var block_manager: Node3D = $"../Blocks"
@onready var highlight: MeshInstance3D = $"../SelectionHighlight"
@onready var camera: Camera3D = $"../CameraRig/Camera3D"
@onready var camera_rig: Node3D = $"../CameraRig"
@onready var inventory = $"../UI/InventoryBar"

func _ready():
    highlight.visible = false

func _input(event):
    if _is_mouse_over_ui():
        highlight.visible = false
        return
    
    if event is InputEventMouseButton:
        # Left click
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                mouse_pressed = true
                mouse_moved = false
                mouse_start_pos = event.position
                get_viewport().set_input_as_handled()
            else:
                mouse_pressed = false
                if not mouse_moved:
                    _handle_left_click()
                camera_rig.stop_drag()
        
        # Right click - delete block
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _handle_right_click()
        
        # Middle click - deselect
        elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
            inventory.selected_slot = -1
            inventory._update_selection_highlight()
            highlight.visible = false
            get_viewport().set_input_as_handled()
    
    if event is InputEventMouseMotion:
        if mouse_pressed:
            if event.position.distance_to(mouse_start_pos) > DRAG_THRESHOLD:
                if not mouse_moved:
                    mouse_moved = true
                    camera_rig.start_drag(mouse_start_pos)
                camera_rig.do_drag(event.position)

func _handle_left_click():
    if inventory.selected_slot < 0:
        return
    var result = _raycast()
    if result:
        var grid_pos = _world_to_grid(result.position, result.normal)
        if grid_pos != null and block_manager.can_place_at(grid_pos):
            block_manager.place_block(grid_pos)

func _handle_right_click():
    var result = _raycast()
    if result and result.collider:
        var parent = result.collider.get_parent()
        if parent is MeshInstance3D:
            var grid_pos = Vector3i(parent.position)
            block_manager.remove_block(grid_pos)

func _raycast() -> Dictionary:
    var space_state = get_world_3d().direct_space_state
    var mouse_pos = get_viewport().get_mouse_position()
    var origin = camera.project_ray_origin(mouse_pos)
    var end = origin + camera.project_ray_normal(mouse_pos) * 1000.0
    var query := PhysicsRayQueryParameters3D.create(origin, end)
    return space_state.intersect_ray(query)

func _world_to_grid(hit_pos: Vector3, hit_normal: Vector3) -> Vector3i:
    var place_pos = hit_pos + hit_normal * 0.5
    return Vector3i(round(place_pos.x), round(place_pos.y), round(place_pos.z))

func _update_highlight():
    var result = _raycast()
    if result and inventory.selected_slot >= 0:
        var grid_pos = _world_to_grid(result.position, result.normal)
        if grid_pos != null and block_manager.can_place_at(grid_pos):
            highlight.visible = true
            highlight.position = Vector3(grid_pos)
        else:
            highlight.visible = false
    else:
        highlight.visible = false

func _is_mouse_over_ui() -> bool:
    var mouse_y = get_viewport().get_mouse_position().y
    var viewport_height = get_viewport().get_visible_rect().size.y
    return mouse_y > viewport_height - 60