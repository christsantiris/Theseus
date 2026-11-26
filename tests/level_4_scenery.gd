extends SceneTree

# Requires a renderer. -- --capture=/absolute/path.png saves a gameplay preview.
const Layout := preload("res://scenes/levels/level_4_layout.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)


func _run() -> void:
	root.get_node("LevelRun").begin_level(4)
	change_scene_to_file("res://scenes/levels/level_4.tscn")
	await scene_changed
	var level := current_scene
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var world: Node = level.get_node("World")
	var painting: Sprite2D = world.backdrop.get_node("ContinuousLandscape")
	var camera: Camera2D = level.player.get_node("Camera2D")
	_expect(painting.texture.get_width() >= 2000 and painting.texture.get_width() <= 4096, "The continuous Troy painting fits mobile GPU limits")
	_expect(world.backdrop.get_child_count() == 1 and painting.material == null and painting.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "One painting covers the route without seams or wrapping")
	_expect(world.midground.get_child_count() == 16 and world.midground.z_index < 0, "Seven bastions, a Trojan horse, four gateways and four retaining walls stay behind the player")
	for sprite: Sprite2D in world.midground.get_children():
		_expect(sprite.texture.get_width() <= 4096 and sprite.texture.get_height() <= 4096 and sprite.texture.get_image().get_pixel(0, 0).a < 0.01, "Trojan props have transparency and fit mobile GPUs")
		var footprint := Rect2(sprite.position, sprite.texture.get_size() * sprite.scale)
		var landing := Layout.surface_at(footprint.position.x)
		for x in range(int(footprint.position.x), int(footprint.end.x)):
			_expect(Layout.surface_at(x) == landing, "%s rests on one landing instead of hanging over a step" % sprite.name)
	_expect(world.midground.has_node("TrojanHorse2112") and world.midground.get_node("TrojanHorse2112").texture == world.TROJAN_HORSE, "The gate court features the complete wooden Trojan horse")
	for index in Layout.PLATFORMS.size():
		var terrace: StaticBody2D = world.get_node("Rampart%d" % index)
		var shape: CollisionShape2D = terrace.get_child(0)
		_expect(Rect2(terrace.position - shape.shape.size * 0.5, shape.shape.size) == Layout.PLATFORMS[index], "Visible rampart stone matches its solid landing")
	for x in range(160, Layout.WIDTH - 159, 64):
		level.player.position = Vector2(x, Layout.surface_at(x) - 70)
		camera.reset_smoothing()
		camera.force_update_scroll()
		world._sync_backdrop()
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var bounds := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(bounds.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Trojan sky and fortifications cover the camera through every climb and jump")
	_expect(level.get_node("TempleGate").self_modulate.a == 0 and world.midground.has_node("Gateway5728"), "The exit uses a Trojan gateway with the shared entry collision")
	level.player.position = Vector2(2112, Layout.surface_at(2112))
	level.player.sprite.flip_h = false
	camera.reset_smoothing()
	camera.force_update_scroll()
	for tick in 5:
		level._set_paused(false)
		await process_frame
	RenderingServer.force_draw(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))
	level._on_gate_entered()
	for tick in 3:
		await process_frame
	var result_safe: Rect2 = root.get_node("MobileControls")._safe_rect() if root.get_node("MobileControls").enabled else root.get_visible_rect()
	_expect(result_safe.encloses(level.pause_panel.get_global_rect()), "Troy's results and music credit fit desktop and mobile landscape: %s in %s" % [level.pause_panel.get_global_rect(), result_safe])
	_expect("Kevin MacLeod" in level.details.text and level.next_button.text == "Continue to Level 5", "Troy credits its composer before continuing into the mountains")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture=").trim_suffix(".png") + "_results.png")
	change_scene_to_file("res://scenes/debug/level_select.tscn")
	await scene_changed
	for tick in 3:
		await process_frame
	var buttons: Array[Node] = current_scene.find_children("*", "Button", true, false)
	_expect(buttons.size() == 9, "The picker offers all nine levels")
	var safe: Rect2 = root.get_node("MobileControls")._safe_rect() if root.get_node("MobileControls").enabled else root.get_visible_rect()
	for button: Button in buttons:
		_expect(safe.encloses(button.get_global_rect()), "The nine-level picker fits desktop and mobile landscape safe areas")
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	print("PASS: Troy panorama coverage, GPU texture limits, grounded bastions, rampart collisions, gateway, music credits and nine-level picker." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
