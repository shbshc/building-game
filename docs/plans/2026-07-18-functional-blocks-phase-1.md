# 功能方块系统 Phase 1 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `run_skill({name: "subagent-driven-development"})` (recommended) or `run_skill({name: "executing-plans"})` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 实现方向性的功能方块系统 Phase 1：方向系统基础设施 + 能源方块(持续/脉冲) + 移动方块 + 拐弯方块 + 激活信号链。

**Architecture:** 方块数据扩展 `functional_type` + `direction` 字段。`ActivationSystem` 节点管理信号传播（方向约束 + 激活ID防循环）。移动方块碰撞拐弯方块时改变方向。

**Tech Stack:** Godot 4.7, GDScript, GL Compatibility renderer

---

## 关键设计决定

- **方向**：6 轴 Vector3i 常量：`+X(1,0,0)`, `-X(-1,0,0)`, `+Y(0,1,0)`, `-Y(0,-1,0)`, `+Z(0,0,1)`, `-Z(0,0,-1)`
- **激活链传播**：信号从能源方块出发，沿箭头方向依次激活相邻方块。每个方块收到信号后执行行为，然后向前方继续传播
- **防循环**：每次激活生成唯一 ID，已激活方块记录该 ID，重复收到直接忽略
- **拐弯方块**：占据格子。移动方块移动到拐弯方块所在格子时，拐弯方块被移除（消耗），移动方块方向被改为拐弯方块的箭头方向
- **移动方块**：激活后向箭头方向移动 1 格。若目标格被普通方块占据则激活失败。移动时连带黏着方块粘合的结构（黏着 Phase 2 实现，Phase 1 仅移动自身）

---

### Task 1: 功能方块类型定义 (functional_types.gd)

**Files:**
- Create: `scripts/functional_types.gd`

- [ ] **Step 1: 创建 functional_types.gd**

```gdscript
extends Node
# functional_types.gd — 功能方块系统的类型定义和辅助函数

# 功能方块类型枚举
enum FuncType {
    NONE = 0,
    ENERGY_CONTINUOUS = 1,  # 持续型能源方块
    ENERGY_PULSE = 2,        # 脉冲型能源方块
    MOVE = 3,                # 移动方块
    TURN = 4,                # 拐弯方块
}

# 6 个方向向量
const DIRECTION_VECTORS: Array[Vector3i] = [
    Vector3i( 1,  0,  0),  # +X  0
    Vector3i(-1,  0,  0),  # -X  1
    Vector3i( 0,  1,  0),  # +Y  2
    Vector3i( 0, -1,  0),  # -Y  3
    Vector3i( 0,  0,  1),  # +Z  4
    Vector3i( 0,  0, -1),  # -Z  5
]

const DIRECTION_NAMES: Array[String] = [
    "+X", "-X", "+Y", "-Y", "+Z", "-Z"
]

# 将方向索引转为 Vector3i
static func dir_index_to_vec(idx: int) -> Vector3i:
    if idx >= 0 and idx < DIRECTION_VECTORS.size():
        return DIRECTION_VECTORS[idx]
    return Vector3i(0, 1, 0)  # 默认 +Y

# 将 Vector3i 方向转为索引
static func dir_vec_to_index(dir: Vector3i) -> int:
    for i in range(DIRECTION_VECTORS.size()):
        if DIRECTION_VECTORS[i] == dir:
            return i
    return 2  # 默认 +Y

# 获取相反方向
static func opposite_direction(dir: Vector3i) -> Vector3i:
    return Vector3i(-dir.x, -dir.y, -dir.z)

# 获取下一个方向索引（用于旋转工具循环切换）
static func next_direction_index(current: int) -> int:
    return (current + 1) % DIRECTION_VECTORS.size()

# 检查是否是能源类型
static func is_energy_type(ft: int) -> bool:
    return ft == FuncType.ENERGY_CONTINUOUS or ft == FuncType.ENERGY_PULSE

# 获取功能方块对应的 item_id（在 item_types 中注册的 ID）
const ENERGY_CONTINUOUS_ITEM_ID = 6
const ENERGY_PULSE_ITEM_ID = 7
const MOVE_ITEM_ID = 8
const TURN_ITEM_ID = 9

# 功能方块的显示颜色（在网格上的颜色）
static func get_func_type_color(ft: int) -> Color:
    match ft:
        FuncType.ENERGY_CONTINUOUS:
            return Color(1.0, 0.3, 0.1)   # 橙红
        FuncType.ENERGY_PULSE:
            return Color(1.0, 0.5, 0.0)   # 橙色
        FuncType.MOVE:
            return Color(0.2, 0.6, 1.0)   # 蓝色
        FuncType.TURN:
            return Color(0.3, 0.9, 0.3)   # 绿色
        _:
            return Color.GRAY

func _ready():
    print("FunctionalTypes loaded: ", DIRECTION_VECTORS.size(), " directions")
```

