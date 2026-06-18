# 等距建筑游戏 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `run_skill({name: "subagent-driven-development"})` (recommended) or `run_skill({name: "executing-plans"})` to implement this plan task-by-task.

**Goal:** 构建一个等距视角的 3D 方块建筑游戏，支持视角旋转/缩放/平移、物品栏选色、方块放置/删除、JSON 存档。

**Architecture:** GDScript + Godot 4.7 原生节点。每个方块是一个 MeshInstance3D + BoxMesh，通过 DirectionalLight3D 产生顶亮/左中/右暗的等距光照效果。方块数据用 Dictionary 管理（Vector3i → Color），UI 在独立 CanvasLayer 上。

**Tech Stack:** Godot 4.7, GDScript, GL Compatibility renderer

---

### Task 1: 项目基础搭建

**Files:**
- Create: `scripts/main.gd`
- Create: `scenes/main.tscn`

- [ ] **Step 1: 创建主脚本 main.gd**

```gdscript
extends Node3D

func _ready():
    print("建筑游戏启动")
```

- [ ] **Step 2: 创建主场景 main.tscn**

在 Godot 编辑器中：
1. 新建 3D Scene，根节点用 Node3D，命名为 "Main"
2. 挂载 `scripts/main.gd`
3. 保存为 `scenes/main.tscn`
4. 在 Project Settings → General → Run → Main Scene 设为 `scenes/main.tscn`

- [ ] **Step 3: 验证**

按 F5 运行，确认控制台输出 "建筑游戏启动"，看到灰色 3D 视口。

- [ ] **Step 4: Commit**

```bash
git add scripts/main.gd scenes/main.tscn project.godot
git commit -m "feat: 项目基础搭建 — 主场景与主脚本"
```

---

### Task 2: 地面网格 (Ground + Grid Shader)

**Files:**
- Create: `shaders/grid_ground.gdshader`
- Create: `scripts/ground.gd`

- [ ] **Step 1: 创建网格 shader**

`shaders/grid_ground.gdshader`:
```glsl
shader_type spatial;
render_mode unshaded;

uniform vec4 ground_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform vec4 grid_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float grid_size = 1.0;
uniform float line_width = 0.04;

void fragment() {
    vec2 coord = UV * grid_size;
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
    float line = min(grid.x, grid.y);
    float grid_line = 1.0 - min(line, 1.0);
    
    // 粗线：每 10 格一条主格线
    vec2 coord10 = UV * grid_size / 10.0;
    vec2 grid10 = abs(fract(coord10 - 0.5) - 0.5) / fwidth(coord10);
    float line10 = min(grid10.x, grid10.y);
    float major_line = 1.0 - min(line10, 1.0);
    float final_line = max(grid_line * 0.5, major_line * 0.8);
    
    ALBEDO = mix(ground_color.rgb, grid_color.rgb, final_line * line_width * 10.0);
}
```

- [ ] **Step 2: 创建 ground.gd 脚本**

`scripts/ground.gd`:
```gdscript
extends MeshInstance3D

@export var ground_color := Color(0.85, 0.85, 0.85)
@export var grid_color := Color(0.4, 0.4, 0.4)

func _ready():
    # 创建 100x100 平面
    mesh = PlaneMesh.new()
    mesh.size = Vector2(100, 100)
    mesh.orientation = PlaneMesh.FACE_Z  # 平放在 XZ 平面
    
    # 应用 shader 材质
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://shaders/grid_ground.gdshader")
    mat.set_shader_parameter("ground_color", ground_color)
    mat.set_shader_parameter("grid_color", grid_color)
    material_override = mat
    
    # 碰撞体
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    col.shape = BoxShape3D.new()
    col.shape.size = Vector3(100, 0.01, 100)
    col.position = Vector3(0, -0.005, 0)
    body.add_child(col)
    add_child(body)

func update_colors(new_ground: Color, new_grid: Color):
    ground_color = new_ground
    grid_color = new_grid
    material_override.set_shader_parameter("ground_color", new_ground)
    material_override.set_shader_parameter("grid_color", new_grid)
```

