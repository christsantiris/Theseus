extends SceneTree

# Requires a rendering backend:
# godot --path . --script res://tests/scenery_art.gd
const BLEND := preload("res://resources/shaders/landscape_blend.gdshader")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _verify_rendered_blend() -> void:
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
	image.fill(Color.BLUE)
	var panel := Sprite2D.new()
	panel.centered = false
	panel.texture = ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	material.shader = BLEND
	material.set_shader_parameter("blend_left", true)
	material.set_shader_parameter("overlap_width", 96.0 / 576.0)
	panel.material = material
	viewport.add_child(panel)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var rendered := viewport.get_texture().get_image()
	# Check actual pixels throughout the height: the old terrain fade reached
	# solid blue after only 12 pixels even though the panels overlap by 96.
	for y in [8, 40, 80]:
		var start := rendered.get_pixel(0, y)
		var early := rendered.get_pixel(12, y)
		var middle := rendered.get_pixel(48, y)
		var late := rendered.get_pixel(84, y)
		var end := rendered.get_pixel(110, y)
		_expect(start.r > 0.98 and start.b < 0.02, "Incoming panel starts transparently at every height")
		_expect(early.r > 0.7 and early.b > 0.01 and early.b < 0.4, "Terrain does not become opaque after a 12-pixel strip")
		_expect(middle.r > 0.35 and middle.b > 0.35, "Both panels contribute at the overlap midpoint")
		_expect(late.b > 0.7 and late.r > 0.01 and late.r < 0.4, "Blend continues through the far side of the overlap")
		_expect(end.b > 0.98 and end.r < 0.02, "Incoming panel is opaque before the previous panel ends")
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
	var parent: Node = world if number == 1 else world.backdrop
	var previous: Sprite2D
	var count := 0
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
		print("PASS: rendered full-height overlap, all 45 landscape joins, both shrine states, all ten shrine triggers and checkpoint saves.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