- [ ] **Step 2: 验证**

在 `main.gd` 的 `_ready()` 末尾临时添加：
```gdscript
var ft = $FunctionalTypes
print("Direction test: +X -> ", ft.dir_vec_to_index(Vector3i(1,0,0)))
print("Opposite test: ", ft.opposite_direction(Vector3i(1,0,0)))
print("Energy check: ", ft.is_energy_type(1))
```

运行，确认控制台输出正确：
```
Direction test: +X -> 0
Opposite test: (-1, 0, 0)
Energy check: True
```

- [ ] **Step 3: Commit**

```bash
git add scripts/functional_types.gd scripts/main.gd
git commit -m "feat: functional_types — direction enums, FuncType enum, helpers"
```

---

### Task 2: 扩展方块数据模型 (block_manager.gd)

**Files:**
- Modify: `scripts/block_manager.gd`

- [ ] **Step 1: 更新 block_manager.gd 数据结构**

将 `scripts/block_manager.gd` 完整替换为：

```gdscript
extends Node3D

@onready var item_types_node = $"../ItemTypes"
@onready var func_types = $"../FunctionalTypes"

var blocks := {}  # Dictionary: Vector3i -> BlockData

class BlockData:
    var item_id: int = -1
    var color: Color = Color.RED
    var node: MeshInstance3D = null
    var func_type: int = 0     # FuncType enum
    var direction: int = 2     # direction index (默认 +Y)

var selected_color := Color.RED


func can_place_at(grid_pos: Vector3i) -> bool:
    if blocks.has(grid_pos):
        return false
    if grid_pos.y == 0:
        return true
    var neighbors := [
        grid_pos + Vector3i.UP,
        grid_pos + Vector3i.DOWN,
        grid_pos + Vector3i.LEFT,
        grid_pos + Vector3i.RIGHT,
        grid_pos + Vector3i.FORWARD,
        grid_pos + Vector3i.BACK,
    ]
    for n in neighbors:
        if blocks.has(n):
            return true
    return false


func place_block(grid_pos: Vector3i, item_id: int = -1, custom_color = null, func_type: int = 0, direction: int = 2) -> bool:
    if not can_place_at(grid_pos):
        return false

    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.position = Vector3(grid_pos) + Vector3(0.5, 0.5, 0.5)

    var mat := StandardMaterial3D.new()
    var color := selected_color
    if custom_color != null:
        color = custom_color
    elif func_type > 0:
        color = func_types.get_func_type_color(func_type)
    elif item_id >= 0 and item_types_node:
        var t = item_types_node.get_type(item_id)
        if t:
            color = t.color
    mat.albedo_color = color
    mesh.material_override = mat

    # 添加方向箭头指示器（功能方块专有）
    if func_type > 0:
        _add_direction_indicator(mesh, direction)

    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    col.shape = BoxShape3D.new()
    col.shape.size = Vector3(1, 1, 1)
    body.add_child(col)
    mesh.add_child(body)

    add_child(mesh)

    var bd := BlockData.new()
    bd.item_id = item_id
    bd.color = color
    bd.node = mesh
    bd.func_type = func_type
    bd.direction = direction
    blocks[grid_pos] = bd
    return true


func _add_direction_indicator(mesh: MeshInstance3D, dir_idx: int):
    # 在方块表面画一个小的方向箭头（半透明锥体/小方块）
    var dir_vec = func_types.DIRECTION_VECTORS[dir_idx]
    var indicator := MeshInstance3D.new()
    indicator.mesh = BoxMesh.new()
    indicator.mesh.size = Vector3(0.3, 0.3, 0.15)
    indicator.position = Vector3(dir_vec) * 0.55  # 贴在表面
    # 根据方向旋转指示器
    if dir_vec.x != 0:
        indicator.rotation = Vector3(0, 0, PI/2 if dir_vec.x > 0 else -PI/2)
    elif dir_vec.z != 0:
        indicator.rotation = Vector3(PI/2, 0, 0 if dir_vec.z > 0 else PI)
    # +Y 和 -Y 不需要旋转（默认朝上）
    if dir_vec.y < 0:
        indicator.rotation = Vector3(PI, 0, 0)
    var ind_mat := StandardMaterial3D.new()
    ind_mat.albedo_color = Color.WHITE
    ind_mat.emission_enabled = true
    ind_mat.emission = Color.WHITE
    ind_mat.emission_energy_multiplier = 0.5
    indicator.material_override = ind_mat
    mesh.add_child(indicator)


func remove_block(grid_pos: Vector3i) -> bool:
    if not blocks.has(grid_pos):
        return false
    blocks[grid_pos].node.queue_free()
    blocks.erase(grid_pos)
    return true


func get_block_data(grid_pos: Vector3i):
    return blocks.get(grid_pos, null)


func get_all_blocks() -> Dictionary:
    return blocks


func clear_all():
    for pos in blocks:
        blocks[pos].node.queue_free()
    blocks.clear()


# 移动方块：将方块从 from_pos 移到 to_pos
# 返回 true 表示移动成功
func move_block(from_pos: Vector3i, to_pos: Vector3i) -> bool:
    if not blocks.has(from_pos):
        return false
    # 检查目标位置是否为空（允许覆盖拐弯方块）
    var target = blocks.get(to_pos, null)
    if target != null:
        if target.func_type == func_types.FuncType.TURN:
            # 拐弯方块被消耗
            remove_block(to_pos)
        else:
            return false  # 被其他方块占据，移动失败

    var bd = blocks[from_pos]
    blocks.erase(from_pos)

    # 更新节点位置
    bd.node.position = Vector3(to_pos) + Vector3(0.5, 0.5, 0.5)

    # 重新创建方向指示器
    _refresh_direction_indicator(bd)

    blocks[to_pos] = bd
    return true


func _refresh_direction_indicator(bd: BlockData):
    # 移除旧指示器（第二个子节点，第一个是碰撞体）
    var children = bd.node.get_children()
    for child in children:
        if child is MeshInstance3D and child != children[0]:
            child.queue_free()
    # 添加新指示器
    _add_direction_indicator(bd.node, bd.direction)


# 设置方块方向
func set_block_direction(grid_pos: Vector3i, new_direction: int) -> bool:
    var bd = blocks.get(grid_pos, null)
    if bd == null or bd.func_type == 0:
        return false
    bd.direction = new_direction
    _refresh_direction_indicator(bd)
    return true
```