- [ ] **Step 3: 添加到主场景**

在 main.tscn 中：
1. 添加子节点 `MeshInstance3D`，命名为 "Ground"
2. 挂载 `scripts/ground.gd`
3. 调整 `DirectionalLight3D`：rotation = (-45°, -45°, 0°)（从上方偏右照）

- [ ] **Step 4: 验证**

运行，确认看到 100×100 的浅灰地面 + 深灰格线。

- [ ] **Step 5: Commit**

```bash
git add shaders/grid_ground.gdshader scripts/ground.gd scenes/main.tscn
git commit -m "feat: 地面网格 — 100x100 地面 + 格线 shader"
```

---

### Task 3: 摄像机系统 (Camera Rig)

**Files:**
- Create: `scripts/camera_rig.gd`

- [ ] **Step 1: 创建 camera_rig.gd**

`scripts/camera_rig.gd`:
```gdscript
extends Node3D

@export var pitch_angle := 35.264   # 等距俯角
@export var yaw_angle := 45.0       # 水平旋转角
@export var distance := 30.0        # 摄像机距离
@export var ortho_size := 15.0      # 正交大小
@export var min_ortho := 5.0
@export var max_ortho := 40.0
@export var min_pitch := 10.0
@export var max_pitch := 60.0
@export var rotation_speed := 90.0  # 度/秒

var target_yaw := 45.0
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
    # 平滑旋转
    var yaw_diff = target_yaw - yaw_angle
    if abs(yaw_diff) > 0.01:
        yaw_angle += sign(yaw_diff) * min(abs(yaw_diff), rotation_speed * delta)
    
    # 平滑俯仰
    var pitch_diff = target_pitch - pitch_angle
    if abs(pitch_diff) > 0.01:
        pitch_angle += sign(pitch_diff) * min(abs(pitch_diff), rotation_speed * delta)
    
    # 平滑缩放
    var ortho_diff = target_ortho - ortho_size
    if abs(ortho_diff) > 0.01:
        ortho_size += ortho_diff * 10.0 * delta
    
    camera.size = ortho_size
    update_camera_transform()
    
    # 键盘输入
    if Input.is_action_just_pressed("rotate_left"):
        target_yaw -= 90.0
    if Input.is_action_just_pressed("rotate_right"):
        target_yaw += 90.0
    if Input.is_action_pressed("pitch_up"):
        target_pitch = clamp(target_pitch - 30.0 * delta, min_pitch, max_pitch)
    if Input.is_action_pressed("pitch_down"):
        target_pitch = clamp(target_pitch + 30.0 * delta, min_pitch, max_pitch)

func _input(event):
    # 滚轮缩放
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            target_ortho = clamp(target_ortho - 1.0, min_ortho, max_ortho)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            target_ortho = clamp(target_ortho + 1.0, min_ortho, max_ortho)
        
        # 中键拖拽
        if event.button_index == MOUSE_BUTTON_MIDDLE:
            if event.pressed:
                is_dragging = true
                drag_start = event.position
                drag_start_pos = global_position
            else:
                is_dragging = false
    
    # 中键拖拽移动
    if event is InputEventMouseMotion and is_dragging:
        var delta_pos = event.position - drag_start
        var right = global_transform.basis.x
        var forward = global_transform.basis.z
        forward.y = 0
        right.y = 0
        var scale_factor = ortho_size / 200.0
        global_position = drag_start_pos + (-right * delta_pos.x + forward * delta_pos.y) * scale_factor

func update_camera_transform():
    var yaw_rad = deg_to_rad(yaw_angle)
    var pitch_rad = deg_to_rad(pitch_angle)
    
    # 摄像机在球坐标上的位置
    var cam_pos := Vector3(
        distance * cos(pitch_rad) * sin(yaw_rad),
        distance * sin(pitch_rad),
        distance * cos(pitch_rad) * cos(yaw_rad)
    )
    camera.position = cam_pos
    camera.look_at(Vector3.ZERO)
```

- [ ] **Step 2: 设置输入映射**

