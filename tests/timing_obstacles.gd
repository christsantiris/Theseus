extends SceneTree

var _failures := 0
var _controls: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for tick in count:
		await physics_frame


func _move(action: String, pressed: bool, finger := 0) -> void:
	if _controls.enabled:
		var touch := InputEventScreenTouch.new()
		touch.index = finger
		touch.position = _controls.buttons[action].position
		touch.pressed = pressed
		root.push_input(touch, true)
		Input.flush_buffered_events()
	elif pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _open_level(number: int) -> Node:
	root.get_node("LevelRun").begin_level(number)
	change_scene_to_file("res://scenes/levels/level_%d.tscn" % number)
	await scene_changed
	for enemy in get_nodes_in_group("enemies"):
		# Remove the encounter root so coordinated packs and Hydra heads leave
		# the tree together with the body that owns them.
		while enemy.get_parent() != current_scene:
			enemy = enemy.get_parent()
		enemy.queue_free()
	await process_frame
	await _frames(3)
	return current_scene


func _place(player: CharacterBody2D, target: Vector2) -> void:
	player.global_position = target
	player.velocity = Vector2.ZERO
	player.health = player.MAX_HEALTH
	player._hurt_lock = 0.0


func _run() -> void:
	_controls = root.get_node("MobileControls")
	for number in range(1, 10):
		var level := await _open_level(number)
		var player: CharacterBody2D = level.player
		if number == 2:
			for crossing: Dictionary in level.layout.QUAY_CROSSINGS:
				await _check_quay_slabs(level, player, crossing.name)
			continue
		if number == 8:
			_expect(not level.hud._root.has_node("TideStatus"), "Atlantis has no tide countdown display")
			for definition: Dictionary in level.layout.JET_BANKS:
				await _check_atlantis_jets(level, level.get_node(definition.name), player)
			continue
		var obstacle_name: String = level.layout.PITS[0].bridge if number == 6 else level.layout.TIMING_OBSTACLE.name
		var obstacle: Node2D = level.get_node(obstacle_name)
		var origin := obstacle.global_position
		var idle: float = obstacle.durations.x
		var warning: float = obstacle.durations.y
		var active: float = obstacle.durations.z
		_expect(absf(obstacle.elapsed) < 0.25, "Level %d begins with a fresh cycle" % number)
		paused = true
		var before: float = obstacle.elapsed
		await _frames(4)
		_expect(obstacle.elapsed == before, "Level %d freezes the obstacle while paused" % number)
		paused = false

		match number:
			5:
				await _check_rockfall(level, level.get_node(level.layout.GARDEN_ROCKFALL.name), player)
				await _check_rockfall(level, obstacle, player)
			6:
				for pit: Dictionary in level.layout.PITS:
					await _check_bridge(level.get_node(pit.bridge), player)
			9:
				await _check_gate(obstacle, player)
			_:
				_expect(level.layout.surface_at(origin.x) == origin.y and level.layout.surface_at(origin.x + obstacle.width - 1) == origin.y,
					"Level %d obstacle follows a flat section of the route" % number)
				if warning > 0:
					obstacle.elapsed = idle + warning / 2
					_expect(obstacle._warning() and not obstacle._danger_rect().has_area(), "Level %d warning gives a safe cue" % number)
				obstacle.elapsed = idle + warning + active / 2
				var danger: Rect2 = obstacle._danger_rect()
				var feet_y := minf(0.0, danger.get_center().y + 20.0)
				_place(player, origin + Vector2(danger.get_center().x, feet_y))
				await _frames(3)
				_expect(player.health == player.MAX_HEALTH - 1, "Level %d active hazard costs one health" % number)
				if number == 1:
					await _check_weight(obstacle, player)
				if number == 7:
					await _check_sunbeam(obstacle, player)
				if number == 4:
					obstacle.elapsed = 0.0
					_place(player, origin + Vector2(obstacle.width / 2, 0))
					await _frames(4)
					_move("duck", true)
					await _frames(3)
					obstacle.elapsed = idle + warning
					await _frames(42)
					_expect(player.health == player.MAX_HEALTH, "Ducking clears the arrow volley")
					_move("duck", false)
	if _failures == 0:
		print("PASS: nine timing obstacles, pause, damage, duck, bridge, gate, and high-tide crossing (%s)." % ("touch" if _controls.enabled else "desktop"))
	quit(int(_failures > 0))


