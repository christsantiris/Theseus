extends SceneTree

const Layout := preload("res://scenes/levels/level_1_layout.gd")
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
	await _frames()


func _run() -> void:
	await _load_level(1)
	var world := level.get_node("World")
	var landscapes: Array[Sprite2D] = []
	for child in world.get_children():
		if child is Sprite2D:
			landscapes.append(child)
	_expect(landscapes.size() == 10, "Five sections each have west/east cinematic panoramas")
	# Every visible slice of the fifteen-screen route has background coverage,
	# including the top edge, ground line, and overlapping section transitions.
	for x in range(0, Layout.WIDTH, 16):
		for y in [0.0, 76.0, 151.0]:
			var covered := false
			for panorama in landscapes:
				var rectangle := Rect2(panorama.position, panorama.texture.get_size() * panorama.scale)
				if rectangle.has_point(Vector2(x, y)):
					covered = true
					break
			_expect(covered, "Cinematic background covers route at %d, %d" % [x, y])
	for panorama in landscapes:
		_expect(panorama.z_index < 0, "Background is behind the solid walkable surfaces")
		_expect(panorama.texture.get_width() >= 2000, "Panorama retains cinematic source detail")
		_expect(is_equal_approx(panorama.texture.get_width() / float(panorama.texture.get_height()), 3.0), "Panorama keeps its natural 3:1 aspect ratio")
	for index in Layout.PLATFORMS.size():
		var body := world.get_node("Terrace%d" % index) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rectangle := Rect2(body.position - collision.shape.size * 0.5, collision.shape.size)
		_expect(rectangle == Layout.PLATFORMS[index], "Cinematic terrace %d keeps its exact collision rectangle" % index)
	var gate := level.get_node("TempleGate") as Node2D
	var facade := gate.get_node_or_null("CinematicFacade")
	_expect(facade != null and gate.self_modulate.a == 0, "Level 1 replaces the original exit facade")
	gate.unlock()
	paused = true
	await _frames()
	_expect(facade._last_unlocked and gate.get_node("Barrier/CollisionShape2D").disabled, "Cinematic gate updates its open state during the paused entry sequence")
	# The base level is inherited by every later level; its new art must not leak
	# into their scenery, gate visuals or collision construction.
	for number in [2, 3, 4, 5]:
		await _load_level(number)
		var later_world := level.get_node("World")
		_expect(later_world.get_script().resource_path != "res://scenes/levels/level_1_geometry.gd", "Level %d keeps its existing renderer" % number)
		var later_gate := level.get_node("TempleGate") as Node2D
		_expect(later_gate.self_modulate.a == 1 and not later_gate.has_node("CinematicFacade"), "Level %d keeps its existing temple facade" % number)
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: ten detailed panoramas, full-route coverage, natural aspect ratios, original terrace collisions, cinematic gate state, and Levels 2–5 art isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
