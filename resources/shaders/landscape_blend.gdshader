shader_type canvas_item;

uniform bool blend_left = false;
uniform float feather_width : hint_range(0.001, 0.5) = 0.142857;
uniform float sky_feather_width : hint_range(0.001, 0.5) = 0.166667;
uniform float panel_row = 0.0;

void fragment() {
	vec4 landscape = texture(TEXTURE, UV);
	if (blend_left) {
		// Atlas rows share the same sky/architecture division. Dissolve the
		// sky broadly while keeping architectural edges crisp below it.
		float local_y = UV.y * 2.0 - panel_row;
		float blend_width = mix(sky_feather_width, feather_width,
			smoothstep(0.25, 0.42, local_y));
		landscape.a *= smoothstep(0.0, blend_width, UV.x);
	}
	COLOR = landscape;
}
