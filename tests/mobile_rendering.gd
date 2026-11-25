extends SceneTree

# Requires a renderer. Use --fixed-fps 60 -- --mobile-controls.
var failures: Array[String] = []
var manager: Node
var original_size: Vector2i
var captures := ""

class Marker:
	extends Node2D
	var color := Color.RED
	func _draw() -> void:
		draw_rect(Rect2(-2, -2, 4, 4), color)


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count := 3) -> void:
	for _frame in count:
		# This renderer check is automated; desktop focus changes must not put
		# a pause panel over its marker samples. Pause behavior has its own test.
		if is_instance_valid(current_scene) and current_scene.has_method("_set_paused"):
			current_scene._set_paused(false)
		await physics_frame
		await process_frame


func _open(number: int) -> Node:
	root.get_node("LevelRun").begin_level(number)
	change_scene_to_file("res://scenes/levels/level_%d.tscn" % number)
	await scene_changed
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0
	await _frames()
	return current_scene


func _trajectory(profile: String, number := 1) -> Array:
	manager.set_profile(profile)
	var level := await _open(number)
	if number == 7:
		level.tide.set_physics_process(false)
		level.tide.elapsed = 15.0
		level.tide._sync_tide()
		_expect(is_equal_approx(level.player.movement_speed(), 63.0), "Water drag is active for the profile comparison")
	var player = level.player
	var history := []
	Input.action_press("move_right")
	Input.action_press("jump")
	Input.action_press("attack")
	for index in 18:
		await _frames(1)
		history.append([player.position, player.velocity, player.sprite.animation, player.sprite.frame])
		if index == 0:
			Input.action_release("jump")
			Input.action_release("attack")
	Input.action_release("move_right")
	return history


func _verify_markers(level: Node, profile: String) -> void:
	var camera := root.get_camera_2d()
	var points := [Vector2(24, 72), Vector2(160, 90), Vector2(296, 100)]
	var colors := [Color.RED, Color.GREEN, Color.BLUE]
	var markers: Array[Node] = []
	for index in points.size():
		var marker := Marker.new()
		var unlit := CanvasItemMaterial.new()
		unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		marker.material = unlit
		marker.color = colors[index]
		marker.z_index = 500
		level.add_child(marker)
		marker.global_position = root.canvas_transform.affine_inverse() * points[index]
		markers.append(marker)
	await _frames(2)
	for index in points.size():
		markers[index].global_position = root.canvas_transform.affine_inverse() * points[index]
	level._set_paused(false)
	manager._sync_camera()
	RenderingServer.force_draw(false)
	var world: Image = manager.world_viewport.get_texture().get_image()
	var display := root.get_texture().get_image()
	var calculated_size := Vector2i((root.get_visible_rect().size * root.get_stretch_transform().get_scale()).round())
	_expect(display.get_size() == calculated_size, "Reported UI pixel size matches the actual framebuffer")
	_expect(world.get_size() == manager.TARGETS[profile], "Actual world texture is " + profile)
	for index in points.size():
		var world_point := Vector2i(points[index] * Vector2(world.get_size()) / Vector2(320, 180))
		var display_point := Vector2i(points[index] * Vector2(display.get_size()) / Vector2(320, 180))
		_expect(world.get_pixelv(world_point).is_equal_approx(colors[index]), "World marker retains framing in " + profile)
		_expect(display.get_pixelv(display_point).is_equal_approx(colors[index]), "Composited marker retains framing in " + profile)
	_expect(camera == root.get_camera_2d() and camera.zoom == Vector2.ONE, "Root camera remains active at the original zoom")
	for marker in markers:
		marker.free()


