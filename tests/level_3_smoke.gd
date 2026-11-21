extends SceneTree

# Run: godot --headless --path . --script res://tests/level_3_smoke.gd --fixed-fps 60
const Town := preload("res://scenes/levels/level_3_layout.gd")
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


func _fresh(number: int = 3) -> Node:
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
	state = root.get_node("LevelRun")
	var level = await _fresh(2)
	level.player.position = Coast.CHECKPOINTS[1].position
	await _frames()
	_expect(state.level_number == 2 and state.checkpoint_index == 1, "Level 2 shrine is saved before entering town")
	level._on_next_pressed()
	_expect(state.level_number == 2, "Continue cannot skip an uncleared level")
	level._on_gate_entered()
	_expect(level.next_button.visible and level.next_button.text == "Continue to Level 3", "Level 2 completion names the correct next level")
	level._on_next_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 3 and state.level_number == 3 and state.can_load(), "Level 2 advances to a saved Level 3 entrance")
	_expect(state.checkpoint_index == -1 and state.checkpoint_defeated.is_empty(), "The new level replaces the old checkpoint and encounter snapshot")
	_expect(level.player.position.distance_to(Town.START) < 1.0, "Town entry starts at the correct ground height")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 3 and level.player.position.distance_to(Town.START) < 1.0, "Title Load resumes Level 3 before a town shrine is lit")
	var previous_id: int = level.get_instance_id()
	level.player._die()
	await _reload(previous_id)
	level = current_scene
	_expect(level.level_number == 3 and level.player.health == 5 and level.player.position.distance_to(Town.START) < 1.0, "Death before the first shrine restarts the town entrance")
	await _check_encounters(level)
	level.player.position = Town.FLASKS[0].position
	await _frames()
	_expect(level.has_node("HealthFlaskGate"), "A full-health player leaves the town flask available")
	level.player.hurt(2)
	level.player.velocity = Vector2.ZERO
	await _frames()
	_expect(level.player.health == 5 and "HealthFlaskGate" in level._collected, "Town flask restores two bars and records collection")
	level.get_node("LamiaWorkshop").die()
	level.player.position = Town.CHECKPOINTS[0].position
	await _frames()
	_expect(state.checkpoint_index == 0 and state.checkpoint_score == 150, "Agora shrine saves Lamia's defeat and score")
	level.get_node("LamiaAgora").die()
	_expect(level._score == 300, "Later Lamia defeat awards its score")
	previous_id = level.get_instance_id()
	level.player._die()
	await _reload(previous_id)
	level = current_scene
	_expect(not level.has_node("LamiaWorkshop") and level.has_node("LamiaAgora"), "Town death restores the shrine's defeated-enemy snapshot")
	_expect(not level.has_node("HealthFlaskGate") and level._score == 150, "Checkpoint restores collected flasks and rolls back later score")
	_expect(level.player.position.distance_to(Town.CHECKPOINTS[0].spawn) < 1.0, "Death restores the Agora's safe spawn")
	level.player.position = Town.CHECKPOINTS[1].position
	await _frames()
	level.player.position = Town.CHECKPOINTS[0].position
	await _frames()
	_expect(state.checkpoint_index == 1, "Backtracking cannot replace the Acropolis shrine")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 3 and level.player.position.distance_to(Town.CHECKPOINTS[1].spawn) < 1.0, "Load resumes the highest town shrine")
	await _traverse()
	level = current_scene
	_expect(level.pause_heading.text == "Level 3 Complete" and level.next_button.visible and level.next_button.text == "Continue to Level 4", "Town completion offers the mountain level")
	_expect(ResourceLoader.exists(level.next_level), "Town continuation points to a real level scene")
	level._on_replay_pressed()
	await _frames()
	_expect(current_scene.level_number == 3 and state.can_load() and state.checkpoint_index == -1, "Replay restarts Level 3 and keeps its entrance load point")
	_expect(current_scene.player.position.distance_to(Town.START) < 1.0, "Replay begins at the city gate")
	current_scene._on_title_pressed()
	await _frames()
	current_scene._on_new_game_pressed()
	await _frames()
	_expect(state.level_number == 1 and not state.can_load(), "New Game resets the campaign to Level 1")
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Level 2→3, entrance/Load/death, four enemy types, Lamia activation, pickups, both shrines, checkpoint rollback, full town traversal, camera, temple entry, completion, replay and New Game.")
	quit(0 if failures.is_empty() else 1)


