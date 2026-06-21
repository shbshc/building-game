extends Node
# functional_types.gd — 功能方块系统的类型定义和辅助函数

# 功能方块类型枚举
enum FuncType {
	NONE = 0,
	MOVE = 1,     # 移动方块
	TURN = 2,     # 拐弯方块
	GENERATOR = 3, # 生成器方块
	PUSH = 4,     # 推动方块
	CONSUME = 5,  # 消耗方块
	SLIME = 6,    # 粘液方块
	POWER = 7,    # 电源
	SWITCH = 8,   # 开关
	WIRE = 9,     # 导线
	LAMP = 10,    # 灯泡

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

const DIRECTION_SHORT: Array[String] = [
	"→", "←", "↑", "↓", "↗", "↙"
]

# 方向 → Vector3i
static func dir_index_to_vec(idx: int) -> Vector3i:
	if idx >= 0 and idx < DIRECTION_VECTORS.size():
		return DIRECTION_VECTORS[idx]
	return Vector3i(0, 1, 0)

# Vector3i → 方向索引
static func dir_vec_to_index(dir: Vector3i) -> int:
	for i in range(DIRECTION_VECTORS.size()):
		if DIRECTION_VECTORS[i] == dir:
			return i
	return 2  # 默认 +Y

# 下一个方向（Shift+右键循环）
static func next_direction_index(current: int) -> int:
	return (current + 1) % DIRECTION_VECTORS.size()

# 功能方块颜色
static func get_func_type_color(ft: int) -> Color:
	match ft:
		FuncType.MOVE:
			return Color(0.2, 0.6, 1.0)   # 蓝色
		FuncType.TURN:
			return Color(0.3, 0.9, 0.3)   # 绿色
		FuncType.GENERATOR:
			return Color(0.7, 0.3, 1.0)   # 紫色
		FuncType.PUSH:
			return Color(1.0, 0.6, 0.1)   # 橙色
		FuncType.CONSUME:
			return Color(0.2, 0.05, 0.05) # 暗红
		FuncType.SLIME:
			return Color(0.2, 1.0, 0.3)   # 亮绿
		FuncType.POWER:
			return Color(1.0, 0.2, 0.1)   # 红橙
		FuncType.SWITCH:
			return Color(0.4, 0.4, 0.4)   # 灰色
		FuncType.WIRE:
			return Color(0.6, 0.5, 0.3)   # 铜色
		FuncType.LAMP:
			return Color(0.9, 0.9, 0.8)   # 米白
		FuncType.CONSUME:
			return Color(0.9, 0.2, 0.2)   # 红色
		_:
			return Color.GRAY

func _ready():
	print("FunctionalTypes loaded: ", DIRECTION_VECTORS.size(), " directions")
