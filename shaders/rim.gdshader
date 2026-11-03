shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 rim_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform float push = 0.045;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	ALBEDO = rim_color.rgb;
	EMISSION = rim_color.rgb;
}
