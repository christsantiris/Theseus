extends SceneTree

const SEARCH := preload("res://tools/landscape_seam.gd")
const DATA := preload("res://scenes/levels/landscape_join_data.gd")
const BAKER_FILES := ["res://tools/bake_landscapes.gd", "res://tools/landscape_seam.gd"]
var check := false
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	check = "--check" in OS.get_cmdline_user_args()
	for number in range(1, 6):
		_bake(number)
	if failures.is_empty():
		print("PASS: all 36 legacy landscape joins %s; source pixels and seam masks are lossless." % ("are current" if check else "baked"))
	else:
		for failure in failures:
			push_error(failure)
	# Project autoloads also run for command-line scripts. Release their music
	# playback before exit so this offline tool leaves no audio objects behind.
	_stop_audio(root)
	await process_frame
	await process_frame
	OS.delay_msec(150)
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null


func _baker_hash() -> String:
	var hashes := ""
	for path in BAKER_FILES:
		hashes += FileAccess.get_sha256(path)
	return hashes.sha256_text()


func _number(source: String, name: String) -> float:
	var expression := RegEx.new()
	expression.compile("const " + name + " := ([0-9.]+)")
	var found := expression.search(source)
	if found == null:
		failures.append("Cannot find numeric geometry constant: " + name)
		return -1.0
	return found.get_string(1).to_float()


func _panels(number: int) -> Dictionary:
	# Read the authored order without loading geometry scripts or GPU textures.
	var source := FileAccess.get_file_as_string("res://scenes/levels/level_%d_geometry.gd" % number)
	if source.contains("const CONTINUOUS_LANDSCAPE := true"):
		return {"continuous": true}
	var start := source.find("const PANORAMA_SHEETS := [")
	if start < 0 or source.find("]", start) < 0:
		failures.append("Missing panorama list in level %d" % number)
		return {}
	var block := source.substr(start, source.find("]", start) - start)
	var expression := RegEx.new()
	expression.compile('preload\\("([^"]+)"\\)')
	var panels: Array[Dictionary] = []
	var hashes := {}
	for found in expression.search_all(block):
		var path := found.get_string(1)
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(path))
		if sheet == null or sheet.is_empty() or sheet.get_height() % 2 != 0:
			failures.append("Cannot read two equal panorama halves: " + path)
			return {}
		hashes[path] = FileAccess.get_sha256(path)
		for half in 2:
			var region := Rect2i(0, half * sheet.get_height() / 2, sheet.get_width(), sheet.get_height() / 2)
			panels.append({"key": "%s:%s" % [path, Rect2(region)], "image": sheet.get_region(region)})
	if panels.size() != 10:
		failures.append("Expected ten panoramas in level %d" % number)
		return {}
	var overlap := _number(source, "OVERLAP")
	var panel_width := _number(source, "PANEL_WIDTH")
	if overlap <= 0 or panel_width <= 0:
		return {}
	return {"panels": panels, "hashes": hashes,
		"overlap": overlap * 2.0 / (panel_width + overlap * 2.0)}


func _pack(images: Array[Image], border := 1, alignment := 1) -> Dictionary:
	# Color atlases need a full replicated 4x4 compression block around each
	# strip. Masks stay lossless and need only their original bilinear border.
	var width := 0
	var height := 0
	for image in images:
		width = maxi(width, image.get_width() + border * 2)
		height = maxi(height, image.get_height() + border * 2)
	width = ceili(float(width) / alignment) * alignment
	height = ceili(float(height) / alignment) * alignment
	var format := images[0].get_format()
	var atlas := Image.create(width * 3, height * 3, false, format)
	atlas.fill(Color.BLACK)
	var rects: Array[Rect2] = []
	for index in images.size():
		var image := images[index]
		image.convert(format)
		var position := Vector2i((index % 3) * width + border, (index / 3) * height + border)
		var size := image.get_size()
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, size), position)
		for y in range(-border, height - border):
			if y < 0 or y >= size.y:
				atlas.blit_rect(image, Rect2i(0, clampi(y, 0, size.y - 1), size.x, 1), position + Vector2i(0, y))
		for x in range(-border, width - border):
			if x >= 0 and x < size.x:
				continue
			atlas.blit_rect(image, Rect2i(clampi(x, 0, size.x - 1), 0, 1, size.y), position + Vector2i(x, 0))
			atlas.fill_rect(Rect2i(position + Vector2i(x, -border), Vector2i(1, border)), image.get_pixel(clampi(x, 0, size.x - 1), 0))
			atlas.fill_rect(Rect2i(position + Vector2i(x, size.y), Vector2i(1, height - border - size.y)), image.get_pixel(clampi(x, 0, size.x - 1), size.y - 1))
		rects.append(Rect2(position, size))
	if atlas.get_width() > 4096 or atlas.get_height() > 4096:
		failures.append("Bake exceeds the mobile texture limit")
		return {}
	return {"image": atlas, "rects": rects}


