extends SceneTree

# Requires a renderer. Guards platform variants, protected alpha/data textures,
# the selective mip policy; compares minified stone sampling.
const TERRAIN := ["limestone_wall", "coastal_limestone", "city_masonry", "mountain_stone", "gorge_masonry"]
var failures: Array[String] = []
var captures := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
			DirAccess.make_dir_recursive_absolute(captures)
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _imports(directory: String) -> void:
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".png.import"):
			continue
		var path := directory.path_join(name)
		var config := ConfigFile.new()
		_expect(config.load(path) == OK, "Readable import: " + path)
		if config.get_value("remap", "importer", "") == "skip":
			_expect(directory == "res://assets/fonts", "Only bitmap-font source pages bypass texture import: " + path)
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path.trim_suffix(".import")))
		var opaque_background := directory.contains("/backgrounds/") and image.get_format() == Image.FORMAT_RGB8
		var mode: int = config.get_value("params", "compress/mode", -1)
		var mips: bool = config.get_value("params", "mipmaps/generate", false)
		var terrain := TERRAIN.has(name.trim_suffix(".png.import"))
		_expect(mode == (2 if opaque_background else 0), "Only opaque backgrounds use VRAM compression: " + path)
		_expect(mips == terrain, "Only isolated terrain tiles generate mipmaps: " + path)
		if not opaque_background:
			continue
		_expect(not config.get_value("params", "compress/high_quality"), "Compatibility renderer uses S3TC/ETC2: " + path)
		for variant in ["s3tc", "etc2"]:
			var texture: Texture2D = load(config.get_value("remap", "path." + variant))
			var encoded := texture.get_image()
			_expect(encoded.is_compressed(), "Compressed " + variant + ": " + path)
			_expect(encoded.get_data_size() < image.get_data_size() / 3, "At least 3x smaller GPU payload: " + path)
			_expect(encoded.has_mipmaps() == terrain, "Variant retains mip policy: " + path)
			_expect(Vector2i(texture.get_size()) == image.get_size() and texture.get_width() <= 4096 and texture.get_height() <= 4096, "Original dimensions within mobile limit: " + path)
	for name in DirAccess.get_directories_at(directory):
		_imports(directory.path_join(name))


func _error(image: Image, a: int, b: int, width: int) -> float:
	var total := 0.0
	for y in image.get_height():
		for x in width:
			var p := image.get_pixel(a + x, y)
			var q := image.get_pixel(b + x, y)
			for channel in 3:
				total += pow(p[channel] - q[channel], 2)
	return sqrt(total / (width * image.get_height() * 3)) * 255.0


func _terrain(number: int) -> void:
	var path := "res://assets/art/backgrounds/level_%d/%s.png" % [number, TERRAIN[number - 1]]
	var raw := Image.load_from_file(ProjectSettings.globalize_path(path))
	raw.generate_mipmaps()
	var reference := ImageTexture.create_from_image(raw)
	var compressed: Texture2D = load(path)
	var geometry = load("res://scenes/levels/level_%d_geometry.gd" % number).new()
	root.add_child(geometry)
	_expect(geometry.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Level %d actually samples terrain mips" % number)
	geometry.free()
	for factor in [0.1875, 0.25]: # Three/four output pixels per 16 source texels.
		var side := 192
		var viewport := SubViewport.new()
		viewport.size = Vector2i(side * 3, side)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		for column in 3:
			var sprite := Sprite2D.new()
			sprite.texture = reference if column == 0 else compressed
			sprite.centered = false
			sprite.position = Vector2(column * side, 0)
			sprite.scale = Vector2.ONE * factor
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if column == 1 else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			viewport.add_child(sprite)
		await process_frame
		RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image()
		var without := _error(image, 0, side, side)
		var with_mips := _error(image, 0, side * 2, side)
		print("Terrain %d scale %.4f: RMS versus lossless mip reference, no mips %.2f, mips %.2f /255" % [number, factor, without, with_mips])
		_expect(with_mips < without * 0.8, "Mipmaps improve downsampled terrain fidelity: " + path)
		if not captures.is_empty():
			image.save_png(captures.path_join("terrain_%d_%.4f.png" % [number, factor]))
		viewport.free()


func _run() -> void:
	for directory in ["res://assets/art", "res://assets/fonts"]:
		if DirAccess.dir_exists_absolute(directory):
			_imports(directory)
	# Bitmap-font pages are embedded by the font importer, not PNG imports.
	for name in ["inscription", "inscription_large"]:
		var font: FontFile = load("res://assets/fonts/%s.fnt" % name)
		for cache in font.get_cache_count():
			for size in font.get_size_cache_list(cache):
				for index in font.get_texture_count(cache, size):
					var page := font.get_texture_image(cache, size, index)
					_expect(not page.is_compressed() and not page.has_mipmaps(), "Bitmap font stays uncompressed without mips: " + name)
	var exports := ConfigFile.new()
	exports.load("res://export_presets.cfg")
	_expect(exports.get_value("preset.0.options", "vram_texture_compression/for_desktop") and exports.get_value("preset.0.options", "vram_texture_compression/for_mobile"), "Web ships both platform compression variants")
	for number in range(1, 6):
		await _terrain(number)
	print("PASS: texture budgets, protected textures, variants and minified terrain." if failures.is_empty() else "FAIL: " + str(failures))
	quit(0 if failures.is_empty() else 1)
