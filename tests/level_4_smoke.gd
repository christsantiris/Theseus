extends SceneTree

# Run: godot --headless --path . --script res://tests/level_4_smoke.gd --fixed-fps 60
const Mountain := preload("res://scenes/levels/level_4_layout.gd")
const Town := preload("res://scenes/levels/level_3_layout.gd")
var failures: Array[String] = []
var state: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _isolate() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.contact.collision_mask = 0
		enemy.remove_from_group("enemies")
		if enemy.get_script().resource_path.ends_with("satyr.gd"):
			enemy.wine_drop_chance = 0


func _fresh(number: int = 4) -> Node:
	paused = false
	for action in ["move_right", "jump", "attack"]:
		Input.action_release(action)
	if is_instance_valid(current_scene):
		current_scene.free()
	state.begin_level(number)
	var level = load(state.scene_path()).instantiate()
	root.add_child(level)
	current_scene = level
	_isolate()
	await _frames()
	return level


func _reload(previous_id: int) -> void:
	for frame in 100:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id:
			break
	_isolate()
	await _frames()
	_expect(current_scene.get_instance_id() != previous_id, "Death actually reloads Level 4")


func _run() -> void:
	state = root.get_node("LevelRun")
	var level = await _fresh(3)
	level.player.position = Town.CHECKPOINTS[1].position
	await _frames()
	_expect(state.checkpoint_index == 1, "The town shrine is saved before moving to Level 4")
	level._on_next_pressed()
	_expect(state.level_number == 3, "Continue cannot skip an uncleared town")
	level._on_gate_entered()
	_expect(level.next_button.visible and level.next_button.text == "Continue to Level 4", "Town completion offers Level 4")
	level._on_next_pressed()
	await _frames()
	level = current_scene
	_isolate()
	_expect(level.level_number == 4 and state.can_load() and state.checkpoint_index == -1, "Entering the mountains saves a new entrance checkpoint")
	_expect(level.player.position.distance_to(Mountain.START) < 1, "Mountain entrance has the correct spawn")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate()
	_expect(level.level_number == 4 and level.player.position.distance_to(Mountain.START) < 1, "Title Load resumes the highest level before its first shrine")
	var previous: int = level.get_instance_id()
	level.player._die()
	await _reload(previous)
	level = current_scene
	_expect(level.player.health == 5 and level.player.position.distance_to(Mountain.START) < 1, "Death before a shrine restores the mountain entrance")
	await _placements(level)
	level.player.position = Mountain.FLASKS[0].position
	await _frames()
	_expect(level.has_node("HealthFlaskFoothill"), "Full health leaves the first flask available")
	level.player.hurt(2)
	level.player.velocity = Vector2.ZERO
	await _frames()
	_expect(level.player.health == 5 and "HealthFlaskFoothill" in level._collected, "Mountain flask heals and records collection")
	level.get_node("CyclopsFoothills").die()
	level.player.position = Mountain.CHECKPOINTS[0].position
	await _frames()
	_expect(state.checkpoint_index == 0 and state.checkpoint_score == 200, "First mountain shrine snapshots Cyclops score")
	level.get_node("SatyrGarden").die()
	_expect(level._score == 325, "Satyr awards its score in the real level")
	# A final-health spike fall must use the same checkpoint recovery as combat.
	previous = level.get_instance_id()
	level.player.health = 1
	level.player._hurt_lock = 0
	level.player.position = Mountain.PITS[0].position + Vector2(16, 0)
	level.player.velocity = Vector2.ZERO
	await _reload(previous)
	level = current_scene
	_expect(level.player.health == 5 and level.player.position.distance_to(Mountain.CHECKPOINTS[0].spawn) < 1, "Fatal spike damage restores the latest mountain shrine")
	_expect(not level.has_node("CyclopsFoothills") and level.has_node("SatyrGarden") and level._score == 200, "Spike death restores the correct enemy and score snapshot")
	_expect(not level.has_node("HealthFlaskFoothill"), "Checkpoint retains earlier flask collection")
	level.player.position = Mountain.CHECKPOINTS[1].position
	await _frames()
	level.player.position = Mountain.CHECKPOINTS[0].position
	await _frames()
	_expect(state.checkpoint_index == 1, "Backtracking does not replace the summit shrine")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate()
	_expect(level.level_number == 4 and level.player.position.distance_to(Mountain.CHECKPOINTS[1].spawn) < 1, "Load resumes the highest mountain shrine")
	await _traverse()
	level = current_scene
	_expect(level.pause_heading.text == "Level 4 Complete" and not level.next_button.visible, "Mountain temple completes the current final level")
	level._on_next_pressed()
	_expect(state.level_number == 4, "Final completion cannot advance to a missing scene")
	level._on_replay_pressed()
	await _frames()
	_expect(current_scene.level_number == 4 and state.checkpoint_index == -1 and state.can_load(), "Replay restarts Level 4 while retaining its entrance load point")
	_expect(current_scene.player.position.distance_to(Mountain.START) < 1, "Replay starts in the foothills")
	current_scene._on_title_pressed()
	await _frames()
	current_scene._on_new_game_pressed()
	await _frames()
	_expect(state.level_number == 1 and not state.can_load(), "New Game resets the whole campaign")
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Level 3→4, entrance/Load/death, all enemies, Cyclops placement, flasks, both shrines, fatal spike recovery, full mountain traversal with four pit jumps, camera, temple entry, replay and New Game.")
	quit(0 if failures.is_empty() else 1)


