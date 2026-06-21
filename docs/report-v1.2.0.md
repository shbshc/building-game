# Building Game v1.2.0 — 项目报告

> 日期：2026-07-18  
> 引擎：Godot 4.7 (GL Compatibility)  
> 语言：GDScript  
> 版本：v1.2.0

---

## 1. 项目概述

第一人称 3D 方块建筑游戏。玩家放置 42 种功能方块构建自动化机械装置，支持贴图绘制系统自定义方块外观。

---

## 2. 已实现功能

### 2.1 基础系统

| 系统 | 说明 |
|------|------|
| 地面 | 100×100 平面 + Shader 格线（细线 + 每 10 格粗线） |
| 移动 | WASD 移动、空格/Ctrl 升降、双击空格切换飞行/行走 |
| 视角 | 自由旋转、ESC 释放/捕获鼠标、滚轮切换物品栏 |
| 交互 | 左键放置（按住连续）、右键功能方块旋转方向 |
| 物品栏 | 10 格 Hotbar 底部居中、名字+颜色、金色选中边框 |
| 背包 | E 键 100 格可滚动背包（10 列）、创造模式 |
| 存档 | JSON v5 格式、支持贴图 PNG 保存/加载 |

### 2.2 方块系统（42 种）

| 类型 | 数量 | 颜色 | 行为 |
|------|:--:|------|------|
| 🧱 普通 | 6 | 灰棕绿黄半红 | 固定不动、可被推动 |
| 🔵 移动 | 6 | 蓝系 | 每 1s 向箭头方向移动 1 格（0.5s 平滑动画） |
| 🟢 拐弯 | 6 | 绿系 | 移动方块碰到后转向、不消失 |
| 🟣 生成器 | 6 | 紫系 | 每 1s 复制后方方块到前方 |
| 🟠 推动 | 6 | 橙系 | 被推时传递推力、推动前方整排 |
| 🩸 消耗 | 6 | 暗红 | 推入的方块被摧毁、消耗方块保留 |
| 🟢 粘液 | 6 | 亮绿 | 粘连 6 面邻居、被推动时整组移动 |

### 2.3 推动链系统

`slide_chain` 统一推动逻辑：
1. 沿方向扫描找到停止点（空格/普通方块/消耗方块）
2. 收集链上所有方块
3. BFS 扩展粘液邻居（仅粘液方块传播）
4. 检查所有目标位置
5. 原子瞬移全部方块

- 功能方块可被推动、普通方块不可推
- 消耗方块终止推动并摧毁推动者
- 移动方块不触发酵液组（只有推动方块能）

### 2.4 贴图绘制系统

| 功能 | 说明 |
|------|------|
| 入口 | 背包（E）→ 右键方块类型 → 绘图面板 |
| 面板 | 6 面选择预览 → 点击进入单面编辑 |
| 画布 | 320×320（16×16 像素、20 倍放大） |
| 画笔 | 1px / 2px / 4px，左键画、右键取色 |
| 调色板 | 24 种预设颜色 + 自定义取色器 |
| 工具 | Copy/Paste 跨面、Fill 填充、Clear |
| 保存 | Apply 自动保存到 `user://textures/` |
| 加载 | 打开同类型自动读取已有贴图 |
| 渲染 | 6-Surface 自定义立方体、每面独立纹理 |
| 抗锯齿 | TEXTURE_FILTER_NEAREST 保持像素锐利 |

---

## 3. 技术架构

### 3.1 文件结构

```
建筑/
├── scripts/
│   ├── main.gd                  # 主循环、tick、贴图管理
│   ├── functional_types.gd      # FuncType 枚举、方向向量
│   ├── item_types.gd            # 42 种物品定义
│   ├── block_manager.gd         # 方块数据、放置/移动/推动链/6面网格
│   ├── inventory_manager.gd     # Hotbar + Backpack
│   ├── inventory.gd             # Hotbar UI
│   ├── backpack_panel.gd        # Backpack UI（可滚动）
│   ├── paint_panel.gd           # 绘图面板（两面模式）
│   ├── raycast_handler.gd       # 射线交互
│   ├── camera_rig.gd            # FPS 移动 + 下落限速
│   ├── ground.gd                # 地面网格
│   └── save_manager.gd          # JSON v5 + PNG 贴图
├── scenes/
│   ├── main.tscn
│   └── ui/ (backpack, paint, color_picker, ground_color)
├── shaders/grid_ground.gdshader
├── docs/ (报告、计划、规格)
└── project.godot
```

### 3.2 核心数据流

```
main.gd (_process, 1s tick)
  ├── _tick_move_blocks()
  │     ├── get_slime_group → BFS 粘液连通
  │     ├── slide_chain → 推动链
  │     └── move_block → 单个移动 (Tween 0.5s)
  ├── _tick_generators() → 复制后方到前方
  └── 贴图管理 → _save/_load_item_textures

block_manager.gd
  ├── place_block → _build_cube_mesh (6 Surface)
  ├── move_block / remove_block
  ├── slide_chain (扫描 + BFS + 原子移动)
  └── get_slime_group (BFS 连通组件)
```

### 3.3 关键设计决策

| 决策 | 理由 |
|------|------|
| 自定义 6-Surface 立方体 | BoxMesh 不支持每面独立纹理 |
| CULL_DISABLED 双面渲染 | 避免面朝向反导致贴图看不见 |
| BFS 仅通过粘液方块 | 防止功能方块意外粘连 |
| 推动瞬移（无动画） | 避免动画时序导致方块卡死 |
| 移动方块保留 Tween | 单块视觉效果、不涉及复杂交互 |
| 贴图保存为 PNG | 持久化、跨会话复用 |
| 背包入口绘图面板 | 编辑物品模板、非单方块 |

---

## 4. 版本迭代

| 版本 | 日期 | 内容 |
|------|------|------|
| v1.0.0 | 2026-06 | 基础建筑 + 背包 + 存档 |
| v1.1.0 | 2026-07 | 42 种功能方块 + 推动链 + 粘液 |
| v1.2.0 | 2026-07 | 贴图绘制系统 + 6 面独立纹理 |

**总提交数**：80+ commits
