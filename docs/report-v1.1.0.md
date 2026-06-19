# Building Game v1.1.0 — 项目报告

> 日期：2026-07-18  
> 引擎：Godot 4.7 (GL Compatibility)  
> 语言：GDScript  
> 版本：v1.1.0

---

## 1. 项目概述

一款第一人称 3D 方块建筑游戏，支持多种功能方块和物理交互。玩家从物品栏选择方块，在 100×100 的地面上搭建结构。核心特色是**功能方块系统**——不同方块具有独特行为，可组合创造自动化装置。

---

## 2. 已实现功能

### 2.1 基础系统

| 系统 | 说明 |
|------|------|
| 地面网格 | 100×100 平面 + Shader 格线（细线 + 每 10 格粗线） |
| 第一人称移动 | WASD 移动、空格/Ctrl 升降、双击空格切换飞行/行走 |
| 鼠标视角 | 自由旋转，ESC 释放/捕获鼠标，滚轮切换物品栏 |
| 方块放置/拆除 | 左键放置（按住连续）、右键普通方块拆除 |
| 物品栏 | 10 格 Hotbar 底部居中，显示名字+颜色，金色选中边框 |
| 背包系统 | E 键打开 100 格可滚动背包（10 列） |
| 存档 | JSON v4 格式，保存方块类型/功能类型/方向 |
| 创造模式 | 点击选中不消耗物品 |

### 2.2 方块系统（42 种）

#### 🧱 普通方块（6 种）
Stone、Wood、Grass、Sand、Glass、Brick —— 基础建筑方块，可推动，不可自移。

#### 🔵 移动方块（6 种）
Move+X/-X/+Y/-Y/+Z/-Z —— 每 1 秒向箭头方向移动 1 格，0.5 秒平滑动画。作为自动轨道的动力源。

#### 🟢 拐弯方块（6 种）
Turn+X/-X/+Y/-Y/+Z/-Z —— 移动方块碰到后改变方向，拐弯方块不消失。

#### 🟣 生成器方块（6 种）
Gen+X/-X/+Y/-Y/+Z/-Z —— 每 1 秒将箭头后方方块复制到箭头前方。

#### 🟠 推动方块（6 种）
Push+X/-X/+Y/-Y/+Z/-Z —— 被移动方块推入时，将前方整排方块推动。支持链式推动。

#### 🩸 消耗方块（6 种）
Consume+X/-X/+Y/-Y/+Z/-Z —— 任何方块推入时该方块消失，消耗方块保留。

#### 🟢 粘液方块（6 种）
Slime+X/-X/+Y/-Y/+Z/-Z —— 与相邻方块粘连。被推动时整组一起移动。BFS 算法查找连通组件。

### 2.3 推动链系统

`slide_chain` 统一处理所有推动逻辑：

```
1. 沿方向扫描找到停止点（空格/消耗方块/边界）
2. 收集链上所有方块
3. BFS 扩展粘液邻居
4. 检查所有目标位置
5. 原子瞬移全部方块
```

- 所有方块均可被推动
- 粘液组自动扩展开来
- 消耗方块终止推动并摧毁推动者

---

## 3. 技术架构

### 3.1 文件结构

```
建筑/
├── scripts/
│   ├── main.gd                  # 主场景、tick 循环、交互入口
│   ├── functional_types.gd      # FuncType 枚举、方向向量、颜色
│   ├── item_types.gd            # ItemType/ItemSlot 类、42 种物品
│   ├── block_manager.gd         # BlockData 类、放置/删除/移动/推动链
│   ├── inventory_manager.gd     # Hotbar + Backpack 数据管理
│   ├── inventory.gd             # Hotbar UI
│   ├── backpack_panel.gd        # Backpack UI（可滚动）
│   ├── raycast_handler.gd       # 射线检测、放置/拆除/旋转
│   ├── camera_rig.gd            # 第一人称移动 + 视角
│   ├── ground.gd                # 地面网格
│   ├── save_manager.gd          # JSON 存档 v4
│   ├── color_picker_popup.gd    # 颜色选择器
│   └── ground_color_picker.gd   # 地面颜色
├── scenes/
│   ├── main.tscn
│   └── ui/
│       ├── backpack_panel.tscn
│       ├── color_picker_popup.tscn
│       └── ground_color_popup.tscn
├── shaders/
│   └── grid_ground.gdshader
├── docs/
│   ├── specs/   # 设计文档
│   └── plans/   # 实施计划
└── project.godot
```

### 3.2 核心数据流

```
main.gd (_process, 1s tick)
  ├── _tick_move_blocks()
  │     ├── get_slime_group(pos) → BFS 找粘液组
  │     ├── slide_chain(pos, dir) → 推动链
  │     └── move_block(pos, new_pos) → 单个移动 (Tween)
  └── _tick_generators()
        └── 生成器：后方 → 前方复制

block_manager.gd
  ├── place_block / remove_block / move_block
  ├── slide_chain (推动链 + 粘液 BFS)
  ├── get_slime_group (BFS 连通组件)
  └── set_block_direction / can_place_at
```

### 3.3 关键设计决策

| 决策 | 理由 |
|------|------|
| 第一人称而非等距 | 更直观的建造体验 |
| 瞬间推动（无动画） | 避免动画时序导致方块卡死 |
| 移动方块保留 Tween | 单个移动视觉效果好，不涉及复杂交互 |
| BFS 粘液扩展 | 正确处理任意拓扑的粘液网络 |
| 方块数据用 BlockData 类 | 清晰封装 func_type + direction |
| 存档 v4 JSON | 兼容旧版，保存功能类型和方向 |

---

## 4. 已知问题 & 后续方向

### 4.1 已知限制
- 推动链中粘液组扩展可能导致意外的大型移动
- 无 Undo/Redo
- 无音效
- 无多人联机
- 移动方块只有 1 秒固定速度

### 4.2 后续可能方向
- 可配置移动速度
- 红石式逻辑方块（与/或/非门）
- 传感器方块（检测前方方块类型）
- 蓝图复制粘贴
- 地形编辑
- UI 美化 & 设置菜单

---

## 5. 提交历史概要

| 阶段 | 提交数 | 主要内容 |
|------|:--:|------|
| 基础搭建 | 10 | 地面、相机、方块、UI、存档 |
| 背包系统 | 6 | 物品类型、物品栏、背包面板 |
| 功能方块 Phase 1 | 13 | 方向系统、移动、拐弯、生成器、推动、消耗、粘液 |
| 修复迭代 | 15+ | 创造模式、背包扩容、推动链修复、动画调试 |
| **合计** | **44+** | **v1.1.0** |