在 Project Settings → Input Map 中：
| Action | Key |
|--------|-----|
| `rotate_left` | Left Arrow |
| `rotate_right` | Right Arrow |
| `pitch_up` | Up Arrow |
| `pitch_down` | Down Arrow |

- [ ] **Step 3: 添加到主场景**

在 main.tscn 中：
1. 添加 `Node3D` 子节点，命名为 "CameraRig"
2. 在其下添加 `Camera3D`，命名为 "Camera3D"
3. CameraRig 挂载 `scripts/camera_rig.gd`

- [ ] **Step 4: 验证**

运行：方向键左右 → 视角平滑旋转 90°；上下 → 俯角变化；滚轮 → 缩放；中键拖拽 → 平移。

- [ ] **Step 5: Commit**

```bash
git add scripts/camera_rig.gd scenes/main.tscn
git commit -m "feat: 摄像机系统 — 旋转/俯仰/缩放/平移"
```

---

### Task 4: 方块管理器 (Block Manager)

**Files:**
- Create: `scripts/block_manager.gd`

- [ ] **Step 1: 创建 block_manager.gd**

`scripts/block_manager.gd`:
```gdscript
extends Node3D

var blocks := {}  # Dictionary: Vector3i -> {color: Color, node: MeshInstance3D}
var selected_color := Color(1.0, 0.2, 0.2)  # 默认红色

func can_place_at(grid_pos: Vector3i) -> bool:
    # 已占用则不能放
    if blocks.has(grid_pos):
        return false
    
    # 在地面上 (y=0) 可以放
    if grid_pos.y == 0:
        return true
    
    # 检查是否贴着已有方块（上下左右前后）
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

func place_block(grid_pos: Vector3i, color: Color = selected_color) -> bool:
    if not can_place_at(grid_pos):
        return false
    
    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.mesh.size = Vector3(1, 1, 1)
    mesh.position = Vector3(grid_pos)
    
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = mat
    
    # 碰撞体
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    col.shape = BoxShape3D.new()
    col.shape.size = Vector3(1, 1, 1)
    body.add_child(col)
    mesh.add_child(body)
    
    add_child(mesh)
    blocks[grid_pos] = {"color": color, "node": mesh}
    return true

func remove_block(grid_pos: Vector3i) -> bool:
    if not blocks.has(grid_pos):
        return false
    
    blocks[grid_pos]["node"].queue_free()
    blocks.erase(grid_pos)
    return true

func get_block(grid_pos: Vector3i):
    return blocks.get(grid_pos, null)

func get_all_blocks() -> Dictionary:
    return blocks

func clear_all():
    for pos in blocks:
        blocks[pos]["node"].queue_free()
    blocks.clear()

func load_blocks(block_data: Array):
    clear_all()
    for b in block_data:
        place_block(Vector3i(b["x"], b["y"], b["z"]), Color(b["color"][0], b["color"][1], b["color"][2]))
```

- [ ] **Step 2: 添加到主场景**

在 main.tscn 中添加 `Node3D` 子节点，命名为 "Blocks"，挂载 `scripts/block_manager.gd`。

- [ ] **Step 3: 验证测试**

在 main.gd 的 `_ready` 中临时测试：
```gdscript
@onready var block_manager := $Blocks

func _ready():
    block_manager.place_block(Vector3i(0, 0, 0))
    block_manager.place_block(Vector3i(1, 0, 0))
    block_manager.place_block(Vector3i(0, 1, 0))
```
运行后确认看到 3 个方块。

- [ ] **Step 4: Commit**

```bash
git add scripts/block_manager.gd scripts/main.gd scenes/main.tscn
git commit -m "feat: 方块管理器 — 放置/删除/邻接检测"
```

---

### Task 5: 光照设置

**Files:**
- Modify: `scenes/main.tscn`

- [ ] **Step 1: 添加环境光**

在 main.tscn 中：
1. 添加 `WorldEnvironment` 节点
2. 新建 `Environment` 资源：
   - Background → Mode: Color
   - Background → Color: 天蓝色 `#87CEEB`
   - Ambient Light → Color: `#404040`（暗面不会全黑）
   - Ambient Light → Energy: 0.3

