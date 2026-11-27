extends SceneTree

const Atlantis := preload("res://scenes/levels/level_8_layout.gd")
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
	await _load_level(8)
	var world := level.get_node("World")
	var backdrop := world.get_node("AtlantisBackdrop") as Node2D
	_expect(backdrop.get_child_count() == 1, "One continuous Atlantis painting replaces ten separate panoramas")
	_expect(backdrop.z_index < 0, "Scenery stays behind terrain")
	var painting := backdrop.get_node("ContinuousLandscape") as Sprite2D
	_expect(painting.texture.get_width() >= 2000, "Landscape retains source detail")
	_expect(painting.material == null and painting.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "Landscape never blends or wraps")
	_expect(is_equal_approx(painting.texture.get_width() / float(painting.texture.get_height()), 3.0), "Landscape keeps its natural 3:1 aspect ratio")
	for index in Atlantis.PLATFORMS.size():
		var body := world.get_node("AtlantisTerrace%dPart0" % index) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == Atlantis.PLATFORMS[index], "Atlantis terrace %d keeps its original collision rectangle" % index)
	var solids: Array[Rect2] = []
	for index in Atlantis.terrain_pieces(Rect2(0, 280, 5760, 72)).size():
		var body := world.get_node("GroundPart%d" % index) as StaticBody2D
		var shape := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - shape.shape.size * 0.5, shape.shape.size)
		solids.append(rectangle)
		_expect(rectangle == Atlantis.terrain_pieces(Rect2(0, 280, 5760, 72))[index], "Canal bed and causeway retain their exact cuts")
	for canal: Dictionary in Atlantis.CANALS:
		var opening := Rect2(canal.position, Vector2(canal.width, canal.depth - 1))
		for rectangle in solids:
			_expect(not rectangle.intersects(opening), "Canal opening has no invisible bridge")
		for sprite: Sprite2D in world.midground.get_children():
			_expect(not Rect2(sprite.position, sprite.texture.get_size() * sprite.scale).intersects(opening), "Scenery leaves canal openings visible")
	var boundaries := {
		"LeftBoundary": Rect2(-16, -128, 16, 512),
		"RightBoundary": Rect2(Atlantis.WIDTH, -128, 16, 512),
	}
	for body_name in boundaries:
		var body := world.get_node(NodePath(body_name)) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == boundaries[body_name], "%s keeps its original collision rectangle" % body_name)
	var camera := level.player.get_node("Camera2D") as Camera2D
	var previous_sample := -INF
	for x in range(160, Atlantis.WIDTH - 160 + 1, 32):
		level.player.position = Vector2(x, Atlantis.surface_at(x))
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames(1)
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var rectangle := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(rectangle.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Landscape covers the full camera at x=%d" % x)
		var sample := (corner.x - rectangle.position.x) / painting.scale.x
		_expect(sample >= previous_sample, "Landscape UV advances without resetting")
		previous_sample = sample
	for point: Vector2 in [Vector2(48, 280), Vector2(1000, 232), Vector2(2400, 248), Vector2(3500, 152), Vector2(3780, 216), Vector2(5680, 280), Vector2(3264, 80), Vector2(4640, 352), Vector2(1488, 304), Vector2(4036, 304)]:
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
	var gate := level.get_node("TempleGate") as Node2D
	var facade := gate.get_node_or_null("CinematicFacade")
	_expect(facade != null and gate.self_modulate.a == 0, "Atlantis exit uses the cinematic facade")
	gate.unlock()
	paused = true
	await _frames()
	_expect(facade._last_unlocked and gate.get_node("Barrier/CollisionShape2D").disabled, "Atlantis facade opens during paused entry without changing gate collision logic")
	for number in [1, 2, 3, 4, 5, 6, 7]:
		await _load_level(number)
		_expect(not level.get_node("World").has_node("AtlantisBackdrop"), "Level %d does not inherit Atlantis scenery" % number)
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: one continuous Atlantis landscape and 15 complete landmarks, full-route coverage through the temple climb, natural proportions, original terrace collisions, cinematic gate state, and other-level isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