func _check_quay_slabs(level: Node, player: CharacterBody2D, crossing: String) -> void:
	var first := level.get_node(crossing + "QuaySlab1") as StaticBody2D
	var second := level.get_node(crossing + "QuaySlab2") as StaticBody2D
	var pit: Node2D = level.get_node(crossing + "QuayPit")
	var origin := first.global_position
	var width: float = level.layout.QUAY_PIT_WIDTH
	_expect(level.layout.surface_at(origin.x - 1) == origin.y
		and level.layout.surface_at(origin.x + width) == origin.y,
		crossing + " has a solid bank on both sides")
	_expect(pit.z_index > level.get_node("World/SeaBackdrop").z_index and pit.z_index < player.z_index,
		crossing + " spikes render above the backdrop and behind Theseus")
	await _frames(45)
	_expect(first.elapsed < 0.0 and first.collision_layer == 1, "Quay slabs wait for a footstep")
	_place(player, origin + Vector2(12, -4))
	await _frames(16)
	_expect(first.elapsed >= 0.0 and first.collision_layer == 1 and second.elapsed < 0.0,
		"A footstep starts only the slab beneath Theseus")
	var before: float = first.elapsed
	paused = true
	await _frames(35)
	_expect(first.elapsed == before and first.collision_layer == 1, "Pausing freezes the crumbling slab")
	paused = false
	await _frames(55)
	_expect(first.collision_layer == 0 and player.global_position.y > origin.y + 14
		and player.health == player.MAX_HEALTH - 1, crossing + " drops Theseus onto damaging spikes")
	_move("move_right", true)
	await _frames(31)
	_move("jump", true, 1)
	await _frames(18)
	_move("move_right", false)
	await _frames(21)
	_move("jump", false, 1)
	_expect(player.global_position.x > origin.x + width and absf(player.global_position.y - origin.y) < 1.0
		and player.health == player.MAX_HEALTH - 1, crossing + " allows Theseus to jump onto the far bank")
	await _frames(80)
	_expect(first.elapsed < 0.0 and first.collision_layer == 1, crossing + " slabs reset after the fall")
	_place(player, origin + Vector2(-12, 0))
	await _frames(4)
	_move("move_right", true)
	await _frames(66)
	_move("move_right", false)
	_expect(player.global_position.x > origin.x + width and player.health == player.MAX_HEALTH,
		"Continuously moving crosses all three quay slabs before they fall")


