# Backpack System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `run_skill({name: "subagent-driven-development"})` (recommended) or `run_skill({name: "executing-plans"})` to implement this plan task-by-task.

**Goal:** Build Minecraft-style inventory with 6 block types, stacking, 10-slot hotbar, 27-slot backpack, click/drag item movement, tooltip on hover.

**Architecture:** ItemSlot data class manages item_id + count. ItemType resource defines named block types. InventoryManager (Node) owns hotbar+backpack arrays. Inventory UI renders slots as colored rectangles with count labels. BackpackPanel is a separate PopupPanel scene. CameraRig handles E key for backpack toggle.

**Tech Stack:** Godot 4.7, GDScript, GL Compatibility

---

### Task 1: Item Data Layer (item_types.gd)

**Files:**
- Create: `scripts/item_types.gd`

- [ ] **Step 1: Create item_types.gd**

```gdscript
extends Node

class ItemType:
    var id: int
    var name: String
    var color: Color
    var max_stack: int = 64
    
    func _init(p_id: int, p_name: String, p_color: Color, p_max: int = 64):
        id = p_id
        name = p_name
        color = p_color
        max_stack = p_max

class ItemSlot:
    var item_id: int = -1
    var count: int = 0
    
    func is_empty() -> bool:
        return item_id < 0 or count <= 0
    
    func clear():
        item_id = -1
        count = 0
    
    func can_accept(id: int, max_stack: int) -> bool:
        if is_empty():
            return true
        return id == item_id and count < max_stack
    
    func add(id: int, amount: int, max_stack: int) -> int:
        if is_empty():
            item_id = id
            count = 0
        if id != item_id:
            return amount
        var space = max_stack - count
        var to_add = min(amount, space)
        count += to_add
        return amount - to_add
    
    func remove(amount: int) -> int:
        var to_remove = min(amount, count)
        count -= to_remove
        if count <= 0:
            clear()
        return to_remove

# Default item types
var item_types: Array[ItemType] = []

func _ready():
    _init_defaults()

func _init_defaults():
    item_types = [
        ItemType.new(0, "Stone", Color(0.5, 0.5, 0.5)),
        ItemType.new(1, "Wood", Color(0.545, 0.27, 0.075)),
        ItemType.new(2, "Grass", Color(0.298, 0.647, 0.314)),
        ItemType.new(3, "Sand", Color(0.957, 0.816, 0.247)),
        ItemType.new(4, "Glass", Color(0.835, 0.859, 0.859, 0.5)),
        ItemType.new(5, "Brick", Color(0.753, 0.224, 0.169)),
    ]
    print("Item types loaded: ", item_types.size())

func get_type(id: int) -> ItemType:
    if id >= 0 and id < item_types.size():
        return item_types[id]
    return null

func get_name(id: int) -> String:
    var t = get_type(id)
    return t.name if t else "Unknown"
```

- [ ] **Step 2: Verify**

Add `ItemTypes` node to main.tscn, run, confirm console prints "Item types loaded: 6".

- [ ] **Step 3: Commit**

```bash
git add scripts/item_types.gd scenes/main.tscn
git commit -m "feat: item data layer - ItemType + ItemSlot classes, 6 default types"
```

---

### Task 2: Inventory Data Manager

**Files:**
- Create: `scripts/inventory_manager.gd`

- [ ] **Step 1: Create inventory_manager.gd**

```gdscript
extends Node

var hotbar: Array = []       # 10 ItemSlot
var backpack: Array = []     # 27 ItemSlot
var held_item: ItemSlot = null
var selected_slot := 0
const HOTBAR_SIZE := 10
const BACKPACK_SIZE := 27

func _ready():
    for i in range(HOTBAR_SIZE):
        hotbar.append(ItemSlot.new())
    for i in range(BACKPACK_SIZE):
        backpack.append(ItemSlot.new())
    # Give player some starter items
    hotbar[0].add(0, 64, 64)
    hotbar[1].add(1, 64, 64)
    hotbar[2].add(2, 64, 64)

func get_selected_slot() -> ItemSlot:
    return hotbar[selected_slot]

func get_selected_type() -> int:
    return hotbar[selected_slot].item_id

func pickup_from(slot: ItemSlot):
    if slot.is_empty():
        return
    if held_item == null:
        held_item = ItemSlot.new()
    var tmp = held_item.item_id
    var tmp_count = held_item.count
    held_item.item_id = slot.item_id
    held_item.count = slot.count
    slot.item_id = tmp
    slot.count = tmp_count
    if slot.is_empty():
        slot.clear()

func place_into(slot: ItemSlot, item_types_node):
    if held_item == null or held_item.is_empty():
        return
    if slot.is_empty():
        slot.item_id = held_item.item_id
        slot.count = held_item.count
        held_item.clear()
    elif slot.item_id == held_item.item_id:
        var t = item_types_node.get_type(slot.item_id)
        var max_s = t.max_stack if t else 64
        var remaining = slot.add(held_item.item_id, held_item.count, max_s)
        if remaining > 0:
            held_item.count = remaining
        else:
            held_item.clear()
    else:
        var tmp_id = slot.item_id
        var tmp_count = slot.count
        slot.item_id = held_item.item_id
        slot.count = held_item.count
        held_item.item_id = tmp_id
        held_item.count = tmp_count

func pickup_half(slot: ItemSlot):
    if slot.is_empty():
        return
    if held_item == null:
        held_item = ItemSlot.new()
    var half = ceil(slot.count / 2.0)
    held_item.item_id = slot.item_id
    held_item.count = half
    slot.count -= half
    if slot.count <= 0:
        slot.clear()

func place_one(slot: ItemSlot, item_types_node):
    if held_item == null or held_item.is_empty():
        return
    if slot.is_empty():
        slot.item_id = held_item.item_id
        slot.count = 1
        held_item.count -= 1
        if held_item.count <= 0:
            held_item.clear()
    elif slot.item_id == held_item.item_id:
        var t = item_types_node.get_type(slot.item_id)
        var max_s = t.max_stack if t else 64
        if slot.count < max_s:
            slot.count += 1
            held_item.count -= 1
            if held_item.count <= 0:
                held_item.clear()
```

