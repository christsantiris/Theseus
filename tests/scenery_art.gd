extends SceneTree

# Requires a rendering backend:
# godot --path . --script res://tests/scenery_art.gd
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)


func _verify_level(number: int) -> void:
	root.get_node("LevelRun").begin_level(number)
	var level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	level.player.set_physics_process(false)
	level.player.collision_layer = 0
	level.player.collision_mask = 0
	level.set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var world: Node = level.get_node("World")
	var parent: Node = world.backdrop
	var continuous := parent.get_node("ContinuousLandscape") as Sprite2D
	_expect(parent.get_child_count() == 1 and continuous.material == null and continuous.texture == world.PANORAMA_SHEETS[0], "Level %d uses one unblended painting" % number)
	_expect(continuous.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "Level %d never wraps its landscape" % number)
	_expect(world.midground.get_child_count() == [15, 16, 14, 16, 15, 13, 12, 15, 6][number - 1], "Level %d has complete independent scenery objects" % number)
	_expect(level.find_children("*Shrine", "Area2D", true, false).is_empty(), "Level %d has no checkpoint triggers" % number)
	_expect(level.layout.WIDTH == 5760 and level.layout.TIME_LIMIT == 150.0, "Level %d has the extended route and the 2:30 countdown" % number)
	_expect(level.layout.ENEMIES.size() == [19, 20, 19, 19, 19, 13, 20, 16, 16][number - 1], "Level %d has the expected campaign enemy count" % number)
	var camera: Camera2D = level.player.get_node("Camera2D")
	for x in range(160, level.layout.WIDTH - 159, 64):
		# Check floor, jump headroom and the bottom camera clamp on the full route.
		for y in [level.layout.surface_at(x), level.layout.surface_at(x) - 80, level.layout.HEIGHT]:
			level.player.position = Vector2(x, y)
			camera.reset_smoothing()
			camera.force_update_scroll()
			world._sync_backdrop()
			var corner := camera.get_screen_center_position() - Vector2(160, 90)
			var painting := Rect2(continuous.global_position, continuous.texture.get_size() * continuous.global_scale)
			_expect(painting.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Level %d background covers the extended route and camera edges" % number)
		await process_frame
	current_scene = null
	level.free()


func _run() -> void:
	for number in range(1, 10):
		await _verify_level(number)
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: all nine continuous landscapes, complete scenery objects, removed checkpoint triggers.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
