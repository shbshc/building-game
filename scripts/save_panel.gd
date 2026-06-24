extends PopupPanel

@onready var name_input := $VBox/NameRow/NameInput
@onready var slot_list := $VBox/Scroll/SlotList

var _selected_slot := -1
var _block_manager
var _inventory_manager
var _ground_node
var _camera_rig
var _save_manager
var _slot_rows: Array = []


func open_panel(block_mgr, inv_mgr, ground, cam, save_mgr):
    _block_manager = block_mgr
    _inventory_manager = inv_mgr
    _ground_node = ground
    _camera_rig = cam
    _save_manager = save_mgr
    _selected_slot = -1
    _refresh_list()
    name_input.text = ""
    popup_centered()


func _refresh_list():
    for row in _slot_rows:
        row.queue_free()
    _slot_rows.clear()

    var saves = _save_manager.list_saves()
    for s in saves:
        _add_slot_row(s["id"], s["name"], s.get("updated_at", "").split(" ")[0], false)
    # Empty new-slot row at end
    _add_slot_row(-1, "(new)", "", true)


func _add_slot_row(sid: int, sname: String, sdate: String, is_new: bool):
    var row := HBoxContainer.new()
    var btn := Button.new()
    if is_new:
        btn.text = sname
    else:
        btn.text = "%s   %s" % [sname, sdate]
    btn.custom_minimum_size = Vector2(300, 32)
    btn.pressed.connect(_on_slot_clicked.bind(sid))
    row.add_child(btn)

    if not is_new:
        var del := Button.new()
        del.text = "X"
        del.custom_minimum_size = Vector2(32, 32)
        del.pressed.connect(_on_delete.bind(sid))
        row.add_child(del)

    slot_list.add_child(row)
    _slot_rows.append(row)


func _on_slot_clicked(sid: int):
    if sid < 0:
        # New slot
        var name = name_input.text.strip_edges()
        if name == "":
            name = "Save %d" % _save_manager._next_id()
        sid = _save_manager.create_save(name)
    _selected_slot = sid
    _do_save()


func _do_save():
    if _selected_slot < 0:
        return
    var name = name_input.text.strip_edges()
    if name == "":
        name = "Save %d" % _selected_slot
    _save_manager.rename_save(_selected_slot, name)
    _save_manager.save(_selected_slot, _block_manager, _inventory_manager, _ground_node, _camera_rig)
    _refresh_list()
    hide()


func _on_delete(sid: int):
    _save_manager.delete_save(sid)
    _refresh_list()


func _ready():
    UITheme.style_panel(self)
    $VBox/TitleBar/CloseBtn.pressed.connect(func(): hide())
    $VBox/NewBtn.pressed.connect(_on_slot_clicked.bind(-1))