- [ ] **Step 2: 调整方向光**

DirectionalLight3D：
- Rotation: (-45°, -45°, 0°)（从上方偏右）
- Energy: 0.8
- Shadow → Enabled: ON（可选，提升立体感）
- Color: `#FFFFFF`

- [ ] **Step 3: 验证**

运行，确认方块三个面有明显明暗对比：顶面最亮、左面中等、右面最暗。

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn
git commit -m "feat: 光照设置 — 环境光 + 方向光实现等距三面明暗"
```

---

### Task 6: 射线检测 & 方块交互 (RayCast Handler)

**Files:**
- Create: `scripts/raycast_handler.gd`

- [ ] **Step 1: 创建 raycast_handler.gd**

`scripts/raycast_handler.gd`:
```gdscript
extends Node3D

var mouse_pressed := false
var mouse_moved := false
var mouse_start_pos := Vector2.ZERO
const DRAG_THRESHOLD := 5.0

@onready var block_manager: Node3D = $"../Blocks"
@onready var highlight: MeshInstance3D = $"../SelectionHighlight"
@onready var camera: Camera3D = $"../CameraRig/Camera3D"

func _ready():
    highlight.visible = false

func _input(event):
    # 如果鼠标在 UI 上，不处理 3D 交互
    if _is_mouse_over_ui():
        highlight.visible = false
        return
    
    if event is InputEventMouseButton:
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
        
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _handle_right_click()
    
    if event is InputEventMouseMotion:
        if mouse_pressed:
            if event.position.distance_to(mouse_start_pos) > DRAG_THRESHOLD:
                mouse_moved = true
        # 更新选中高亮位置
        _update_highlight()

func _handle_left_click():
    var result = _raycast()
    if result:
        var grid_pos = _world_to_grid(result.position, result.normal)
        if grid_pos != null:
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
    # 根据法线方向偏移到相邻格子
    var place_pos = hit_pos + hit_normal * 0.5
    return Vector3i(round(place_pos.x), round(place_pos.y), round(place_pos.z))

func _update_highlight():
    var result = _raycast()
    if result:
        var grid_pos = _world_to_grid(result.position, result.normal)
        if grid_pos != null and block_manager.can_place_at(grid_pos):
            highlight.visible = true
            highlight.position = Vector3(grid_pos)
        else:
            highlight.visible = false
    else:
        highlight.visible = false

func _is_mouse_over_ui() -> bool:
    # 简易版：如果鼠标在底部 60px（物品栏区域），跳过
    var mouse_y = get_viewport().get_mouse_position().y
    var viewport_height = get_viewport().get_visible_rect().size.y
    return mouse_y > viewport_height - 60
```

- [ ] **Step 2: 创建选中高亮节点**

在 main.tscn 中添加 `MeshInstance3D` 子节点，命名为 "SelectionHighlight"：
- Mesh: BoxMesh (size 1.05, 1.05, 1.05)
- Material: StandardMaterial3D
  - Transparency: Alpha
  - Albedo Color: White, alpha 0.3
  - Shading Mode: Unshaded
  - Cull Mode: Disabled（线框模式或用 Emission 亮色）

- [ ] **Step 3: 添加 RayCastHandler 到主场景**

在 main.tscn 中添加 `Node3D` 子节点，命名为 "RayCastHandler"，挂载 `scripts/raycast_handler.gd`。

- [ ] **Step 4: 更新 main.gd**

`scripts/main.gd`:
```gdscript
extends Node3D

@onready var block_manager = $Blocks
@onready var raycast_handler = $RayCastHandler
```

- [ ] **Step 5: 验证**

运行：左键地面 → 放置方块；右键方块 → 删除；鼠标悬停空白格 → 高亮。

- [ ] **Step 6: Commit**

```bash
git add scripts/raycast_handler.gd scripts/main.gd scenes/main.tscn
git commit -m "feat: 射线交互 — 放置/删除/高亮预览"
```

---

### Task 7: UI — 物品栏 (Inventory Bar)

**Files:**
- Create: `scripts/inventory.gd`
- Modify: `scenes/main.tscn`

- [ ] **Step 1: 创建 inventory.gd**

`scripts/inventory.gd`:
```gdscript
extends Control

