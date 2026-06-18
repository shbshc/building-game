shader_type spatial;
render_mode unshaded;

uniform vec4 ground_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform vec4 grid_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 coord = world_pos.xz;
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
    float line = min(grid.x, grid.y);
    float grid_line = 1.0 - min(line, 1.0);
    
    vec2 coord10 = world_pos.xz / 10.0;
    vec2 grid10 = abs(fract(coord10 - 0.5) - 0.5) / fwidth(coord10);
    float line10 = min(grid10.x, grid10.y);
    float major_line = 1.0 - min(line10, 1.0);
    float final_line = max(grid_line * 0.5, major_line * 0.8);
    
    ALBEDO = mix(ground_color.rgb, grid_color.rgb, final_line * 0.5);
}