extends SceneTree

# Run: godot --headless --path . --script res://tests/level_2_smoke.gd --fixed-fps 60
const Coast := preload("res://scenes/levels/level_2_layout.gd")
var failures: Array[String] = []
var state: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _isolate(level: Node) -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.contact.collision_mask = 0
		enemy.remove_from_group("enemies")


func _fresh(number: int = 2) -> Node:
	paused = false
	for action in ["move_right", "jump", "duck", "attack"]:
		Input.action_release(action)
	if is_instance_valid(current_scene):
		current_scene.free()
	state.begin_level(number)
	var level = load(state.scene_path()).instantiate()
	root.add_child(level)
	current_scene = level
	_isolate(level)
	await _frames()
	return level


func _run() -> void:
	state = root.get_node("LevelRun")
	var level = await _fresh(1)
	_expect(not state.can_load(), "A new game has no saved progress")
	level.player.position = Vector2(3840, 152)
	await _frames()
	_expect(state.checkpoint_index == 1 and state.level_number == 1, "Level 1 shrine saves normally")
	level._on_gate_entered()
	_expect(level.next_button.visible, "Level 1 completion offers Level 2")
	level._on_next_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(state.level_number == 2 and state.checkpoint_index == -1 and state.can_load(), "Entering Level 2 replaces the old shrine with an entrance checkpoint")
	_expect(level.player.position.distance_to(Coast.START) < 1.0, "Level 2 starts at its coastal entrance")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 2 and level.player.position.distance_to(Coast.START) < 1.0, "Load resumes the highest level before any new shrine is lit")
	var old_id: int = level.get_instance_id()
	level.player._die()
	await _reload(old_id)
	level = current_scene
	_expect(level.level_number == 2 and level.player.health == 5 and level.player.position.distance_to(Coast.START) < 1.0, "Death before the first shrine restarts Level 2")
	level.get_node("TelchineRoad").die()
	level.player.position = Coast.CHECKPOINTS[0].position
	await _frames()
	_expect(state.checkpoint_index == 0 and state.checkpoint_score == 100, "Coastal shrine saves Level 2 progress")
	level.get_node("SpartoiQuay").die()
	old_id = level.get_instance_id()
	level.player._die()
	await _reload(old_id)
	level = current_scene
	_expect(not level.has_node("TelchineRoad") and level.has_node("SpartoiQuay"), "Death restores this level's defeated-enemy snapshot")
	_expect(level._score == 100 and level.player.position.distance_to(Coast.CHECKPOINTS[0].spawn) < 1.0, "Death restores the Level 2 shrine and score")
	level.player.position = Coast.CHECKPOINTS[1].position
	await _frames()
	level.player.position = Coast.CHECKPOINTS[0].position
	await _frames()
	_expect(state.checkpoint_index == 1, "Backtracking preserves the highest shrine")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 2 and level.player.position.distance_to(Coast.CHECKPOINTS[1].spawn) < 1.0, "Title Load resumes the latest Level 2 shrine")
	await _traverse()
	level = current_scene
	_expect(not level.next_button.visible and level.pause_heading.text == "Level 2 Complete", "Coastal temple completes Level 2 without a missing next level")
	level._on_replay_pressed()
	await _frames()
	_expect(current_scene.level_number == 2 and state.can_load(), "Replay restarts the current level and retains its entrance checkpoint")
	current_scene._on_title_pressed()
	await _frames()
	current_scene._on_new_game_pressed()
	await _frames()
	_expect(current_scene.level_number == 1 and not state.can_load(), "New Game explicitly resets progression")
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Level 1→2 progression, entrance checkpoint, Load, death, both coastal shrines, snapshot isolation, platform traversal, camera, completion, replay, and New Game.")
	quit(0 if failures.is_empty() else 1)


func _reload(previous_id: int) -> void:
	for frame in 100:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id:
			break
	_isolate(current_scene)
	await _frames()
	_expect(current_scene.get_instance_id() != previous_id, "Death reloads the scene")


func _traverse() -> void:
	var level = await _fresh()
	var player = level.player
	_expect(level.get_node("World").has_node("CoastalLedge29"), "All thirty coastal ledges have collision")
	_expect(player.get_node("Camera2D").limit_bottom == Coast.HEIGHT, "Camera follows the taller coastal route")
	for encounter: Dictionary in Coast.ENEMIES:
		if encounter.kind != "bird":
			_expect(encounter.position.y == Coast.surface_at(encounter.position.x), String(encounter.name) + " starts on terrain")
		else:
			var offset: float = Coast.surface_at(encounter.position.x) - encounter.position.y
			_expect(offset == 8.0 or offset == 44.0, "Bird uses a readable high or low lane")
			_expect(Coast.surface_at(encounter.patrol.x) == Coast.surface_at(encounter.patrol.y), "Bird lane stays above a level landing")
	for pickup: Dictionary in Coast.FLASKS:
		_expect(pickup.position.y == Coast.surface_at(pickup.position.x), "Flask is on terrain")
	var jumping := false
	var left_floor := false
	var jumps := 0
	var highest := float(Coast.FLOOR_Y)
	var camera_highest := float(Coast.HEIGHT)
	var camera_lowest := 0.0
	Input.action_press("move_right")
	for frame in 5500:
		await physics_frame
		highest = minf(highest, player.position.y)
		var camera_y: float = player.get_node("Camera2D").get_screen_center_position().y
		camera_highest = minf(camera_highest, camera_y)
		camera_lowest = maxf(camera_lowest, camera_y)
		if level._complete:
			break
		if not player.is_on_floor() and jumping:
			left_floor = true
		if player.is_on_floor() and jumping and left_floor:
			Input.action_release("jump")
			jumping = false
			left_floor = false
		elif player.is_on_floor() and not jumping:
			for platform: Rect2 in Coast.PLATFORMS:
				var distance: float = platform.position.x - player.position.x
				var rise: float = player.position.y - platform.position.y
				if distance > -7.0 and distance <= 27.0 and rise > 4.0:
					Input.action_press("jump")
					jumping = true
					jumps += 1
					break
		if player.position.x > 4700 and not level._gate.unlocked:
			level.get_node(Coast.GATE_GUARD).die()
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(level._complete, "Entire coast is traversable; final x=%.1f y=%.1f" % [player.position.x, player.position.y])
	_expect(jumps >= 20 and highest < 110, "Route exercises the high terraces and at least twenty jumps")
	_expect(camera_lowest - camera_highest > 80.0, "Camera scrolls vertically through the ascent and descent")
	_expect(state.checkpoint_index == 1, "Route passes both shrine triggers")
	print("Coastal traversal: %d jumps; peak feet y=%.1f; %.1f simulated seconds." % [jumps, highest, state.elapsed_seconds])


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
