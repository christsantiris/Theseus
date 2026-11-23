extends RefCounted

const BLEND := preload("res://resources/shaders/landscape_blend.gdshader")
const SEAM_WIDTH := 96
const FEATHER_PIXELS := 8.0
const DATA := preload("res://scenes/levels/landscape_join_data.gd")
# Lowest fraction of every panorama, plain road in all panels, that is mirrored
# below the painting.
const APRON_BAND := 0.08
# Each mirrored band is stretched vertically, like nearer ground in perspective,
# so reflections repeat rarely enough not to form a visible pattern.
const APRON_STRETCH := 1.0


static func prepare(panorama: Sprite2D, blend_left: bool, overlap_width: float, previous: Texture2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = BLEND
	var can_blend := blend_left and previous != null
	material.set_shader_parameter("atlas_rect", _atlas_rect(panorama.texture))
	material.set_shader_parameter("overlap_width", overlap_width)
	material.set_shader_parameter("feather_width", overlap_width * FEATHER_PIXELS / SEAM_WIDTH)
	if can_blend:
		var texture := panorama.texture as AtlasTexture
		var path := texture.atlas.resource_path.get_base_dir().path_join("_seams/joins.tres") if texture != null else ""
		var data := load(path) as DATA if ResourceLoader.exists(path) else null
		var index := data.panel_keys.find(DATA.panel_key(panorama.texture)) if data != null else -1
		can_blend = index >= 0 and index < data.previous_keys.size() and index < data.overlap_rects.size() and index < data.mask_rects.size() and data.overlaps != null and data.masks != null
		if can_blend:
			can_blend = data.previous_keys[index] == DATA.panel_key(previous) and is_equal_approx(data.overlap_width, overlap_width)
		if can_blend:
			material.set_shader_parameter("under_tex", data.overlaps)
			material.set_shader_parameter("seam_tex", data.masks)
			material.set_shader_parameter("under_rect", _uv_rect(data.overlap_rects[index], data.overlaps.get_size()))
			material.set_shader_parameter("seam_rect", _uv_rect(data.mask_rects[index], data.masks.get_size()))
			material.set_meta("landscape_joins", data)
		else:
			push_error("Missing or mismatched baked landscape join: %s. Run tools/bake_landscapes.sh." % DATA.panel_key(panorama.texture))
	material.set_shader_parameter("blend_left", can_blend)
	panorama.material = material


static func extend_downward(panorama: Sprite2D, depth: float) -> void:
	# The painting ends at its bottom edge; when the camera looks below the
	# backdrop's anchor, continue the road beneath it so scenery still fills the
	# view. The apron shares the panel's seam blend, so joins between panels hold.
	var panel_height := panorama.texture.get_height()
	var apron := Sprite2D.new()
	apron.name = "Apron"
	apron.texture = panorama.texture
	apron.centered = false
	apron.position.y = panel_height
	apron.scale.y = depth / (panel_height * panorama.scale.y)
	var material := panorama.material.duplicate() as ShaderMaterial
	material.set_shader_parameter("apron_band", APRON_BAND)
	material.set_shader_parameter("apron_tiles", apron.scale.y / (APRON_BAND * APRON_STRETCH))
	apron.material = material
	panorama.add_child(apron)


static func _atlas_rect(texture: Texture2D) -> Vector4:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		var size := atlas.atlas.get_size()
		if size.x > 0.0 and size.y > 0.0:
			var region := atlas.region
			return Vector4(
				region.position.x / size.x,
				region.position.y / size.y,
				region.size.x / size.x,
				region.size.y / size.y
			)
	return Vector4(0, 0, 1, 1)


static func _uv_rect(rect: Rect2, size: Vector2) -> Vector4:
	return Vector4(rect.position.x / size.x, rect.position.y / size.y, rect.size.x / size.x, rect.size.y / size.y)
