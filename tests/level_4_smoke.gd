extends SceneTree

const Layout := preload("res://scenes/levels/level_4_layout.gd")
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


func _open(number := 4, score := 700) -> Node:
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
	var level := await _open(3)
	level._on_gate_entered()
	_expect(level.next_button.text == "Continue to Level 4", "The city offers the Trojan level")
	level._on_next_pressed()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 4 and level.layout == Layout and level._score == 700, "The city enters Troy with the carried score")
	_expect(not level.has_node("AtlantisTide") and level.player.movement_speed() == 90, "Troy uses the existing movement without water drag")
	var picker: Node = load("res://scenes/debug/level_select.tscn").instantiate()
	_expect(picker._level_numbers() == [1, 2, 3, 4, 5, 6, 7, 8, 9] and picker._validate(4).is_empty(), "The launcher discovers all nine levels")
	picker.free()
	_expect(root.get_node("GameMusic")._active_path == "res://assets/audio/music/IbnAl-Noor.mp3", "Troy selects its requested soundtrack")
	_expect("Kevin MacLeod (incompetech.com)" in level.completion_text and "http://creativecommons.org/licenses/by/4.0/" in level.completion_text, "Troy includes the supplied soundtrack attribution")
	var counts := {"hoplite": 0, "peltast": 0, "raider": 0}
	for definition: Dictionary in Layout.ENEMIES:
		counts[definition.kind] += 1
		var enemy: Node = level.get_node(String(definition.name))
		_expect(enemy.tuning == Difficulty.for_level(4, definition.name == Layout.GATE_GUARD), "Existing enemies receive Level 4 tuning once")
		_expect(Layout.surface_at(definition.position.x) == definition.position.y, "Enemy starts on the ramparts: " + definition.name)
		_expect(Layout.surface_at(definition.patrol.x) == definition.position.y and Layout.surface_at(definition.patrol.y) == definition.position.y, "Patrol stays on its landing: " + definition.name)
	_expect(counts == {"hoplite": 6, "peltast": 7, "raider": 6}, "Troy reuses nineteen existing soldiers")
	for flask: Dictionary in Layout.FLASKS:
		_expect(Layout.surface_at(flask.position.x) == flask.position.y, "Every flask rests on reachable terrain")
	level.player.position = Layout.FLASKS[0].position
	await _frames()
	_expect(level.has_node("HealthFlaskOuterWall"), "Full health leaves the flask available")
	level.player.hurt(2)
	await _frames()
	_expect(level.player.health == 5 and "HealthFlaskOuterWall" in level._collected, "A Trojan flask restores two health bars")
	level.get_node("RaiderPlain").die()
	_expect(level._score > 700, "Recycled enemies award their normal score")
	level.player._die()
	await scene_changed
	_expect(current_scene.has_method("load_game"), "Death in Troy opens Hades")
	current_scene.load_game()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 4 and level.player.position == Layout.START and level.player.health == 5 and level._score == 700, "Hades restores the Trojan entrance, health and carried score")
	_expect(level.has_node("RaiderPlain") and level.has_node("HealthFlaskOuterWall") and state.elapsed_seconds < 1.0, "Retry restores encounters, flasks and countdown")
	level._on_title_pressed()
	await scene_changed
	current_scene._on_load_pressed()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 4 and level.player.position == Layout.START, "Title Load returns to the Trojan entrance")
	await _traverse()
	level = current_scene
	_expect(level.pause_heading.text == "Level 4 Complete" and level.next_button.text == "Continue to Level 5", "Trojan results name the mountain as Level 5")
	level._on_replay_pressed()
	await scene_changed
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 4 and level.player.health == 5 and state.elapsed_seconds < 1.0, "Replay restores a fresh Trojan attempt")
	level._on_gate_entered()
	level._on_next_pressed()
	await scene_changed
	_expect(current_scene.level_number == 5 and current_scene.layout == load("res://scenes/levels/level_5_layout.gd"), "Troy continues into the mountain sanctuary")
	restore_scores.call()
	_stop_audio(root)
	OS.delay_msec(150)
	print("PASS: city→Troy→mountain, recycled enemies, scaling, healing, death/retry, title restart, replay, complete jump route, timer and temple gate." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _traverse() -> void:
	var level := await _open()
	var player: Node = level.player
	var jumping := false
	var airborne := false
	var jumps := 0
	var highest := float(Layout.FLOOR_Y)
	var tested_guard := false
	var entry_frame := -1
	var walk_advanced := false
	Input.action_press("move_right")
	for tick in 6000:
		await physics_frame
		if level._gate.entering:
			_expect(absf(player.position.y - Layout.FLOOR_Y) < 0.1, "Theseus keeps his feet on the paving throughout the Troy exit")
			_expect(player.sprite.animation == &"walk" and player.sprite.is_playing(), "The walk cycle plays during the scripted entry")
			if entry_frame == -1:
				entry_frame = player.sprite.frame
			walk_advanced = walk_advanced or player.sprite.frame != entry_frame
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
	_expect(level._complete and paused and player.health == 5, "Normal movement and jumps traverse the entire Trojan route without a boost")
	_expect(jumps >= 13 and highest < 190 and state.elapsed_seconds < Layout.TIME_LIMIT, "The route exercises the rampart climbs inside its countdown")
	_expect(walk_advanced and player.sprite.modulate.a < 0.01 and player.position.distance_to(Layout.EXIT + Vector2(2, 0)) < 0.1, "Theseus walks to the doorway at paving height and fades inside it")
	print("Troy traversal: %d jumps, peak feet y=%.1f, %.1f simulated seconds (combat isolated)." % [jumps, highest, state.elapsed_seconds])


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
