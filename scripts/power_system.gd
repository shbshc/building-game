extends Node
# power_system.gd — 电力网络 BFS 更新

@onready var block_manager = $"../Blocks"
@onready var func_types = $"../FunctionalTypes"

const MAX_DISTANCE := 15


func update_power_network():
    # 1. 清除所有带电状态
    _clear_all_power()
    
    # 2. 收集电源 + 打开的开关 → BFS 队列
    var queue: Array = []  # [Vector3i, distance]
    var visited: Dictionary = {}
    
    for pos in block_manager.blocks:
        var bd = block_manager.blocks[pos]
        if bd.func_type == func_types.FuncType.POWER:
            queue.append([pos, 0])
            visited[pos] = true
        elif bd.func_type == func_types.FuncType.SWITCH:
            # 开关不发电，只导电——由 BFS 蔓延时通过导线连通
            pass
    
    # 3. BFS 蔓延
    while not queue.is_empty():
        var item = queue.pop_front()
        var pos: Vector3i = item[0]
        var dist: int = item[1]
        
        var bd = block_manager.blocks.get(pos, null)
        if bd != null:
            bd.powered = true
        
        for d in func_types.DIRECTION_VECTORS:
            var n = pos + d
            if visited.has(n):
                continue
            var nb = block_manager.blocks.get(n, null)
            if nb == null:
                continue
            var can_conduct = (nb.func_type == func_types.FuncType.WIRE or 
                              nb.func_type == func_types.FuncType.LAMP)
            if nb.func_type == func_types.FuncType.SWITCH and nb.get("switch_on") == true:
                can_conduct = true
            if can_conduct:
                visited[n] = true
                queue.append([n, dist + 1])
    
    # 4. 更新方块视觉
    _update_powered_visuals()


func _clear_all_power():
    for pos in block_manager.blocks:
        block_manager.blocks[pos].powered = false


func _update_powered_visuals():
    for pos in block_manager.blocks:
        var bd = block_manager.blocks[pos]
        var mesh = bd.node
        var mat = mesh.material_override
        if mat == null:
            continue
        
        if bd.powered:
            match bd.func_type:
                func_types.FuncType.WIRE:
                    mat.albedo_color = Color(1.0, 0.8, 0.1)   # 亮黄
                    mat.emission_enabled = true
                    mat.emission = Color(1.0, 0.6, 0.0)
                    mat.emission_energy_multiplier = 0.8
                func_types.FuncType.SWITCH:
                    mat.albedo_color = Color(1.0, 0.3, 0.1)   # 红
                    mat.emission_enabled = true
                    mat.emission = Color(0.8, 0.2, 0.0)
                    mat.emission_energy_multiplier = 0.5
                func_types.FuncType.LAMP:
                    mat.albedo_color = Color(1.0, 1.0, 0.9)   # 亮白
                    mat.emission_enabled = true
                    mat.emission = Color(1.0, 1.0, 0.8)
                    mat.emission_energy_multiplier = 1.5
        else:
            mat.emission_enabled = false
            match bd.func_type:
                func_types.FuncType.WIRE:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.WIRE)
                func_types.FuncType.SWITCH:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.SWITCH)
                func_types.FuncType.LAMP:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.LAMP)
