extends Node3D

@onready var block_manager = $Blocks
@onready var inventory_bar = $UI/UIContainer/InventoryBar
@onready var save_manager = $SaveManager
@onready var ground = $Ground
@onready var camera_rig = $CameraRig
var backpack_panel: Panel = null
var paint_panel: PopupPanel = null

var ground_color_popup: PopupPanel
var color_picker_popup: PopupPanel
var save_btn: Button
var load_btn: Button
var ground_btn: Button
var crosshair: ColorRect
var _move_tick_timer := 0.0
var _item_textures: Dictionary = {}
const MOVE_TICK_INTERVAL := 1.0

func _ready():
	print("=== Game started ===")
	_setup_ui()
	_create_crosshair()
	_create_popups()
	backpack_panel = preload("res://scenes/ui/backpack_panel.tscn").instantiate()
	$UI/UIContainer.add_child(backpack_panel)
	paint_panel = preload("res://scenes/ui/paint_panel.tscn").instantiate()
	$UI/UIContainer.add_child(paint_panel)
	paint_panel.hide()
	get_tree().root.size_changed.connect(_on_window_resize)

func _process(delta):
	_move_tick_timer -= delta
	if _move_tick_timer <= 0:
		_move_tick_timer = MOVE_TICK_INTERVAL
		_tick_move_blocks()
		_tick_generators()
		$PowerSystem.update_power_network()

func _tick_move_blocks():
	var ft = $FunctionalTypes
	var positions = block_manager.blocks.keys()  # snapshot
	
	for pos in positions:
		var bd = block_manager.blocks.get(pos)
		if bd == null or bd.func_type != ft.FuncType.MOVE:
			continue
		var dir_vec = ft.DIRECTION_VECTORS[bd.direction]
		var new_pos = pos + dir_vec
		
		var target = block_manager.get_block_data(new_pos)
		
		# 拐弯：改方向
		if target != null and target.func_type == ft.FuncType.TURN:
			block_manager.set_block_direction(pos, target.direction)
			continue
		
		# 消耗：移动方块消失
		if target != null and target.func_type == ft.FuncType.CONSUME:
			block_manager.remove_block(pos)
			continue
		
		# 粘液组：移动方块接触粘液 → 推动整组
		var group = block_manager.get_slime_group(pos)
		if group.size() > 1:
			block_manager.slide_chain(pos, dir_vec)
			continue
		
		# 目标被功能方块占据 → 尝试推动
		if target != null and target.func_type > 0:
			if block_manager.slide_chain(new_pos, dir_vec):
				pass
			else:
				continue  # 推不动，跳过
		
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


func open_paint_panel_for_item(item_id: int):
	_paint_is_item = true
	_paint_item_id = item_id
	# 自动加载已有贴图
	var loaded = _load_item_textures(item_id)
	if loaded.size() == 6:
		paint_panel._init_faces_from(loaded)
	else:
		paint_panel._init_faces()
	paint_panel.texture_applied.connect(_on_item_texture_applied, CONNECT_ONE_SHOT)
	paint_panel.popup_centered()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var _paint_is_item := false
var _paint_item_id := -1

func _on_item_texture_applied(face_data: Array):
	if _paint_is_item:
		_item_textures[_paint_item_id] = face_data.duplicate()
		# 保存到文件
		_save_item_textures(_paint_item_id, face_data)
		_paint_is_item = false
	# 不关背包，面板自己处理
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE



func get_item_textures(item_id: int) -> Array:
	return _item_textures.get(item_id, [])


func _save_item_textures(item_id: int, textures: Array):
	DirAccess.make_dir_absolute("user://textures")
	for i in range(6):
		if i < textures.size() and textures[i] != null:
			var path = "user://textures/item_%d_face_%d.png" % [item_id, i]
			textures[i].save_png(path)


func _load_item_textures(item_id: int) -> Array:
	var result: Array = []
	for i in range(6):
		var path = "user://textures/item_%d_face_%d.png" % [item_id, i]
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null:
				img.resize(16, 16, Image.INTERPOLATE_NEAREST)
				result.append(img)
				continue
		result.append(null)
	return result


func _get_color_picker_popup():
	return color_picker_popup

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
				backpack_panel.position = Vector2((vp.x - 500) / 2, (vp.y - 350) / 2)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_ESCAPE and backpack_panel != null and backpack_panel.visible:
			backpack_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