- [ ] **Step 2: 在 main.tscn 中添加 FunctionalTypes 节点**

在 `scenes/main.tscn` 中添加：
```ini
[node name="FunctionalTypes" type="Node" parent="."]
script = ExtResource("10_functional_types")
```

同时增加 load_step 和 ext_resource：
```ini
[gd_scene load_steps=13 format=3]
...
[ext_resource type="Script" path="res://scripts/functional_types.gd" id="10_functional_types"]
```

- [ ] **Step 3: 验证**

在 `main.gd` 中添加临时测试：
```gdscript
func _ready():
    # ... existing code ...
    # 临时测试：放置一个功能方块
    block_manager.place_block(Vector3i(5, 0, 5), -1, null, $FunctionalTypes.FuncType.ENERGY_CONTINUOUS, 2)
```

运行，确认在 (5, 0, 5) 看到一个橙红色方块，顶面有白色方向指示器。

- [ ] **Step 4: Commit**

```bash
git add scripts/block_manager.gd scenes/main.tscn scripts/main.gd
git commit -m "feat: block_manager — BlockData class, direction indicator, move_block"
```

---

### Task 3: 激活系统 (activation_system.gd)

**Files:**
- Create: `scripts/activation_system.gd`

- [ ] **Step 1: 创建 activation_system.gd**

