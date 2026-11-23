extends SceneTree

# Compare standalone decoded strips with GPU atlas sampling for every join,
# including aprons. The baker's --check independently verifies the original
# lossless seam search; compression must not alter atlas lookup or introduce cuts.
const PANELS := preload("res://scenes/levels/landscape_panels.gd")
const ArtImage := preload("res://tests/art_image.gd")
const DATA := preload("res://scenes/levels/landscape_join_data.gd")
var failures: Array[String] = []
var maximum_error := 0
var captures := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
			DirAccess.make_dir_recursive_absolute(captures)
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(576, 288)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _panel(texture: Texture2D) -> Sprite2D:
	var panel := Sprite2D.new()
	panel.texture = texture
	panel.centered = false
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	panel.scale = Vector2.ONE * 576.0 / texture.get_width()
	return panel


func _extend_if_present(panel: Sprite2D) -> void:
	# Downward extensions may be under development in a separate change. Keep
	# this regression check usable when only the seam-baking commit is staged.
	var script: Script = PANELS
	for method in script.get_script_method_list():
		if method.name == "extend_downward":
			script.call("extend_downward", panel, 300.0)
			return


func _run() -> void:
	for number in range(2, 6):
		var bundle := load("res://assets/art/backgrounds/level_%d/_seams/joins.tres" % number) as DATA
		_expect(bundle != null and bundle.panel_keys.size() == 9, "Level %d has nine baked joins" % number)
		if bundle == null:
			continue
		var geometry := load("res://scenes/levels/level_%d_geometry.gd" % number)
		var sheets: Array = geometry.PANORAMA_SHEETS
		var previous: AtlasTexture
		for index in 10:
			var sheet: Texture2D = sheets[index / 2]
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2(0, (index % 2) * sheet.get_height() / 2, sheet.get_width(), sheet.get_height() / 2)
			if previous != null:
				await _compare(number, index, previous, texture)
			previous = texture
	print("Largest before/after channel difference: %d / 255" % maximum_error)
	print("PASS: all 36 rendered legacy joins and aprons match standalone strip sampling within 3/255." if failures.is_empty() else "FAIL: " + str(failures))
	quit(0 if failures.is_empty() else 1)


func _compare(number: int, index: int, previous: Texture2D, incoming: Texture2D) -> void:
	var data := load("res://assets/art/backgrounds/level_%d/_seams/joins.tres" % number) as DATA
	var under := ArtImage.read(data.overlaps).get_region(Rect2i(data.overlap_rects[index - 1]))
	var seam := ArtImage.read(data.masks).get_region(Rect2i(data.mask_rects[index - 1]))
	var reference := _viewport()
	var actual := _viewport()
	var old_panel := _panel(incoming)
	var material := ShaderMaterial.new()
	material.shader = PANELS.BLEND
	material.set_shader_parameter("atlas_rect", PANELS._atlas_rect(incoming))
	material.set_shader_parameter("blend_left", true)
	material.set_shader_parameter("overlap_width", 1.0 / 6.0)
	material.set_shader_parameter("feather_width", (1.0 / 6.0) * 8.0 / 96.0)
	material.set_shader_parameter("under_tex", ImageTexture.create_from_image(under))
	material.set_shader_parameter("seam_tex", ImageTexture.create_from_image(seam))
	old_panel.material = material
	reference.add_child(old_panel)
	_extend_if_present(old_panel)
	var new_panel := _panel(incoming)
	PANELS.prepare(new_panel, true, 1.0 / 6.0, previous)
	actual.add_child(new_panel)
	_extend_if_present(new_panel)
	await process_frame
	RenderingServer.force_draw(false)
	var before_image := reference.get_texture().get_image()
	var after_image := actual.get_texture().get_image()
	if not captures.is_empty() and index == 5:
		before_image.save_png(captures.path_join("level_%d_before.png" % number))
		after_image.save_png(captures.path_join("level_%d_after.png" % number))
	var before := before_image.get_data()
	var after := after_image.get_data()
	var largest := 0
	for channel in before.size():
		largest = maxi(largest, absi(before[channel] - after[channel]))
	maximum_error = maxi(maximum_error, largest)
	_expect(largest <= 3, "Level %d join %d has a rendered channel difference of %d/255" % [number, index, largest])
	reference.free()
	actual.free()
