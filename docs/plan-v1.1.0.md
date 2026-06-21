# v1.1.0 实施计划 — 功能方块系统 Phase 1

> 日期：2026-07-18  
> 对应报告：report-v1.1.0.md

---

## 设计讨论

基于初版建筑游戏（v1.0.0，等距→第一人称 3D 建造），用户提出新增**功能方块系统**。

核心需求：
- 方块有方向性（6 个面）
- 能源方块激活其他方块
- 移动方块、拐弯方块、活塞、复制、粘着等特殊行为
- 信号链传播

经过 brainstorming，确定的 Phase 1 范围：
- 方向系统（6 轴 Vector3i）
- 能源方块（持续 + 脉冲）
- 移动方块
- 拐弯方块
- 激活信号链

---

## 架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 信号传播 | 信号链传播（A 方案） | 直观、易调试 |
| 防循环 | 方向约束 + 激活 ID | 双重保险 |
| 活塞推力 | 推全部 + 边界停止 | 符合直觉 |
| 方向设定 | 放置后可改方向 | 灵活 |
| 实施顺序 | 分 3 阶段 | 降低风险 |

---

## 实施内容

### 新增文件
- `scripts/functional_types.gd` — 方向枚举、FuncType、辅助函数
- `scripts/activation_system.gd` — 信号传播引擎

### 修改文件
- `scripts/block_manager.gd` — BlockData 类、方向指示器、move_block
- `scripts/item_types.gd` — 4 种功能方块类型
- `scripts/raycast_handler.gd` — 放置/激活/旋转
- `scripts/main.gd` — tick 循环集成

### 方块新增
- Energy Continuous（持续能源）
- Energy Pulse（脉冲能源）
- Move（移动方块）
- Turn（拐弯方块）

---

## 后续迭代

Phase 1 完成后进入 Phase 2（推动方块、粘液方块）和 Phase 3（复制方块 + 打磨）。

但在实际使用中发现能源系统过于复杂，用户反馈后简化——去掉能源、信号链，改为移动方块自走。详见 v1.2.0 计划。
