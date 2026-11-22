shader_type canvas_item;

uniform bool blend_left = false;
uniform float overlap_width : hint_range(0.001, 0.5) = 0.166667;

void fragment() {
	vec4 landscape = texture(TEXTURE, UV);
	if (blend_left) {
		// Blend across the entire physical overlap at every height. A shorter
		// terrain fade exposes a vertical cut through rocks, trees and arches.
		landscape.a *= smoothstep(0.0, overlap_width, UV.x);
	}
	COLOR = landscape;
}