- [ ] **Step 2: Add to main.tscn**

Add `InventoryManager` Node to main.tscn with this script. Update load_steps.

- [ ] **Step 3: Commit**

```bash
git add scripts/inventory_manager.gd scenes/main.tscn
git commit -m "feat: inventory data manager - hotbar, backpack, pickup/place logic"
```

---

### Task 3: Rewrite Hotbar UI (inventory.gd)

**Files:**
- Modify: `scripts/inventory.gd`

- [ ] **Step 1: Rewrite inventory.gd for item system**

```gdscript
extends Control

@onready var inv_mgr = $"../../InventoryManager"
@onready var item_types_node = $"../../ItemTypes"
var slot_buttons: Array[Button] = []
const SLOT_COUNT := 10
var tooltip_label: Label

func _ready():
    _build_ui()
    get_tree().root.size_changed.connect(_on_resize)

func _build_ui():
    var hbox := HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 4)
    add_child(hbox)
    for i in SLOT_COUNT:
        var btn := Button.new()
        btn.name = "Hotbar%d" % i
        btn.custom_minimum_size = Vector2(48, 48)
        btn.mouse_filter = Control.MOUSE_FILTER_STOP
        btn.pressed.connect(_on_slot_clicked.bind(i))
        btn.gui_input.connect(_on_slot_input.bind(i))
        btn.mouse_entered.connect(_on_slot_hover.bind(i))
        btn.mouse_exited.connect(_on_slot_unhover)
        hbox.add_child(btn)
        slot_buttons.append(btn)
    tooltip_label = Label.new()
    tooltip_label.visible = false
    tooltip_label.add_theme_color_override("font_color", Color.WHITE)
    tooltip_label.add_theme_color_override("font_outline_color", Color.BLACK)
    tooltip_label.add_theme_constant_override("outline_size", 2)
    add_child(tooltip_label)
    _on_resize()

func _on_resize():
    var vp = get_viewport().get_visible_rect().size
    var s = min(48, int((vp.x - 80) / SLOT_COUNT))
    for btn in slot_buttons:
        btn.custom_minimum_size = Vector2(s, s)
    _refresh()

func _refresh():
    for i in SLOT_COUNT:
        _draw_slot(i)

func _draw_slot(index: int):
    var btn = slot_buttons[index]
    var slot = inv_mgr.hotbar[index]
    var style := StyleBoxFlat.new()
    if slot.is_empty():
        style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
    else:
        var t = item_types_node.get_type(slot.item_id)
        style.bg_color = t.color if t else Color.GRAY
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    btn.add_theme_stylebox_override("normal", style)
    btn.text = str(slot.count) if slot.count > 1 else ""
    if index == inv_mgr.selected_slot:
        var sel := StyleBoxFlat.new()
        sel.bg_color = style.bg_color
        sel.border_width_left = 3
        sel.border_width_right = 3
        sel.border_width_top = 3
        sel.border_width_bottom = 3
        sel.border_color = Color.GOLD
        sel.corner_radius_top_left = 4
        sel.corner_radius_top_right = 4
        sel.corner_radius_bottom_left = 4
        sel.corner_radius_bottom_right = 4
        btn.add_theme_stylebox_override("normal", sel)

func _on_slot_clicked(index: int):
    var slot = inv_mgr.hotbar[index]
    if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
        inv_mgr.place_into(slot, item_types_node)
    else:
        inv_mgr.pickup_from(slot)
    _refresh()

func _on_slot_input(event: InputEvent, index: int):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            var slot = inv_mgr.hotbar[index]
            if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
                inv_mgr.place_one(slot, item_types_node)
            else:
                inv_mgr.pickup_half(slot)
            _refresh()
        elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
            inv_mgr.selected_slot = index
            inv_mgr.held_item = null
            _refresh()

func _on_slot_hover(index: int):
    var slot = inv_mgr.hotbar[index]
    if not slot.is_empty():
        var t = item_types_node.get_type(slot.item_id)
        if t:
            tooltip_label.text = t.name + " x" + str(slot.count)
            tooltip_label.visible = true
            tooltip_label.position = get_global_mouse_position() + Vector2(16, -16)

func _on_slot_unhover():
    tooltip_label.visible = false

func _process(_delta):
    if tooltip_label.visible:
        tooltip_label.position = get_global_mouse_position() + Vector2(16, -16)
    _refresh()
```

