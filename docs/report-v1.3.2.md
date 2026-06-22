# v1.3.2 纹理系统重构 — 改动报告

> 日期：2026-07-19  
> 标签：v1.3.2

---

## 新增文件

| 文件 | 说明 |
|------|------|
| `scripts/block_model.gd` | 方块模型定义（21 模型 / 3 父模型），支持父模型继承、纹理变量替换、叠加面、染色面 |
| `scripts/texture_atlas.gd` | 全局纹理图集 AutoLoad（2048×2048），装箱算法，UV 查询，in-place 槽位更新 |
| `scripts/color_provider.gd` | 动态染色接口 + FixedTint/BiomeTint/SignalTint 三种内置实现 |

## 修改文件

| 文件 | 改动 |
|------|------|
| `scripts/block_manager.gd` | 重构：去除 `_make_atlas()`、旧 `_build_cube_mesh()`，新增 `_build_cube_mesh_from_atlas()`，使用模型系统 + 图集 UV。BlockData 增加 `model_id`、`custom_textures`。修复 6 面法线朝向 |
| `scripts/item_types.gd` | `ItemType` 增加 `model_id` 字段，35 种物品全部赋值，新增 `get_model_id()` 辅助函数 |
| `scripts/main.gd` | 启动时注册 20×6=120 个逐面纹理到图集。画板联动改为模型 face key。去除 `_item_textures` 字典 |
| `scripts/paint_panel.gd` | 完全重写：立方体展开图布局，6 面同屏编辑，共享 key 的面引用同一 Image，激活面金色高亮，Copy/Paste/Fill/Reset 按激活面操作。调色板 + 系统取色器 |
| `scripts/save_manager.gd` | 存档格式增加 `model_id`。加载时从 PNG 恢复纹理并推送至图集 |
| `scenes/main.tscn` | 新增 `BlockModel`、`ColorProvider` 节点，load_steps 14→16 |
| `scenes/ui/paint_panel.tscn` | 重写：单一画布 512×384，立方体展开图布局，去掉面选择视图 |
| `project.godot` | 新增 `TextureAtlas` AutoLoad |

## 删除

- `block_manager.gd` 中 `_make_atlas()` 函数
- `block_manager.gd` 中旧 `_build_cube_mesh()` 函数
- `main.gd` 中 `_item_textures` 字典和 `get_item_textures()` 函数
- `docs/plan-v1.4.0.md`（旧版计划，被新纹理系统设计替代）

## 架构

```
ItemType.model_id → BlockModel.resolve() → face_keys
                                                 │
                                          TextureAtlas (AutoLoad)
                                                 │
                                          block_manager._build_cube_mesh_from_atlas()
                                                 │
                                          ColorProvider (预留, Task 5)
```

- 全局图集：所有方块共享一张 2048×2048 ImageTexture，Godot 自动合批
- 模型系统：`cube_all`（6面独立key）、`cube_bottom_top`（顶/底/侧）、`cube_bottom_top_overlay`（叠加层）
- 画板：展开图 4×3 网格，编辑直接覆写图集槽位 → 场上同款方块即时更新