var inventory_colors: Array[Color] = []
var selected_slot := 0
const SLOT_COUNT := 10
var slot_buttons: Array[Button] = []

signal slot_selected(index: int)
signal slot_right_clicked(index: int)
signal color_changed(index: int, color: Color)

func _ready():
    inventory_colors.resize(SLOT_COUNT)
    # 默认颜色
    var defaults := [
        Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
        Color.ORANGE, Color.PURPLE, Color.CYAN, Color.WHITE,
        Color.BROWN, Color.PINK
    ]
    for i in SLOT_COUNT:
        inventory_colors[i] = defaults[i]
    
    _build_ui()

func _build_ui():
    var hbox := HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 4)
    add_child(hbox)
    
    # 居中
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_bottom = 1.0
    offset_bottom = -8
    offset_left = -SLOT_COUNT * 28
    
    for i in SLOT_COUNT:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(48, 48)
        btn.name = "Slot%d" % i
        _update_slot_style(btn, i)
        
        btn.pressed.connect(_on_slot_pressed.bind(i))
        btn.gui_input.connect(_on_slot_gui_input.bind(i))
        
        hbox.add_child(btn)
        slot_buttons.append(btn)
    
    _update_selection_highlight()

func _update_slot_style(btn: Button, index: int):
    var style := StyleBoxFlat.new()
    style.bg_color = inventory_colors[index]
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    
    # 方块缩略图效果：在小色块上加一个亮色小方块
    var inner := StyleBoxFlat.new()
    inner.bg_color = inventory_colors[index].lightened(0.3)
    inner.corner_radius_top_left = 2
    inner.corner_radius_top_right = 2
    
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_stylebox_override("hover", style)
    btn.add_theme_stylebox_override("pressed", style)

func _update_selection_highlight():
    for i in SLOT_COUNT:
        var btn = slot_buttons[i]
        if i == selected_slot:
            var sel := StyleBoxFlat.new()
            sel.bg_color = inventory_colors[i]
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
        else:
            _update_slot_style(btn, i)

func _on_slot_pressed(index: int):
    selected_slot = index
    _update_selection_highlight()
    slot_selected.emit(index)

func _on_slot_gui_input(event: InputEvent, index: int):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            slot_right_clicked.emit(index)

func set_slot_color(index: int, color: Color):
    inventory_colors[index] = color
    _update_slot_style(slot_buttons[index], index)
    if index == selected_slot:
        _update_selection_highlight()
    color_changed.emit(index, color)

func get_selected_color() -> Color:
    return inventory_colors[selected_slot]

func get_inventory_colors() -> Array[Color]:
    return inventory_colors
```

- [ ] **Step 2: 添加到主场景 UI**

在 main.tscn 中：
1. 添加 `CanvasLayer` 子节点，命名为 "UI"
2. 在其下添加 `Control`，命名为 "InventoryBar"
3. 挂载 `scripts/inventory.gd`
4. 调整 Control 的 anchors 使其在底部居中

- [ ] **Step 3: 验证**

运行，确认底部显示 10 个颜色格子，点击高亮金色边框。

- [ ] **Step 4: Commit**

```bash
git add scripts/inventory.gd scenes/main.tscn
git commit -m "feat: UI — 物品栏 10 格"
```

---

### Task 8: UI — 调色盘弹出面板 (Color Picker Popup)

**Files:**
- Create: `scripts/color_picker_popup.gd`

- [ ] **Step 1: 创建 color_picker_popup.gd**

`scripts/color_picker_popup.gd`:
```gdscript
extends PopupPanel

signal color_confirmed(color: Color)

var current_color := Color.RED

@onready var color_picker: ColorPicker = $VBox/ColorPicker
@onready var r_spin: SpinBox = $VBox/HBox/RSpin
@onready var g_spin: SpinBox = $VBox/HBox/GSpin
@onready var b_spin: SpinBox = $VBox/HBox/BSpin

