extends Node
# power_system.gd — 电力网络 BFS 更新

@onready var block_manager = $"../Blocks"
@onready var func_types = $"../FunctionalTypes"

const MAX_DISTANCE := 15


func update_power_network():
    _clear_all_power()
    
    var queue: Array = []
    var visited: Dictionary = {}
    
    # Collect Power blocks
    for pos in block_manager.blocks:
        var bd = block_manager.blocks[pos]
        if bd.func_type == func_types.FuncType.POWER:
            queue.append([pos, 0, false])  # [pos, dist, is_not_gate]
            visited[pos] = true
    
    # BFS pass 1: from Power blocks (skip NOT_GATEs)
    _bfs_spread(queue, visited, false)
    
    # Pass 2: unpowered NOT_GATEs become directional sources
    for pos in block_manager.blocks:
        var bd = block_manager.blocks[pos]
        if bd.func_type != func_types.FuncType.NOT_GATE:
            continue
        if bd.powered:
            continue  # got power from pass 1, stays off
        # Check input face (opposite of arrow)
        var dir_vec = func_types.DIRECTION_VECTORS[bd.direction]
        var input_pos = pos - dir_vec
        var input_bd = block_manager.blocks.get(input_pos, null)
        if input_bd != null and input_bd.powered:
            continue  # input side has power → NOT stays off
        # No input power → NOT acts as directional source
        queue.append([pos, 0, true])
        visited[pos] = true
    
    _bfs_spread(queue, visited, true)
    _update_powered_visuals()


func _bfs_spread(queue: Array, visited: Dictionary, is_not_pass: bool):
    while not queue.is_empty():
        var item = queue.pop_front()
        var pos: Vector3i = item[0]
        var dist: int = item[1]
        var from_not: bool = item[2] if item.size() > 2 else false
        
        var bd = block_manager.blocks.get(pos, null)
        if bd != null:
            bd.powered = true
        
        # NOT_GATE only outputs in arrow direction
        var dirs = func_types.DIRECTION_VECTORS
        if from_not and bd != null and bd.func_type == func_types.FuncType.NOT_GATE:
            dirs = [func_types.DIRECTION_VECTORS[bd.direction]]
        
        for d in dirs:
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
                queue.append([n, dist + 1, false])


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
                func_types.FuncType.NOT_GATE:
                    mat.albedo_color = Color(1.0, 0.4, 0.6)   # 亮粉
                    mat.emission_enabled = true
                    mat.emission = Color(1.0, 0.2, 0.4)
                    mat.emission_energy_multiplier = 0.6
        else:
            mat.emission_enabled = false
            match bd.func_type:
                func_types.FuncType.WIRE:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.WIRE)
                func_types.FuncType.SWITCH:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.SWITCH)
                func_types.FuncType.LAMP:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.LAMP)
                func_types.FuncType.NOT_GATE:
                    mat.albedo_color = func_types.get_func_type_color(func_types.FuncType.NOT_GATE)
