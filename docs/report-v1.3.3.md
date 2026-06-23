# v1.3.3 — 多存档 + 反转器 + 蓝图系统

> 日期：2026-07-19

---

## 新功能

### 多存档系统
- 从单一 `save.json` 升级为文件夹多槽系统（`user://saves/slot_XXXX/`）
- `save_manager.gd` 新增 `list_saves`、`create_save`、`delete_save`、`rename_save`
- 弹窗式存档面板：命名、覆盖、删除（`save_panel.gd`）
- 弹窗式读档面板：列表选择加载（`load_panel.gd`）
- 旧 `save.json` 自动迁移到 `slot_0001`

### 反转器 (NOT Gate)
- `functional_types.gd`：`NOT_GATE = 11`（粉色），带方向箭头（蓝色）
- 方向性：箭头后方 = 输入端，箭头前方 = 输出端
- 输入端有电 → 关闭；无电 → 当电源输出
- 右键旋转方向
- `power_system.gd` 两趟 BFS 防自激

### 蓝图系统
- `blueprint_tool.gd`：B 键进入蓝图模式，左键放置蓝线框（4³ 或 8³）
- 线框内搭方块后右键压缩 → 微缩物品入背包
- `blueprint_data.gd`：JSON 存储蓝图数据
- 取出蓝图物品：左键展开还原 / Shift+左键放置微缩 3D 模型
- 微缩模型：原建筑按比例缩成 1×1 方块内的 ArrayMesh

## 修改文件

| 文件 | 改动 |
|------|------|
| `scripts/save_manager.gd` | 重写：多槽 API + 文件夹存储 + 迁移 |
| `scripts/save_panel.gd` | 新建：保存面板 |
| `scripts/load_panel.gd` | 新建：加载面板 |
| `scripts/blueprint_tool.gd` | 新建：蓝图笔框选/压缩/展开/微缩 |
| `scripts/blueprint_data.gd` | 新建：蓝图 JSON 读写 |
| `scripts/functional_types.gd` | NOT_GATE=11 枚举 + 颜色 |
| `scripts/item_types.gd` | 新增 id 35 NOT Gate |
| `scripts/block_model.gd` | 新增 not_gate 模型 |
| `scripts/power_system.gd` | 两趟 BFS + NOT_GATE 条件电源 |
| `scripts/block_manager.gd` | NOT_GATE 方向指示器 + 蓝色箭头 + CULL_DISABLED + UNSHADED |
| `scripts/raycast_handler.gd` | NOT_GATE 右键旋转 + 蓝图模式拦截 |
| `scripts/main.gd` | 面板实例化 + B 键切换蓝图 + 纹理 per-face 注册 + atlas 导出 |
| `scripts/inventory_manager.gd` | 新增 NOT_GATE 物品 |
| `scripts/texture_atlas.gd` | 新增 export_atlas_png |
| `scenes/main.tscn` | 新增节点：BlockModel、ColorProvider、Sun(OmniLight)、BlueprintData、BlueprintTool、SavePanel、LoadPanel |
| `scenes/ui/save_panel.tscn` | 新建 |
| `scenes/ui/load_panel.tscn` | 新建 |
| `project.godot` | TextureAtlas AutoLoad |
