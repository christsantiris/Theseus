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
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _frames()


func _run() -> void:
	await _load_level(1)
	var world := level.get_node("World")
	var backdrop := world.get_node("RoadBackdrop") as Node2D
	var landscapes: Array[Sprite2D] = []
	for child in backdrop.get_children():
		if child is Sprite2D:
			landscapes.append(child)
	_expect(landscapes.size() == 1 and landscapes[0].material == null, "One continuous painting covers the route without a blend shader")
	_expect(not backdrop.has_node("RoadContinuation"), "No repeated road apron is needed")
	var camera := level.player.get_node("Camera2D") as Camera2D
	_expect(camera.limit_bottom == Layout.HEIGHT and camera.limit_bottom > 180 and camera.position.y == -24, "Level 1 now has vertical camera room and the later-level look-ahead")
	var highest_camera := INF
	var lowest_camera := -INF
	var highest_backdrop := INF
	var lowest_backdrop := -INF
	for point: Vector2 in [Vector2(48, 152), Vector2(280, 120), Vector2(400, 104), Vector2(400, 68), Vector2(3440, 120), Vector2(5600, 152)]:
		level.player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames()
		var center := camera.get_screen_center_position()
		var top := center.y - 90
		highest_camera = minf(highest_camera, center.y)
		lowest_camera = maxf(lowest_camera, center.y)
		highest_backdrop = minf(highest_backdrop, backdrop.position.y)
		lowest_backdrop = maxf(lowest_backdrop, backdrop.position.y)
		_expect(backdrop.position.y <= top, "Skyline covers the top of the view through climbs, jumps and descent")
		# Every visible slice stays covered, including joins and newly revealed
		# portions below the original fixed screen. No blank strip may appear.
		for x in range(int(center.x - 160), int(center.x + 160), 32):
			for y in [top + 1, top + 90, top + 179]:
				var covered := false
				for panorama in landscapes:
					var rectangle := Rect2(panorama.global_position, panorama.texture.get_size() * panorama.global_scale)
					covered = covered or rectangle.has_point(Vector2(x, y))
				_expect(covered, "Moving background covers route at %d, %d" % [x, y])
	_expect(lowest_camera - highest_camera > 25 and lowest_backdrop - highest_backdrop > 20, "Camera and distant scenery both respond to the existing terrace route")
	# Sweep the full route, including both texture ends and every old join.
	# A single source must remain in view without resets, wraps or blank pixels.
	var previous_sample := -INF
	for x in range(160, Layout.WIDTH - 160 + 1, 32):
		level.player.position = Vector2(x, Layout.surface_at(x))
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames(1)
		var left := camera.get_screen_center_position() - Vector2(160, 90)
		var painting := landscapes[0]
		var rectangle := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(rectangle.grow(0.001).encloses(Rect2(left, Vector2(320, 180))), "Continuous painting covers the complete camera at route x=%d" % x)
		var sample := (left.x - rectangle.position.x) / painting.scale.x
		_expect(sample >= previous_sample, "Landscape UV never wraps or changes source along the route")
		previous_sample = sample
	_expect(world.midground.get_child_count() == 15, "All fifteen scenery objects remain whole")
	for sprite: Sprite2D in world.midground.get_children():
		_expect(sprite.material == null and sprite.get_child_count() == 0, "Landmarks need no fade masks or repeated aprons")
		_expect(sprite.texture.get_width() <= 4096 and sprite.texture.get_height() <= 4096, "Scenery textures fit mobile limits")
	# The visual frame can travel farther without changing any solid surfaces.
	var ground := world.get_node("Ground") as StaticBody2D
	var ground_shape := ground.get_child(0) as CollisionShape2D
	_expect(Rect2(ground.position - ground_shape.shape.size * 0.5, ground_shape.shape.size) == Rect2(0, 152, 5760, 64), "Ground collision spans the longer road")
	for panorama in landscapes:
		_expect(backdrop.z_index < 0, "Background is behind the solid walkable surfaces")
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
	# Each level owns its cinematic renderer; the shared facade follows its gate.
	for number in [2, 3, 4, 5]:
		await _load_level(number)
		var later_world := level.get_node("World")
		var later_camera := level.player.get_node("Camera2D") as Camera2D
		_expect(later_camera.limit_bottom == level.layout.HEIGHT and later_camera.position.y == (-24 if number >= 4 else 0), "Level %d retains its own camera bounds and framing" % number)
		_expect(later_world.get_script().resource_path != "res://scenes/levels/level_1_geometry.gd", "Level %d keeps its existing renderer" % number)
		var later_gate := level.get_node("TempleGate") as Node2D
		_expect(later_gate.self_modulate.a == 0 and later_gate.has_node("CinematicFacade"), "Level %d uses its own cinematic temple facade" % number)
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Level 1 vertical camera and skyline motion, full moving-view coverage, one continuous panorama, natural proportions, unchanged ground/terrace collisions, cinematic gate state, and Levels 2–5 camera/renderer isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
