extends SceneTree

const Tide := preload("res://scenes/objects/atlantis_tide.gd")
const Layout := preload("res://scenes/levels/level_8_layout.gd")
const Difficulty := preload("res://scenes/levels/difficulty.gd")
var failures: Array[String] = []
var level: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count := 1) -> void:
	for tick in count:
		await physics_frame
		if is_instance_valid(level) and level.has_node("AtlantisTide") and not level.tide.is_physics_processing() and not paused:
			level.tide._sync_tide()


func _release() -> void:
	for action in ["move_right", "move_left", "jump", "duck", "attack"]:
		Input.action_release(action)


func _open(number := 8) -> void:
	_release()
	paused = false
	if is_instance_valid(level):
		_stop_audio(level)
		level.free()
	root.get_node("LevelRun").begin_level(number)
	level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0
	await _frames(4)


func _set_time(time: float) -> void:
	level.tide.set_physics_process(false)
	level.tide.elapsed = time
	level.tide._sync_tide()


func _place(at: Vector2) -> void:
	_release()
	level.player.position = at
	level.player.velocity = Vector2.ZERO
	level.player._finish_attack()
	level.player._next_ground_swing = false
	await _frames(4)


func _cycle_and_scaling() -> void:
	_expect(Tide.height_at(0) == 304 and Tide.height_at(4) == 304 and Tide.height_at(12) == 128 and Tide.height_at(18) == 128 and Tide.height_at(26) == 304, "Tide repeats low, fill, high and drain phases")
	for step in 80:
		var t := 4.0 + step * 0.1
		_expect(Tide.height_at(t + 0.1) <= Tide.height_at(t), "Filling is continuous and rises monotonically")
		_expect(Tide.height_at(t + 14.1) >= Tide.height_at(t + 14.0), "Draining is continuous and falls monotonically")
		_expect(is_equal_approx(Tide.height_at(t), Tide.height_at(t + 26)), "Every cycle repeats the same waterline")
	var tuning := Difficulty.for_level(8)
	for definition: Dictionary in Layout.ENEMIES:
		var enemy := level.get_node(String(definition.name))
		var blade: bool = enemy.reefblade
		var speed: float = 30.0 if blade else 26.0
		for time in [0, 8, 15, 22, 26]:
			_set_time(time)
			_expect(enemy.tuning.level == 8 and is_equal_approx(enemy.walk_speed, speed * tuning.speed), "Every Merfolk retains full Level 8 pursuit speed throughout the tide")
			_expect(is_equal_approx(enemy._telegraph(0.65 if blade else 0.7), Difficulty.telegraph(0.65 if blade else 0.7, tuning)), "Level 8 windup scaling is applied to the actual spawned fighter")
			_expect(is_equal_approx(enemy._punish(1.05 if blade else 1.1), Difficulty.punish(1.05 if blade else 1.1, tuning)) and is_equal_approx(enemy._rest(1.25), Difficulty.rest(1.25, tuning)), "Level 8 recovery and cooldown scaling remain applied")
		_expect(enemy.hp == (3 if definition.name == Layout.GATE_GUARD else 2), "Only the captain gets the elite health bonus")
	_expect(Tide.speed_at(280, 280) == 1.0 and Tide.speed_at(280, 272) == 1.0, "Feet and ankle-depth water do not cause sudden drag")
	_expect(is_equal_approx(Tide.speed_at(280, 248), 0.7), "Waist-depth water reaches 30 percent drag")


func _movement() -> void:
	for time in [0.0, 15.0]:
		_set_time(time)
		await _place(Vector2(64, 280))
		var start: Vector2 = level.player.position
		Input.action_press("move_right")
		await _frames(30)
		_release()
		var expected := 90.0 if time == 0 else 63.0
		_expect(absf(level.player.position.x - start.x - expected * 0.5) < 2, "Real movement follows the dry/wet speed budget")
		_expect(is_equal_approx(level.player.movement_speed(), expected), "Theseus moves at 90 dry or 63 fully submerged")
		_expect(is_equal_approx(level.player.sprite.speed_scale, 1.0 if time == 0 else 0.7), "Walk animation follows the wading cadence")
	_set_time(15)
	await _place(Vector2(3264, 152))
	_expect(level.player.movement_speed() > 63.0, "Higher landings reduce water drag")
	level.player.position.y = 112
	level.tide._sync_tide()
	_expect(level.player.movement_speed() == 90.0, "Leaving the water restores speed immediately")
	await _place(Vector2(64, 280))
	level.player.grant_speed_boost()
	_expect(is_equal_approx(level.player.movement_speed(), 90.0 * 1.35 * 0.7), "Wine and water modifiers compose once")
	level.player._speed_boost_left = 0.0


func _jump_peak(time: float) -> float:
	_set_time(time)
	await _place(Vector2(64, 280))
	Input.action_press("jump")
	var peak := 280.0
	for tick in 45:
		await _frames()
		peak = minf(peak, level.player.position.y)
	_release()
	return peak


func _attacks(time: float) -> Array:
	_set_time(time)
	await _place(Vector2(64, 280))
	Input.action_press("attack")
	var history := []
	for tick in 24:
		await _frames()
		history.append([level.player.sprite.animation, level.player.sprite.frame, level.player._attacking, level.player.sprite.speed_scale])
		if tick == 2:
			Input.action_release("attack")
	return history