```gdscript
extends Node

@onready var block_manager = $"../Blocks"
@onready var func_types = $"../FunctionalTypes"

var _activation_id := 0
var _activated_blocks: Dictionary = {}  # activation_id -> Array[Vector3i]


func trigger_activation(origin_pos: Vector3i, direction_vec: Vector3i):
    _activation_id += 1
    var aid = _activation_id
    _activated_blocks[aid] = []
    _propagate(origin_pos, direction_vec, aid)
    # 清理旧激活记录（保留最近 10 次）
    if _activated_blocks.size() > 10:
        var oldest = _activation_id - 10
        for k in _activated_blocks.keys():
            if k < oldest:
                _activated_blocks.erase(k)


func _propagate(current_pos: Vector3i, signal_dir: Vector3i, aid: int):
    # 停止条件：越界
    if current_pos.y < 0:
        return
    if abs(current_pos.x) > 50 or abs(current_pos.z) > 50 or current_pos.y > 50:
        return

    var bd = block_manager.get_block_data(current_pos)
    if bd == null:
        return  # 空位置，信号终止

    # 防循环：本轮已激活则跳过
    if current_pos in _activated_blocks[aid]:
        return
    _activated_blocks[aid].append(current_pos)

    var ft = bd.func_type

    match ft:
        func_types.FuncType.ENERGY_CONTINUOUS, func_types.FuncType.ENERGY_PULSE:
            # 能源方块收到激活 → 沿自己的箭头方向发出信号
            var dir_vec = func_types.DIRECTION_VECTORS[bd.direction]
            var next_pos = current_pos + dir_vec
            print("Energy at ", current_pos, " firing toward ", dir_vec)
            _propagate(next_pos, dir_vec, aid)

        func_types.FuncType.MOVE:
            # 移动方块：向自己的箭头方向移动 1 格
            var dir_vec = func_types.DIRECTION_VECTORS[bd.direction]
            var new_pos = current_pos + dir_vec
            print("Move block from ", current_pos, " to ", new_pos)

            # 检查目标格是否有拐弯方块
            var target = block_manager.get_block_data(new_pos)
            var was_turn = (target != null and target.func_type == func_types.FuncType.TURN)
            var turn_dir = target.direction if was_turn else -1

            if block_manager.move_block(current_pos, new_pos):
                # 移动成功
                if was_turn:
                    # 拐弯方块被消耗，移动方块转向
                    block_manager.set_block_direction(new_pos, turn_dir)
                    print("Move block turned to ", func_types.DIRECTION_NAMES[turn_dir])

                # 继续向前传播信号
                var new_dir_vec = func_types.DIRECTION_VECTORS[block_manager.get_block_data(new_pos).direction]
                _propagate(new_pos, new_dir_vec, aid)
            else:
                print("Move blocked at ", current_pos, " -> ", new_pos)

        func_types.FuncType.TURN:
            # 拐弯方块不响应激活，信号终止
            pass

        _:
            # 普通方块：信号终止
            pass
```

- [ ] **Step 2: 在 main.tscn 中添加 ActivationSystem 节点**

```ini
[gd_scene load_steps=14 format=3]
...
[ext_resource type="Script" path="res://scripts/activation_system.gd" id="11_activation_system"]
...
[node name="ActivationSystem" type="Node" parent="."]
script = ExtResource("11_activation_system")
```

- [ ] **Step 3: 验证**

在 `main.gd` 中临时添加：
```gdscript
# 放一条链：能源(5,0,5, ↑) → 移动(5,1,5, ↑)
func _test_activation_chain():
    var ft = $FunctionalTypes
    block_manager.place_block(Vector3i(5, 0, 5), -1, null, ft.FuncType.ENERGY_PULSE, 2)  # +Y
    block_manager.place_block(Vector3i(5, 1, 5), -1, null, ft.FuncType.MOVE, 2)         # +Y
    $ActivationSystem.trigger_activation(Vector3i(5, 0, 5), Vector3i.UP)
```

