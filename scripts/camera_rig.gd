extends Node3D

@export var pitch_angle := 35.264
@export var yaw_angle := 45.0
@export var distance := 30.0
@export var ortho_size := 15.0
@export var min_ortho := 5.0
@export var max_ortho := 40.0
@export var min_pitch := 10.0
@export var max_pitch := 60.0
@export var rotate_speed := 60.0
@export var zoom_speed := 10.0
@export var pan_sensitivity := 200.0

var target_pitch := 35.264
var target_ortho := 15.0
var is_dragging := false
var drag_start := Vector2.ZERO
var drag_start_pos := Vector3.ZERO

@onready var camera: Camera3D = $Camera3D

func _ready():
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = ortho_size
    update_camera_transform()

func _process(delta):
    # Smooth rotation
    if Input.is_action_pressed("rotate_left"):
        yaw_angle -= rotate_speed * delta
    if Input.is_action_pressed("rotate_right"):
        yaw_angle += rotate_speed * delta
    
    # Smooth pitch
    if Input.is_action_pressed("pitch_up"):
        target_pitch = clamp(target_pitch - 30.0 * delta, min_pitch, max_pitch)
    if Input.is_action_pressed("pitch_down"):
        target_pitch = clamp(target_pitch + 30.0 * delta, min_pitch, max_pitch)
    
    var pitch_diff = target_pitch - pitch_angle
    if abs(pitch_diff) > 0.01:
        pitch_angle += sign(pitch_diff) * min(abs(pitch_diff), rotate_speed * delta)
    
    # Smooth zoom
    var ortho_diff = target_ortho - ortho_size
    if abs(ortho_diff) > 0.01:
        ortho_size += ortho_diff * zoom_speed * delta
    
    camera.size = ortho_size
    update_camera_transform()

func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            target_ortho = clamp(target_ortho - 1.0, min_ortho, max_ortho)
            get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            target_ortho = clamp(target_ortho + 1.0, min_ortho, max_ortho)
            get_viewport().set_input_as_handled()

func start_drag(pos: Vector2):
    is_dragging = true
    drag_start = pos
    drag_start_pos = global_position

func stop_drag():
    is_dragging = false

func do_drag(pos: Vector2):
    if not is_dragging:
        return
    var delta_pos = pos - drag_start
    var yaw_rad = deg_to_rad(yaw_angle)
    # Screen-aligned movement vectors
    var screen_right = Vector3(cos(yaw_rad), 0, -sin(yaw_rad))
    var screen_down = Vector3(sin(yaw_rad), 0, cos(yaw_rad))
    var scale_factor = ortho_size / pan_sensitivity
    global_position = drag_start_pos + (-screen_right * delta_pos.x + screen_down * delta_pos.y) * scale_factor

func update_camera_transform():
    var yaw_rad = deg_to_rad(yaw_angle)
    var pitch_rad = deg_to_rad(pitch_angle)
    var cam_pos := Vector3(
        distance * cos(pitch_rad) * sin(yaw_rad),
        distance * sin(pitch_rad),
        distance * cos(pitch_rad) * cos(yaw_rad)
    )
    camera.position = cam_pos
    camera.look_at(global_position)