extends SceneTree

const Layout := preload("res://scenes/levels/level_6_layout.gd")
const Difficulty := preload("res://scenes/levels/difficulty.gd")
var failures: Array[String] = []
var state: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)


func _frames(count := 4) -> void:
	for tick in count:
		await physics_frame


func _isolate(level: Node) -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0
			enemy.collision_mask = 0


func _open(number := 6, score := 700) -> Node:
	paused = false
	state.begin_level(number, score)
	change_scene_to_file(state.scene_path())
	await scene_changed
	_isolate(current_scene)
	await _frames()
	return current_scene


func _run() -> void:
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	state = root.get_node("LevelRun")
	var level := await _open(5)
	level._on_gate_entered()
	_expect(level.next_button.text == "Continue to Level 6", "The gorge offers the Egyptian level")
	level._on_next_pressed()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and level.layout == Layout and level._score == 700, "The gorge enters Egypt with the carried score")
	_expect(not level.has_node("AtlantisTide") and level.player.movement_speed() == 90, "Desert sand uses the existing movement without water drag")
	var picker: Node = load("res://scenes/debug/level_select.tscn").instantiate()
	_expect(picker._level_numbers() == [1, 2, 3, 4, 5, 6, 7, 8] and picker._validate(6).is_empty(), "The launcher discovers all eight levels")
	picker.free()
	var counts := {"hoplite": 0, "peltast": 0, "raider": 0, "spartoi": 0}
	for definition: Dictionary in Layout.ENEMIES:
		counts[definition.kind] += 1
		var enemy: Node = level.get_node(String(definition.name))
		_expect(enemy.tuning == Difficulty.for_level(6, definition.name == Layout.GATE_GUARD), "Existing enemies receive Level 6 tuning once")
		_expect(Layout.surface_at(definition.position.x) == definition.position.y, "Enemy starts on sandstone: " + definition.name)
		_expect(Layout.surface_at(definition.patrol.x) == definition.position.y and Layout.surface_at(definition.patrol.y) == definition.position.y, "Patrol stays on its landing: " + definition.name)
	_expect(counts == {"hoplite": 4, "peltast": 4, "raider": 4, "spartoi": 4}, "Egypt recycles four of each requested enemy type")
	for flask: Dictionary in Layout.FLASKS:
		_expect(Layout.surface_at(flask.position.x) == flask.position.y, "Every flask rests on reachable terrain")
	level.player.position = Layout.FLASKS[0].position
	await _frames()
	_expect(level.has_node("HealthFlaskPyramids"), "Full health leaves the flask available")
	level.player.hurt(2)
	await _frames()
	_expect(level.player.health == 5 and "HealthFlaskPyramids" in level._collected, "A desert flask restores two health bars")
	level.get_node("RaiderDunes").die()
	_expect(level._score > 700, "Recycled enemies award their normal score")
	level.player._die()
	await scene_changed
	_expect(current_scene.has_method("load_game"), "Death in Egypt opens Hades")
	current_scene.load_game()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and level.player.position == Layout.START and level.player.health == 5 and level._score == 700, "Hades restores the desert entrance, health and carried score")
	_expect(level.has_node("RaiderDunes") and level.has_node("HealthFlaskPyramids") and state.elapsed_seconds < 1.0, "Retry restores encounters, flasks and countdown")
	level._on_title_pressed()
	await scene_changed
	current_scene._on_load_pressed()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and level.player.position == Layout.START, "Title Restart Level returns to the Egyptian entrance")
	await _traverse()
	level = current_scene
	_expect(level.pause_heading.text == "Level 6 Complete" and level.next_button.text == "Continue to Level 7", "Egyptian results name Atlantis as Level 7")
	level._on_replay_pressed()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and level.player.health == 5 and state.elapsed_seconds < 1.0, "Replay restores a fresh desert attempt")
	level._on_gate_entered()
	level._on_next_pressed()
	await scene_changed
	_expect(current_scene.level_number == 7 and current_scene.has_node("AtlantisTide"), "Egypt continues into Atlantis, including its tide")
	restore_scores.call()
	_stop_audio(root)
	OS.delay_msec(150)
	print("PASS: gorge→Egypt→Atlantis, recycled enemies, scaling, healing, death/retry, title restart, replay, complete jump route, timer and temple gate." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _traverse() -> void:
	var level := await _open()
	var player: Node = level.player
	var jumping := false
	var airborne := false
	var jumps := 0
	var highest := float(Layout.FLOOR_Y)
	var tested_guard := false
	Input.action_press("move_right")
	for tick in 6000:
		await physics_frame
		if level._complete:
			break
		highest = minf(highest, player.position.y)
		if not player.is_on_floor() and jumping:
			airborne = true
		if player.is_on_floor() and jumping and airborne:
			Input.action_release("jump")
			jumping = false
			airborne = false
		elif player.is_on_floor() and not jumping:
			for platform: Rect2 in Layout.PLATFORMS:
				var distance: float = platform.position.x - player.position.x
				if distance > -7 and distance <= 27 and player.position.y - platform.position.y > 4:
					Input.action_press("jump")
					jumping = true
					jumps += 1
					break
		if player.position.x > Layout.EXIT.x - 72 and not tested_guard:
			tested_guard = true
			var guard: Node = level.get_node(Layout.GATE_GUARD)
			guard.sword_hit()
			_expect(guard.hp == 3 and not level._gate.unlocked, "The captain's existing crouch blocks sword hits")
			guard._state = "recover"
			guard.sword_hit()
			_expect(guard.alive and not level._gate.unlocked, "The elite hoplite survives the first sword hit")
			guard.sword_hit()
			_expect(guard.alive and not level._gate.unlocked, "The gate stays locked until the third hit")
			guard.sword_hit()
			_expect(not guard.alive and level._gate.unlocked, "Defeating the captain opens the sun temple")
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(level._complete and paused and player.health == 5, "Normal movement and jumps traverse the entire desert without a boost")
	_expect(jumps >= 13 and highest < 190 and state.elapsed_seconds < Layout.TIME_LIMIT, "The route exercises the sandstone climbs inside its countdown")
	_expect(player.sprite.modulate.a < 0.01 and player.position.distance_to(Layout.EXIT + Vector2(2, -20)) < 0.1, "Theseus walks into the Egyptian temple doorway")
	print("Desert traversal: %d jumps, peak feet y=%.1f, %.1f simulated seconds (combat isolated)." % [jumps, highest, state.elapsed_seconds])


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
