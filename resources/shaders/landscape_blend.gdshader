shader_type canvas_item;

uniform bool blend_left = false;
uniform float overlap_width : hint_range(0.001, 0.5) = 0.166667;
uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D under_tex : filter_linear, repeat_disable;
uniform sampler2D seam_tex : filter_linear, repeat_disable;
uniform float feather_width = 0.013889;

float feather(float x, float center, float width) {
	return smoothstep(max(0.0, center - width * 0.5), min(1.0, center + width * 0.5), x);
}

void fragment() {
	vec4 over = texture(TEXTURE, UV);
	vec2 local = (UV - atlas_rect.xy) / atlas_rect.zw;
	if (!blend_left || local.x >= overlap_width) {
		COLOR = vec4(over.rgb, 1.0);
	} else {
		// One continuous seam follows matching scenery. Feather only around
		// that seam, rather than switching paintings separately for each color.
		vec2 under_uv = vec2(clamp(local.x / overlap_width, 0.0, 1.0), clamp(local.y, 0.0, 1.0));
		vec2 seam = texture(seam_tex, vec2(0.5, under_uv.y)).rg;
		float fade = feather(under_uv.x, seam.r, max(seam.g, feather_width / overlap_width));
		vec4 under = texture(under_tex, under_uv);
		COLOR = vec4(mix(under.rgb, over.rgb, fade), 1.0);
	}
}