运行后手动调用 `_test_activation_chain()`，观察移动方块从 (5,1,5) 移到 (5,2,5)。

- [ ] **Step 4: Commit**

```bash
git add scripts/activation_system.gd scenes/main.tscn scripts/main.gd
git commit -m "feat: activation_system — signal propagation with loop prevention"
```

---

### Task 4: 扩展物品类型 (item_types.gd)

**Files:**
- Modify: `scripts/item_types.gd`

- [ ] **Step 1: 在 item_types.gd 中添加功能方块类型**

`scripts/item_types.gd` 完整替换为：

```gdscript
extends Node

class ItemType:
    var id: int
    var name: String
    var color: Color
    var max_stack: int = 64
    var func_type: int = 0  # FuncType, 0 = 普通方块

    func _init(p_id: int, p_name: String, p_color: Color, p_max: int = 64, p_func: int = 0):
        id = p_id
        name = p_name
        color = p_color
        max_stack = p_max
        func_type = p_func


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


var item_types: Array = []

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
        # 功能方块 (id 6-9)
        ItemType.new(6, "Energy (Continuous)", Color(1.0, 0.3, 0.1), 64, 1),
        ItemType.new(7, "Energy (Pulse)", Color(1.0, 0.5, 0.0), 64, 2),
        ItemType.new(8, "Move", Color(0.2, 0.6, 1.0), 64, 3),
        ItemType.new(9, "Turn", Color(0.3, 0.9, 0.3), 64, 4),
    ]
    print("Item types loaded: ", item_types.size())

func get_type(id: int):
    if id >= 0 and id < item_types.size():
        return item_types[id]
    return null

func get_item_name(id: int) -> String:
    var t = get_type(id)
    return t.name if t else "Unknown"

func is_functional(id: int) -> bool:
    var t = get_type(id)
    return t != null and t.func_type > 0

func get_func_type(id: int) -> int:
    var t = get_type(id)
    return t.func_type if t else 0
```

- [ ] **Step 2: Commit**

```bash
git add scripts/item_types.gd
git commit -m "feat: item_types — 4 functional block types (id 6-9)"
```

---

### Task 5: 更新物品栏 (inventory_manager.gd + inventory.gd)

**Files:**
- Modify: `scripts/inventory_manager.gd`
- Modify: `scripts/inventory.gd`

- [ ] **Step 1: inventory_manager.gd 初始给功能方块**

修改 `inventory_manager.gd` 的 `_ready()` 中的初始物品分配：

```gdscript
func _ready():
    for i in range(HOTBAR_SIZE):
        hotbar.append(ItemTypesScript.ItemSlot.new())
        slot_colors.append(null)
    for i in range(BACKPACK_SIZE):
        backpack.append(ItemTypesScript.ItemSlot.new())

    # 5 种普通方块
    hotbar[0].add(0, 1, 64)
    hotbar[1].add(1, 1, 64)
    hotbar[2].add(2, 1, 64)
    hotbar[3].add(3, 1, 64)
    hotbar[4].add(4, 1, 64)
    hotbar[5].add(5, 1, 64)

    # 4 种功能方块
    hotbar[6].add(6, 1, 64)  # Energy Continuous
    hotbar[7].add(7, 1, 64)  # Energy Pulse
    hotbar[8].add(8, 1, 64)  # Move
    hotbar[9].add(9, 1, 64)  # Turn
```

- [ ] **Step 2: inventory.gd 显示功能方块颜色**

`inventory.gd` 中 `_draw_slot()` 方法不需要改动（它已经通过 `item_types_node.get_type()` 获取颜色，我们已经在 `ItemType` 中定义了功能方块的颜色）。

验证：运行游戏，确认物品栏后 4 格显示功能方块（橙红、橙色、蓝色、绿色）。

- [ ] **Step 3: Commit**

```bash
git add scripts/inventory_manager.gd
git commit -m "feat: hotbar — functional blocks in slots 6-9"
```

---