- [ ] **Step 2: Update main.gd references**

Remove old inventory signal connections, use `inv_mgr` instead.

- [ ] **Step 3: Commit**

```bash
git add scripts/inventory.gd scripts/main.gd
git commit -m "feat: rewrite hotbar UI for item system with pickup/place/tooltip"
```

---

### Task 4: Backpack Panel

**Files:**
- Create: `scripts/backpack_panel.gd`
- Create: `scenes/ui/backpack_panel.tscn`

- [ ] **Step 1: Create backpack_panel.tscn**

A PopupPanel with a GridContainer (9 columns, 3 rows) + a title label "Backpack". Grid cells are Buttons similar to hotbar.

- [ ] **Step 2: Create backpack_panel.gd**

```gdscript
extends PopupPanel

@onready var inv_mgr = $"../../../InventoryManager"
@onready var item_types_node = $"../../../ItemTypes"
@onready var grid = $Grid
var slot_buttons: Array[Button] = []

func _ready():
    for i in range(inv_mgr.BACKPACK_SIZE):
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(48, 48)
        btn.pressed.connect(_on_slot_clicked.bind(i))
        btn.gui_input.connect(_on_slot_input.bind(i))
        btn.mouse_entered.connect(_on_slot_hover.bind(i))
        btn.mouse_exited.connect(_on_slot_unhover)
        grid.add_child(btn)
        slot_buttons.append(btn)
    hide()

func _refresh():
    for i in range(inv_mgr.BACKPACK_SIZE):
        var btn = slot_buttons[i]
        var slot = inv_mgr.backpack[i]
        var style := StyleBoxFlat.new()
        if slot.is_empty():
            style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
        else:
            var t = item_types_node.get_type(slot.item_id)
            style.bg_color = t.color if t else Color.GRAY
        style.corner_radius_top_left = 4
        style.corner_radius_top_right = 4
        style.corner_radius_bottom_left = 4
        style.corner_radius_bottom_right = 4
        btn.add_theme_stylebox_override("normal", style)
        btn.text = str(slot.count) if slot.count > 1 else ""

func _on_slot_clicked(index: int):
    var slot = inv_mgr.backpack[index]
    if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
        inv_mgr.place_into(slot, item_types_node)
    else:
        inv_mgr.pickup_from(slot)
    _refresh()

func _on_slot_input(event: InputEvent, index: int):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            var slot = inv_mgr.backpack[index]
            if inv_mgr.held_item != null and not inv_mgr.held_item.is_empty():
                inv_mgr.place_one(slot, item_types_node)
            else:
                inv_mgr.pickup_half(slot)
            _refresh()

func _on_slot_hover(index: int):
    pass  # Tooltip handled by hotbar's tooltip system

func _on_slot_unhover():
    pass

func _process(_delta):
    _refresh()

func open_backpack():
    popup_centered()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/backpack_panel.gd scenes/ui/backpack_panel.tscn
git commit -m "feat: backpack panel UI with 27-slot grid"
```

---

### Task 5: Integration (main.gd, camera_rig.gd, project.godot)

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scripts/camera_rig.gd`
- Modify: `scripts/block_manager.gd`
- Modify: `scripts/raycast_handler.gd`
- Modify: `project.godot`

- [ ] **Step 1: Add backpack action to project.godot** ！ E key (keycode 69)

- [ ] **Step 2: Update camera_rig.gd** ！ E = toggle backpack, ESC/B = release mouse

- [ ] **Step 3: Update main.gd** ！ instantiate backpack panel, handle E to toggle

- [ ] **Step 4: Update block_manager.gd** ！ use item_id to look up color from ItemTypes

- [ ] **Step 5: Update raycast_handler.gd** ！ place block using item_id

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd scripts/camera_rig.gd scripts/block_manager.gd scripts/raycast_handler.gd project.godot
git commit -m "feat: integrate backpack - E toggle, item-based block placement, ESC/B release mouse"
```

---

### Task 6: Polish & Test

- [ ] Verify: E opens backpack, items display correctly
- [ ] Verify: left-click pickup/place works in hotbar and backpack
- [ ] Verify: right-click pickup half / place one
- [ ] Verify: scroll wheel switches hotbar
- [ ] Verify: placing blocks uses correct item type/color
- [ ] Verify: tooltip shows on hover
- [ ] Commit final changes
