extends RefCounted

const BLEND := preload("res://resources/shaders/landscape_blend.gdshader")
const SEAM_WIDTH := 96
const FEATHER_PIXELS := 8.0
const SEAM_MARGIN := 12
static var _joins: Dictionary = {}


static func prepare(panorama: Sprite2D, blend_left: bool, overlap_width: float, previous: Texture2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = BLEND
	var can_blend := blend_left and previous != null
	material.set_shader_parameter("atlas_rect", _atlas_rect(panorama.texture))
	material.set_shader_parameter("overlap_width", overlap_width)
	material.set_shader_parameter("feather_width", overlap_width * FEATHER_PIXELS / SEAM_WIDTH)
	if can_blend:
		var join := _join(previous, panorama.texture, overlap_width)
		can_blend = not join.is_empty()
		if can_blend:
			material.set_shader_parameter("under_tex", join.under)
			material.set_shader_parameter("seam_tex", join.seam)
	material.set_shader_parameter("blend_left", can_blend)
	panorama.material = material


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


static func _texture_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		return "%s:%s" % [_texture_key(texture.atlas), texture.region]
	return "%s:%d" % [texture.resource_path, texture.get_instance_id()]


static func _join(previous: Texture2D, incoming: Texture2D, overlap_width: float) -> Dictionary:
	var key := "%s/%s/%s" % [_texture_key(previous), _texture_key(incoming), overlap_width]
	if _joins.has(key):
		return _joins[key]
	var old_image := previous.get_image()
	var new_image := incoming.get_image()
	if old_image == null or new_image == null or old_image.is_empty() or new_image.is_empty():
		return {}
	var old_width := maxi(1, roundi(old_image.get_width() * overlap_width))
	var new_width := maxi(1, roundi(new_image.get_width() * overlap_width))
	var under := old_image.get_region(Rect2i(old_image.get_width() - old_width, 0, old_width, old_image.get_height()))
	var over := new_image.get_region(Rect2i(0, 0, new_width, new_image.get_height()))
	var join := {
		"under": ImageTexture.create_from_image(under),
		"seam": _seam(under, over),
	}
	_joins[key] = join
	return join


static func _difference(a: Color, b: Color) -> float:
	return (a.r - b.r) ** 2 + (a.g - b.g) ** 2 + (a.b - b.b) ** 2


static func _seam(under: Image, over: Image) -> Texture2D:
	# Work at roughly one sample per world pixel, independently of source PNG
	# resolution. Cache the result so replaying a level does not search again.
	var height := clampi(roundi(SEAM_WIDTH * float(over.get_height()) / over.get_width()), 2, 256)
	var left := under.duplicate() as Image
	var right := over.duplicate() as Image
	left.resize(SEAM_WIDTH, height, Image.INTERPOLATE_LANCZOS)
	right.resize(SEAM_WIDTH, height, Image.INTERPOLATE_LANCZOS)
	var parents := PackedInt32Array()
	parents.resize(SEAM_WIDTH * height)
	var previous := PackedFloat32Array()
	previous.resize(SEAM_WIDTH)
	previous.fill(INF)
	for y in height:
		var current := PackedFloat32Array()
		current.resize(SEAM_WIDTH)
		current.fill(INF)
		for x in range(SEAM_MARGIN, SEAM_WIDTH - SEAM_MARGIN):
			# Match neighborhoods, not individual highlights or gaps in leaves.
			var cost := 0.0
			for offset in [-2, 0, 2]:
				cost += _difference(left.get_pixel(x + offset, y), right.get_pixel(x + offset, y)) / 3.0
			cost += absf(x - SEAM_WIDTH * 0.5) / SEAM_WIDTH * 0.02
			var best := x
			var total := 0.0
			if y > 0:
				total = previous[x]
				for candidate in [x - 1, x + 1]:
					if previous[candidate] + 0.01 < total:
						total = previous[candidate] + 0.01
						best = candidate
			current[x] = cost + total
			parents[y * SEAM_WIDTH + x] = best
		previous = current
	var end := SEAM_WIDTH / 2
	for x in range(SEAM_MARGIN, SEAM_WIDTH - SEAM_MARGIN):
		if previous[x] < previous[end]:
			end = x
	var path := PackedInt32Array()
	path.resize(height)
	for y in range(height - 1, -1, -1):
		path[y] = end
		end = parents[y * SEAM_WIDTH + end]
	# Feather broadly through smooth sky and hills, but narrowly around detailed
	# structures. Estimate detail over an entire row so individual colored pixels
	# cannot punch holes in the scene. Strong edges keep whole columns distinct.
	var widths := PackedFloat32Array()
	widths.resize(height)
	for y in height:
		var edges := PackedFloat32Array()
		for x in range(1, SEAM_WIDTH - 1):
			edges.append(sqrt(maxf(
				_difference(left.get_pixel(x - 1, y), left.get_pixel(x + 1, y)),
				_difference(right.get_pixel(x - 1, y), right.get_pixel(x + 1, y))
			)))
		edges.sort()
		var detail := 0.0
		for index in range(edges.size() - 8, edges.size()):
			detail += edges[index] / 8.0
		widths[y] = lerpf(1.0, FEATHER_PIXELS / SEAM_WIDTH, smoothstep(0.04, 0.18, detail))
	var image := Image.create(1, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var center := 0.0
		var width := 0.0
		for offset in range(-2, 3):
			center += path[clampi(y + offset, 0, height - 1)] / 5.0
			width += widths[clampi(y + offset, 0, height - 1)] / 5.0
		# Keep the narrow fade clear of either edge. The shader also clamps wider
		# sky fades so the overlap boundaries exactly match their source images.
		image.set_pixel(0, y, Color((center + 0.5) / SEAM_WIDTH, width, 0, 1))
	return ImageTexture.create_from_image(image)
