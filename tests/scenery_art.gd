extends SceneTree

# Requires a rendering backend:
# godot --path . --script res://tests/scenery_art.gd
const BLEND := preload("res://resources/shaders/landscape_blend.gdshader")
const SEARCH := preload("res://tools/landscape_seam.gd")
const PANELS := preload("res://scenes/levels/landscape_panels.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)


func _color_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _verify_rendered_blend() -> void:
	for scenario in ["columns", "foliage", "sky"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(128, 96)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var backdrop := ColorRect.new()
		backdrop.size = Vector2(128, 96)
		backdrop.color = Color.RED
		viewport.add_child(backdrop)
		var image := Image.create(576, 96, false, Image.FORMAT_RGBA8)
		var under := Image.create(576, 96, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.55, 0.72, 0.90))
		under.fill(Color(0.42, 0.62, 0.86))
		for y in 96:
			if scenario == "columns":
				# A continuous seam can pass through the sky between these two
				# whole columns, rather than fading their full silhouettes.
				for x in range(60, 84):
					image.set_pixel(x, y, Color(0.86, 0.75, 0.55))
				for x in range(24, 48):
					under.set_pixel(480 + x, y, Color(0.84, 0.72, 0.52))
			elif scenario == "foliage":
				for x in 96:
					# Same blue channel in both old-image colors lets us measure
					# blend weight independently of a checkerboard of stone/sky.
					var color := Color(0.84, 0.72, 0.4) if (x / 4 + y / 4) % 2 == 0 else Color(0.25, 0.3, 0.4)
					under.set_pixel(480 + x, y, color)
		# Exercise the actual stacked-atlas path, including a contrasting upper
		# half that must never leak into the lower panorama's overlap.
		var sheet := Image.create(576, 192, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.MAGENTA)
		sheet.blit_rect(image, Rect2i(0, 0, 576, 96), Vector2i(0, 96))
		var atlas := AtlasTexture.new()
		atlas.atlas = ImageTexture.create_from_image(sheet)
		atlas.region = Rect2(0, 96, 576, 96)
		var panel := Sprite2D.new()
		panel.centered = false
		panel.texture = atlas
		# Synthetic artwork has no shipped bake. Exercise the unchanged shader
		# with the offline seam search; real bundles are checked below.
		var strip := under.get_region(Rect2i(480, 0, 96, 96))
		var over := image.get_region(Rect2i(0, 0, 96, 96))
		var material := ShaderMaterial.new()
		material.shader = BLEND
		material.set_shader_parameter("atlas_rect", Vector4(0, 0.5, 1, 0.5))
		material.set_shader_parameter("blend_left", true)
		material.set_shader_parameter("under_tex", ImageTexture.create_from_image(strip))
		material.set_shader_parameter("seam_tex", ImageTexture.create_from_image(SEARCH.seam(strip, over)))
		panel.material = material
		viewport.add_child(panel)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var rendered := viewport.get_texture().get_image()
		for y in 96:
			_expect(_color_error(rendered.get_pixel(0, y), under.get_pixel(480, y)) < 0.025, "Overlap starts at the previous image without a cut")
			_expect(_color_error(rendered.get_pixel(95, y), image.get_pixel(95, y)) < 0.025, "Overlap ends at the incoming image without a vertical cut")
			_expect(_color_error(rendered.get_pixel(110, y), image.get_pixel(110, y)) < 0.025, "Incoming atlas remains unchanged beyond the overlap")
			if scenario == "columns":
				_expect(_color_error(rendered.get_pixel(36, y), under.get_pixel(516, y)) < 0.025, "Previous column keeps its complete solid silhouette")
				_expect(_color_error(rendered.get_pixel(72, y), image.get_pixel(72, y)) < 0.025, "Incoming column keeps its complete solid silhouette")
			elif scenario == "foliage":
				for x in range(1, 96):
					_expect(rendered.get_pixel(x, y).b + 0.015 >= rendered.get_pixel(x - 1, y).b, "Blend passes through one continuous seam, without color-selected holes")
			else:
				_expect(rendered.get_pixel(12, y).r > under.get_pixel(492, y).r + 0.002, "Smooth sky starts blending well before the seam")
				_expect(rendered.get_pixel(84, y).r < image.get_pixel(84, y).r - 0.002, "Smooth sky keeps blending well past the seam")
		viewport.free()


func _verify_level(number: int) -> void:
	root.get_node("LevelRun").begin_level(number)
	var layout = load("res://scenes/levels/level_%d_layout.gd" % number)
	var level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var world: Node = level.get_node("World")
	var parent: Node = world.backdrop
	var previous: Sprite2D
	var count := 0
	if number == 1:
		var continuous := parent.get_node("ContinuousLandscape") as Sprite2D
		_expect(continuous.material == null and continuous.texture == world.PANORAMA_SHEETS[0], "Level 1 uses one unblended painting")
		_expect(world.midground.get_child_count() == 13, "Level 1 has complete independent scenery objects")
	else:
		for child in parent.get_children():
			if not child is Sprite2D or not child.name.begins_with("Landscape"):
				continue
			var panel := child as Sprite2D
			var material := panel.material as ShaderMaterial
			_expect(material.shader == BLEND, "Level %d uses the shared blend" % number)
			_expect(bool(material.get_shader_parameter("blend_left")) == (previous != null), "First panel stays opaque; later panels blend")
			if previous != null:
				var old_end := previous.position.x + previous.texture.get_width() * previous.scale.x
				var overlap := old_end - panel.position.x
				var fade := float(material.get_shader_parameter("overlap_width")) * panel.texture.get_width() * panel.scale.x
				_expect(overlap > 0 and is_equal_approx(fade, overlap), "Level %d join %d blends across its full physical overlap" % [number, count])
			previous = panel
			count += 1
		_expect(count == 10, "Every level retains all ten panoramas")
	for definition in layout.CHECKPOINTS:
		var shrine := level.get_node(String(definition.name)) as Area2D
		var collision := shrine.get_node("CollisionShape2D") as CollisionShape2D
		_expect(collision.shape.size == Vector2(48, 56) and collision.position == Vector2(0, -24), "Cinematic shrine keeps its original activation area")
		_expect(shrine.position == definition.position and shrine.spawn_position == definition.spawn, "Shrine and saved spawn stay in their authored positions")
		_expect(shrine.ART.get_size() == Vector2(1024, 768), "Both detailed shrine states are available")
		shrine.set_lit(false)
		var activations := {"count": 0}
		shrine.activated.connect(func(_checkpoint: Area2D) -> void: activations.count += 1)
		shrine._on_body_entered(level.player)
		shrine._on_body_entered(level.player)
		_expect(shrine.lit and activations.count == 1, "Entering a shrine lights it and saves once")
		_expect(root.get_node("LevelRun").checkpoint_index == shrine.checkpoint_index, "The lit shrine still saves the active checkpoint")
	current_scene = null
	level.free()


func _run() -> void:
	await _verify_rendered_blend()
	for number in range(1, 6):
		_verify_level(number)
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: continuous content-aware seams, solid columns, no color-selected holes or overlap-edge cuts, 36 legacy landscape joins and Level 1 continuous landscape, both shrine states, all ten shrine triggers and checkpoint saves.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
