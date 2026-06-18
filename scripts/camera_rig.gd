extends Node3D

@export var move_speed := 10.0
@export var mouse_sensitivity := 0.002
@export var min_pitch := -89.0
@export var max_pitch := 89.0

var yaw := 0.0
var pitch := 0.0
var mouse_captured := true

@onready var camera: Camera3D = $Camera3D
@onready var inventory = $"../UI/UIContainer/InventoryBar"

func _ready():
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 75.0
    camera.near = 0.1
    camera.far = 1000.0
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
    if Input.is_action_just_pressed("toggle_mouse"):
        _toggle_mouse()
    
    if mouse_captured:
        var input_dir := Vector3.ZERO
        if Input.is_action_pressed("move_forward"):
            input_dir.z -= 1
        if Input.is_action_pressed("move_back"):
            input_dir.z += 1
        if Input.is_action_pressed("move_left"):
            input_dir.x -= 1
        if Input.is_action_pressed("move_right"):
            input_dir.x += 1
        if Input.is_action_pressed("move_up"):
            input_dir.y += 1
        if Input.is_action_pressed("move_down"):
            input_dir.y -= 1
        
        if input_dir != Vector3.ZERO:
            input_dir = input_dir.normalized()
            global_position += global_transform.basis * input_dir * move_speed * delta

func _input(event):
    if event is InputEventMouseButton:
        if mouse_captured:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                if inventory.selected_slot < 9:
                    inventory.selected_slot += 1
                else:
                    inventory.selected_slot = 0
                inventory._update_selection_highlight()
            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                if inventory.selected_slot > 0:
                    inventory.selected_slot -= 1
                else:
                    inventory.selected_slot = 9
                inventory._update_selection_highlight()
    
    if mouse_captured and event is InputEventMouseMotion:
        yaw -= event.relative.x * mouse_sensitivity
        pitch -= event.relative.y * mouse_sensitivity
        pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
        rotation = Vector3(0, yaw, 0)
        camera.rotation = Vector3(pitch, 0, 0)

func _toggle_mouse():
    mouse_captured = !mouse_captured
    if mouse_captured:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    else:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE