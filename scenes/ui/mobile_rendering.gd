extends Node

# World coordinates and root scene ownership stay unchanged. A shared World2D
# is drawn at a fixed resolution; CanvasLayer UI stays on the display viewport.
const LOGICAL_SIZE := Vector2i(320, 180)
const TARGETS := {"720": Vector2i(1280, 720), "540": Vector2i(960, 540), "preview": LOGICAL_SIZE}
const WORLD_MASK := 1
const UI_MASK := 2
var profile := "native"
var world_viewport: SubViewport
var _output: CanvasLayer
var _original_mask := 0xffffffff
var _original_mode := Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
var _original_stretch := Window.CONTENT_SCALE_STRETCH_INTEGER


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_mask = get_window().canvas_cull_mask
	_original_mode = get_window().content_scale_mode
	_original_stretch = get_window().content_scale_stretch
	get_tree().node_added.connect(_route_added)
	RenderingServer.frame_pre_draw.connect(_sync_camera)
	set_profile(_requested_profile())


func _requested_profile() -> String:
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	# iPadOS can request desktop pages and identify itself as a Mac.
	mobile = mobile or (OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available())
	var selected := "native"
	if mobile:
		var setting := "rendering/mobile/simulator_profile" if is_simulator() else "rendering/mobile/world_profile"
		selected = str(ProjectSettings.get_setting(setting, "preview" if is_simulator() else "720"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mobile-render="):
			selected = argument.trim_prefix("--mobile-render=")
	if OS.has_feature("web"):
		var query = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('render') || ''", true)
		if query is String and not query.is_empty():
			selected = query
	if selected != "native" and not TARGETS.has(selected):
		push_warning("Unknown mobile render profile '%s'; using %s." % [selected, "720" if mobile else "native"])
		return "720" if mobile else "native"
	return selected


static func simulator_for_platform(platform: String, architecture: String, model: String, simulator_id: String) -> bool:
	if platform == "iOS":
		return architecture == "x86_64" or not simulator_id.is_empty()
	if platform == "Android":
		return architecture.begins_with("x86") or "sdk_gphone" in model.to_lower() or "emulator" in model.to_lower()
	return false


func is_simulator() -> bool:
	if OS.get_name() not in ["iOS", "Android"]:
		return false
	return simulator_for_platform(OS.get_name(), Engine.get_architecture_name(), OS.get_model_name(), OS.get_environment("SIMULATOR_UDID"))


func set_profile(value: String) -> void:
	if value != "native" and not TARGETS.has(value):
		push_error("Unsupported mobile render profile: " + value)
		return
	profile = value
	var window := get_window()
	if value == "native":
		window.canvas_cull_mask = _original_mask
		window.content_scale_mode = _original_mode
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL if "--mobile-controls" in OS.get_cmdline_user_args() else _original_stretch
		_restore_ui(get_tree().root)
		if is_instance_valid(_output):
			_output.free()
		if is_instance_valid(world_viewport):
			world_viewport.free()
		return
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if value == "preview" else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if not is_instance_valid(world_viewport):
		world_viewport = SubViewport.new()
		world_viewport.name = "WorldRenderTarget"
		world_viewport.disable_3d = true
		world_viewport.gui_disable_input = true
		world_viewport.handle_input_locally = false
		world_viewport.size_2d_override = LOGICAL_SIZE
		world_viewport.size_2d_override_stretch = true
		world_viewport.world_2d = window.world_2d
		world_viewport.canvas_cull_mask = WORLD_MASK
		world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(world_viewport)
		_output = CanvasLayer.new()
		_output.name = "WorldPresentation"
		_output.layer = -100
		add_child(_output)
		var picture := TextureRect.new()
		picture.name = "WorldPicture"
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.size = Vector2(LOGICAL_SIZE)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.texture = world_viewport.get_texture()
		_output.add_child(picture)
	world_viewport.size = TARGETS[value]
	_route_ui(get_tree().root, false)
	window.canvas_cull_mask = UI_MASK
	_sync_camera()


func _sync_camera() -> void:
	if profile != "native" and is_instance_valid(world_viewport):
		# Camera2D continues to own the root camera and its original 320x180
		# framing. Copy its completed transform immediately before each draw.
		world_viewport.canvas_transform = get_window().canvas_transform


func _route_added(node: Node) -> void:
	if profile == "native" or node.get_viewport() != get_window():
		return
	var parent := node
	while parent != null:
		if parent is CanvasLayer:
			_route_ui(node, true)
			return
		parent = parent.get_parent()


func _route_ui(node: Node, inside_layer: bool) -> void:
	if node is Viewport and node != get_window():
		return
	inside_layer = inside_layer or node is CanvasLayer
	if node is CanvasItem and inside_layer:
		if not node.has_meta("mobile_original_visibility"):
			node.set_meta("mobile_original_visibility", node.visibility_layer)
		node.visibility_layer = UI_MASK
	for child in node.get_children():
		_route_ui(child, inside_layer)


func _restore_ui(node: Node) -> void:
	if node is CanvasItem and node.has_meta("mobile_original_visibility"):
		node.visibility_layer = node.get_meta("mobile_original_visibility")
		node.remove_meta("mobile_original_visibility")
	for child in node.get_children():
		_restore_ui(child)
