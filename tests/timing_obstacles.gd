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
		var obstacle: Node2D = level.get_node(level.layout.TIMING_OBSTACLE.name)
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
			6:
				await _check_bridge(obstacle, player)
			9:
				await _check_gate(obstacle, player)
			_:
				_expect(level.layout.surface_at(origin.x) == origin.y and level.layout.surface_at(origin.x + obstacle.width - 1) == origin.y,
					"Level %d obstacle follows a flat section of the route" % number)
				if warning > 0:
					obstacle.elapsed = idle + warning / 2
					_expect(obstacle._warning() and not obstacle._danger_rect().has_area(), "Level %d warning gives a safe cue" % number)
				obstacle.elapsed = idle + warning + active / 2
				if number == 5:
					obstacle.elapsed = idle + warning + 0.33
					var first: Rect2 = obstacle._danger_rect()
					obstacle.elapsed += 0.40
					_expect(obstacle._danger_rect().position.x > first.position.x, "Rockfall reaches the two marked spots in order")
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
				if number == 8:
					await _check_high_tide(level, obstacle, player)
	if _failures == 0:
		print("PASS: nine timing obstacles, pause, damage, duck, bridge, gate, and high-tide crossing (%s)." % ("touch" if _controls.enabled else "desktop"))
	quit(int(_failures > 0))


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
	await _frames(39)
	_move("move_right", false)
	_expect(player.global_position.x > origin.x + obstacle.width and player.health == player.MAX_HEALTH,
		"The extended bridge carries a walking player across")
	_place(player, origin + Vector2(16, 0))
	obstacle.elapsed = 3.8
	await _frames(13)
	_expect(player.global_position.y > origin.y + 12, "A retracted bridge exposes the spike pit")
	_place(player, origin + Vector2(-9, 0))
	await _frames(3)
	_move("move_right", true)
	_move("jump", true, 1)
	await _frames(38)
	_move("move_right", false)
	_move("jump", false, 1)
	_expect(player.global_position.x > origin.x + obstacle.width and player.health == player.MAX_HEALTH,
		"Moving and jumping together clears the open bridge")


func _check_gate(obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	_place(player, origin + Vector2(4, 0))
	obstacle.elapsed = 4.60
	await _frames(12)
	_expect(player.health == player.MAX_HEALTH - 1 and player.global_position.x < origin.x - 6,
		"The descending gate damages Theseus and pushes him out on the nearer side")
	var health: int = player.health
	_move("move_right", true)
	await _frames(35)
	_expect(player.global_position.x < origin.x and player.health == health,
		"The closed gate blocks passage without dealing damage")
	obstacle.elapsed = 0.0
	await _frames(56)
	_move("move_right", false)
	_expect(player.global_position.x > origin.x + obstacle.width, "Theseus can cross when the gate rises")


func _check_high_tide(level: Node, obstacle: Node2D, player: CharacterBody2D) -> void:
	var origin := obstacle.global_position
	level.tide.elapsed = 12.0
	obstacle.elapsed = 0.0
	_place(player, origin + Vector2(-12, 0))
	await _frames(4)
	_move("move_right", true)
	await _frames(111)
	_move("move_right", false)
	_expect(level.tide.phase_name == "HIGH TIDE" and player.global_position.x > origin.x + obstacle.width + 7
		and player.health == player.MAX_HEALTH, "High-tide drag leaves enough time to pass the inactive jets")
