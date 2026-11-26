extends SceneTree

const Mountain := preload("res://scenes/levels/level_5_layout.gd")
var failures: Array[String] = []
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 3) -> void:
	for tick in count:
		await process_frame


func _load_level(number: int) -> void:
	paused = false
	if is_instance_valid(level):
		_stop_audio(level)
		level.free()
	root.get_node("LevelRun").begin_level(number)
	level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _frames()


func _run() -> void:
	await _load_level(4)
	var world := level.get_node("World")
	var backdrop := world.get_node("MountainBackdrop") as Node2D
	_expect(backdrop.get_child_count() == 1, "One continuous mountain painting replaces ten separate panoramas")
	_expect(backdrop.z_index < 0, "Scenery stays behind terrain")
	var painting := backdrop.get_node("ContinuousLandscape") as Sprite2D
	_expect(painting.texture.get_width() >= 2000, "Landscape retains source detail")
	_expect(painting.material == null and painting.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "Landscape never blends or wraps")
	_expect(is_equal_approx(painting.texture.get_width() / float(painting.texture.get_height()), 3.0), "Landscape keeps its natural 3:1 aspect ratio")
	var terrain := {"Ground": Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72)}
	for index in Mountain.PLATFORMS.size():
		terrain["MountainTerrace%d" % index] = Mountain.PLATFORMS[index]
	var solid_rectangles: Array[Rect2] = []
	for prefix in terrain:
		var pieces := Mountain.terrain_pieces(terrain[prefix])
		for index in pieces.size():
			var body := world.get_node("%sPart%d" % [prefix, index]) as StaticBody2D
			var collision := body.get_child(0) as CollisionShape2D
			var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
			solid_rectangles.append(rectangle)
			_expect(rectangle == pieces[index], "%s piece %d keeps its exact collision rectangle" % [prefix, index])
			_expect(bool(body.get_meta("spike_pit", false)) == Mountain.is_spike_floor(rectangle), "Spike-floor metadata stays synchronized for %s piece %d" % [prefix, index])
	for pit: Dictionary in Mountain.PITS:
		var rims := maxf(Mountain.surface_at(pit.position.x - 1), Mountain.surface_at(pit.position.x + pit.width))
		_expect(pit.position.y == rims, "%s rim sits at the lowest neighboring ground, so it reads as a recess" % pit.name)
		var opening := Rect2(pit.position + Vector2(1, 0), Vector2(pit.width - 2, pit.depth - 1))
		for rectangle in solid_rectangles:
			_expect(not rectangle.intersects(opening), "%s remains recessed without an invisible bridge" % pit.name)
		var hazard := level.get_node(NodePath(pit.name))
		_expect(hazard.pit_width == pit.width and hazard.pit_depth == pit.depth, "%s keeps its original hazard dimensions" % pit.name)
		var detection := hazard.get_node("Spikes/CollisionShape2D") as CollisionShape2D
		_expect(detection.shape.size == Vector2(pit.width - 4, 8), "%s keeps its original damage area" % pit.name)
	for body_name in ["LeftBoundary", "RightBoundary"]:
		var body := world.get_node(NodePath(body_name)) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		var expected := Rect2(-16, -128, 16, 512) if body_name == "LeftBoundary" else Rect2(Mountain.WIDTH, -128, 16, 512)
		_expect(rectangle == expected, "%s keeps its original collision rectangle" % body_name)
	var camera := level.player.get_node("Camera2D") as Camera2D
	var previous_sample := -INF
	for x in range(160, Mountain.WIDTH - 160 + 1, 32):
		level.player.position = Vector2(x, Mountain.surface_at(x))
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames(1)
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var rectangle := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(rectangle.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Landscape covers the full camera at x=%d" % x)
		var sample := (corner.x - rectangle.position.x) / painting.scale.x
		_expect(sample >= previous_sample, "Landscape UV advances without resetting")
		previous_sample = sample
	for point: Vector2 in [Vector2(48, 280), Vector2(1040, 232), Vector2(2480, 232), Vector2(3440, 136), Vector2(3720, 200), Vector2(5680, 280), Vector2(320, 304), Vector2(1364, 304), Vector2(3108, 192), Vector2(4244, 304), Vector2(3440, 64), Vector2(4640, 352)]:
		level.player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames()
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var rectangle := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(rectangle.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Landscape covers all camera edges at %s" % point)
	_expect(world.midground.get_child_count() == 15, "15 complete landmarks frame the route")
	for sprite: Sprite2D in world.midground.get_children():
		_expect(sprite.material == null and sprite.get_child_count() == 0, "Landmarks need no fades or aprons")
		_expect(sprite.texture.get_width() <= 4096 and sprite.texture.get_height() <= 4096, "Landmarks fit mobile texture limits")
		_expect(sprite.position == sprite.global_position, "Landmarks stay anchored in world space")
		var bounds := Rect2(sprite.position, sprite.texture.get_size() * sprite.scale)
		for pit: Dictionary in Mountain.PITS:
			var opening := Rect2(pit.position, Vector2(pit.width, pit.depth))
			_expect(not bounds.intersects(opening), "Scenery does not bridge spike opening: " + str(sprite.name))
	var gate := level.get_node("TempleGate") as Node2D
	var facade := gate.get_node_or_null("CinematicFacade")
	_expect(facade != null and gate.self_modulate.a == 0, "Mountain exit uses the cinematic facade")
	gate.unlock()
	paused = true
	await _frames()
	_expect(facade._last_unlocked and gate.get_node("Barrier/CollisionShape2D").disabled, "Mountain facade opens during paused entry without changing gate collision logic")
	for number in [1, 2, 3, 5]:
		await _load_level(number)
		_expect(not level.get_node("World").has_node("MountainBackdrop"), "Level %d does not inherit mountain scenery" % number)
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: one continuous mountain landscape and 15 complete landmarks, full-route coverage through the high pass and pit bottoms, natural proportions, unchanged terrain cuts and spike metadata, cinematic gate state, and other-level isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
