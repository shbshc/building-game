extends CharacterBody3D

@export var move_speed := 5.0
@export var jump_velocity := 9.5
@export var mouse_sensitivity := 0.002
@export var min_pitch := -89.0
@export var max_pitch := 89.0

var yaw := 0.0
var pitch := 0.0
var mouse_captured := true
var scroll_cooldown := 0.0
var is_flying := true
var last_space_time := 0.0
const DOUBLE_TAP_TIME := 0.3
var gravity = 30.0

@onready var camera: Camera3D = $Camera3D
@onready var inv_mgr = $"../InventoryManager"

func _ready():
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 1000.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
	if scroll_cooldown > 0:
		scroll_cooldown -= delta
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_mouse()
	if not mouse_captured:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if mouse_captured:
		var space_just = Input.is_action_just_pressed("move_up")
		if space_just:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_space_time < DOUBLE_TAP_TIME:
				is_flying = !is_flying
				print("Mode: ", "FLY" if is_flying else "WALK")
			last_space_time = now
		
		if is_flying:
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
				velocity = global_transform.basis * input_dir * move_speed
			else:
				velocity = Vector3.ZERO
		else:
			var input_dir := Vector3.ZERO
			if Input.is_action_pressed("move_forward"):
				input_dir.z -= 1
			if Input.is_action_pressed("move_back"):
				input_dir.z += 1
			if Input.is_action_pressed("move_left"):
				input_dir.x -= 1
			if Input.is_action_pressed("move_right"):
				input_dir.x += 1
			input_dir = input_dir.normalized() if input_dir != Vector3.ZERO else input_dir
			var flat_velocity = global_transform.basis * input_dir * move_speed
			velocity.x = flat_velocity.x
			velocity.z = flat_velocity.z
			
			if not is_on_floor():
				velocity.y -= gravity * delta
			if space_just and is_on_floor():
				velocity.y = jump_velocity
	
	move_and_slide()

func _input(event):
	if event is InputEventMouseButton:
		if mouse_captured and scroll_cooldown <= 0:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_cooldown = 0.1
				inv_mgr.selected_slot = (inv_mgr.selected_slot + 1) % inv_mgr.HOTBAR_SIZE
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_cooldown = 0.1
				inv_mgr.selected_slot = (inv_mgr.selected_slot - 1 + inv_mgr.HOTBAR_SIZE) % inv_mgr.HOTBAR_SIZE
	
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
