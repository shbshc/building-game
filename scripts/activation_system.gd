extends Node

@onready var block_manager = $"../Blocks"
@onready var func_types = $"../FunctionalTypes"

var _activation_id := 0
var _activated_blocks: Dictionary = {}  # activation_id -> Array[Vector3i]


func trigger_activation(origin_pos: Vector3i, direction_vec: Vector3i):
    _activation_id += 1
    var aid = _activation_id
    _activated_blocks[aid] = []
    _propagate(origin_pos, direction_vec, aid)
    # 清理旧激活记录（保留最近 10 次）
    if _activated_blocks.size() > 10:
        var oldest = _activation_id - 10
        for k in _activated_blocks.keys():
            if k < oldest:
                _activated_blocks.erase(k)


func _propagate(current_pos: Vector3i, signal_dir: Vector3i, aid: int):
    # 停止条件：越界
    if current_pos.y < 0:
        return
    if abs(current_pos.x) > 50 or abs(current_pos.z) > 50 or current_pos.y > 50:
        return

    var bd = block_manager.get_block_data(current_pos)
    if bd == null:
        return  # 空位置，信号终止

    # 防循环：本轮已激活则跳过
    if current_pos in _activated_blocks[aid]:
        return
    _activated_blocks[aid].append(current_pos)

    var ft = bd.func_type

    match ft:
        func_types.FuncType.ENERGY_CONTINUOUS, func_types.FuncType.ENERGY_PULSE:
            # 能源方块收到激活 → 沿自己的箭头方向发出信号
            var dir_vec = func_types.DIRECTION_VECTORS[bd.direction]
            var next_pos = current_pos + dir_vec
            print("Energy at ", current_pos, " firing toward ", dir_vec)
            _propagate(next_pos, dir_vec, aid)

        func_types.FuncType.MOVE:
            # 移动方块：向自己的箭头方向移动 1 格
            var dir_vec = func_types.DIRECTION_VECTORS[bd.direction]
            var new_pos = current_pos + dir_vec
            print("Move block from ", current_pos, " to ", new_pos)

            # 检查目标格是否有拐弯方块
            var target = block_manager.get_block_data(new_pos)
            var was_turn = (target != null and target.func_type == func_types.FuncType.TURN)
            var turn_dir = target.direction if was_turn else -1

            if block_manager.move_block(current_pos, new_pos):
                # 移动成功
                if was_turn:
                    # 拐弯方块被消耗，移动方块转向
                    block_manager.set_block_direction(new_pos, turn_dir)
                    print("Move block turned to ", func_types.DIRECTION_NAMES[turn_dir])

                # 继续向前传播信号
                var new_dir_vec = func_types.DIRECTION_VECTORS[block_manager.get_block_data(new_pos).direction]
                _propagate(new_pos, new_dir_vec, aid)
            else:
                print("Move blocked at ", current_pos, " -> ", new_pos)

        func_types.FuncType.TURN:
            # 拐弯方块不响应激活，信号终止
            pass

        _:
            # 普通方块：信号终止
            pass
