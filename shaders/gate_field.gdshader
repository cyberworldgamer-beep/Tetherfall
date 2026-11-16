shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.15, 1.0, 0.86);
uniform float intensity = 0.7;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float angle = atan(uv.y, uv.x);
	float swirl = 0.5 + 0.5 * sin(angle * 7.0 + TIME * 1.8 - r * 13.0);
	float swirl2 = 0.5 + 0.5 * sin(angle * -12.0 - TIME * 1.1 + r * 9.0);
	float ring = smoothstep(1.0, 0.55, r) * smoothstep(0.08, 0.24, r);
	float alpha = ring * (0.08 + swirl * 0.16 + swirl2 * 0.08);
	vec3 col = color * (0.7 + swirl * 1.8 + swirl2 * 0.6);
	ALBEDO = col;
	ALPHA = alpha * intensity;
}