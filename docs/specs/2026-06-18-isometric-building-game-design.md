# 等距视角建筑游戏 — 设计文档

> 日期：2026-06-18  
> 引擎：Godot 4.7 (GL Compatibility)  
> 语言：GDScript

---

## 1. 概述

一款等距视角的方块建筑游戏。玩家从底部物品栏选择彩色方块，在 100×100 的地面上搭建建筑。支持视角旋转、缩放、平移。方块可放置于地面或其他方块的侧面/顶面，右键删除。

---

## 2. 技术方案

方案 A：手动 3D 网格体素

- 每个方块 = MeshInstance3D + BoxMesh（1×1×1）
- 每方块一个 StandardMaterial3D，通过 albedo_color 动态改色
- 地面 = 大平面 PlaneMesh + 自定义 shader 绘制格线
- 光源 = DirectionalLight3D（从上偏右），引擎自动产生面间明暗
- 射线检测 = RayCast3D 跟随鼠标，计算落点网格坐标
- 方块容器 = Node3D，管理所有已放置方块的增删

## 3. 场景架构

Main (Node3D)
├── WorldEnvironment              
├── DirectionalLight3D            
├── CameraRig (Node3D)            
│   └── Camera3D (正交投影, 等距角度)
├── Ground (MeshInstance3D)       
│   └── StaticBody3D + CollisionShape3D
├── Blocks (Node3D)               
│   └── Block (MeshInstance3D + StaticBody3D) × N
├── SelectionHighlight (MeshInstance3D)
└── UI (CanvasLayer)
    ├── TopBar → [Save][Load][GroundColor]
    ├── InventoryBar (10 slots)
    └── ColorPickerPopup

## 4. 方块系统

### 4.1 外观
- 1×1×1 立方体，DirectionalLight3D 产生自然明暗：顶面=最亮, 左面=中等, 右面=最暗

### 4.2 数据结构
```gdscript
var blocks := {}          # Dictionary: Vector3i -> Color
var inventory := []        # Array[Color], 10 elements
var selected_slot := 0     # int
```

### 4.3 放置规则
- 只能放在已有方块顶面或侧面（包括地面），不能悬空
- 坐标对齐到整数 Vector3i

### 4.4 选中高亮
- 半透明 BoxMesh，尺寸 1.05，跟随鼠标落点

## 5. 地面网格
- 100×100 单位，中心在原点
- 地面色默认 #D9D9D9，格线色默认 #666666，均可配置
- PlaneMesh + ShaderMaterial 用 fract() 画格线

## 6. 摄像机 & 操作

| 操作 | 输入 | 行为 |
|------|------|------|
| 选择方块 | 左键物品栏格子 | selected_slot = index |
| 调色盘 | 右键物品栏格子 | 弹出 ColorPicker + RGB 面板 |
| 放置方块 | 左键点击(无拖拽) | RayCast 落点放置 |
| 删除方块 | 右键已有方块 | 移除 |
| 旋转视角 | ← → | 平滑旋转到下一个 90°(Tween 0.3s) |
| 俯仰 | ↑ ↓ | 俯角 ±5°(10°~60°) |
| 平移 | 左键拖拽(>5px) | 水平移动 CameraRig |
| 缩放 | 滚轮 | 调整正交 size(5~40) |
| 保存/加载 | 按钮 | JSON 到 user://save.json |

## 7. UI
- 物品栏：底部居中10格，选中金色边框，左键选/右键调色盘
- 调色盘弹窗：ColorPicker + R/G/B SpinBox(0-255) + 确认/取消
- 顶栏：[保存][加载][地面颜色]，地面颜色弹出面板

## 8. 存档（JSON）

```json
{
  "version": 1,
  "blocks": [{"x":3,"y":0,"z":5,"color":[1.0,0.2,0.2]}],
  "inventory": [[1.0,0.2,0.2],...],
  "ground_color": [0.85,0.85,0.85],
  "grid_color": [0.4,0.4,0.4]
}
```
路径：user://save.json

## 9. 文件结构
```
建筑/
├── scenes/main.tscn, ui/inventory_slot.tscn, ui/color_picker_popup.tscn
├── scripts/main.gd, camera_rig.gd, block_manager.gd, ground.gd, inventory.gd, color_picker_popup.gd, save_manager.gd, raycast_handler.gd
├── shaders/grid_ground.gdshader
└── docs/specs/2026-06-18-isometric-building-game-design.md
```

## 10. 未决
- 地面无限扩展(预留)
- 不同形状方块(预留)
- Undo/Redo(不在本期)
- 音效(不在本期)
