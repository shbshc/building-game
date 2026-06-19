extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/UIContainer/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground
@onready var camera_rig = $CameraRig
var backpack_panel: Panel = null

var ground_color_popup: PopupPanel
var color_picker_popup: PopupPanel
var save_btn: Button
var load_btn: Button
var ground_btn: Button
var crosshair: ColorRect
var _move_tick_timer := 0.0
const MOVE_TICK_INTERVAL := 1.0

func _ready():
	print("=== Game started ===")
	_setup_ui()
	_create_crosshair()
	_create_popups()
	backpack_panel = preload("res://scenes/ui/backpack_panel.tscn").instantiate()
	$UI/UIContainer.add_child(backpack_panel)
	get_tree().root.size_changed.connect(_on_window_resize)

func _process(delta):
	_move_tick_timer -= delta
	if _move_tick_timer <= 0:
		_move_tick_timer = MOVE_TICK_INTERVAL
		_tick_move_blocks()
		_tick_generators()

func _tick_move_blocks():
	var ft = $FunctionalTypes
	var positions = block_manager.blocks.keys()  # snapshot
	for pos in positions:
		var bd = block_manager.blocks.get(pos)
		if bd == null or bd.func_type != ft.FuncType.MOVE:
			continue
		var dir_vec = ft.DIRECTION_VECTORS[bd.direction]
		var new_pos = pos + dir_vec
		
		# 检查目标格是否有拐弯方块
		var target = block_manager.get_block_data(new_pos)
		if target != null and target.func_type == ft.FuncType.TURN:
			# 拐弯方块不消失，只改变移动方块方向
			block_manager.set_block_direction(pos, target.direction)
			continue
		
		var delta = block_manager.move_block(pos, new_pos)
		if delta != Vector3.ZERO:
			_carry_player(delta, pos)

# 检查玩家是否站在方块上，是则一起移动
func _carry_player(delta: Vector3, block_pos: Vector3i):
	var player = $CameraRig
	var p = player.global_position
	# 方块顶面中心
	var block_top = Vector3(block_pos) + Vector3(0.5, 1.0, 0.5)
	# 玩家脚底（胶囊体底部约在 position.y - 1.3）
	var player_feet_y = p.y - 1.3
	# 检查是否站在方块上
	if abs(p.x - block_top.x) < 0.6 and abs(p.z - block_top.z) < 0.6:
		if abs(player_feet_y - block_top.y) < 0.15:
			# 玩家站在方块上，用 Tween 平滑移动
			var end_pos = player.global_position + delta
			var tween = create_tween()
			tween.tween_property(player, "global_position", end_pos, 0.5).set_trans(Tween.TRANS_LINEAR)

func _tick_generators():
	var ft = $FunctionalTypes
	var positions = block_manager.blocks.keys()  # snapshot
	for pos in positions:
		var bd = block_manager.blocks.get(pos)
		if bd == null or bd.func_type != ft.FuncType.GENERATOR:
			continue
		var dir_vec = ft.DIRECTION_VECTORS[bd.direction]
		var behind_pos = pos - dir_vec   # 箭头后方（来源）
		var front_pos = pos + dir_vec    # 箭头前方（目标）
		
		var source = block_manager.get_block_data(behind_pos)
		if source == null:
			continue  # 后方没有方块
		if not block_manager.can_place_at(front_pos):
			continue  # 前方放不下
		
		block_manager.place_block(front_pos, source.item_id, null, source.func_type, source.direction)

func _setup_ui():
	var ui_root = $UI/UIContainer
	
	save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	ui_root.add_child(save_btn)
	
	load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_pressed)
	ui_root.add_child(load_btn)
	
	ground_btn = Button.new()
	ground_btn.text = "Ground"
	ground_btn.pressed.connect(_on_ground_color_pressed)
	ui_root.add_child(ground_btn)
	
	_position_buttons()

func _create_crosshair():
	crosshair = ColorRect.new()
	crosshair.color = Color.WHITE
	crosshair.size = Vector2(2, 20)
	crosshair.position = Vector2.ZERO
	$UI/UIContainer.add_child(crosshair)
	
	var cross_h := ColorRect.new()
	cross_h.color = Color.WHITE
	cross_h.size = Vector2(20, 2)
	$UI/UIContainer.add_child(cross_h)
	
	_position_crosshair()

func _position_crosshair():
	var vp_size = get_viewport().get_visible_rect().size
	var cx = vp_size.x / 2
	var cy = vp_size.y / 2
	crosshair.position = Vector2(cx - 1, cy - 10)
	crosshair.get_parent().get_child(crosshair.get_index() + 1).position = Vector2(cx - 10, cy - 1)

func _position_buttons():
	var margin = 8
	var btn_w = 70
	var btn_h = 34
	save_btn.position = Vector2(margin, margin)
	save_btn.size = Vector2(btn_w, btn_h)
	load_btn.position = Vector2(margin + btn_w + 4, margin)
	load_btn.size = Vector2(btn_w, btn_h)
	ground_btn.position = Vector2(margin + (btn_w + 4) * 2, margin)
	ground_btn.size = Vector2(btn_w, btn_h)

func _on_window_resize():
	_position_buttons()
	_position_crosshair()

func _create_popups():
	color_picker_popup = preload("res://scenes/ui/color_picker_popup.tscn").instantiate()
	$UI/UIContainer.add_child(color_picker_popup)
	color_picker_popup.color_confirmed.connect(_on_color_confirmed)
	ground_color_popup = preload("res://scenes/ui/ground_color_popup.tscn").instantiate()
	$UI/UIContainer.add_child(ground_color_popup)

func open_color_picker(index: int):
	var inv_mgr = $InventoryManager
	var c = inv_mgr.slot_colors[index]
	if c == null:
		var t = $ItemTypes.get_type(inv_mgr.hotbar[index].item_id)
		c = t.color if t else Color.RED
	inv_mgr.selected_slot = index
	color_picker_popup.open_with_color(c)

func _on_color_confirmed(color: Color):
	$InventoryManager.slot_colors[$InventoryManager.selected_slot] = color

func _on_save_pressed():
	print("SAVE")
	DirAccess.make_dir_absolute("user://")
	print(save_manager.save(block_manager, $InventoryManager, ground))

func _on_load_pressed():
	print("LOAD")
	print(save_manager.load(block_manager, $InventoryManager, ground))

func is_backpack_open() -> bool:
	return backpack_panel != null and backpack_panel.visible

func _on_ground_color_pressed():
	print("GROUND")
	ground_color_popup.open_with_colors(ground, ground.ground_color, ground.grid_color)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and backpack_panel != null:
			backpack_panel.visible = !backpack_panel.visible
			if backpack_panel.visible:
				var vp = get_viewport().get_visible_rect().size
				backpack_panel.position = Vector2((vp.x - 480) / 2, (vp.y - 220) / 2)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_ESCAPE and backpack_panel != null and backpack_panel.visible:
			backpack_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