func _check_encounters(level: Node) -> void:
	var counts := {"hoplite": 0, "lamia": 0, "spartoi": 0, "peltast": 0}
	for encounter: Dictionary in Town.ENEMIES:
		counts[encounter.kind] += 1
		_expect(level.has_node(encounter.name), "Encounter spawns: " + String(encounter.name))
		_expect(encounter.position.y == Town.surface_at(encounter.position.x), String(encounter.name) + " stands on the correct terrace")
		_expect(Town.surface_at(encounter.patrol.x) == encounter.position.y and Town.surface_at(encounter.patrol.y) == encounter.position.y, String(encounter.name) + " has a level patrol landing")
	for kind in counts:
		_expect(counts[kind] == 4, "Town contains four " + kind + " enemies")
	for pickup: Dictionary in Town.FLASKS:
		_expect(pickup.position.y == Town.surface_at(pickup.position.x), "Flask is on terrain: " + String(pickup.name))
	for shrine: Dictionary in Town.CHECKPOINTS:
		_expect(shrine.spawn.y == Town.surface_at(shrine.spawn.x), "Shrine spawn is supported")
	var lamia = level.get_node("LamiaWorkshop")
	# Activate the real controller on its actual platform; the rest of the scene
	# remains isolated so this checks placement independently of other fights.
	level.player.position = lamia.position + Vector2(-56, 0)
	lamia.set_physics_process(true)
	for frame in 60:
		await physics_frame
		if lamia._state == "windup":
			break
	_expect(lamia._state == "windup", "Placed Lamia engages Theseus on her broad workshop platform")
	_expect(lamia.position.distance_to(Town.ENEMIES[3].position) < 0.2, "Lamia stays on her anchored platform")
	lamia.set_physics_process(false)


func _reload(previous_id: int) -> void:
	for frame in 100:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id:
			break
	_isolate(current_scene)
	await _frames()
	_expect(current_scene.get_instance_id() != previous_id, "Death reloads the town scene")


func _traverse() -> void:
	var level = await _fresh()
	var player = level.player
	_expect(player.get_node("Camera2D").limit_right == Town.WIDTH and player.get_node("Camera2D").limit_bottom == Town.HEIGHT, "Camera covers the town's full route")
	_expect(level.get_node("World").has_node("TownTerrace22"), "All twenty-three town terraces have collision")
	level._gate._on_body_entered(player)
	_expect(not level._complete and not level._entering_temple, "Closed town gate cannot complete the level")
	var jumping := false
	var left_floor := false
	var jumps := 0
	var highest := float(Town.FLOOR_Y)
	var camera_top := float(Town.HEIGHT)
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
			for platform: Rect2 in Town.PLATFORMS:
				var distance: float = platform.position.x - player.position.x
				var rise: float = player.position.y - platform.position.y
				if distance > -7.0 and distance <= 27.0 and rise > 4.0:
					Input.action_press("jump")
					jumping = true
					jumps += 1
					break
		if player.position.x > 4700 and not level._gate.unlocked:
			level.get_node(Town.GATE_GUARD).die()
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(level._complete and saw_entry, "Entire town reaches its temple entry and completion; x=%.1f y=%.1f" % [player.position.x, player.position.y])
	_expect(jumps >= 15 and highest < 135, "Route exercises fifteen climbs and the temple district's height")
	_expect(camera_bottom - camera_top > 60.0, "Camera follows the town ascent and descent")
	_expect(state.checkpoint_index == 1, "The normal route reaches both shrine triggers")
	_expect(player.sprite.modulate.a < 0.01 and player.position.distance_to(Town.EXIT + Vector2(2, -20)) < 0.1, "Theseus disappears into the temple doorway")
	print("Town traversal: %d jumps; peak feet y=%.1f; %.1f simulated seconds." % [jumps, highest, state.elapsed_seconds])


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