func _ready():
    color_picker.color_changed.connect(_on_picker_changed)
    
    r_spin.value_changed.connect(_on_rgb_changed)
    g_spin.value_changed.connect(_on_rgb_changed)
    b_spin.value_changed.connect(_on_rgb_changed)
    
    $VBox/Confirm.pressed.connect(_on_confirm)
    $VBox/Cancel.pressed.connect(_on_cancel)
    
    # 关闭时
    popup_hide.connect(_on_cancel)

func open_with_color(color: Color):
    current_color = color
    color_picker.color = color
    _update_spinboxes(color)
    popup_centered()

func _on_picker_changed(c: Color):
    current_color = c
    _update_spinboxes(c)

func _on_rgb_changed(_val: float):
    var c := Color(r_spin.value / 255.0, g_spin.value / 255.0, b_spin.value / 255.0)
    current_color = c
    color_picker.color = c

func _update_spinboxes(c: Color):
    r_spin.value = int(c.r * 255)
    g_spin.value = int(c.g * 255)
    b_spin.value = int(c.b * 255)

func _on_confirm():
    color_confirmed.emit(current_color)
    hide()

func _on_cancel():
    hide()
```

- [ ] **Step 2: 创建调色盘场景**

创建 `scenes/ui/color_picker_popup.tscn`：
```
ColorPickerPopup (PopupPanel)
├── VBoxContainer
│   ├── ColorPicker
│   ├── HBoxContainer
│   │   ├── Label("R")
│   │   ├── RSpin (SpinBox, 0-255)
│   │   ├── Label("G")
│   │   ├── GSpin (SpinBox, 0-255)
│   │   ├── Label("B")
│   │   └── BSpin (SpinBox, 0-255)
│   ├── Confirm (Button, "确认")
│   └── Cancel (Button, "取消")
```

- [ ] **Step 3: 集成到主场景**

在 `scripts/main.gd` 中实例化并连接信号：
```gdscript
var color_picker_popup: PopupPanel

func _ready():
    color_picker_popup = preload("res://scenes/ui/color_picker_popup.tscn").instantiate()
    $UI.add_child(color_picker_popup)
    
    $UI/InventoryBar.slot_right_clicked.connect(_on_slot_right_clicked)
    color_picker_popup.color_confirmed.connect(_on_color_confirmed)

func _on_slot_right_clicked(index: int):
    var current = $UI/InventoryBar.inventory_colors[index]
    color_picker_popup.open_with_color(current)

func _on_color_confirmed(color: Color):
    var idx = $UI/InventoryBar.selected_slot
    $UI/InventoryBar.set_slot_color(idx, color)
    $Blocks.selected_color = color
```

- [ ] **Step 4: 验证**

运行：右键物品栏格子 → 弹出调色盘 → 选色 → 确认 → 格子颜色更新。

- [ ] **Step 5: Commit**

```bash
git add scripts/color_picker_popup.gd scenes/ui/color_picker_popup.tscn scripts/main.gd scenes/main.tscn
git commit -m "feat: UI — 调色盘 ColorPicker + RGB"
```

---

### Task 9: 存档系统 (Save/Load)

**Files:**
- Create: `scripts/save_manager.gd`

- [ ] **Step 1: 创建 save_manager.gd**

`scripts/save_manager.gd`:
```gdscript
extends Node

const SAVE_PATH := "user://save.json"

func save(block_manager, inventory_bar, ground_node):
    var data := {
        "version": 1,
        "blocks": [],
        "inventory": [],
        "ground_color": [0.85, 0.85, 0.85],
        "grid_color": [0.4, 0.4, 0.4]
    }
    
    # 方块数据
    for pos in block_manager.blocks:
        var b = block_manager.blocks[pos]
        data["blocks"].append({
            "x": pos.x, "y": pos.y, "z": pos.z,
            "color": [b["color"].r, b["color"].g, b["color"].b]
        })
    
    # 物品栏
    for c in inventory_bar.inventory_colors:
        data["inventory"].append([c.r, c.g, c.b])
    
    # 地面颜色
    if ground_node:
        data["ground_color"] = [ground_node.ground_color.r, ground_node.ground_color.g, ground_node.ground_color.b]
        data["grid_color"] = [ground_node.grid_color.r, ground_node.grid_color.g, ground_node.grid_color.b]
    
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        return true
    return false

