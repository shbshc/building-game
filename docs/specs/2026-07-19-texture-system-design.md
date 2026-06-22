# 纹理系统重构 — 设计文档

> 日期：2026-07-19  
> 引擎：Godot 4.7 (GL Compatibility)  
> 语言：GDScript  
> 状态：设计已批准

---

## 1. 概述

重构方块纹理系统，从「硬编码颜色 + 每方块独立材质」升级为「模型定义 + 全局图集 + 动态染色 + 纹理叠加 + 游戏内绘制」五位一体。同时为后续逻辑电路系统提供视觉基础。

---

## 2. 架构拆分

当前 `block_manager.gd`（463 行）职责过重。纹理相关逻辑全部拆出：

```
scripts/
├── block_manager.gd      → 方块增删/移动/碰撞/粘液（减负）
├── block_model.gd         ★ 新建：方块模型定义与解析
├── texture_atlas.gd       ★ 新建：全局纹理图集（AutoLoad）
├── color_provider.gd      ★ 新建：动态染色接口
├── paint_panel.gd         → 升级：像素画编辑器
├── functional_types.gd    → 不变
├── item_types.gd          → ItemType 增加 model_id 字段
└── ...
```

### 数据流

```
ItemType.model_id ──→ BlockModel (block_model.gd)
                           │
                           ├── texture refs ──→ TextureAtlas (texture_atlas.gd)
                           │                        │
                           ├── tint mask ────→ ColorProvider (color_provider.gd)
                           │                        │
                           └── overlay refs ─┘       │
                                                     ▼
                                            block_manager.gd
                                            _build_cube_mesh()
                                            (接收数据 → 生成 ArrayMesh)
```

### BlockData 扩展

```gdscript
class BlockData:
    var item_id: int
    var color: Color
    var node: MeshInstance3D
    var func_type: int
    var direction: int
    var powered: bool
    var switch_on: bool
    # 纹理系统新增
    var model_id: String
    var tint_values: Dictionary      # {"top": Color, ...}
    var custom_textures: Array       # 6 面玩家绘制覆盖
```

---

## 3. 方块模型定义 (`block_model.gd`)

### 3.1 父模型（3 种内置布局）

```gdscript
const PARENT_MODELS = {
    "cube_all": {
        "faces": {
            "top": "#all", "bottom": "#all",
            "front": "#all", "back": "#all",
            "left": "#all", "right": "#all"
        }
    },
    "cube_bottom_top": {
        "faces": {
            "top": "#top", "bottom": "#bottom",
            "front": "#side", "back": "#side",
            "left": "#side", "right": "#side"
        }
    },
    "cube_bottom_top_overlay": {
        "faces": {
            "top": "#top", "bottom": "#bottom",
            "front": "#side", "back": "#side",
            "left": "#side", "right": "#side"
        },
        "overlay_faces": {
            "front": "#overlay", "back": "#overlay",
            "left": "#overlay", "right": "#overlay"
        }
    }
}
```

### 3.2 方块模型定义

```gdscript
var block_models = {
    "stone": {
        "parent": "cube_all",
        "textures": { "all": "res://assets/textures/stone.png" }
    },
    "grass": {
        "parent": "cube_bottom_top",
        "textures": {
            "top": "res://assets/textures/grass_top.png",
            "bottom": "res://assets/textures/dirt.png",
            "side": "res://assets/textures/grass_side.png"
        },
        "tint_faces": ["top", "front", "back", "left", "right"]
    },
    "grass_overlay": {
        "parent": "cube_bottom_top_overlay",
        "textures": {
            "top": "res://assets/textures/grass_top.png",
            "bottom": "res://assets/textures/dirt.png",
            "side": "res://assets/textures/dirt.png",
            "overlay": "res://assets/textures/grass_side_overlay.png"
        },
        "tint_faces": ["top"]
    }
}
```

### 3.3 解析逻辑

1. 给定 `model_id` → 查 `block_models` 定义
2. 追踪 `parent` → 合并 `PARENT_MODELS` 的面布局
3. 将 `#变量` 替换为实际纹理路径
4. 输出：6 面纹理引用 + 染色面列表 + 叠加面列表

### 3.4 ItemType 改动

`item_types.gd` 中 `ItemType` 增加 `model_id: String` 字段。

---

## 4. 纹理图集 (`texture_atlas.gd`)

### 4.1 全局图集

- 一张 `2048×2048` `Image`，纹理统一 `16×16`
- 所有方块纹理拼入同一张图
- `texture_map: Dictionary<String, Rect2>` 记录每个纹理的 UV 区域

### 4.2 核心接口

