extends SceneTree

# Run: godot --headless --path . --script res://tests/level_1_smoke.gd --fixed-fps 60
const Layout := preload("res://scenes/levels/level_1_layout.gd")
var failures: Array[String] = []
var _run_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _settle(frames: int = 4) -> void:
	for index in frames:
		await physics_frame


func _freeze_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		# Isolate terrain/camera traversal from the soldiers' solid bodies as well
		# as their AI. Otherwise the frozen first raider blocks the route outright.
		enemy.collision_layer = 0
		enemy.get_node("CollisionShape2D").set_deferred("disabled", true)
		enemy.contact.collision_mask = 0


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null


func _fresh_level() -> Node:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	_run_state.begin_run()
	var level = load("res://scenes/levels/level_1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	_freeze_enemies()
	await _settle()
	return level


func _run() -> void:
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	_run_state = root.get_node("LevelRun")
	var level = await _fresh_level()
	var player = level.player
	_expect(get_nodes_in_group("enemies").size() == 16, "All sixteen enemies spawn")
	_expect(player.get_node("Camera2D").limit_right == 4800, "Camera covers the full level")
	for encounter: Dictionary in Layout.ENEMIES:
		_expect(is_equal_approx(encounter.position.y, Layout.surface_at(encounter.position.x)), String(encounter.name) + " stands on terrain")
		_expect(encounter.position.x >= encounter.patrol.x and encounter.position.x <= encounter.patrol.y, String(encounter.name) + " starts inside patrol")
	for pickup: Dictionary in Layout.FLASKS:
		_expect(is_equal_approx(pickup.position.y, Layout.surface_at(pickup.position.x)), String(pickup.name) + " sits on terrain")
	player.position = Vector2(528, 152)
	await _settle()
	_expect(level.has_node("HealthFlaskRoad"), "A full-health player does not consume a flask")
	player.hurt(2)
	player.velocity = Vector2.ZERO
	await _settle()
	_expect(player.health == 5, "Flask restores two health")
	_expect("HealthFlaskRoad" in level._collected, "Flask collection is recorded")
	var distant_enemy = level.get_node("PeltastAqueductWest")
	distant_enemy.set_physics_process(true)
	await _settle()
	_expect(distant_enemy._state_time == 0.0, "Distant encounters stay dormant")
	player.position = Vector2(3104, 120)
	await _settle()
	_expect(distant_enemy._state_time > 0.0, "Nearby encounters wake up")
	distant_enemy.set_physics_process(false)
	level.get_node("Raider").die()
	player.health = 3
	player.position = Vector2(1920, 152)
	await _settle()
	_expect(player.health == 3, "A shrine saves progress without restoring health")
	_expect(_run_state.checkpoint_index == 0, "First shrine activates through its trigger")
	_expect(_run_state.checkpoint_score == 100, "Checkpoint saves the current score")
	_expect(_run_state.spawn_position == Vector2(1952, 152), "Checkpoint has a safe spawn position")
	level.get_node("PeltastAqueductWest").die()
	_expect(level._score == 200, "Post-checkpoint enemy awards points")
	var previous_id: int = level.get_instance_id()
	player._die()
	var hades: Node = null
	for frame in 90:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id:
			hades = current_scene
			break
	_expect(hades != null and hades.has_method("load_game"), "Death opens Hades")
	if hades != null and hades.has_method("load_game"):
		hades.load_game()
	for frame in 20:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene != hades:
			break
	level = current_scene
	_freeze_enemies()
	await _settle()
	player = level.player
	_expect(level.get_instance_id() != previous_id, "Death really reloads the scene")
	_expect(player.health == 5 and absf(player.position.x - 1952.0) < 1.0, "Death restores full health at the checkpoint")
	_expect(level._score == 100, "Death rolls score back to the checkpoint")
	_expect(not level.has_node("Raider"), "Enemies defeated before the checkpoint remain defeated")
	_expect(not level.has_node("HealthFlaskRoad"), "Previously collected flasks remain collected")
	_expect(level.has_node("PeltastAqueductWest"), "Enemies defeated after the checkpoint reset")
	player.position = Vector2(3840, 152)
	await _settle()
	_expect(_run_state.checkpoint_index == 1, "Second shrine activates")
	player.position = Vector2(1920, 152)
	await _settle()
	_expect(_run_state.checkpoint_index == 1, "Backtracking cannot overwrite a later checkpoint")
	level._gate._on_body_entered(player)
	_expect(not level._complete, "Closed gate cannot complete the level")
	level.get_node(Layout.GATE_GUARD).die()
	await _settle()
	_expect(level._gate.unlocked, "Defeating the temple guard opens the gate")
	_expect(level._gate.get_node("Barrier/CollisionShape2D").disabled, "Open gate removes its collision barrier")
	_expect(level._gate.z_index < player.z_index, "Temple is behind Theseus on approach")
	player.position = Layout.EXIT + Vector2(-60, 0)
	var entry_scale: Vector2 = player.sprite.scale
	await _settle()
	_expect(level._entering_temple and paused and not level._complete, "Approaching the steps starts entry before level completion")
	_expect(not player.is_physics_processing() and not level.pause_screen.visible, "Entry freezes combat and input without opening the pause menu")
	level._set_paused(false)
	_expect(paused, "Escape cannot interrupt temple entry")
	await _settle(25)
	_expect(player.position.y < Layout.FLOOR_Y, "Theseus climbs the visible steps")
	for frame in 90:
		if level._complete:
			break
		await physics_frame
	_expect(player.position.distance_to(Layout.EXIT + Vector2(2, -20)) < 0.1, "Entry ends inside the doorway")
	_expect(player.sprite.modulate.a < 0.01, "Theseus disappears into the temple before the clear screen")
	_expect(player.sprite.scale.is_equal_approx(entry_scale * 0.72), "Temple entry shrinks the cinematic sprite relative to its game scale")
	_expect(level._complete and paused, "Level completion pauses the world")
	_expect(level.replay_button.visible and not level.resume_button.visible, "Completion offers replay instead of resume")
	level._set_paused(false)
	_expect(paused, "Completion cannot accidentally resume combat")
	level._on_replay_pressed()
	await _settle()
	_expect(_run_state.checkpoint_index == -1 and _run_state.checkpoint_score == 0, "Replay clears checkpoint and score state")
	_expect(absf(current_scene.player.position.x - 48.0) < 1.0, "Replay starts at the beginning")
	await _traverse_route()
	Input.action_release("move_right")
	Input.action_release("jump")
	current_scene._on_title_pressed()
	await _settle()
	_expect(current_scene.get_script().resource_path.ends_with("main.gd"), "Completion can return to the title")
	current_scene._on_new_game_pressed()
	await _settle()
	_expect(_run_state.checkpoint_index == -1 and current_scene._score == 0, "New Game clears the previous run")
	_expect(absf(current_scene.player.position.x - 48.0) < 1.0, "New Game starts at the road entrance")
	paused = false
	_stop_audio(root)
	# Allow the audio mixer to release MP3 playbacks after the rapid scene reloads.
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: layout placement, health pickup, both checkpoints, actual death/reload, state rollback, gate, completion, replay, and full physics traversal.")
	else:
		print("FAILURES: ", failures)
	restore_scores.call()
	quit(0 if failures.is_empty() else 1)


func _traverse_route() -> void:
	var level = await _fresh_level()
	var player = level.player
	var jump_held := false
	var jump_left_floor := false
	var jumps := 0
	var camera := player.get_node("Camera2D") as Camera2D
	var highest_camera := camera.get_screen_center_position().y
	var lowest_camera := highest_camera
	Input.action_press("move_right")
	for frame in 5000:
		await physics_frame
		highest_camera = minf(highest_camera, camera.get_screen_center_position().y)
		lowest_camera = maxf(lowest_camera, camera.get_screen_center_position().y)
		if level._complete:
			break
		if not player.is_on_floor() and jump_held:
			jump_left_floor = true
		if player.is_on_floor() and jump_held and jump_left_floor:
			Input.action_release("jump")
			jump_held = false
			jump_left_floor = false
		elif player.is_on_floor() and not jump_held:
			for platform: Rect2 in Layout.PLATFORMS:
				var distance: float = platform.position.x - player.position.x
				var rise: float = player.position.y - platform.position.y
				if distance > -7.0 and distance <= 27.0 and rise > 4.0:
					Input.action_press("jump")
					jump_held = true
					jumps += 1
					break
		if player.position.x > 4700 and not level._gate.unlocked:
			level.get_node(Layout.GATE_GUARD).die()
	_expect(level._complete, "The complete route is traversable with real movement and jumping; final x=%.1f" % player.position.x)
	_expect(_run_state.checkpoint_index == 1, "Traversal reaches both shrine triggers")
	_expect(jumps >= 10, "Traversal exercises the terrace jumps")
	_expect(lowest_camera - highest_camera > 25, "Normal movement and terrace jumps now scroll the Level 1 camera vertically")
	print("Traversal: %.1f pixels, %d jumps, %.1f simulated seconds." % [player.position.x, jumps, _run_state.elapsed_seconds])
