shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 shade = mix(tex.rgb, vec3(0.62, 0.78, 0.92), 0.72);
	COLOR = vec4(shade, step(0.05, tex.a));
}