### Task 6: 放置功能方块 & 方向旋转 (raycast_handler.gd + main.gd)

**Files:**
- Modify: `scripts/raycast_handler.gd`
- Modify: `scripts/main.gd`

- [ ] **Step 1: raycast_handler.gd — 放置时传 func_type 和方向**

修改 `_try_place()` 方法：

```gdscript
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
                var direction = _face_to_direction(result.normal) if func_type > 0 else 2
                var color = inv_mgr.get_selected_color(item_types_node) if func_type == 0 else null
                block_manager.place_block(grid_pos, selected_id, color, func_type, direction)


# 将放置面的法线转为方向索引（功能方块初始面朝玩家放置的面）
func _face_to_direction(normal: Vector3) -> int:
    var n = Vector3i(int(round(normal.x)), int(round(normal.y)), int(round(normal.z)))
    return $"../FunctionalTypes".dir_vec_to_index(n)
```

- [ ] **Step 2: main.gd — 右键脉冲能源方块触发激活**

在 `main.gd` 的 `_process` 中添加能源方块右键检测。由于 `raycast_handler` 已经处理了鼠标输入，我们在 `main.gd` 中增加一个通过 `raycast` 检测右键点击功能方块的方法。

更简洁的做法：在 `raycast_handler.gd` 的 `_input` 中，右键点击已有方块时检测是否是脉冲能源：

修改 `raycast_handler.gd` 的 `_try_break()` 和添加 `_try_interact()`：

```gdscript
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
                # 右键：如果指向功能方块 → 交互；否则 → 拆除
                var result = _raycast()
                if result and result.collider:
                    var parent = result.collider.get_parent()
                    if parent is MeshInstance3D:
                        var pos = parent.position
                        var grid_pos = Vector3i(int(pos.x - 0.5), int(pos.y - 0.5), int(pos.z - 0.5))
                        var bd = block_manager.get_block_data(grid_pos)
                        if bd != null:
                            var ft = $"../FunctionalTypes"
                            if bd.func_type == ft.FuncType.ENERGY_PULSE:
                                # 激活脉冲能源
                                var dir_vec = ft.DIRECTION_VECTORS[bd.direction]
                                $"../ActivationSystem".trigger_activation(grid_pos, dir_vec)
                                return
                            elif bd.func_type == ft.FuncType.ENERGY_CONTINUOUS:
                                # 持续能源也可以右键手动激活
                                var dir_vec = ft.DIRECTION_VECTORS[bd.direction]
                                $"../ActivationSystem".trigger_activation(grid_pos, dir_vec)
                                return
                # 否则拆方块
                mouse_right_held = true
                break_timer = 0.0
            else:
                mouse_right_held = false

    if event is InputEventMouseMotion:
        _update_highlight()
```

- [ ] **Step 3: 持续能源方块自动脉冲 (main.gd)**

在 `main.gd` 的 `_process` 中添加：

```gdscript
var _energy_tick_timer := 0.0
const ENERGY_TICK_INTERVAL := 2.0  # 每 2 秒一次脉冲

func _process(delta):
    _energy_tick_timer -= delta
    if _energy_tick_timer <= 0:
        _energy_tick_timer = ENERGY_TICK_INTERVAL
        _tick_continuous_energy()

func _tick_continuous_energy():
    var ft = $FunctionalTypes
    for pos in block_manager.blocks:
        var bd = block_manager.blocks[pos]
        if bd.func_type == ft.FuncType.ENERGY_CONTINUOUS:
            var dir_vec = ft.DIRECTION_VECTORS[bd.direction]
            $ActivationSystem.trigger_activation(pos, dir_vec)
```

- [ ] **Step 4: 方向旋转工具**

在 `raycast_handler.gd` 中，按住 Shift + 右键功能方块 → 旋转方向：

