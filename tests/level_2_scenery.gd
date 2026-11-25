extends SceneTree

const Coast := preload("res://scenes/levels/level_2_layout.gd")
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
	await _load_level(2)
	var world := level.get_node("World")
	var backdrop := world.get_node("SeaBackdrop") as Node2D
	_expect(backdrop.get_child_count() == 1, "One coastal painting replaces the ten separate views")
	_expect(backdrop.z_index < 0, "Coastal scenery stays behind walkable terrain")
	for panorama: Sprite2D in backdrop.get_children():
		_expect(panorama.texture.get_width() >= 2000, "Coastal panorama retains source detail")
		_expect(panorama.material == null and panorama.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "Coast never blends or wraps its source")
		_expect(is_equal_approx(panorama.texture.get_width() / float(panorama.texture.get_height()), 3.0), "Coastal panorama keeps its natural 3:1 aspect ratio")
	for index in Coast.PLATFORMS.size():
		var body := world.get_node("CoastalLedge%d" % index) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == Coast.PLATFORMS[index], "Coastal ledge %d keeps its original collision rectangle" % index)
	var camera := level.player.get_node("Camera2D") as Camera2D
	var previous_sample := -INF
	for x in range(160, Coast.WIDTH - 160 + 1, 32):
		level.player.position = Vector2(x, Coast.surface_at(x))
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames(1)
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var painting := backdrop.get_child(0) as Sprite2D
		var rectangle := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(rectangle.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Continuous sea covers the complete camera at route x=%d" % x)
		var sample := (corner.x - rectangle.position.x) / painting.scale.x
		_expect(sample >= previous_sample, "Sea UV advances continuously without switching paintings")
		previous_sample = sample
	for point: Vector2 in [Vector2(48, 280), Vector2(1320, 168), Vector2(2472, 216),
		Vector2(3460, 104), Vector2(3460, 66), Vector2(3760, 200), Vector2(5648, 280), Vector2(4640, 320)]:
		level.player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames()
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var painting := backdrop.get_child(0) as Sprite2D
		var rectangle := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(rectangle.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Sea and sky cover low shore, both climbs, summit jumps and descent")
	_expect(world.midground.get_child_count() == 16, "Fourteen coastal landmarks remain complete")
	for sprite: Sprite2D in world.midground.get_children():
		_expect(sprite.material == null and sprite.get_child_count() == 0, "Scenery objects need no fades or repeated aprons")
		_expect(sprite.texture.get_width() <= 4096 and sprite.texture.get_height() <= 4096, "Landmarks fit mobile texture limits")
		_expect(sprite.position == sprite.global_position, "Landmark feet stay anchored in world space through climbs")
	var gate := level.get_node("TempleGate") as Node2D
	var facade := gate.get_node_or_null("CinematicFacade")
	_expect(facade != null and gate.self_modulate.a == 0, "Coastal exit uses the cinematic facade")
	gate.unlock()
	paused = true
	await _frames()
	_expect(facade._last_unlocked and gate.get_node("Barrier/CollisionShape2D").disabled, "Coastal facade opens during paused entry without changing gate collision logic")
	for number in [1, 3, 4, 5]:
		await _load_level(number)
		_expect(not level.get_node("World").has_node("SeaBackdrop"), "Level %d does not inherit coastal scenery" % number)
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: one continuous coastline, sixteen complete landmarks, full-route coverage through both climbs, natural proportions, original ledge collisions, cinematic gate state, and other-level isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
