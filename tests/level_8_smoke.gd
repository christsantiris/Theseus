extends SceneTree

# Run: godot --headless --path . --script res://tests/level_8_smoke.gd --fixed-fps 60
const Atlantis := preload("res://scenes/levels/level_8_layout.gd")
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


func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node.is_in_group("enemies"):
		node.remove_from_group("enemies")
	for child in node.get_children():
		_freeze(child)


func _isolate(level: Node) -> void:
	for encounter: Dictionary in level.layout.ENEMIES:
		var enemy := level.find_child(String(encounter.name), true, false)
		if is_instance_valid(enemy):
			_freeze(enemy)
	for pack in get_nodes_in_group("cerberus_packs"):
		pack.set_physics_process(false)


func _fresh(number: int = 8) -> Node:
	paused = false
	for action in ["move_right", "jump", "attack"]:
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
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	state = root.get_node("LevelRun")
	var level = await _fresh(7)
	level._on_next_pressed()
	_expect(state.level_number == 7, "Continue cannot skip an uncleared level")
	level._on_gate_entered()
	_expect(level.next_button.visible and level.next_button.text == "Continue to Level 8", "Level 7 completion names the correct next level")
	level._on_next_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 8 and state.level_number == 8 and state.can_load(), "Level 7 advances to a current Level 8 entrance")
	_expect(level.player.position.distance_to(Atlantis.START) < 1.0, "Atlantis entry starts at the correct ground height")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 8 and level.player.position.distance_to(Atlantis.START) < 1.0, "Title Load resumes Level 8 at its entrance")
	var previous_id: int = level.get_instance_id()
	level.player._die()
	await _reload(previous_id)
	level = current_scene
	_expect(level.level_number == 8 and level.player.health == 5 and level.player.position.distance_to(Atlantis.START) < 1.0, "Death from any point restarts the Atlantis entrance")
	await _check_encounters(level)
	level.player.position = Atlantis.FLASKS[0].position
	await _frames()
	_expect(level.has_node("HealthFlaskAgora"), "A full-health player leaves the Atlantis flask available")
	level.player.hurt(2)
	level.player.velocity = Vector2.ZERO
	await _frames()
	_expect(level.player.health == 5 and "HealthFlaskAgora" in level._collected, "Atlantis flask restores two bars and records collection")
	level.get_node("MerfolkHarbor").die()
	level.get_node("MerfolkRingQuay").die()
	_expect(level._score == 250, "Later Merfolk defeat awards its score")
	previous_id = level.get_instance_id()
	level.player._die()
	await _reload(previous_id)
	level = current_scene
	_expect(level.has_node("MerfolkHarbor") and level.has_node("MerfolkRingQuay"), "Atlantis death restores all encounters")
	_expect(level.has_node("HealthFlaskAgora") and level._score == 0, "Retry restores flasks and rolls back level score")
	_expect(level.player.position.distance_to(Atlantis.START) < 1.0, "Death restores the level entrance")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 8 and level.player.position.distance_to(Atlantis.START) < 1.0, "Load resumes the Atlantis entrance")
	var canal_level := await _fresh()
	await _canals(canal_level)
	await _traverse()
	level = current_scene
	_expect(level.pause_heading.text == "Level 8 Complete" and level.next_button.visible and level.next_level == "res://scenes/levels/level_9.tscn", "Atlantis continues into the final labyrinth")
	level._on_replay_pressed()
	await _frames()
	_expect(current_scene.level_number == 8 and state.can_load(), "Replay retains the current level")
	_expect(current_scene.player.position.distance_to(Atlantis.START) < 1.0, "Replay begins at the harbor")
	current_scene._on_title_pressed()
	await _frames()
	current_scene._on_new_game_pressed()
	await _frames()
	_expect(state.level_number == 1 and not state.can_load(), "New Game resets the campaign to Level 1")
	paused = false
	_stop_audio(root)
	OS.delay_msec(125)
	if failures.is_empty():
		print("PASS: Level 7→8, entrance/Load/death, Merfolk roles, duckable tridents, safe canal escapes, pickups, entrance retry, full Atlantis traversal, camera, temple entry, completion, replay and New Game.")
	restore_scores.call()
	quit(0 if failures.is_empty() else 1)


func _check_encounters(level: Node) -> void:
	var counts := {"merfolk": 0, "reefblade": 0}
	var total := 0
	var picker = load("res://scenes/debug/level_select.tscn").instantiate()
	_expect(8 in picker._level_numbers() and picker._validate(8).is_empty(), "Debug launcher discovers Atlantis at its entrance")
	picker.free()
	for encounter: Dictionary in Atlantis.ENEMIES:
		counts[encounter.kind] += 1
		var enemy := level.get_node(String(encounter.name))
		total += enemy.points
		_expect(enemy != null and encounter.position.y == Atlantis.surface_at(encounter.position.x), "Enemy is on its landing: " + String(encounter.name))
		_expect(Atlantis.surface_at(encounter.patrol.x) == encounter.position.y and Atlantis.surface_at(encounter.patrol.y) == encounter.position.y, "Patrol stays level: " + String(encounter.name))
		_expect(enemy.hp == (3 if encounter.name == Atlantis.GATE_GUARD else 2), "Only the captain receives one elite health bonus")
	_expect(counts.merfolk == 11 and counts.reefblade == 5 and total == 2250, "Ten trident guards, five Reefblades and one captain award 2250 total")
	for pickup: Dictionary in Atlantis.FLASKS:
		_expect(pickup.position.y == Atlantis.surface_at(pickup.position.x), "Flask is supported")
	var merfolk = level.get_node("MerfolkHarbor")
	level.player.position = merfolk.position + Vector2(-32, 0)
	merfolk.collision_layer = 4
	merfolk.collision_mask = 1
	merfolk.set_physics_process(true)
	for tick in 70:
		await physics_frame
		if merfolk._state == "windup":
			break
	_expect(merfolk._state == "windup", "The real placed trident guard engages on its authored quay")
	merfolk.set_physics_process(false)