```gdscript
func register_texture(key: String, path: String) -> Rect2
    # 将纹理加载并装箱到图集，返回 UV 区域
    # 已注册的纹理直接返回已有 UV

func update_slot(key: String, new_image: Image)
    # 在图集中原地覆盖像素，调用 atlas_texture.update()

func get_uv(key: String) -> Rect2
    # 查询纹理 UV
```

### 4.3 渲染合批

所有方块引用同一个 `atlas_texture`，仅 UV 坐标不同。Godot 渲染器自动合批，减少 draw call。

### 4.4 可编辑槽位

- **固定槽**：内置纹理，注册后不动
- **可编辑槽**：玩家绘制的纹理占的格子，位置固定，内容可被 `update_slot()` 原地覆盖
- 新建方块纹理：`register_texture()` 动态分配新格子
- 图集满时自动扩容（`2048 → 4096`）

---

## 5. 动态染色 (`color_provider.gd`)

### 5.1 原理

纹理不变，改 `StandardMaterial3D.albedo_color`。Godot 将纹理像素 × `albedo_color` 做乘法混合。

### 5.2 接口

```gdscript
func get_tint(block_data: BlockData, face: String) -> Color:
    return Color.WHITE  # 默认不染色
```

### 5.3 内置实现

| 实现 | 用途 |
|------|------|
| `FixedTintProvider` | 模型定义中写死的颜色 |
| `BiomeTintProvider` | 根据世界坐标查色板 |
| `SignalTintProvider` | 根据信号强度渐变（后续电路用） |

---

## 6. 纹理叠加 (Overlay)

### 6.1 实现方式

`ArrayMesh` 双 surface：

- Surface 0：底部纹理（不透明）
- Surface 1：覆盖纹理（半透明）

仅 `cube_bottom_top_overlay` 父模型产生双 surface。两个 surface 的纹理都来自同一张图集。

### 6.2 触发条件

`block_model.gd` 解析后检测 `overlay_faces` 非空 → `_build_cube_mesh` 生成两个 `SurfaceTool.commit()`。

---

## 7. 游戏内画板升级 (`paint_panel.gd`)

### 7.1 改动清单

| 现有 | 升级 |
|------|------|
| 6 面独立选择 | 不变 |
| 16×16 画布 | 加 32×32 缩放选项 |
| 手动保存 | 自动备份 + "恢复默认"按钮 |
| 无预览 | 3D 实时预览（方块旋转） |
| 应用到单个方块 | 应用到同 model_id 的所有方块 |

### 7.2 保存流程

- 保存：`user://textures/{model_id}_{face}.png`
- 备份：每次保存前自动生成 `{model_id}_{face}_backup_{n}.png`
- 恢复默认：删除自定义文件 → `update_slot()` 重 blit 内置纹理

### 7.3 实时更新

画板确认 → `TextureAtlas.update_slot()` → `atlas_texture.update(atlas_image)` → GPU 刷新 → 场上所有同款方块瞬间更新，无需重建 mesh。

---

## 8. 文件结构

```
scripts/
├── block_model.gd           ★ 新建
├── texture_atlas.gd          ★ 新建（AutoLoad）
├── color_provider.gd         ★ 新建
├── block_manager.gd          → 修改（删纹理逻辑）
├── item_types.gd             → 修改（加 model_id）
├── paint_panel.gd            → 修改（升级编辑器）
├── main.gd                   → 修改（适配新接口）
└── inventory_manager.gd      → 不变

assets/textures/block/        ★ 新建：内置纹理 PNG
user://textures/              → 已有：玩家绘制的纹理
```

---

## 9. 实施顺序

| 阶段 | 内容 | 依赖 |
|------|------|------|
| 1 | `block_model.gd` 新建 + `item_types.gd` 改 model_id | 无 |
| 2 | `texture_atlas.gd` AutoLoad + `block_manager.gd` 重构 | 阶段 1 |
| 3 | 所有内置纹理放入 `assets/textures/block/`，注册到图集 | 阶段 2 |
| 4 | `color_provider.gd` + 染色集成 | 阶段 2 |
| 5 | 叠加纹理支持（双 surface） | 阶段 2 |
| 6 | `paint_panel.gd` 升级 + 图集联动 | 阶段 3 |

---

## 10. 验收标准

1. 草方块顶面绿色、底面棕色、侧面草覆盖层，各面纹理不同
2. 放置 100 个不同纹理方块，帧率 ≥ 60fps
3. 玩家用画板改草顶贴图 → 场上所有草方块即时更新
4. 恢复默认 → 草顶回到原始贴图
5. 染色方块在不同位置显示不同颜色
6. 叠加方块侧面同时显示底图和覆盖层
