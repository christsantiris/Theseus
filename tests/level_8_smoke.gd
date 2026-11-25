extends SceneTree

const Layout := preload("res://scenes/levels/level_8_layout.gd")
var failures: Array[String] = []
var state: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count := 4) -> void:
	for tick in count:
		await physics_frame


func _isolate(level: Node) -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.remove_from_group("enemies")


func _fresh(number := 8) -> Node:
	paused = false
	for action in ["move_right", "jump", "duck", "attack"]:
		Input.action_release(action)
	if is_instance_valid(current_scene):
		_stop_audio(current_scene)
		current_scene.free()
	state.begin_level(number)
	var level := load(state.scene_path()).instantiate() as Node
	root.add_child(level)
	current_scene = level
	_isolate(level)
	await _frames()
	return level


func _run() -> void:
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	state = root.get_node("LevelRun")
	var level := await _fresh(7)
	level._on_gate_entered()
	_expect(level.next_button.text == "Continue to Level 8", "Atlantis names the final destination")
	level._on_next_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(not level.has_node("AtlantisTide") and level.player.movement_speed() == 90, "Atlantis water does not affect the labyrinth")
	_expect(level.player.position.distance_to(Layout.START) < 1, "Labyrinth entrance is safely grounded")
	var picker := load("res://scenes/debug/level_select.tscn").instantiate() as Node
	_expect(8 in picker._level_numbers() and picker._validate(8).is_empty(), "CLI picker discovers Level 8 at its entrance")
	picker.free()
	var kinds := {"hoplite": 0, "peltast": 0, "raider": 0, "minotaur": 0}
	for encounter: Dictionary in Layout.ENEMIES:
		kinds[encounter.kind] += 1
		var enemy: Node = level.get_node(String(encounter.name))
		_expect(encounter.position.y == Layout.surface_at(encounter.position.x), "Enemy starts on terrain: " + encounter.name)
		_expect(enemy.tuning == load("res://scenes/levels/difficulty.gd").for_level(8, encounter.kind == "minotaur"), "All enemies receive Level 8 difficulty exactly once")
		_expect(Layout.surface_at(encounter.patrol.x) == encounter.position.y and Layout.surface_at(encounter.patrol.y) == encounter.position.y, "Enemy patrol stays on its landing")
	_expect(kinds == {"hoplite": 4, "peltast": 4, "raider": 4, "minotaur": 1}, "Four of each soldier precede one final boss")
	_expect(level.get_node("Minotaur").hp == 8 and not level._gate.unlocked, "Eight-health boss locks the final exit")
	await _scenery(level)
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 8 and level.player.position.distance_to(Layout.START) < 1, "Title Load restarts the highest reached level")
	level.player.position = Vector2(4000, 280)
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.player.position.distance_to(Layout.START) < 1 and level.get_node("Minotaur").alive, "Load restores the level entrance and live boss")
	var previous_id: int = level.get_instance_id()
	level.player._die()
	for tick in 100:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id:
			break
	_expect(current_scene.has_method("load_game"), "Death opens Hades with Level 8 saved")
	if current_scene.has_method("load_game"):
		current_scene.load_game()
		await _frames(10)
		level = current_scene
		_isolate(level)
		_expect(level.level_number == 8 and level.player.health == 5 and level.player.position.distance_to(Layout.START) < 1, "Death reload restores the safe level entrance at full health")
	await _traverse()
	level = current_scene
	_expect(level._complete and level.pause_heading.text == "Theseus Victorious" and not level.next_button.visible and level.next_level.is_empty(), "Escaping after the boss ends the campaign with victory")
	level._on_replay_pressed()
	await _frames()
	_expect(current_scene.level_number == 8 and state.can_load() and current_scene.has_node("Minotaur"), "Replay restores the complete level and boss")
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	print("PASS: Atlantis→labyrinth, Level 8 scaling, entrance retries, soldiers, boss gate, complete jump/corridor route, camera, final victory, and replay." if failures.is_empty() else str(failures))
	restore_scores.call()
	quit(0 if failures.is_empty() else 1)


func _traverse() -> void:
	var level := await _fresh()
	var player: Node = level.player
	var jumping := false
	var airborne := false
	var jumps := 0
	var corridor_frames := 0
	Input.action_press("move_right")
	for tick in 6000:
		await physics_frame
		if level._complete:
			break
		var low := false
		for lintel: Rect2 in Layout.CEILINGS:
			if player.position.x >= lintel.position.x - 30 and player.position.x <= lintel.end.x + 14:
				low = true
		if low:
			corridor_frames += 1
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
		if player.position.x > 4668 and not level._gate.unlocked:
			var boss: Node = level.get_node("Minotaur")
			for hit in 7:
				boss.sword_hit()
			_expect(boss.alive and not level._gate.unlocked, "Boss gate stays locked through seven hits")
			boss.sword_hit()
			_expect(not boss.alive and level._gate.unlocked, "Eighth hit unlocks the final gate")
	for action in ["move_right", "jump", "duck"]:
		Input.action_release(action)
	_expect(level._complete, "Entire route reaches victory: player=" + str(player.position))
	_expect(jumps >= 11 and corridor_frames > 200 and player.health == 5, "Traversal exercises every ascent and both low-roofed corridors without changing player physics")
	print("Labyrinth traversal: %d jumps, %d corridor frames, %.1f seconds (combat isolated)." % [jumps, corridor_frames, state.elapsed_seconds])


func _scenery(level: Node) -> void:
	var world: Node = level.get_node("World")
	var painting: Sprite2D = world.backdrop.get_node("ContinuousLandscape")
	var camera: Camera2D = level.player.get_node("Camera2D")
	var mounts := {}
	for torch: Node2D in world.midground.get_children():
		mounts[torch.name] = painting.to_local(torch.global_position)
	level.player.set_physics_process(false)
	level.player.collision_layer = 0
	for x in range(160, 4641, 64):
		level.player.position = Vector2(x, Layout.surface_at(x))
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames(1)
		world._sync_backdrop()
		var corner := camera.get_screen_center_position() - Vector2(160, 90)
		var bounds := Rect2(painting.global_position, painting.texture.get_size() * painting.global_scale)
		_expect(bounds.grow(0.001).encloses(Rect2(corner, Vector2(320, 180))), "Continuous interior covers the full route at x=%d" % x)
		var lights := 0
		for torch: Node2D in world.midground.get_children():
			_expect(painting.to_local(torch.global_position).is_equal_approx(mounts[torch.name]), "Torch bracket stays on the same wall pixels across camera movement: " + String(torch.name))
			if torch.is_visible_in_tree():
				lights += 1
			_expect(not torch._light.shadow_enabled, "Torch shadows remain disabled for mobile")
		_expect(lights >= 2 and lights <= 4, "Only nearby torches illuminate the visible corridor")
	_expect(world.midground.z_index < 0, "Wall-mounted torches stay behind solid foreground terrain")
	_expect(world.get_node("LabyrinthAmbient").color.r > 0.6, "Ambient lighting preserves character readability")
	level.player.position = Layout.START
	level.player.collision_layer = 2
	level.player.set_physics_process(true)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