在 `_input` 的右键处理中增加：
```gdscript
elif event.button_index == MOUSE_BUTTON_RIGHT:
    if event.pressed and Input.is_key_pressed(KEY_SHIFT):
        # Shift + 右键：旋转功能方块方向
        var result = _raycast()
        if result and result.collider:
            var parent = result.collider.get_parent()
            if parent is MeshInstance3D:
                var pos = parent.position
                var grid_pos = Vector3i(int(pos.x - 0.5), int(pos.y - 0.5), int(pos.z - 0.5))
                var bd = block_manager.get_block_data(grid_pos)
                if bd != null and bd.func_type > 0:
                    var new_dir = $"../FunctionalTypes".next_direction_index(bd.direction)
                    block_manager.set_block_direction(grid_pos, new_dir)
                    return
    # ... rest of right-click handling ...
```

- [ ] **Step 5: 验证**

1. 运行游戏，选择 Energy Pulse（橙色），左键放在地面上
2. 选择 Move（蓝色），放在能源方块上方一格
3. 右键点击能源方块 → 观察移动方块向上移动一格
4. Shift+右键功能方块 → 方向指示器旋转

- [ ] **Step 6: Commit**

```bash
git add scripts/raycast_handler.gd scripts/main.gd
git commit -m "feat: interaction — place functional blocks, right-click activate, Shift+right-click rotate"
```

---

### Task 7: 拐弯方块 (Turn Block)

**Files:**
- Modify: `scripts/raycast_handler.gd`（已在 Task 6 完成）
- 核心逻辑已在 `scripts/activation_system.gd` 的 `_propagate()` 中实现
- 核心逻辑已在 `scripts/block_manager.gd` 的 `move_block()` 中实现

> 拐弯方块的行为在 Task 3 和 Task 6 中已经实现，本 Task 仅做集成验证。

- [ ] **Step 1: 验证拐弯方块完整流程**

在 `main.gd` 中创建测试场景：

```gdscript
func _test_turn_chain():
    var ft = $FunctionalTypes
    # 能源(5,0,5, ↑) → 移动(5,1,5, →) → 拐弯(6,1,5, ↑)
    block_manager.place_block(Vector3i(5, 0, 5), -1, null, ft.FuncType.ENERGY_PULSE, 2)  # 箭头 +Y
    block_manager.place_block(Vector3i(5, 1, 5), -1, null, ft.FuncType.MOVE, 0)          # 箭头 +X
    block_manager.place_block(Vector3i(6, 1, 5), -1, null, ft.FuncType.TURN, 2)          # 箭头 +Y
    # 激活
    $ActivationSystem.trigger_activation(Vector3i(5, 0, 5), Vector3i.UP)
    # 预期：移动方块从 (5,1,5) 移到 (6,1,5)，拐弯方块被消耗，
    # 移动方块方向变为 +Y，然后继续向上移动
```

运行，手动调用，观察：
- 移动方块移到 (6,1,5)
- 拐弯方块消失
- 移动方块方向箭头变成 ↑

- [ ] **Step 2: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: turn block — move block changes direction on turn block consumption"
```

---

### Task 8: 存档系统更新 (save_manager.gd)

**Files:**
- Modify: `scripts/save_manager.gd`

- [ ] **Step 1: 更新存档格式 v3**

```gdscript
extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3

func save(block_manager, inventory_manager, ground_node) -> bool:
    var data := {
        "version": SAVE_VERSION,
        "blocks": [],
        "inventory": [],
        "ground_color": [0.85, 0.85, 0.85],
        "grid_color": [0.4, 0.4, 0.4]
    }
    for pos in block_manager.blocks:
        var b = block_manager.blocks[pos]
        data["blocks"].append({
            "x": pos.x, "y": pos.y, "z": pos.z,
            "item_id": b.item_id,
            "func_type": b.func_type,
            "direction": b.direction
        })
    for slot in inventory_manager.hotbar:
        data["inventory"].append({
            "item_id": slot.item_id,
            "count": slot.count
        })
    if ground_node:
        data["ground_color"] = [ground_node.ground_color.r, ground_node.ground_color.g, ground_node.ground_color.b]
        data["grid_color"] = [ground_node.grid_color.r, ground_node.grid_color.g, ground_node.grid_color.b]

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        return true
    return false


