extends SceneTree

# Run: godot --headless --path . --script res://tests/level_6_smoke.gd --fixed-fps 60
const Gorge := preload("res://scenes/levels/level_6_layout.gd")
const Mountain := preload("res://scenes/levels/level_5_layout.gd")
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


func _enemy(level: Node, enemy_name: String) -> Node:
	return level.find_child(enemy_name, true, false)


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
		var enemy := _enemy(level, encounter.name)
		if is_instance_valid(enemy):
			_freeze(enemy)
	for pack_name in ["TemplePack", "CausewayPack", "WesternPack", "SanctuaryPack"]:
		var pack := level.get_node_or_null(NodePath(pack_name))
		if pack != null:
			pack.set_physics_process(false)


func _fresh(number: int = 6) -> Node:
	paused = false
	for action in ["move_right", "move_left", "jump", "attack", "duck"]:
		Input.action_release(action)
	if is_instance_valid(current_scene):
		_stop_audio(current_scene)
		current_scene.free()
	state.begin_level(number)
	var level = load(state.scene_path()).instantiate()
	root.add_child(level)
	current_scene = level
	_isolate(level)
	await _frames()
	return level


func _reload(previous_id: int) -> void:
	var hades: Node = null
	for frame in 110:
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
	_expect(current_scene.get_instance_id() != previous_id and current_scene.has_node("Player"), "Load Game restores the gorge after death")


func _progress_and_saves() -> void:
	var level = await _fresh(5)
	level._on_next_pressed()
	_expect(state.level_number == 5, "Continue cannot skip an uncleared mountain level")
	level._on_gate_entered()
	_expect(level.next_button.visible and level.next_button.text == "Continue to Level 6", "Mountain completion offers the gorge")
	level._on_next_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and state.can_load(), "Level 6 remains available for entrance restart")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and level.player.position.distance_to(Gorge.START) < 1, "Title Load resumes Level 6 at its entrance")
	var previous: int = level.get_instance_id()
	level.player._die()
	await _reload(previous)
	level = current_scene
	_expect(level.player.health == 5 and level.player.position.distance_to(Gorge.START) < 1, "Death restores the gorge entrance")
	_placements(level)
	level.player.position = level.get_node("HealthFlaskCauseway").position
	await _frames()
	_expect(level.has_node("HealthFlaskCauseway"), "Full health leaves a flask available")
	level.player.hurt(2)
	level.player.velocity = Vector2.ZERO
	await _frames()
	_expect(level.player.health == 5 and "HealthFlaskCauseway" in level._collected, "A gorge flask heals and records collection")
	_enemy(level, "BullGorgeMouth").take_damage(4)
	_enemy(level, "TemplePupA").take_damage(2)
	_enemy(level, "TemplePupB").take_damage(2)
	_enemy(level, "BullDryRiver").take_damage(4)
	_expect(level._score == 700, "Each pup awards 100 and each bull awards 250")
	previous = level.get_instance_id()
	level.player.health = 1
	level.player._hurt_lock = 0
	level.get_node(Gorge.PITS[0].bridge).elapsed = Gorge.BRIDGE_TIMING.x + Gorge.BRIDGE_TIMING.y
	level.player.position = Gorge.PITS[0].position + Vector2(16, 0)
	level.player.velocity = Vector2.ZERO
	await _reload(previous)
	level = current_scene
	_expect(level.player.health == 5 and level.player.position.distance_to(Gorge.START) < 1 and level._score == 0, "Fatal spikes restart at the entrance with the original score")
	_expect(_enemy(level, "TemplePupA") != null and _enemy(level, "TemplePupB") != null and level.get_node("TemplePack").get_child_count() == 2, "Retry restores both pups")
	_expect(_enemy(level, "BullGorgeMouth") != null and _enemy(level, "BullDryRiver") != null and level.has_node("HealthFlaskCauseway"), "Retry restores all enemies and flasks")
	_enemy(level, "TemplePupA").take_damage(2)
	await _frames()
	var pup := _enemy(level, "TemplePupB")
	pup.collision_layer = 4
	pup.collision_mask = 1
	pup.contact.collision_mask = 2
	pup.add_to_group("enemies")
	pup.set_physics_process(true)
	pup.get_parent().set_physics_process(true)
	level.player.position = pup.global_position + Vector2(-40, 0)
	var attacked := false
	for frame in 140:
		await physics_frame
		if pup._state == "pounce":
			attacked = true
			break
	_expect(attacked and pup._has_focus, "The surviving single pup can still pursue and take an attack turn")
	_isolate(level)
	_expect(level.level_number == 6 and state.can_load(), "Level 6 remains available for entrance restart")
	level._on_title_pressed()
	await _frames()
	current_scene._on_load_pressed()
	await _frames()
	level = current_scene
	_isolate(level)
	_expect(level.level_number == 6 and level.player.position.distance_to(Gorge.START) < 1, "Load resumes the gorge entrance")
	await _guard_combat(level)
	level._on_replay_pressed()
	await _frames()
	_expect(current_scene.level_number == 6 and state.can_load(), "Replay retains the current level")
	_isolate(current_scene)
	_expect(current_scene.level_number == 6 and state.can_load() and current_scene.player.position.distance_to(Gorge.START) < 1 and current_scene.get_node("TemplePack").get_child_count() == 2, "Replay restores the level entrance and both members of each pack")
	current_scene._on_title_pressed()
	await _frames()
	current_scene._on_new_game_pressed()
	await _frames()
	_expect(state.level_number == 1 and not state.can_load(), "New Game resets the campaign to Level 1")


