extends SceneTree

# Run with -- --mobile-controls to exercise native multitouch events. Without
# the flag, verify that desktop input and integer scaling remain untouched.
var failures: Array[String] = []
var controls: Node
var restore_scores: Callable


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 3) -> void:
	for _frame in count:
		await physics_frame
		# Touch visibility and menu layout update on process frames. Several
		# catch-up physics ticks can run before those updates after a level load.
		await process_frame


func _touch(action: String, finger: int, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = controls.buttons[action].position
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)
	Input.flush_buffered_events()


func _drag(action: String, finger: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = controls.buttons[action].position
	root.push_input(event, true)
	Input.flush_buffered_events()


func _open_level(number := 1) -> Node:
	paused = false
	root.get_node("LevelRun").begin_level(number)
	change_scene_to_file("res://scenes/levels/level_%d.tscn" % number)
	# Fast baked loads can finish four physics ticks before the deferred scene
	# change is applied. Wait for the scene itself, then exercise its controls.
	await scene_changed
	await _frames(4)
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0
	return current_scene


func _all_released() -> bool:
	for action in controls.buttons:
		if Input.is_action_pressed(action):
			return false
	return true


func _check_button_bounds(node: Node) -> void:
	if node is Button and node.is_visible_in_tree():
		_expect(root.get_visible_rect().encloses(node.get_global_rect()), "Menu button fits viewport: " + str(node.get_path()))
		_expect(node.size.y >= 22, "Menu button has a touch-sized target")
	for child in node.get_children():
		_check_button_bounds(child)


func _run() -> void:
	restore_scores = preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	controls = root.get_node("MobileControls")
	var logical := Rect2(0, 0, 320, 180)
	var iphone: Rect2 = controls.safe_rect_for_display(Rect2(186, 0, 2250, 1146), Vector2(2622, 1206), logical)
	_expect(is_zero_approx(iphone.position.x) and is_equal_approx(iphone.size.x, 320), "iPhone letterboxing absorbs the side notch insets")
	_expect(is_equal_approx(iphone.end.y, 1146.0 / 6.7), "iPhone home indicator is converted from physical pixels to game coordinates")
	var android: Rect2 = controls.safe_rect_for_display(Rect2(80, 0, 2240, 1020), Vector2(2400, 1080), logical)
	_expect(android.is_equal_approx(Rect2(0, 0, 320, 170)), "Android display insets account for viewport scaling and letterboxing")
	var notch: Rect2 = controls.safe_rect_for_display(Rect2(300, 0, 2022, 1206), Vector2(2622, 1206), logical)
	_expect(notch.position.x > 9 and notch.position.x < 10 and notch.size.x > 300, "A notch extending into gameplay moves controls inward without collapsing the layout")
	var tablet: Rect2 = controls.safe_rect_for_display(Rect2(0, 24, 2732, 2004), Vector2(2732, 2048), logical)
	_expect(tablet.is_equal_approx(logical), "Tablet letterboxing keeps the entire gameplay rectangle safe")
	if not controls.enabled:
		_expect(controls.buttons.is_empty(), "Desktop has no touch buttons")
		_expect(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "Desktop retains integer scaling")
		_expect(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Desktop retains full-resolution Canvas Items rendering")
		var desktop_level = await _open_level()
		Input.action_press("move_right")
		await _frames()
		_expect(desktop_level.player.velocity.x > 0, "Desktop actions still move Theseus")
		Input.action_release("move_right")
		_finish()
		return
	_expect(controls.buttons.size() == 6, "All six touch actions exist")
	_expect(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "Mobile preview scales to fit")
	var level = await _open_level()
	var player = level.player
	_expect(controls.buttons.move_right.visible, "Gameplay shows controls")
	_touch("move_right", 0, true)
	await _frames()
	_expect(player.velocity.x > 0, "Holding Right walks")
	_touch("jump", 1, true)
	_touch("attack", 2, true)
	await _frames()
	_expect(player.velocity.x > 0 and player.velocity.y < 0 and player.sprite.animation == "air_swing", "Three fingers move, jump and slash together")
	_touch("jump", 1, false)
	_touch("attack", 2, false)
	_touch("move_right", 0, false)
	await _frames(40)
	_expect(_all_released() and player.is_on_floor(), "Releasing fingers ends actions and lands")
	_touch("duck", 0, true)
	await _frames()
	_expect(player._ducked, "Holding Duck crouches")
	_touch("duck", 0, false)
	await _frames()
	_touch("jump", 1, true)
	await _frames()
	_touch("duck", 0, true)
	_touch("attack", 2, true)
	await _frames()
	_expect(player.sprite.animation == "down_thrust", "Duck + Sword in the air performs a downward thrust")
	_touch("duck", 0, false)
	_touch("jump", 1, false)
	_touch("attack", 2, false)
	await _frames(40)
	await _verify_one_thumb_air_attacks(player)
	_touch("move_left", 0, true)
	await _frames()
	_drag("move_right", 0)
	await _frames()
	_expect(not Input.is_action_pressed("move_left") and player.velocity.x > 0, "Sliding between arrows changes direction")
	_touch("move_right", 0, false, true)
	await _frames()
	_expect(_all_released(), "Canceled touch releases its action")
	_touch("move_right", 0, true)
	_touch("pause", 1, true)
	await _frames()
	_expect(paused and not controls.buttons.move_right.visible and _all_released(), "Pause clears held actions and hides movement controls")
	_check_button_bounds(level)
	_touch("pause", 1, false)
	_touch("pause", 1, true)
	await _frames()
	_expect(not paused and controls.buttons.move_right.visible, "Pause button also resumes")
	_touch("pause", 1, false)
	_touch("move_right", 0, true)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames()
	_expect(paused and _all_released(), "Losing focus pauses and clears all touches")
	controls.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	_expect(not paused, "Android Back toggles pause")
	var safe := Rect2(12, 4, 296, 166)
	controls._layout_controls(safe)
	for action in controls.buttons:
		var button: TouchScreenButton = controls.buttons[action]
		_expect(safe.encloses(Rect2(button.position - Vector2.ONE * button.shape.radius, Vector2.ONE * button.shape.radius * 2)), "Safe area contains " + action)
	controls._on_viewport_changed()
	await _frames()
	_touch("move_right", 0, true)
	level = await _open_level(2)
	_expect(_all_released() and controls.buttons.jump.visible, "New level clears old finger capture and restores controls")
	level._complete = true
	await _frames()
	_expect(not controls.buttons.attack.visible and not controls.buttons.pause.visible, "Completion hides combat controls")
	change_scene_to_file("res://scenes/main/main.tscn")
	await _frames(5)
	_expect(_all_released() and not controls.buttons.jump.visible, "Title has no gameplay controls")
	_expect(not current_scene.privacy_button.visible, "Privacy Choices stays hidden where consent does not apply")
	_check_button_bounds(current_scene)
	# Players in consent regions see a fourth title button; it must still fit.
	current_scene.privacy_button.show()
	await _frames()
	_check_button_bounds(current_scene)
	current_scene.privacy_button.hide()
	await _frames()
	current_scene._on_controls_pressed()
	await _frames()
	_check_button_bounds(current_scene)
	controls.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_expect(current_scene.title_screen.visible, "Android Back closes the controls screen")
	change_scene_to_file("res://scenes/hades/hades.tscn")
	await _frames(5)
	_expect(not controls.buttons.jump.visible, "Hades has no gameplay controls")
	_check_button_bounds(current_scene)
	_finish()


func _reset_player(player: Node, start: Vector2) -> void:
	for action in controls.buttons:
		Input.action_release(action)
	player.position = start
	player.velocity = Vector2.ZERO
	player.health = 5
	player._hurt_lock = 0.0
	player._finish_attack()
	player.sprite.flip_h = false
	await _frames(4)


func _jump_rise(player: Node, touch: bool) -> float:
	# Tap Jump for 50 ms, as a thumb or a quick key press does.
	var floor_y: float = player.position.y
	var highest := floor_y
	if touch:
		_touch("jump", 1, true)
	else:
		Input.action_press("jump")
	for frame in 50:
		if frame == 3:
			if touch:
				_touch("jump", 1, false)
			else:
				Input.action_release("jump")
		await _frames(1)
		highest = minf(highest, player.position.y)
	return floor_y - highest


func _one_thumb_strike(player: Node, start: Vector2, jump_at: int) -> bool:
	await _reset_player(player, start)
	var bird: Node = load("res://scenes/enemies/stymphalian_bird.tscn").instantiate()
	bird.position = start + Vector2(62, -44)
	bird.direction = -1
	bird.patrol_left = 0
	bird.patrol_right = 400
	player.get_parent().add_child(bird)
	var won := false
	# The right thumb taps Jump for 67 ms, then reaches Sword 133 ms later.
	for frame in 120:
		if frame == jump_at:
			_touch("jump", 1, true)
		elif frame == jump_at + 4:
			_touch("jump", 1, false)
		elif frame == jump_at + 12:
			_touch("attack", 1, true)
		elif frame == jump_at + 15:
			_touch("attack", 1, false)
		await _frames(1)
		if player.health < 5:
			break
		if not bird.alive:
			won = true
			break
	for action in ["jump", "attack"]:
		if controls.is_touching(action):
			_touch(action, 1, false)
	bird.free()
	return won


func _verify_one_thumb_air_attacks(player: Node) -> void:
	await _frames(40)
	var start: Vector2 = player.position
	_expect(player.is_on_floor(), "Air-attack checks start on level ground")
	var touch_rise := await _jump_rise(player, true)
	_expect(touch_rise > 36.0, "A quick touch tap on Jump still reaches full height (%.1f px)" % touch_rise)
	await _reset_player(player, start)
	var key_rise := await _jump_rise(player, false)
	_expect(key_rise < 25.0, "A quick keyboard tap still makes a short hop (%.1f px)" % key_rise)
	await _reset_player(player, start)
	_touch("jump", 1, true)
	await _frames(6)
	_drag("attack", 1)
	await _frames(1)
	_expect(Input.is_action_pressed("attack") and Input.is_action_pressed("jump") and player.sprite.animation == "air_swing", "Sliding a thumb from Jump onto Sword swings in the air")
	_touch("attack", 1, false)
	await _frames(50)
	_expect(_all_released() and player.is_on_floor(), "Lifting the sliding thumb releases Jump and Sword")
	var wins := 0
	for jump_at in range(0, 40, 2):
		if await _one_thumb_strike(player, start, jump_at):
			wins += 1
	# Before touch jumps kept full height, this pattern never reached the bird.
	_expect(wins >= 6, "One thumb (tap Jump, then Sword) defeats a high bird across a usable timing window (%d of 20)" % wins)
	await _reset_player(player, start)


func _finish() -> void:
	paused = false
	if controls.enabled:
		controls.release_controls()
	_stop_audio(root)
	OS.delay_msec(150)
	print("PASS: mobile controls and layout" if failures.is_empty() else str(failures))
	restore_scores.call()
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