func _verify_insets(level: Node) -> void:
	var controls := root.get_node("MobileControls")
	if not controls.enabled:
		return
	for physical in [Rect2(186, 0, 2436, 1146), Rect2(0, 0, 2436, 1146)]:
		var safe: Rect2 = controls.safe_rect_for_display(physical, Vector2(2622, 1206), Rect2(0, 0, 320, 180), false)
		controls._layout_controls(safe)
		level.hud._layout_mobile(safe)
		_expect(level.hud._root.get_global_rect().is_equal_approx(safe), "HUD follows left/right landscape safe areas")
		_expect(level.hud._area.get_global_rect().end.x <= level.hud._score.get_global_rect().position.x, "Area title cannot cover the score")
		level.hud.show_message("Each head has 2 HP. Cut all three; jump for high heads.", 1.0, 9)
		var plaque: Rect2 = level.hud._message_backdrop.get_global_rect()
		_expect(safe.encloses(plaque) and plaque.end.y > safe.end.y - 24, "The longest hint sits at the bottom of the safe area")
		var label: Rect2 = level.hud._message.get_global_rect()
		_expect(level.hud._message.get_line_count() <= 4 and plaque.encloses(label), "The longest hint wraps to fit its plaque")
		for action in controls.buttons:
			var touch: TouchScreenButton = controls.buttons[action]
			var target := Rect2(touch.position - Vector2.ONE * touch.shape.radius, Vector2.ONE * touch.shape.radius * 2)
			_expect(not plaque.intersects(target), "Hints never cover the %s button" % action)
		for action in controls.buttons:
			var button: TouchScreenButton = controls.buttons[action]
			_expect(safe.encloses(Rect2(button.position - Vector2.ONE * button.shape.radius, Vector2.ONE * button.shape.radius * 2)), "Landscape safe area contains " + action)
	controls._on_viewport_changed()
	level.hud._layout_mobile()


func _run() -> void:
	manager = root.get_node("MobileRendering")
	original_size = root.size
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
			DirAccess.make_dir_recursive_absolute(captures)
	_expect(not manager.simulator_for_platform("iOS", "arm64", "iPhone17,3", ""), "Physical iOS uses the phone profile")
	_expect(manager.simulator_for_platform("iOS", "arm64", "", "simulator-id"), "Apple Silicon simulator has a separate preview")
	_expect(manager.simulator_for_platform("Android", "x86_64", "sdk_gphone64_x86_64", ""), "Android emulator has a separate preview")
	_expect(not manager.simulator_for_platform("Android", "arm64", "Pixel 8", ""), "Physical Android uses the phone profile")
	var native := await _trajectory("native")
	var wet_native := await _trajectory("native", 7)
	for profile in ["720", "540", "preview"]:
		var actual := await _trajectory(profile)
		_expect(actual == native, "Movement, jumps, collisions and sword frames match native rendering: " + profile)
		var wet := await _trajectory(profile, 7)
		_expect(wet == wet_native, "Underwater movement and sword frames match native rendering: " + profile)
		for number in range(1, 9):
			var level := await _open(number)
			_expect(current_scene.get_parent() == root, "Scene ownership and reload behavior remain unchanged")
			_expect(root.get_visible_rect().size == Vector2(320, 180), "Logical view remains 320x180")
			_expect(manager.world_viewport.world_2d == root.world_2d, "The renderer shares the original physics world")
			await _verify_markers(level, profile)
			if number == 1:
				_verify_insets(level)
				if not captures.is_empty():
					await _frames()
					RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png(captures.path_join(profile + "_hud.png"))
		# A display resize must not change the render budget or world framing.
		for dimensions in [Vector2i(1800, 900), Vector2i(1080, 2400), original_size]:
			root.size = dimensions
			await _frames()
			_expect(manager.world_viewport.size == manager.TARGETS[profile], "Rotation/resizing preserves the render budget")
			_expect(root.get_visible_rect().size == Vector2(320, 180), "Rotation/resizing preserves world coordinates")
		# The presentation quad must not intercept title buttons.
		change_scene_to_file("res://scenes/main/main.tscn")
		await scene_changed
		await _frames()
		var button: Button = current_scene.controls_button
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = button.get_global_rect().get_center()
			event.pressed = pressed
			root.push_input(event, true)
		await _frames()
		_expect(current_scene.controls_screen.visible, "Menus receive input through the presentation layer")
	manager.set_profile("native")
	_expect(not is_instance_valid(manager.world_viewport), "Native profile releases the additional render target")
	_expect(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Desktop returns to native rendering")
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	print("PASS: render sizes, all eight camera views, identical physics/attacks, HUD and touch safe areas, resizing, menus and desktop restoration." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