func _placements(level: Node) -> void:
	var picker = load("res://scenes/debug/level_select.tscn").instantiate()
	_expect(6 in picker._level_numbers() and picker._validate(6).is_empty(), "The play-test launcher discovers Level 6 at its entrance")
	picker.free()
	var counts := {"bronze_bull": 0, "cerberus_pup": 0, "hydra": 0}
	for encounter: Dictionary in Gorge.ENEMIES:
		counts[encounter.kind] += 1
		var enemy := _enemy(level, encounter.name)
		_expect(enemy != null, "Encounter spawns: " + String(encounter.name))
		_expect(encounter.position.y == Gorge.surface_at(encounter.position.x) and Gorge.surface_at(encounter.patrol.x) == encounter.position.y and Gorge.surface_at(encounter.patrol.y) == encounter.position.y, String(encounter.name) + " has a supported, flat encounter lane")
		if encounter.has("pack"):
			_expect(enemy.get_parent().name == encounter.pack and enemy.pack == enemy.get_parent(), "Pup belongs to its coordinated pair")
	_expect(counts.bronze_bull == 4 and counts.cerberus_pup == 8 and counts.hydra == 1, "Gorge contains four bulls, four pairs and one Hydra")
	for pack_name in ["TemplePack", "CausewayPack", "WesternPack", "SanctuaryPack"]:
		_expect(level.get_node(NodePath(pack_name)).get_child_count() == 2, "A fresh pack contains exactly two pups")
	for pickup: Dictionary in Gorge.FLASKS:
		_expect(pickup.position.y == Gorge.surface_at(pickup.position.x, pickup.get("bonus", false)), "Flask is supported: " + String(pickup.name))
	for index in Gorge.BONUS_LEDGES.size():
		var ledge: Rect2 = Gorge.BONUS_LEDGES[index]
		var collision: CollisionShape2D = level.get_node("World/BullLedge%d" % index).get_child(0)
		_expect(collision.one_way_collision and Gorge.surface_at(ledge.position.x) - ledge.position.y == 56, "Bonus ledge is above a normal jump and can be approached through its underside")
	_expect(get_nodes_in_group("spike_pits").size() == Gorge.PITS.size(), "All gorge spike recesses have active hazards")


func _swing() -> void:
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _frames(18)