func _all_jumps() -> void:
	_set_time(15)
	var count := 0
	for platform: Rect2 in Layout.PLATFORMS:
		var below := Layout.surface_at(platform.position.x - 1)
		if below <= platform.position.y:
			continue
		await _place(Vector2(platform.position.x - 18, below))
		Input.action_press("move_right")
		Input.action_press("jump")
		await _frames(40)
		_release()
		_expect(level.player.position.x > platform.position.x and absf(level.player.position.y - platform.position.y) < 0.5, "Every required upward step remains reachable at maximum tide")
		count += 1
	_expect(count == 18, "All eighteen climbs are exercised at high tide")
	for canal: Dictionary in Layout.CANALS:
		for facing in [-1, 1]:
			var start_x: float = canal.position.x - 1 if facing == 1 else canal.position.x + canal.width + 1
			await _place(Vector2(start_x, 280))
			Input.action_press("move_right" if facing == 1 else "move_left")
			Input.action_press("jump")
			var lowest := 0.0
			for tick in 46:
				await _frames()
				lowest = maxf(lowest, level.player.position.y)
			_release()
			_expect(lowest <= 280.5 and (level.player.position.x > canal.position.x + canal.width if facing == 1 else level.player.position.x < canal.position.x), "Both canal gaps can be jumped in either direction at high tide")


func _touch_and_hud() -> void:
	var controls := root.get_node("MobileControls")
	if not controls.enabled:
		return
	_set_time(15)
	await _place(Vector2(64, 280))
	controls._set_pressed("jump", true)
	Input.action_press("jump")
	await _frames(2)
	controls._set_pressed("jump", false)
	Input.action_release("jump")
	Input.action_press("attack")
	var peak := 280.0
	var saw_slash := false
	for tick in 45:
		await _frames()
		peak = minf(peak, level.player.position.y)
		saw_slash = saw_slash or level.player.sprite.animation == "air_swing"
		if tick == 2:
			Input.action_release("attack")
	_expect(peak < 245.0 and saw_slash, "A thumb can leave Jump for Sword underwater without cutting jump height")
	for safe in [Rect2(16, 0, 304, 180), Rect2(0, 0, 304, 180)]:
		level.hud._layout_mobile(safe)
		controls._layout_controls(safe)
		await process_frame
		var indicator: Rect2 = level.tide._display.get_global_rect()
		_expect(safe.encloses(indicator), "Tide indicator follows landscape safe areas")
		_expect(not indicator.intersects(level.hud._area.get_global_rect()) and not indicator.intersects(level.hud._score.get_global_rect()), "Tide status leaves the area title and score readable")
		for action in controls.buttons:
			var button: TouchScreenButton = controls.buttons[action]
			var bounds := Rect2(button.position - Vector2.ONE * button.shape.radius, Vector2.ONE * button.shape.radius * 2)
			_expect(not indicator.intersects(bounds), "Tide status never covers a touch control")
	level.hud._layout_mobile(controls._safe_rect())
	controls._layout_controls(controls._safe_rect())


func _pause_and_reset() -> void:
	_set_time(7)
	level.tide.set_physics_process(true)
	await _frames(4)
	level._set_paused(true)
	var before: float = level.tide.elapsed
	var surface: float = level.tide.water_y
	await _frames(15)
	_expect(level.tide.elapsed == before and level.tide.water_y == surface, "Pause freezes the tide clock and waterline")
	level._set_paused(false)
	await _frames(4)
	_expect(level.tide.elapsed > before, "Resume continues without skipping phases")
	_set_time(15)
	level._on_replay_pressed()
	for tick in 8:
		await physics_frame
	level = current_scene
	_expect(level.level_number == 8 and level.tide.elapsed < 4 and level.player.movement_speed() == 90, "Replay starts a safe low tide and clears drag")
	level.player.position = Vector2(4120, 280)
	level._on_title_pressed()
	for tick in 5:
		await physics_frame
	current_scene._on_load_pressed()
	for tick in 8:
		await physics_frame
	level = current_scene
	_expect(level.level_number == 8 and level.player.position.distance_to(Layout.START) < 1 and level.tide.elapsed < 4 and level.player.movement_speed() == 90, "Retry returns to the entrance and starts at low tide")
	await _open(1)
	_expect(not level.has_node("AtlantisTide") and level.player.movement_speed() == 90, "Leaving Atlantis cannot carry water drag into earlier levels")


func _run() -> void:
	await _open()
	_cycle_and_scaling()
	await _movement()
	var dry_peak := await _jump_peak(0)
	var wet_peak := await _jump_peak(15)
	_expect(is_equal_approx(dry_peak, wet_peak), "Tides do not change jump height or gravity")
	var dry_attack := await _attacks(0)
	var wet_attack := await _attacks(15)
	_expect(dry_attack == wet_attack, "Sword frames and attack timing are identical underwater")
	await _all_jumps()
	await _touch_and_hud()
	await _pause_and_reset()
	_release()
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: cycling tides, actual Level 8 enemy scaling, full-speed Merfolk, player-only drag, higher ground, wine, unchanged jumps/attacks, all mandatory high-tide jumps, pause, replay, entrance retry and other-level isolation.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
