shader_type canvas_item;

void fragment() {
	vec4 portrait = texture(TEXTURE, UV);
	float circle = 1.0 - smoothstep(0.94, 1.0, length(UV * 2.0 - 1.0));
	COLOR = vec4(portrait.rgb, portrait.a * circle);
}