func _image(path: String, expected: Image) -> void:
	if check:
		var actual := Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null
		if actual != null:
			actual.convert(expected.get_format())
		if actual == null or actual.get_size() != expected.get_size() or actual.get_data() != expected.get_data():
			failures.append("Missing or stale baked image: " + path)
	else:
		if expected.save_png(path) != OK:
			failures.append("Cannot write " + path)


func _bake(number: int) -> void:
	var definition := _panels(number)
	if definition.is_empty() or definition.get("continuous", false):
		return
	var panels: Array = definition.panels
	var strips: Array[Image] = []
	var seams: Array[Image] = []
	var data := DATA.new()
	data.overlap_width = definition.overlap
	data.source_hashes = definition.hashes
	data.baker_hash = _baker_hash()
	for index in range(1, panels.size()):
		var old_image: Image = panels[index - 1].image
		var new_image: Image = panels[index].image
		var old_width := maxi(1, roundi(old_image.get_width() * data.overlap_width))
		var new_width := maxi(1, roundi(new_image.get_width() * data.overlap_width))
		var under := old_image.get_region(Rect2i(old_image.get_width() - old_width, 0, old_width, old_image.get_height()))
		var over := new_image.get_region(Rect2i(0, 0, new_width, new_image.get_height()))
		strips.append(under)
		seams.append(SEARCH.seam(under, over))
		data.panel_keys.append(panels[index].key)
		data.previous_keys.append(panels[index - 1].key)
	var overlaps := _pack(strips, 4, 4)
	var masks := _pack(seams)
	if overlaps.is_empty() or masks.is_empty():
		return
	data.overlap_rects = overlaps.rects
	data.mask_rects = masks.rects
	var directory := "res://assets/art/backgrounds/level_%d/_seams" % number
	var resource_path := directory.path_join("joins.tres")
	if not check:
		DirAccess.make_dir_recursive_absolute(directory)
	_image(directory.path_join("overlaps.png"), overlaps.image)
	_image(directory.path_join("masks.png"), masks.image)
	if check:
		var actual := load(resource_path) as DATA if ResourceLoader.exists(resource_path) else null
		if actual == null or actual.panel_keys != data.panel_keys or actual.previous_keys != data.previous_keys or actual.overlap_rects != data.overlap_rects or actual.mask_rects != data.mask_rects or actual.source_hashes != data.source_hashes or actual.baker_hash != data.baker_hash or not is_equal_approx(actual.overlap_width, data.overlap_width):
			failures.append("Missing or stale landscape bundle: " + resource_path)
		elif actual.overlaps.resource_path != directory.path_join("overlaps.png") or actual.masks.resource_path != directory.path_join("masks.png"):
			failures.append("Incorrect atlas references: " + resource_path)
	else:
		# Write external texture references directly: PNG import happens after
		# baking, so generation also works in a fresh checkout without .godot/.
		var text := '[gd_resource type="Resource" load_steps=4 format=3]\n\n'
		text += '[ext_resource type="Script" path="res://scenes/levels/landscape_join_data.gd" id="1"]\n'
		text += '[ext_resource type="Texture2D" path="%s/overlaps.png" id="2"]\n' % directory
		text += '[ext_resource type="Texture2D" path="%s/masks.png" id="3"]\n\n[resource]\nscript = ExtResource("1")\n' % directory
		text += 'overlaps = ExtResource("2")\nmasks = ExtResource("3")\n'
		for property in ["panel_keys", "previous_keys", "overlap_width", "overlap_rects", "mask_rects", "source_hashes", "baker_hash"]:
			text += property + " = " + var_to_str(data.get(property)) + "\n"
		var file := FileAccess.open(resource_path, FileAccess.WRITE)
		if file:
			file.store_string(text)
		else:
			failures.append("Cannot write " + resource_path)
	print("Level %d: 9 joins, overlap atlas %s, mask atlas %s" % [number, overlaps.image.get_size(), masks.image.get_size()])
