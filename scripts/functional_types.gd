extends Node
# functional_types.gd — 功能方块系统的类型定义和辅助函数

# 功能方块类型枚举
enum FuncType {
    NONE = 0,
    ENERGY_CONTINUOUS = 1,  # 持续型能源方块
    ENERGY_PULSE = 2,        # 脉冲型能源方块
    MOVE = 3,                # 移动方块
    TURN = 4,                # 拐弯方块
}

# 6 个方向向量
const DIRECTION_VECTORS: Array[Vector3i] = [
    Vector3i( 1,  0,  0),  # +X  0
    Vector3i(-1,  0,  0),  # -X  1
    Vector3i( 0,  1,  0),  # +Y  2
    Vector3i( 0, -1,  0),  # -Y  3
    Vector3i( 0,  0,  1),  # +Z  4
    Vector3i( 0,  0, -1),  # -Z  5
]

const DIRECTION_NAMES: Array[String] = [
    "+X", "-X", "+Y", "-Y", "+Z", "-Z"
]

# 将方向索引转为 Vector3i
static func dir_index_to_vec(idx: int) -> Vector3i:
    if idx >= 0 and idx < DIRECTION_VECTORS.size():
        return DIRECTION_VECTORS[idx]
    return Vector3i(0, 1, 0)  # 默认 +Y

# 将 Vector3i 方向转为索引
static func dir_vec_to_index(dir: Vector3i) -> int:
    for i in range(DIRECTION_VECTORS.size()):
        if DIRECTION_VECTORS[i] == dir:
            return i
    return 2  # 默认 +Y

# 获取相反方向
static func opposite_direction(dir: Vector3i) -> Vector3i:
    return Vector3i(-dir.x, -dir.y, -dir.z)

# 获取下一个方向索引（用于旋转工具循环切换）
static func next_direction_index(current: int) -> int:
    return (current + 1) % DIRECTION_VECTORS.size()

# 检查是否是能源类型
static func is_energy_type(ft: int) -> bool:
    return ft == FuncType.ENERGY_CONTINUOUS or ft == FuncType.ENERGY_PULSE

# 获取功能方块对应的 item_id（在 item_types 中注册的 ID）
const ENERGY_CONTINUOUS_ITEM_ID = 6
const ENERGY_PULSE_ITEM_ID = 7
const MOVE_ITEM_ID = 8
const TURN_ITEM_ID = 9

# 功能方块的显示颜色
static func get_func_type_color(ft: int) -> Color:
    match ft:
        FuncType.ENERGY_CONTINUOUS:
            return Color(1.0, 0.3, 0.1)   # 橙红
        FuncType.ENERGY_PULSE:
            return Color(1.0, 0.5, 0.0)   # 橙色
        FuncType.MOVE:
            return Color(0.2, 0.6, 1.0)   # 蓝色
        FuncType.TURN:
            return Color(0.3, 0.9, 0.3)   # 绿色
        _:
            return Color.GRAY

func _ready():
    print("FunctionalTypes loaded: ", DIRECTION_VECTORS.size(), " directions")
