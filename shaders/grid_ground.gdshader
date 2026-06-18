shader_type spatial;
render_mode unshaded;

uniform vec4 ground_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform vec4 grid_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float grid_size = 1.0;
uniform float line_width = 0.04;

void fragment() {
    vec2 coord = UV * grid_size;
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
    float line = min(grid.x, grid.y);
    float grid_line = 1.0 - min(line, 1.0);
    
    // 粗线：每 10 格一条主格线
    vec2 coord10 = UV * grid_size / 10.0;
    vec2 grid10 = abs(fract(coord10 - 0.5) - 0.5) / fwidth(coord10);
    float line10 = min(grid10.x, grid10.y);
    float major_line = 1.0 - min(line10, 1.0);
    float final_line = max(grid_line * 0.5, major_line * 0.8);
    
    ALBEDO = mix(ground_color.rgb, grid_color.rgb, final_line * line_width * 10.0);
}