func _canals(level: Node) -> void:
	for canal: Dictionary in Atlantis.CANALS:
		for facing in [-1, 1]:
			var player = level.player
			player.position = canal.position + Vector2(canal.width * 0.5, canal.depth)
			player.velocity = Vector2.ZERO
			await _frames(8)
			_expect(player.is_on_floor() and player.health == 5 and absf(player.position.y - 304) < 0.2, "Canal has a safe solid bed without automatic ejection")
			var water: Node = level.get_node("World/" + String(canal.name))
			level._set_paused(true)
			var at: float = water._time
			await _frames(8)
			_expect(is_equal_approx(at, water._time), "Pause freezes local water animation")
			level._set_paused(false)
			var move := "move_right" if facing == 1 else "move_left"
			Input.action_press(move)
			Input.action_press("jump")
			await _frames(38)
			Input.action_release(move)
			Input.action_release("jump")
			_expect(player.position.x > canal.position.x + canal.width if facing == 1 else player.position.x < canal.position.x, "Canal can be escaped in either direction")
			_expect(player.health == 5, "Shallow water never causes damage")


func _reload(previous_id: int) -> void:
	var hades: Node = null
	for frame in 100:
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
	_isolate(current_scene)
	await _frames()
	_expect(current_scene.get_instance_id() != previous_id and current_scene.has_node("Player"), "Load Game restores the Atlantis after death")


func _traverse() -> void:
	var level = await _fresh()
	var player = level.player
	_expect(player.get_node("Camera2D").limit_right == Atlantis.WIDTH and player.get_node("Camera2D").limit_bottom == Atlantis.HEIGHT, "Camera covers the Atlantis's full route")
	_expect(level.get_node("World").has_node("AtlantisTerrace22Part0"), "All twenty-three Atlantis terraces have collision")
	level._gate._on_body_entered(player)
	_expect(not level._complete and not level._entering_temple, "Closed Atlantis gate cannot complete the level")
	var jumping := false
	var left_floor := false
	var jumps := 0
	var highest := float(Atlantis.FLOOR_Y)
	var camera_top := float(Atlantis.HEIGHT)
	var camera_bottom := 0.0
	var saw_entry := false
	Input.action_press("move_right")
	for frame in 5500:
		await physics_frame
		highest = minf(highest, player.position.y)
		var camera_y: float = player.get_node("Camera2D").get_screen_center_position().y
		camera_top = minf(camera_top, camera_y)
		camera_bottom = maxf(camera_bottom, camera_y)
		if level._entering_temple:
			saw_entry = true
			_expect(paused and not player.is_physics_processing(), "Temple entry pauses combat and controls")
		if level._complete:
			break
		if not player.is_on_floor() and jumping:
			left_floor = true
		if player.is_on_floor() and jumping and left_floor:
			Input.action_release("jump")
			jumping = false
			left_floor = false
		elif player.is_on_floor() and not jumping:
			for canal: Dictionary in Atlantis.CANALS:
				var distance: float = canal.position.x - player.position.x
				if distance > -5 and distance <= 3:
					Input.action_press("jump")
					jumping = true
					jumps += 1
			for platform: Rect2 in Atlantis.PLATFORMS:
				var distance: float = platform.position.x - player.position.x
				var rise: float = player.position.y - platform.position.y
				if distance > -7.0 and distance <= 27.0 and rise > 4.0:
					Input.action_press("jump")
					jumping = true
					jumps += 1
					break
		if player.position.x > Atlantis.EXIT.x - 52 and not level._gate.unlocked:
			level.get_node(Atlantis.GATE_GUARD).die()
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(level._complete and saw_entry, "Entire Atlantis reaches its temple entry and completion; x=%.1f y=%.1f" % [player.position.x, player.position.y])
	_expect(jumps >= 17 and highest < 135, "Route exercises fifteen climbs and the temple district's height")
	_expect(camera_bottom - camera_top > 60.0, "Camera follows the Atlantis ascent and descent")
	_expect(player.sprite.modulate.a < 0.01 and player.position.distance_to(Atlantis.EXIT + Vector2(2, -20)) < 0.1, "Theseus disappears into the temple doorway")
	print("Atlantis traversal: %d jumps; peak feet y=%.1f; %.1f simulated seconds." % [jumps, highest, state.elapsed_seconds])


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