func _check_rockfall(level: Node, obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	var label := String(obstacle.name)
	var approach := origin.x - 146.0
	_place(player, Vector2(approach, level.layout.surface_at(approach)))
	await _frames(4)
	_expect(obstacle.elapsed == 0.0, label + " waits for Theseus to get close")
	_move("move_right", true)
	await _frames(15)
	_expect(obstacle._warning(), label + " warns while Theseus is approaching")
	await _frames(35)
	_move("move_right", false)
	var first: Rect2 = obstacle._danger_rect()
	_expect(player.global_position.x < origin.x and first.has_area() and first.position.y < -80,
		label + " starts falling high above the path before Theseus enters")
	await _frames(26)
	var falling: Rect2 = obstacle._danger_rect()
	_expect(falling.has_area() and falling.position.y > first.position.y,
		label + " keeps the first boulder visible as it falls")
	var second_impact: float = obstacle.durations.x + obstacle.durations.y + obstacle.ROCK_INTERVAL + obstacle.ROCK_FALL_SECONDS
	obstacle.elapsed = second_impact
	var second: Rect2 = obstacle._danger_rect()
	_expect(second.position.x > first.position.x, label + " then drops a second boulder")
	_place(player, origin + Vector2(second.get_center().x, 0))
	await _frames(3)
	_expect(player.health == player.MAX_HEALTH - 1, label + " damages Theseus at the impact point")
	_expect(level.layout.surface_at(origin.x) == origin.y
		and level.layout.surface_at(origin.x + obstacle.width - 1) == origin.y,
		label + " follows a flat section of the route")


func _check_weight(obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	_place(player, origin + Vector2(-9, 0))
	obstacle.elapsed = obstacle.durations.z
	await _frames(4)
	obstacle.elapsed = 1.65
	_move("move_right", true)
	await _frames(82)
	_move("move_right", false)
	_expect(player.global_position.x > origin.x + obstacle.width and player.health == player.MAX_HEALTH,
		"Running under the weight as it swings high clears the colonnade")


func _check_sunbeam(obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	_place(player, origin + Vector2(27, 0))
	obstacle.elapsed = obstacle.durations.x + obstacle.durations.y + obstacle.durations.z
	await _frames(4)
	obstacle.elapsed = 4.35
	_move("move_right", true)
	_move("jump", true, 1)
	await _frames(42)
	_move("move_right", false)
	_move("jump", false, 1)
	_expect(player.global_position.x > origin.x + obstacle.width and player.health == player.MAX_HEALTH,
		"A timed running jump clears the approaching sunbeam")


func _check_bridge(obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	_place(player, origin + Vector2(-12, 0))
	obstacle.elapsed = 0.0
	await _frames(4)
	_move("move_right", true)
	await _frames(100)
	_move("move_right", false)
	_expect(player.global_position.x > origin.x + obstacle.width and player.health == player.MAX_HEALTH,
		"The extended bridge carries a walking player across")
	# A boosted full-height jump from the edge is the longest normal jump.
	_place(player, origin + Vector2(-12, 0))
	obstacle.elapsed = obstacle.durations.x + obstacle.durations.y
	await _frames(4)
	_place(player, origin + Vector2(4, 0))
	await _frames(3)
	player.grant_speed_boost()
	_move("move_right", true)
	_move("jump", true, 1)
	await _frames(15)
	_expect(player.global_position.y < origin.y - 25.0, "Theseus reaches full jump height at " + String(obstacle.name))
	await _frames(25)
	_move("move_right", false)
	_move("jump", false, 1)
	_expect(player.global_position.x < origin.x + obstacle.width - 7 and player.global_position.y > origin.y,
		"%s is too wide even for a boosted running jump" % obstacle.name)
	await _frames(25)
	_expect(player.global_position.x < origin.x and player.health == player.MAX_HEALTH - 1,
		"%s returns a player who hits the spikes to the approach bank" % obstacle.name)


func _check_gate(obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	_expect(not obstacle.has_node("GateCountdown"), "The gate has no countdown display")
	await _frames(190)
	_expect(obstacle.elapsed == 0.0 and obstacle._gate_bottom() == 0.0,
		"The gate stays shut until Theseus approaches")
	_place(player, origin + Vector2(-30, 0))
	await _frames(4)
	_move("move_right", true)
	await _frames(164)
	_expect(player.global_position.x < origin.x and obstacle._gate_bottom() == 0.0,
		"The gate blocks Theseus for the first three seconds")
	await _frames(60)
	_move("move_right", false)
	_expect(player.global_position.x > origin.x + obstacle.width,
		"Theseus can cross on the first opening")
	await _frames(140)
	_expect(obstacle._gate_bottom() == -obstacle.GATE_HEIGHT,
		"The gate remains fully raised during its open phase")
	_place(player, origin + Vector2(4, 0))
	await _frames(48)
	_expect(player.health == player.MAX_HEALTH - 1 and player.global_position.x < origin.x - 6,
		"The descending gate damages Theseus and pushes him out on the nearer side")
	_expect(obstacle._gate_bottom() == 0.0,
		"The gate begins the next closed phase after landing")


func _check_atlantis_jets(level: Node, obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	var label := String(obstacle.name)
	_expect(level.layout.surface_at(origin.x - 12) == origin.y
		and level.layout.surface_at(origin.x + obstacle.width + 12) == origin.y,
		label + " leaves a flat approach and exit")
	obstacle.elapsed = obstacle.durations.x + obstacle.durations.y / 2
	_expect(obstacle._warning() and not obstacle._danger_rect().has_area(), label + " warns before becoming dangerous")
	paused = true
	var before: float = obstacle.elapsed
	await _frames(4)
	_expect(obstacle.elapsed == before, label + " pauses with gameplay")
	paused = false
	obstacle.elapsed = obstacle.durations.x + obstacle.durations.y
	_place(player, origin + Vector2(obstacle.width / 2, 0))
	await _frames(4)
	_expect(player.health == player.MAX_HEALTH - 1, label + " damages Theseus during a burst")
	level.tide.elapsed = 12.0
	obstacle.elapsed = 0.0
	_place(player, origin + Vector2(-12, 0))
	await _frames(4)
	_move("move_right", true)
	await _frames(117)
	_move("move_right", false)
	_expect(is_equal_approx(level.tide.water_y, level.tide.HIGH_Y) and player.global_position.x > origin.x + obstacle.width + 7
		and player.health == player.MAX_HEALTH, label + " leaves enough time to cross even at high tide")
