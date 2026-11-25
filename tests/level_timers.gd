extends SceneTree

# Run both normally and with -- --mobile-controls.
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
		await process_frame


func _isolate(level: Node) -> void:
	level.set_process(false)
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0


func _run() -> void:
	state = root.get_node("LevelRun")
	var controls := root.get_node("MobileControls")
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	for number in range(1, 9):
		state.begin_level(number, 700)
		change_scene_to_file(state.scene_path())
		await scene_changed
		var level := current_scene
		_isolate(level)
		_expect(level.player.position == level.layout.START and level._score == 700, "Level %d begins at its entrance with carried score" % number)
		_expect(state.elapsed_seconds == 0.0 and level.hud._level_time.text == "Time 3:00", "Every level starts with a full countdown")
		_expect(level.find_children("*Shrine", "Area2D", true, false).is_empty(), "No checkpoint triggers remain")
		level._process(1.25)
		_expect(state.elapsed_seconds == 1.25 and level.hud._level_time.text == "Time 2:59", "Countdown advances and rounds remaining seconds up")
		level._set_paused(true)
		level._process(60.0)
		_expect(state.elapsed_seconds == 1.25, "Pause does not consume time")
		level._set_paused(false)
		if controls.enabled:
			controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			level._process(60.0)
			_expect(paused and state.elapsed_seconds == 1.25, "App interruption freezes the countdown")
			level._set_paused(false)
			for safe in [Rect2(12, 4, 296, 166), Rect2(0, 0, 320, 170)]:
				await _frames(1)
				controls._layout_controls(safe)
				level.hud._layout_mobile(safe)
				var clock: Rect2 = level.hud._level_time.get_global_rect()
				_expect(safe.encloses(clock), "Countdown fits iOS and Android safe areas")
				_expect(not clock.intersects(level.hud._score.get_global_rect()), "Time and score remain separate")
				for action in controls.buttons:
					var button: TouchScreenButton = controls.buttons[action]
					var bounds := Rect2(button.position - Vector2.ONE * button.shape.radius, Vector2.ONE * button.shape.radius * 2.0)
					_expect(not clock.intersects(bounds), "Countdown clears touch button " + action)
			controls._on_viewport_changed()
		level._on_gate_entry_started(level.player)
		level._process(60.0)
		_expect(state.elapsed_seconds == 1.25, "Temple entry freezes the clock")
		level._on_gate_entered()
		level._process(60.0)
		_expect(state.elapsed_seconds == 1.25 and "Time 0:01" in level.details.text, "Completion preserves the elapsed result")
		level._on_replay_pressed()
		await scene_changed
		level = current_scene
		_isolate(level)
		_expect(state.elapsed_seconds == 0.0 and level.hud._level_time.text == "Time 3:00", "Replay resets the countdown")
		level._on_enemy_defeated(125, "TimerTestEnemy")
		state.elapsed_seconds = level.layout.TIME_LIMIT - 30.0
		level._process(0.0)
		_expect(level.hud._level_time.text == "Time 0:30" and level.hud._level_time.get_theme_color("font_color") != level.hud.GOLD, "Final 30 seconds use a warning color")
		state.elapsed_seconds = level.layout.TIME_LIMIT - 0.25
		level._process(0.0)
		_expect(level.player.health == 5 and level.hud._level_time.text == "Time 0:01", "A fraction of a second still displays one and keeps the player alive")
		level.player._hurt_lock = 10.0
		level._process(1.0)
		_expect(level.player.health == 0 and state.elapsed_seconds == level.layout.TIME_LIMIT, "Timeout kills even during damage immunity and clamps time")
		_expect(level.hud._level_time.text == "Time 0:00" and level.hud._message.text == "Time up!", "Timeout remains visible at zero")
		level._process(1.0)
		_expect(state.elapsed_seconds == level.layout.TIME_LIMIT, "Death freezes the timer")
		for tick in 100:
			await _frames(1)
			if is_instance_valid(current_scene) and current_scene.name == "Hades":
				break
		_expect(current_scene.name == "Hades" and state.record_result().score == 825, "Timeout opens Hades and records the live score")
		current_scene.load_game()
		await scene_changed
		level = current_scene
		_isolate(level)
		_expect(level.player.position == level.layout.START and level.player.health == 5 and level._score == 700 and state.elapsed_seconds == 0.0, "Hades retry resets position, health, level score and countdown")
	paused = false
	_stop_audio(root)
	restore_scores.call()
	OS.delay_msec(150)
	print("PASS: all eight countdowns, pause, completion, timeout/Hades, score and entrance retries, and mobile safe areas." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