func load(block_manager, inventory_bar, ground_node) -> bool:
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
    
    # 清空并重建方块
    block_manager.clear_all()
    for b in data.get("blocks", []):
        block_manager.place_block(
            Vector3i(b["x"], b["y"], b["z"]),
            Color(b["color"][0], b["color"][1], b["color"][2])
        )
    
    # 恢复物品栏
    var inv = data.get("inventory", [])
    for i in min(inv.size(), inventory_bar.SLOT_COUNT):
        var c = inv[i]
        inventory_bar.set_slot_color(i, Color(c[0], c[1], c[2]))
    
    # 恢复地面颜色
    if ground_node and data.has("ground_color"):
        var gc = data["ground_color"]
        var gridc = data["grid_color"]
        ground_node.update_colors(Color(gc[0], gc[1], gc[2]), Color(gridc[0], gridc[1], gridc[2]))
    
    return true
```

- [ ] **Step 2: 集成到主场景**

在 main.tscn 中添加 `Node` 子节点，命名为 "SaveManager"，挂载 `scripts/save_manager.gd`。

在 `scripts/main.gd` 中添加保存/加载方法：
```gdscript
func _on_save_pressed():
    $SaveManager.save($Blocks, $UI/InventoryBar, $Ground)

func _on_load_pressed():
    $SaveManager.load($Blocks, $UI/InventoryBar, $Ground)
```

- [ ] **Step 3: 创建顶部 UI 按钮**

在 UI CanvasLayer 中添加 HBoxContainer（右上角）：
- SaveButton → `_on_save_pressed()`
- LoadButton → `_on_load_pressed()`

- [ ] **Step 4: 验证**

运行 → 放置几个方块 → 保存 → 关闭 → 重新运行 → 加载 → 方块恢复。

- [ ] **Step 5: Commit**

```bash
git add scripts/save_manager.gd scripts/main.gd scenes/main.tscn
git commit -m "feat: 存档系统 — JSON 保存/加载"
```

---

### Task 10: 集成测试 & 收尾

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scenes/main.tscn`

- [ ] **Step 1: 最终版本 main.gd**

将所有信号连接整合到 main.gd，确保：
- 物品栏选择 → 更新 block_manager.selected_color
- 调色盘确认 → 更新物品栏颜色 + block_manager.selected_color
- 保存/加载按钮正常工作

- [ ] **Step 2: 全流程测试**

1. 启动 → 看到 100×100 地面 + 格线
2. 底部 10 格物品栏
3. 右键格子 → 调色盘 → 选色 → 确认
4. 左键格子选中 → 左键地面放置方块
5. 方向键旋转视角 → 看到方块三面明暗
6. 滚轮缩放
7. 中键拖拽平移
8. 右键方块删除
9. 保存 → 重开 → 加载 → 方块恢复

- [ ] **Step 3: Commit**

```bash
git add scripts/main.gd scenes/main.tscn
git commit -m "feat: 集成收尾 — 完整工作流验证"
```

---

### 附录：主场景节点树最终形态

```
Main (Node3D) [main.gd]
├── WorldEnvironment
├── DirectionalLight3D (rotation: -45, -45, 0)
├── CameraRig (Node3D) [camera_rig.gd]
│   └── Camera3D (orthogonal)
├── Ground (MeshInstance3D) [ground.gd]
├── Blocks (Node3D) [block_manager.gd]
├── SelectionHighlight (MeshInstance3D)
├── RayCastHandler (Node3D) [raycast_handler.gd]
├── SaveManager (Node) [save_manager.gd]
└── UI (CanvasLayer)
    ├── TopBar (HBoxContainer) → Save/Load/GroundColor 按钮
    ├── InventoryBar (Control) [inventory.gd]
    └── ColorPickerPopup (PopupPanel) [color_picker_popup.gd]
```
