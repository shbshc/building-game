extends PopupPanel

@onready var slot_list := $VBox/Scroll/SlotList

var _block_manager
var _inventory_manager
var _ground_node
var _camera_rig
var _main_node
var _save_manager
var _slot_rows: Array = []


func open_panel(block_mgr, inv_mgr, ground, cam, main, save_mgr):
	_block_manager = block_mgr
	_inventory_manager = inv_mgr
	_ground_node = ground
	_camera_rig = cam
	_main_node = main
	_save_manager = save_mgr
	_refresh_list()
	popup_centered()


func _refresh_list():
	for row in _slot_rows:
		row.queue_free()
	_slot_rows.clear()

	var saves = _save_manager.list_saves()
	if saves.is_empty():
		var label := Label.new()
		label.text = "No saves found."
		slot_list.add_child(label)
		return

	for s in saves:
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.text = "%s   %s" % [s["name"], s["updated_at"].split(" ")[0]]
		btn.custom_minimum_size = Vector2(300, 32)
		btn.pressed.connect(_on_load.bind(s["id"]))
		row.add_child(btn)

		var del := Button.new()
		del.text = "X"
		del.custom_minimum_size = Vector2(32, 32)
		del.pressed.connect(_on_delete.bind(s["id"]))
		row.add_child(del)

		slot_list.add_child(row)
		_slot_rows.append(row)


func _on_load(sid: int):
	_save_manager.load(sid, _block_manager, _inventory_manager, _ground_node, _camera_rig, _main_node)
	hide()


func _on_delete(sid: int):
	_save_manager.delete_save(sid)
	_refresh_list()


func _ready():
	$VBox/TitleBar/CloseBtn.pressed.connect(func(): hide())
