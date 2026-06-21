# v1.3.0 实施计划 — 电力系统

> 日期：2026-07-18  
> 对应报告：report-v1.3.0.md

---

## 设计讨论

用户提出电力系统需求："电源、电路、灯泡、开关"——不做红石式复杂信号，做**连通性检测**，复用现有 BFS 能力。

### 核心设计

**原理**：电源通电 → BFS 沿导线蔓延 → 灯泡收到电就亮

| 方块 | 行为 |
|------|------|
| Power（电源） | 始终输出电力 |
| Switch（开关） | 右键切换 ON/OFF，ON 时导电 |
| Wire（导线） | 传递电力，带电变亮黄发光 |
| Lamp（灯泡） | 带电变亮白发光 |

---

## 架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 电力传播 | BFS（复用粘液推动链思路） | 代码复用 |
| 更新时机 | 每 tick | 支持动态电路 |
| 开关默认 | ON | 放下来就通电 |
| 开关交互 | 右键切换 | 直观 |
| 电力距离 | 无限制 | 用户反馈 15 格不够 |
| 导线外观 | 小方块(0.2) + 连接梁(0.05) | 折线视觉效果 |
| 方块方向 | 电路方块无方向 | 简化 |
| 渲染方式 | BoxMesh + material_override | 支持发光切换 |

---

## 技术实现

### BFS 电力蔓延（power_system.gd）
```
1. 清除所有方块 powered 状态
2. 找到所有 POWER 方块 → 加入队列
3. BFS：Wire/Lamp/ON-Switch 导电 → 标记 powered
4. _update_powered_visuals：切换材质颜色和 emission
```

### 导线连接线（_build_wire_mesh）
- 中心 0.2 小方块
- 检测 6 个邻居，有相邻导线→生成 0.05 连接梁
- 6 方向旋转用 match 语句修正（之前 ±X/±Z 方向全错）
- 放置/拆除时调用 `_refresh_adjacent_wires` 刷新邻居

### 渲染修复
- 6-Surface 自定义立方体：移除 CULL_DISABLED（导致方块透明）
- 无贴图方块用 BoxMesh（不透明正常）
- 电路方块用 BoxMesh + material_override（支持 emission 发光）

---

## 关键 bug 修复

| bug | 原因 | 修复 |
|-----|------|------|
| 右键全失效 | `_get_grid_from_collider` 拿到 CollisionShape3D 位置 | 逐级跳到 MeshInstance3D |
| 开关变成电源 | BFS 把 ON 开关当起点 | 只从 POWER 方块开始 BFS |
| 开关 OFF 还能导电 | 导电判断未检查 switch_on | 加 `switch_on == true` 检查 |
| 导线连接方向错 | ±X/±Z 旋转公式全错 | match 语句逐方向写 |
| 电路方块带箭头 | `func_type > 0` 全加指示器 | 排除 `>= POWER` 的类型 |

---

## 后续方向

电力系统基础搭建完成。v1.4.0 可考虑：粒子效果、音效、功率衰减、传感器方块等。