func _placements(level: Node) -> void:
	var picker = load("res://scenes/debug/level_select.tscn").instantiate()
	_expect(4 in picker._level_numbers() and picker._validate(4, 2).is_empty(), "Play-test launcher discovers Level 4 and both shrines")
	picker.free()
	var counts := {"cyclops": 0, "satyr": 0, "raider": 0, "telchine": 0}
	for encounter: Dictionary in Mountain.ENEMIES:
		counts[encounter.kind] += 1
		_expect(level.has_node(encounter.name), "Encounter spawns: " + String(encounter.name))
		_expect(encounter.position.y == Mountain.surface_at(encounter.position.x), String(encounter.name) + " stands on safe terrain")
		_expect(Mountain.surface_at(encounter.patrol.x) == encounter.position.y and Mountain.surface_at(encounter.patrol.y) == encounter.position.y, String(encounter.name) + " starts with a supported patrol")
	for kind in counts:
		_expect(counts[kind] == 4, "Four " + kind + " enemies are present")
	for pickup: Dictionary in Mountain.FLASKS:
		_expect(pickup.position.y == Mountain.surface_at(pickup.position.x), "Flask rests on safe terrain")
	for shrine: Dictionary in Mountain.CHECKPOINTS:
		_expect(shrine.spawn.y == Mountain.surface_at(shrine.spawn.x), "Shrine spawn is supported")
	_expect(get_nodes_in_group("spike_pits").size() == 4, "All four pits have active hazards")
	var cyclops = level.get_node("CyclopsFoothills")
	level.player.position = Vector2(756, 248)
	cyclops.set_physics_process(true)
	for frame in 90:
		await physics_frame
		if cyclops._state == "windup":
			break
	_expect(cyclops._state == "windup" and cyclops.position == Mountain.ENEMIES[1].position, "Cyclops sees the approach from its actual elevated throwing position")
	cyclops.set_physics_process(false)


func _traverse() -> void:
	var level = await _fresh()
	var player = level.player
	_expect(player.get_node("Camera2D").limit_right == Mountain.WIDTH and player.get_node("Camera2D").limit_bottom == Mountain.HEIGHT, "Camera covers the full mountain route and pit depths")
	var jumping := false
	var left_floor := false
	var jumps := 0
	var pit_jumps: Array[String] = []
	var highest := float(Mountain.FLOOR_Y)
	var camera_top := float(Mountain.HEIGHT)
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
		if level._complete:
			break
		if not player.is_on_floor() and jumping:
			left_floor = true
		if player.is_on_floor() and jumping and left_floor:
			Input.action_release("jump")
			jumping = false
			left_floor = false
		elif player.is_on_floor() and not jumping:
			for pit: Dictionary in Mountain.PITS:
				var distance: float = pit.position.x - player.position.x
				if distance > 0 and distance <= 12 and absf(player.position.y - pit.position.y) < 1:
					Input.action_press("jump")
					jumping = true
					jumps += 1
					pit_jumps.append(pit.name)
					break
			if not jumping:
				for platform: Rect2 in Mountain.PLATFORMS:
					var distance: float = platform.position.x - player.position.x
					if distance > -7 and distance <= 27 and player.position.y - platform.position.y > 4:
						Input.action_press("jump")
						jumping = true
						jumps += 1
						break
		if player.position.x > 4700 and not level._gate.unlocked:
			level.get_node(Mountain.GATE_GUARD).die()
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(level._complete and saw_entry, "Normal movement traverses the whole mountain route; x=%.1f y=%.1f" % [player.position.x, player.position.y])
	_expect(pit_jumps.size() == 4 and jumps >= 21 and player.health == 5, "Route clears four pits and seventeen climbs without damage or a speed boost")
	_expect(highest < 125 and camera_bottom - camera_top > 90, "Route reaches the high pass with vertical camera scrolling")
	_expect(state.checkpoint_index == 1, "Traversal lights both mountain shrines")
	_expect(player.sprite.modulate.a < 0.01 and player.position.distance_to(Mountain.EXIT + Vector2(2, -20)) < 0.1, "Theseus enters the sanctuary doorway before completion")
	print("Mountain traversal: %d jumps (%d pits); peak feet y=%.1f; %.1f simulated seconds." % [jumps, pit_jumps.size(), highest, state.elapsed_seconds])


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