func _guard_combat(level: Node) -> void:
	var guard := _enemy(level, Gorge.GATE_GUARD)
	guard.collision_mask = 1
	guard.set_physics_process(true)
	guard._cooldown = 100
	for head in guard.heads:
		head.collision_layer = 4
		head.add_to_group("enemies")
		head.set_physics_process(true)
	level._gate._on_body_entered(level.player)
	guard.take_damage(100)
	guard.die()
	_expect(not level._gate.unlocked and guard.living_heads() == 3 and not level._complete, "Body damage cannot bypass the Hydra gate guard")
	var before: int = level._score
	level.player.position = guard.position + Vector2(38, 0)
	level.player.velocity = Vector2.ZERO
	level.player.sprite.flip_h = true
	await _frames()
	await _swing()
	await _swing()
	_expect(guard.living_heads() == 2 and not level._gate.unlocked and level._score == before, "Cutting one head in the real level neither opens the gate nor awards a full kill")
	level.player.position = guard.position + Vector2(28, 0)
	for index in 2:
		await _frames(20)
		Input.action_press("jump")
		await _frames(9)
		await _swing()
		Input.action_release("jump")
	await _frames(15)
	_expect(guard.living_heads() == 1 and not level._gate.unlocked, "The final surviving head keeps the temple locked")
	for index in 2:
		await _frames(20)
		Input.action_press("jump")
		await _frames(1)
		await _swing()
		Input.action_release("jump")
	await _frames(15)
	_expect(level._gate.unlocked and level._score == before + 450 and Gorge.GATE_GUARD in level._defeated and level.player.health == 5, "Actual sword and jump attacks defeat every head, award one Hydra kill, and unlock the temple")
	Input.action_press("move_right")
	var saw_entry := false
	for frame in 200:
		await physics_frame
		saw_entry = saw_entry or level._entering_temple
		if level._complete:
			break
	Input.action_release("move_right")
	_expect(level._complete and saw_entry and level.pause_heading.text == "Level 6 Complete" and level.next_button.visible and level.next_button.text == "Continue to Level 7", "Entering the unlocked gorge temple offers Egypt")
	_expect(ResourceLoader.exists(level.next_level), "Gorge continuation points to the playable Atlantis scene")


func _bull_reward() -> void:
	var level = await _fresh()
	var bull := _enemy(level, "BullGorgeMouth")
	bull.collision_layer = 4
	bull.collision_mask = 1
	bull.contact.collision_mask = 2
	bull.get_node("Back").collision_layer = 4
	bull.set_physics_process(true)
	level.player.position = bull.position + Vector2(64, 0)
	await _frames()
	bull.direction = 1
	bull._enter("charge")
	Input.action_press("jump")
	Input.action_press("move_left")
	await _frames(9)
	Input.action_release("move_left")
	Input.action_press("duck")
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("duck")
	Input.action_release("attack")
	await _frames(16)
	Input.action_release("jump")
	_expect(bull.can_ride() and bull.hp == 3 and level.player.is_on_floor(), "The placed bull can be staggered and boarded with a normal jump and downward sword")
	var reached := false
	for frame in 160:
		await physics_frame
		if level.player.is_on_floor() and bull.can_ride() and level.player.position.x >= 528:
			reached = true
			break
	_expect(reached, "The moving bull carries Theseus into range of the bonus ledge")
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("jump")
	_expect(absf(level.player.position.y - 224) < 1 and level.player.is_on_floor(), "Theseus can actually jump from the bull onto the high stone ledge")
	level.player.health = 3
	await _frames(28)
	Input.action_release("move_right")
	_expect(level.player.health == 5 and "HealthFlaskBullLedge" in level._collected, "The optional bull route reaches and collects its health reward")


