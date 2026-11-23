shader_type canvas_item;

uniform bool blend_left = false;
uniform float overlap_width : hint_range(0.001, 0.5) = 0.166667;
uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D under_tex : filter_linear, repeat_disable;
uniform sampler2D seam_tex : filter_linear, repeat_disable;
uniform vec4 under_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 seam_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float feather_width = 0.013889;
// Apron mode (band > 0): continue the painting below its bottom edge by
// repeating its lowest rows, mirrored back and forth, so each join is seamless.
uniform float apron_band = 0.0;
uniform float apron_tiles = 1.0;

float feather(float x, float center, float width) {
	return smoothstep(max(0.0, center - width * 0.5), min(1.0, center + width * 0.5), x);
}

void fragment() {
	vec2 local = (UV - atlas_rect.xy) / atlas_rect.zw;
	vec2 uv = UV;
	vec3 gain = vec3(1.0);
	if (apron_band > 0.0) {
		float phase = mod(local.y * apron_tiles, 2.0);
		local.y = 1.0 - apron_band * (phase < 1.0 ? phase : 2.0 - phase);
		uv = atlas_rect.xy + local * atlas_rect.zw;
		// The road darkens toward the painting's edge. Hold every mirrored row
		// at the edge's tone so the reflections keep grain but form no stripes.
		// Tones average each row across the whole panel; they vary only by row,
		// so the correction cannot introduce vertical streaks. TEXTURE is sampled
		// here because Godot cannot pass it to a helper function.
		vec3 edge = vec3(0.0);
		vec3 row = vec3(0.0);
		for (int i = 0; i < 11; i++) {
			float x = 0.05 + float(i) * 0.09;
			edge += texture(TEXTURE, atlas_rect.xy + vec2(x, 0.998) * atlas_rect.zw).rgb;
			row += texture(TEXTURE, atlas_rect.xy + vec2(x, local.y) * atlas_rect.zw).rgb;
		}
		gain = clamp(edge / max(row, vec3(0.2)), vec3(0.6), vec3(1.6));
	}
	vec4 over = texture(TEXTURE, uv);
	if (!blend_left || local.x >= overlap_width) {
		COLOR = vec4(over.rgb * gain, 1.0);
	} else {
		// One continuous seam follows matching scenery. Feather only around
		// that seam, rather than switching paintings separately for each color.
		vec2 under_uv = vec2(clamp(local.x / overlap_width, 0.0, 1.0), clamp(local.y, 0.0, 1.0));
		vec2 seam = texture(seam_tex, seam_rect.xy + vec2(0.5, under_uv.y) * seam_rect.zw).rg;
		float fade = feather(under_uv.x, seam.r, max(seam.g, feather_width / overlap_width));
		vec4 under = texture(under_tex, under_rect.xy + under_uv * under_rect.zw);
		COLOR = vec4(mix(under.rgb, over.rgb, fade) * gain, 1.0);
	}
}
