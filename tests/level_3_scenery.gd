extends SceneTree

const Town := preload("res://scenes/levels/level_3_layout.gd")
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
	await _load_level(3)
	var world := level.get_node("World")
	var backdrop := world.get_node("CityBackdrop") as Node2D
	var road := backdrop.get_node("RoadContinuation") as ColorRect
	var landscapes: Array[Sprite2D] = []
	for child in backdrop.get_children():
		if child is Sprite2D:
			landscapes.append(child)
	_expect(landscapes.size() == 10, "Five city areas each have west/east panoramas")
	_expect(backdrop.z_index < 0, "City scenery stays behind walkable terrain")
	for panorama in landscapes:
		_expect(panorama.texture.get_width() >= 2000, "City panorama retains source detail")
		_expect(is_equal_approx(panorama.texture.get_width() / float(panorama.texture.get_height()), 3.0), "City panorama keeps its natural 3:1 aspect ratio")
	for index in Town.PLATFORMS.size():
		var body := world.get_node("TownTerrace%d" % index) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == Town.PLATFORMS[index], "City terrace %d keeps its original collision rectangle" % index)
	var boundaries := {
		"Ground": Rect2(0, Town.FLOOR_Y, Town.WIDTH, 64),
		"LeftBoundary": Rect2(-16, -128, 16, 512),
		"RightBoundary": Rect2(Town.WIDTH, -128, 16, 512),
	}
	for body_name in boundaries:
		var body := world.get_node(NodePath(body_name)) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == boundaries[body_name], "%s keeps its original collision rectangle" % body_name)
	var camera := level.player.get_node("Camera2D") as Camera2D
	for point: Vector2 in [Vector2(48, 280), Vector2(1000, 232), Vector2(2400, 248), Vector2(3500, 152), Vector2(3780, 216), Vector2(4720, 280)]:
		level.player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames()
		var top := camera.get_screen_center_position().y - 90.0
		_expect(backdrop.position.y <= top and backdrop.position.y + 160.0 <= Town.surface_at(camera.get_screen_center_position().x) + 0.1, "City facades stay visible above the landing at %s" % point)
		for x in range(0, Town.WIDTH, 32):
			for y in [top + 1.0, top + 90.0, top + 179.0]:
				var covered := false
				for panorama in landscapes:
					var rectangle := Rect2(panorama.global_position, panorama.texture.get_size() * panorama.global_scale)
					if rectangle.has_point(Vector2(x, y)):
						covered = true
						break
				covered = covered or Rect2(road.global_position, road.size).has_point(Vector2(x, y))
				_expect(covered, "City panoramas cover world %d, %d" % [x, y])
	var gate := level.get_node("TempleGate") as Node2D
	var facade := gate.get_node_or_null("CinematicFacade")
	_expect(facade != null and gate.self_modulate.a == 0, "City exit uses the cinematic facade")
	gate.unlock()
	paused = true
	await _frames()
	_expect(facade._last_unlocked and gate.get_node("Barrier/CollisionShape2D").disabled, "City facade opens during paused entry without changing gate collision logic")
	for number in [1, 2, 4, 5]:
		await _load_level(number)
		_expect(not level.get_node("World").has_node("CityBackdrop"), "Level %d does not inherit city scenery" % number)
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: ten city panoramas, full-route coverage through the temple climb, natural proportions, original terrace collisions, cinematic gate state, and other-level isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