func _traverse() -> void:
	var level = await _fresh()
	var player = level.player
	_expect(player.get_node("Camera2D").limit_right == Gorge.WIDTH and player.get_node("Camera2D").limit_bottom == Gorge.HEIGHT, "Camera covers the complete gorge and high bonus ledges")
	var jumping := false
	var left_floor := false
	var jumps := 0
	var crossed_bridges := {}
	var highest := float(Gorge.FLOOR_Y)
	var camera_top := float(Gorge.HEIGHT)
	var camera_bottom := 0.0
	var saw_entry := false
	Input.action_press("move_right")
	for frame in 5500:
		await physics_frame
		highest = minf(highest, player.position.y)
		var camera_y: float = player.get_node("Camera2D").get_screen_center_position().y
		camera_top = minf(camera_top, camera_y)
		camera_bottom = maxf(camera_bottom, camera_y)
		saw_entry = saw_entry or level._entering_temple
		if level._complete:
			break
		if not player.is_on_floor() and jumping:
			left_floor = true
		if player.is_on_floor() and jumping and left_floor:
			Input.action_release("jump")
			jumping = false
			left_floor = false
		elif player.is_on_floor() and not jumping:
			var waiting := false
			for pit: Dictionary in Gorge.PITS:
				var distance: float = pit.position.x - player.position.x
				if pit.name in crossed_bridges or distance < 0 or distance > 18:
					continue
				var bridge := level.get_node(pit.bridge)
				if bridge.elapsed <= 1.8:
					crossed_bridges[pit.name] = true
				else:
					waiting = true
				break
			if waiting:
				Input.action_release("move_right")
			else:
				Input.action_press("move_right")
				for platform: Rect2 in Gorge.PLATFORMS:
					var distance: float = platform.position.x - player.position.x
					if distance > -7 and distance <= 27 and player.position.y - platform.position.y > 4:
						Input.action_press("jump")
						jumping = true
						jumps += 1
						break
		if player.position.x > Gorge.EXIT.x - 52 and not level._gate.unlocked:
			for head in _enemy(level, Gorge.GATE_GUARD).heads:
				head.take_damage(2)
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(level._complete and saw_entry, "Normal movement traverses the complete gorge; x=%.1f y=%.1f" % [player.position.x, player.position.y])
	_expect(crossed_bridges.size() == Gorge.PITS.size() and jumps >= 12 and player.health == 5 and highest < 145, "Main route clears all climbs and bridges with no damage")
	_expect(camera_bottom - camera_top > 80, "Traversal scrolls vertically")
	_expect(player.sprite.modulate.a < 0.01 and player.position.distance_to(Gorge.EXIT + Vector2(2, -20)) < 0.1, "Theseus enters the sanctuary doorway before completion")
	print("Gorge traversal: %d jumps (%d bridges); peak feet y=%.1f; %.1f simulated seconds." % [jumps, crossed_bridges.size(), highest, state.elapsed_seconds])


func _pit_input(action: String, pressed: bool, finger := 0) -> void:
	var controls := root.get_node("MobileControls")
	if controls.enabled:
		var touch := InputEventScreenTouch.new()
		touch.index = finger
		touch.position = controls.buttons[action].position
		touch.pressed = pressed
		root.push_input(touch, true)
		Input.flush_buffered_events()
	elif pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _pit_escape() -> void:
	for pit: Dictionary in Gorge.PITS:
		for direction in [-1, 1]:
			var level = await _fresh()
			# Nearby flasks would hide extra damage after escape.
			for definition: Dictionary in Gorge.FLASKS:
				level.get_node(NodePath(definition.name)).free()
			var player = level.player
			var bridge := level.get_node(pit.bridge)
			# Keep the deck retracted to prove escape works without its help.
			bridge.elapsed = Gorge.BRIDGE_TIMING.x + Gorge.BRIDGE_TIMING.y
			bridge.set_physics_process(false)
			bridge._update_solid()
			player.position = pit.position + Vector2(pit.width * 0.5, 0)
			player.velocity = Vector2.ZERO
			await _frames(50)
			_expect(pit.width == 112.0 and player.is_on_floor()
				and absf(player.position.y - pit.position.y - 24.0) < 1 and player.health == 4,
				"%s retains its length and catches Theseus on a shallow spike bed without teleporting" % pit.name)
			_expect(player.movement_speed() == 90.0, "Pit escape uses normal speed without a wine boost")
			var action := "move_right" if direction > 0 else "move_left"
			var launch_x: float = pit.position.x + (pit.width - 16.0 if direction > 0 else 16.0)
			_pit_input(action, true)
			for tick in 60:
				await physics_frame
				if (direction > 0 and player.position.x >= launch_x) or (direction < 0 and player.position.x <= launch_x):
					break
			_pit_input("jump", true, 1)
			await _frames(40)
			_pit_input("jump", false, 1)
			_pit_input(action, false)
			var escaped: bool = player.position.x > pit.position.x + pit.width if direction > 0 else player.position.x < pit.position.x
			_expect(escaped and player.position.y <= pit.position.y + 1 and player.health == 4,
				"%s allows a normal keyboard/touch jump out to side %d without extra spike damage" % [pit.name, direction])


func _run() -> void:
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	state = root.get_node("LevelRun")
	await _progress_and_saves()
	await _bull_reward()
	await _pit_escape()
	await _traverse()
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Level 5→6, entrance/Load/death, placements, per-pup scoring and survivor attacks, spike recovery, actual Hydra gate combat, bull ride and bonus reward, full normal-speed traversal, camera, temple entry, replay and New Game.")
	restore_scores.call()
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
