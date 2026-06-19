# Backpack & Item System Design

> Date: 2026-06-18
> Engine: Godot 4.7 (GL Compatibility)
> Language: GDScript

## 1. Overview

Minecraft-style inventory system: item types with stacking, 10-slot hotbar, 27-slot backpack (3x9), pick-up/place via click, drag to move, tooltip on hover.

## 2. Data Structures

### ItemType (resource)

```gdscript
class ItemType:
    var id: int
    var name: String
    var color: Color
    var max_stack: int = 64
```

### ItemSlot

```gdscript
class ItemSlot:
    var item_id: int = -1   # -1 = empty
    var count: int = 0
```

### Initial Item Types (6)

| ID | Name | Color | Max Stack |
|----|------|-------|-----------|
| 0 | Stone | #808080 | 64 |
| 1 | Wood | #8B4513 | 64 |
| 2 | Grass | #4CAF50 | 64 |
| 3 | Sand | #F4D03F | 64 |
| 4 | Glass | #D5DBDB (50% alpha) | 64 |
| 5 | Brick | #C0392B | 64 |

### Holder

```gdscript
var hotbar: Array[ItemSlot]      # 10 slots
var backpack: Array[ItemSlot]    # 27 slots
var held_item: ItemSlot          # item being carried by cursor (null if none)
```

## 3. UI Layout

```
+--------------------------------------------------+
| [Save][Load][Ground]                              |
|                                                   |
|             3D Game Viewport                      |
|                                                   |
|   +-- Backpack Panel (E to toggle) ------------+  |
|   |  +---+---+---+---+---+---+---+---+---+     |  |
|   |  |   |   |   |   |   |   |   |   |   |     |  |
|   |  +---+---+---+---+---+---+---+---+---+     |  |
|   |  |   |   |   |   |   |   |   |   |   |     |  |
|   |  +---+---+---+---+---+---+---+---+---+     |  |
|   |  |   |   |   |   |   |   |   |   |   |     |  |
|   |  +---+---+---+---+---+---+---+---+---+     |  |
|   |                                            |  |
|   |  [Tooltip: item name on hover]             |  |
|   +--------------------------------------------+  |
+--------------------------------------------------+
| +---+---+---+---+---+---+---+---+---+---+        |
| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |       |
| +---+---+---+---+---+---+---+---+---+---+        |
|          Hotbar (always visible)                  |
+--------------------------------------------------+
```

## 4. Interaction

| Action | Input | Behavior |
|--------|-------|----------|
| Open/close backpack | E | Toggle backpack panel. Open = release mouse, close = capture mouse |
| Release mouse | ESC or B | Release cursor (backpack stays closed) |
| Pick up item | Left-click slot | Takes all items from slot into held_item |
| Place item | Left-click slot (holding item) | Places held_item into slot (stacks if same type) |
| Place single | Right-click slot (holding item) | Places ONE item into slot |
| Pick up half | Right-click slot (empty hand) | Takes half the stack (ceil) |
| Drag move | Mouse drag slot | Moves items between slots (same as click-click) |
| Switch hotbar | Scroll wheel | Cycle selected hotbar slot |
| Place block | Left-click (game world) | Place block of selected hotbar item type |
| Delete block | Right-click (game world) | Remove block (no item return for now) |
| Color picker | Right-click hotbar slot (no held item) | Open color popup for colored blocks |
| Tooltip | Mouse hover slot | Show item name + count |

## 5. Slot Behavior Rules

- Empty slot: left-click = pick up (if slot has items)
- Holding item + empty slot: left-click = place all
- Holding item + same-type slot: left-click = add to stack (up to max_stack)
- Holding item + different-type slot: left-click = swap
- Holding item + same slot: left-click = put back all
- Right-click with held item: place ONE item
- Right-click without held item: pick up HALF (ceil)

## 6. Key Changes

| Old | New |
|-----|-----|
| E not used | E = backpack toggle |
| B = toggle mouse | B/ESC = release mouse only |
| inventory.gd (color-only) | Rewrite as full item inventory system |
| block_manager selected_color | block_manager selected_item_id |

## 7. File Changes

- NEW: `scripts/item_types.gd` ！ ItemType class + default type definitions
- REWRITE: `scripts/inventory.gd` ！ Full item slot system
- NEW: `scenes/ui/backpack_panel.tscn` ！ Backpack grid UI
- NEW: `scripts/backpack_panel.gd` ！ Backpack logic
- MODIFY: `scripts/main.gd` ！ Add backpack toggle, E key handling
- MODIFY: `scripts/block_manager.gd` ！ Use item_id instead of color directly
- MODIFY: `scripts/camera_rig.gd` ！ E opens backpack instead of B toggle
- MODIFY: `scripts/raycast_handler.gd` ！ Place blocks by item_id
- MODIFY: `project.godot` ！ Add backpack input action
