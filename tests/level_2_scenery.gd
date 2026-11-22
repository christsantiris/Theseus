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
	_expect(backdrop.get_child_count() == 10, "Five coastal areas each have west/east panoramas")
	_expect(backdrop.z_index < 0, "Coastal scenery stays behind walkable terrain")
	for panorama: Sprite2D in backdrop.get_children():
		_expect(panorama.texture.get_width() >= 2000, "Coastal panorama retains source detail")
		_expect(is_equal_approx(panorama.texture.get_width() / float(panorama.texture.get_height()), 3.0), "Coastal panorama keeps its natural 3:1 aspect ratio")
	for index in Coast.PLATFORMS.size():
		var body := world.get_node("CoastalLedge%d" % index) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == Coast.PLATFORMS[index], "Coastal ledge %d keeps its original collision rectangle" % index)
	var camera := level.player.get_node("Camera2D") as Camera2D
	for point: Vector2 in [Vector2(48, 280), Vector2(1320, 168), Vector2(2472, 216), Vector2(3460, 104), Vector2(3760, 200), Vector2(4688, 280)]:
		level.player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames()
		var top := camera.get_screen_center_position().y - 90.0
		_expect(is_equal_approx(backdrop.position.y, top), "Sea horizon follows the vertical camera at %s" % point)
		for x in range(0, Coast.WIDTH, 32):
			for y in [top + 1.0, top + 90.0, top + 179.0]:
				var covered := false
				for panorama: Sprite2D in backdrop.get_children():
					var rectangle := Rect2(panorama.global_position, panorama.texture.get_size() * panorama.global_scale)
					if rectangle.has_point(Vector2(x, y)):
						covered = true
						break
				_expect(covered, "Coastal panoramas cover world %d, %d" % [x, y])
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
		print("PASS: ten coastal panoramas, full-route coverage through both climbs, natural proportions, original ledge collisions, cinematic gate state, and other-level isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