func load(block_manager, inventory_manager, ground_node) -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return false
    var json := JSON.new()
    var err = json.parse(file.get_as_text())
    file.close()
    if err != OK:
        return false
    var data = json.data
    var version = data.get("version", 1)

    block_manager.clear_all()
    for b in data.get("blocks", []):
        var item_id = b.get("item_id", -1)
        var func_type = b.get("func_type", 0)
        var direction = b.get("direction", 2)
        block_manager.place_block(
            Vector3i(b["x"], b["y"], b["z"]),
            item_id,
            null,
            func_type,
            direction
        )

    var inv = data.get("inventory", [])
    for i in min(inv.size(), inventory_manager.HOTBAR_SIZE):
        var slot_data = inv[i]
        if slot_data is Dictionary:
            inventory_manager.hotbar[i].item_id = slot_data.get("item_id", -1)
            inventory_manager.hotbar[i].count = slot_data.get("count", 0)
        elif slot_data is Array:
            inventory_manager.hotbar[i].clear()

    if ground_node and data.has("ground_color"):
        var gc = data["ground_color"]
        var gridc = data["grid_color"]
        ground_node.update_colors(Color(gc[0], gc[1], gc[2]), Color(gridc[0], gridc[1], gridc[2]))
    return true
```

- [ ] **Step 2: Commit**

```bash
git add scripts/save_manager.gd
git commit -m "feat: save v3 — func_type + direction fields"
```

---

### Task 9: 集成 & 全流程测试

**Files:**
- Modify: `scripts/main.gd`（清理临时测试代码）

- [ ] **Step 1: 清理 main.gd 中的临时测试代码**

移除 `_ready()` 中的临时方块放置和测试函数，保留正式功能：
- 持续能源 tick
- 背包面板实例化
- UI 设置
- 调色盘

最终的 `scripts/main.gd` 应该干净且仅包含必要代码。

- [ ] **Step 2: 全流程测试清单**

| # | 测试场景 | 预期结果 |
|---|---------|---------|
| 1 | 物品栏选择 Energy Pulse（橙色），右键放置到地面 | 放置成功，顶面有 ↑ 白色箭头 |
| 2 | Shift+右键 Energy Pulse | 方向指示器旋转（↑ → → → ↓ → ← → ↑） |
| 3 | 选择 Move（蓝色），放在能源上方 | 放置成功，有方向指示器 |
| 4 | 右键激活能源 | 移动方块向上移动 1 格 |
| 5 | 测试移动被阻挡：在移动目标格放一个普通方块 | 激活后移动失败，方块不动 |
| 6 | 测试拐弯：能源(↑) → 移动(→) → 拐弯(↑) | 移动右移 → 消耗拐弯 → 转向 ↑ → 继续上移 |
| 7 | 测试循环防死：两个能源对射 | 不崩溃，每轮只激活一次 |
| 8 | 持续能源：放置 Energy Continuous | 每 2 秒自动触发一次脉冲 |
| 9 | 保存 → 关闭 → 加载 | 功能方块的 func_type + direction 恢复正确 |
| 10 | 右键普通方块 | 正常拆除 |

- [ ] **Step 3: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: Phase 1 integration — cleanup + verification"
```

---

### 附录：最终场景节点树

```
Main (Node3D) [main.gd]
├── WorldEnvironment
├── DirectionalLight3D
├── Ground (MeshInstance3D) [ground.gd]
├── CameraRig (CharacterBody3D) [camera_rig.gd]
│   ├── CollisionShape3D
│   └── Camera3D
├── Blocks (Node3D) [block_manager.gd]
├── RayCastHandler (Node3D) [raycast_handler.gd]
├── SaveManager (Node) [save_manager.gd]
├── ItemTypes (Node) [item_types.gd]
├── InventoryManager (Node) [inventory_manager.gd]
├── FunctionalTypes (Node) [functional_types.gd]       ← NEW
├── ActivationSystem (Node) [activation_system.gd]     ← NEW
└── UI (CanvasLayer)
    └── UIContainer (Control)
        ├── Save/Load/Ground buttons
        ├── Crosshair
        ├── InventoryBar (Control) [inventory.gd]
        ├── BackpackPanel (Panel) [backpack_panel.gd]
        ├── ColorPickerPopup (PopupPanel)
        └── GroundColorPopup (PopupPanel)
```
