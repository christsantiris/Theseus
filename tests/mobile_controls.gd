extends SceneTree

# Run with -- --mobile-controls to exercise native multitouch events. Without
# the flag, verify that desktop input and integer scaling remain untouched.
var failures: Array[String] = []
var controls: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 3) -> void:
	for _frame in count:
		await physics_frame


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
	controls = root.get_node("MobileControls")
	if not controls.enabled:
		_expect(controls.buttons.is_empty(), "Desktop has no touch buttons")
		_expect(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "Desktop retains integer scaling")
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
	_check_button_bounds(current_scene)
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


func _finish() -> void:
	paused = false
	if controls.enabled:
		controls.release_controls()
	_stop_audio(root)
	OS.delay_msec(150)
	print("PASS: mobile controls and layout" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
