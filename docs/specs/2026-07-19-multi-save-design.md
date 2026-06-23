# 多存档系统 — 设计文档

> 日期：2026-07-19  
> 引擎：Godot 4.7 (GL Compatibility)  
> 语言：GDScript

---

## 1. 概述

从单一 `save.json` 升级为动态多存档系统：支持任意数量存档槽，自定义命名，弹窗面板管理，文件夹存储。

---

## 2. 存储结构

```
user://saves/
├── index.json              # 槽位列表
├── slot_0001/
│   └── data.json           # 全量快照
├── slot_0002/
│   └── data.json
└── ...
```

### 2.1 `index.json`（轻量索引）

```json
[
  {"id": 1, "name": "我的世界", "created_at": "2026-07-19 14:30", "updated_at": "2026-07-19 15:00"},
  {"id": 2, "name": "测试存档", "created_at": "2026-07-18 10:00", "updated_at": "2026-07-18 12:00"}
]
```

- 启动时读取，生成存档列表
- 保存/删除时更新

### 2.2 `slot_XXXX/data.json`（全量快照）

```json
{
  "version": 5,
  "blocks": [{"x":3,"y":0,"z":5,"item_id":0,"func_type":0,"direction":2,"model_id":"stone"}],
  "inventory": [{"item_id":0, "count":64}, ...],
  "ground_color": [0.85, 0.85, 0.85],
  "grid_color": [0.4, 0.4, 0.4],
  "player_position": [50.0, 20.0, 50.0],
  "player_rotation": [0.0, 0.0, 0.0]
}
```

- 与现有 v5 格式兼容，新增 `player_position`、`player_rotation` 两个可选字段
- 加载时如果缺失，回退到默认位置

### 2.3 自增 ID 机制

- 新建存档：读取 `index.json`，取最大 ID + 1
- 删除存档：从 `index.json` 移除条目，删除对应文件夹
- ID 不重新编号，保证文件夹名永久唯一

---

## 3. UI 设计

### 3.1 保存面板 `SavePanel`

```
┌──────────────────────────────────┐
│  Save Game                 [✕]  │
├──────────────────────────────────┤
│  存档名称: [_______________]     │
│                                  │
│  ┌──────────────────────────┐   │
│  │ Slot 1: 我的世界    6/19 │ 🗑 │
│  │ Slot 2: 测试存档    6/18 │ 🗑 │
│  │ Slot 3: (空)            │ + │
│  │ ...                       │   │
│  └──────────────────────────┘   │
│              [新建存档]          │
└──────────────────────────────────┘
```

- 顶栏输入框绑定当前选中槽位的名称
- 列表 `ScrollContainer`，每行存档条
- 已有存档：点击 = 覆盖保存（先弹确认 "Overwrite?"）
- 空槽：点击 = 新建存档
- 🗑 按钮 → 删除确认 → 执行
- 底部 `新建存档` 按钮

### 3.2 加载面板 `LoadPanel`

```
┌──────────────────────────────────┐
│  Load Game                 [✕]  │
├──────────────────────────────────┤
│  ┌──────────────────────────┐   │
│  │ 我的世界           6/19  │   │
│  │ 测试存档           6/18  │   │
│  │ (空)                     │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
```

- 无命名输入框
- 点击已有存档 → 确认弹窗 "Load this save? Current progress will be lost." → 加载
- 空槽不可点击
- 🗑 按钮同上

---

## 4. 脚本设计

### 4.1 `save_manager.gd` 改动

| 函数 | 改动 |
|------|------|
| `list_saves() → Array` | ★ 新建：读取 `index.json` 返回槽位列表 |
| `save(slot_id, name, ...)` | 改动：增加 slot_id 和 name 参数，写入 `slot_XXXX/data.json`，更新 index |
| `load(slot_id, ...)` | 改动：增加 slot_id 参数，从 `slot_XXXX/data.json` 读取 |
| `delete_save(slot_id)` | ★ 新建：删除文件夹 + 从 index 移除 |
| `create_save(name) → int` | ★ 新建：分配新 ID，写空 data.json，返回 slot_id |

### 4.2 新文件

| 文件 | 说明 |
|------|------|
| `scenes/ui/save_panel.tscn` | 保存面板场景 |
| `scripts/save_panel.gd` | 保存面板逻辑 |
| `scenes/ui/load_panel.tscn` | 加载面板场景 |
| `scripts/load_panel.gd` | 加载面板逻辑 |

### 4.3 `main.gd` 改动

- 替换 `_on_save_pressed()` → 弹出 `SavePanel`
- 替换 `_on_load_pressed()` → 弹出 `LoadPanel`
- `_ready()` 中实例化 SavePanel 和 LoadPanel

---

## 5. 兼容性

- 首次启动时 `user://saves/` 不存在 → 自动创建目录，迁移旧 `user://save.json` 到 `slot_0001/data.json`
- 旧存档格式（v1-v4）由现有 `save_manager.gd` 的 load 逻辑兼容
- `player_position`/`player_rotation` 缺失 → 使用 camera_rig 当前默认位置

---

## 6. 实施顺序

| 阶段 | 内容 |
|------|------|
| 1 | `save_manager.gd` 扩展（多槽 API） |
| 2 | `save_panel.gd` + `save_panel.tscn` |
| 3 | `load_panel.gd` + `load_panel.tscn` |
| 4 | `main.gd` 对接面板，旧存档迁移 |

---

## 7. 验收标准

1. 打开 Save 面板 → 显示已有存档列表
2. 新建存档 → 命名 → 保存 → 列表中可见
3. 覆盖已有存档 → 确认弹窗 → 数据更新
4. 删除存档 → 确认弹窗 → 槽位消失
5. 打开 Load 面板 → 选择存档 → 加载 → 方块/物品/玩家位置恢复
6. 旧 save.json 自动迁移到 slot_0001
