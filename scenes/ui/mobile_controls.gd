extends CanvasLayer

# The same InputMap actions drive keyboard and touch play. Opt in on a desktop
# with: godot --path . -- --mobile-controls
const ACTIONS := ["move_left", "move_right", "duck", "jump", "attack"]
const RADIUS := 16.0
# Outer buttons sit this far from the safe area's bottom and side edges, with
# their neighbors spaced evenly inward.
const BUTTON_INSET := 22.0
const BUTTON_SPACING := 40.0
var enabled := false
var buttons: Dictionary = {}
var _faces: Dictionary = {}
var _scene_id := 0
var _playing := false
var _layout_root: Control
var _last_safe_rect := Rect2()


class ButtonFace:
	extends Node2D
	var caption := ""
	var radius := 15.0
	var pressed := false

	func _draw() -> void:
		var gold := Color("e4ca8d")
		draw_circle(Vector2.ZERO, radius, Color(0.72, 0.52, 0.24, 0.65) if pressed else Color(0.08, 0.1, 0.12, 0.5))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, gold if pressed else Color(0.9, 0.81, 0.6, 0.65), 0.55, true)
		match caption:
			"left", "right":
				var facing := -1 if caption == "left" else 1
				draw_colored_polygon(PackedVector2Array([Vector2(facing * 5, 0), Vector2(-facing * 3, -5), Vector2(-facing * 3, 5)]), gold)
			"pause":
				draw_rect(Rect2(-3, -4, 2, 8), gold)
				draw_rect(Rect2(1, -4, 2, 8), gold)
			"play":
				draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(-3, -5), Vector2(-3, 5)]), gold)
			_:
				# Use the game's bitmap font; tiny dynamic glyphs can fail on the
				# iOS Simulator's software OpenGL path after viewport scaling.
				var font := preload("res://assets/fonts/inscription.fnt")
				var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
				draw_string(font, Vector2(-width * 0.5, 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, gold)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--mobile-controls" in OS.get_cmdline_user_args()
	if not enabled:
		hide()
		set_process(false)
		return
	Input.emulate_mouse_from_touch = true
	if "--mobile-controls" in OS.get_cmdline_user_args():
		Input.emulate_touch_from_mouse = true
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_layout_root = Control.new()
	_layout_root.name = "TouchLayout"
	_layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout_root)
	for item in [["move_left", "left"], ["move_right", "right"], ["duck", "DUCK"], ["jump", "JUMP"], ["attack", "SWORD"], ["pause", "pause"]]:
		_add_button(item[0], item[1])
	get_viewport().size_changed.connect(_on_viewport_changed)
	_layout_controls(_safe_rect())
	_sync_scene()


func _add_button(action: String, caption: String) -> void:
	var button := TouchScreenButton.new()
	button.name = action
	button.action = action
	button.passby_press = action in ["move_left", "move_right", "duck"]
	var shape := CircleShape2D.new()
	shape.radius = 12 if action == "pause" else RADIUS + 1
	button.shape = shape
	button.shape_visible = false
	var face := ButtonFace.new()
	face.caption = caption
	face.radius = 10 if action == "pause" else RADIUS - 1
	button.add_child(face)
	button.pressed.connect(_set_pressed.bind(action, true))
	button.released.connect(_set_pressed.bind(action, false))
	_layout_root.add_child(button)
	buttons[action] = button
	_faces[action] = face
	button.hide()


func _set_pressed(action: String, pressed: bool) -> void:
	_faces[action].pressed = pressed
	_faces[action].queue_redraw()


func _safe_rect() -> Rect2:
	var visible_rect := get_viewport().get_visible_rect()
	if not OS.has_feature("mobile"):
		return visible_rect
	var display_safe := DisplayServer.get_display_safe_area()
	if display_safe.size == Vector2i.ZERO:
		return visible_rect
	# Screen transforms omit the Canvas Items stretch on some mobile backends.
	# Convert physical display pixels through the centered gameplay rectangle.
	var display_rect := Rect2(display_safe)
	display_rect.position -= Vector2(DisplayServer.window_get_position())
	return safe_rect_for_display(display_rect, Vector2(get_window().size), visible_rect, get_window().content_scale_aspect != Window.CONTENT_SCALE_ASPECT_IGNORE)


static func safe_rect_for_display(display_safe: Rect2, window_pixels: Vector2, visible_rect: Rect2, keep_aspect := true) -> Rect2:
	if not display_safe.has_area() or window_pixels.x <= 0 or window_pixels.y <= 0:
		return visible_rect
	var scale := window_pixels / visible_rect.size
	if keep_aspect:
		scale = Vector2.ONE * minf(scale.x, scale.y)
	var origin := (window_pixels - visible_rect.size * scale) * 0.5
	var safe := Rect2((display_safe.position - origin) / scale + visible_rect.position, display_safe.size / scale)
	var clipped := visible_rect.intersection(safe)
	return clipped if clipped.has_area() else visible_rect


func _layout_controls(safe: Rect2) -> void:
	_last_safe_rect = safe
	var bottom := safe.end.y - BUTTON_INSET
	var left := safe.position.x + BUTTON_INSET
	var right := safe.end.x - BUTTON_INSET
	buttons.move_left.position = Vector2(left, bottom)
	buttons.move_right.position = Vector2(left + BUTTON_SPACING, bottom)
	buttons.duck.position = Vector2(left + BUTTON_SPACING * 2.0, bottom)
	buttons.jump.position = Vector2(right - BUTTON_SPACING, bottom)
	buttons.attack.position = Vector2(right, bottom)
	buttons.pause.position = Vector2(safe.end.x - 14, safe.position.y + 28)


static func bottom_gap(safe: Rect2) -> Rect2:
	# The free strip between the left (walk, duck) and right (jump, sword)
	# buttons, spanning their touch areas vertically.
	var touch := RADIUS + 1.0
	var left := safe.position.x + BUTTON_INSET + BUTTON_SPACING * 2.0 + touch
	var right := safe.end.x - BUTTON_INSET - BUTTON_SPACING - touch
	var center := safe.end.y - BUTTON_INSET
	return Rect2(left, center - touch, maxf(0.0, right - left), touch * 2.0)


func _on_viewport_changed() -> void:
	release_controls()
	_layout_controls(_safe_rect())


func _process(_delta: float) -> void:
	var safe := _safe_rect()
	if not safe.is_equal_approx(_last_safe_rect):
		release_controls()
		_layout_controls(safe)
	_sync_scene()


func _sync_scene() -> void:
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if is_instance_valid(scene) else 0
	if scene_id != _scene_id:
		release_controls()
		_scene_id = scene_id
		if scene_id != 0:
			_prepare_menus(scene)
	var player := scene.get_node_or_null("Player") if scene_id != 0 else null
	var gameplay: bool = player != null and player.is_in_group("player") and scene.has_method("_set_paused") and player.health > 0 and not scene._complete and not scene._entering_temple
	var playing := gameplay and not get_tree().paused
	if playing != _playing:
		release_controls()
		_playing = playing
	for action in ACTIONS:
		buttons[action].visible = playing
	buttons.pause.visible = gameplay
	var caption := "play" if get_tree().paused else "pause"
	if _faces.pause.caption != caption:
		_faces.pause.caption = caption
		_faces.pause.queue_redraw()


func _prepare_menus(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 22)
	for child in node.get_children():
		_prepare_menus(child)


func release_controls() -> void:
	for action in buttons:
		# Hiding native touch buttons also clears their finger capture. A later
		# scene or resume must never inherit a held movement or attack action.
		buttons[action].hide()
		if _faces[action].pressed:
			Input.action_release(action)
		_set_pressed(action, false)


func _notification(what: int) -> void:
	if not enabled or not is_inside_tree():
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release_controls()
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_method("_set_paused"):
			scene._set_paused(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		release_controls()
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_method("_set_paused"):
			scene._set_paused(not get_tree().paused)
		elif is_instance_valid(scene) and scene.has_method("_on_controls_back"):
			scene._on_controls_back()
