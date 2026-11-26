@tool
extends "res://scenes/levels/level_geometry.gd"

const Labyrinth := preload("res://scenes/levels/level_9_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/labyrinth/labyrinth_interior.png")]
const MASONRY := preload("res://assets/art/backgrounds/level_3/city_masonry.png")
const TORCH := preload("res://scenes/objects/labyrinth_torch.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 304.0
const FAR_SCROLL := 0.105
const FAR_VERTICAL_SCROLL := 0.25
# Mounts are painted-wall pixel coordinates, independent of the gameplay route.
const TORCH_MOUNTS := [
	Vector2(120, 320), Vector2(620, 345), Vector2(1030, 350),
	Vector2(1400, 350), Vector2(1740, 340), Vector2(1998, 350),
]
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Labyrinth.FLOOR_Y, Labyrinth.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Labyrinth.WIDTH, -128, 16, 512))
	for index in Labyrinth.PLATFORMS.size():
		_make_solid("Gallery%d" % index, Labyrinth.PLATFORMS[index])
	for index in Labyrinth.CEILINGS.size():
		_make_solid("LowLintel%d" % index, Labyrinth.CEILINGS[index])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	process_priority = 10
	backdrop = Node2D.new()
	backdrop.name = "LabyrinthBackdrop"
	backdrop.z_index = -3
	add_child(backdrop)
	var landscape := Sprite2D.new()
	landscape.name = "ContinuousLandscape"
	landscape.texture = PANORAMA_SHEETS[0]
	landscape.centered = false
	landscape.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	landscape.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	landscape.scale = Vector2.ONE * LANDSCAPE_HEIGHT / landscape.texture.get_height()
	backdrop.add_child(landscape)
	midground = Node2D.new()
	midground.name = "LabyrinthTorches"
	midground.z_index = -2
	add_child(midground)
	for mount: Vector2 in TORCH_MOUNTS:
		var torch := Node2D.new()
		torch.set_script(TORCH)
		torch.name = "Torch%d" % int(mount.x)
		torch.position = mount * landscape.scale
		midground.add_child(torch)
	if not Engine.is_editor_hint():
		var darkness := CanvasModulate.new()
		darkness.name = "LabyrinthAmbient"
		darkness.color = Color(0.63, 0.65, 0.72)
		add_child(darkness)
		call_deferred("_decorate_exit")
	_sync_backdrop()
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var corner := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		corner = camera.get_screen_center_position() - view * 0.5
	backdrop.position = Vector2(corner.x * (1.0 - FAR_SCROLL), corner.y * (1.0 - FAR_VERTICAL_SCROLL) - 48)
	# Brackets, flames, and lights share the wall's horizontal and vertical motion.
	midground.position = backdrop.position


func _decorate_exit() -> void:
	var gate := get_parent().get_node_or_null("TempleGate") as Node2D
	if gate != null:
		gate.self_modulate.a = 0
		var facade := Node2D.new()
		facade.name = "CinematicFacade"
		facade.set_script(TEMPLE)
		gate.add_child(facade)


func _draw() -> void:
	_stonework(Rect2(0, Labyrinth.FLOOR_Y, Labyrinth.WIDTH, 72))
	for rectangle: Rect2 in Labyrinth.PLATFORMS:
		_stonework(rectangle)
	for rectangle: Rect2 in Labyrinth.CEILINGS:
		_stonework(rectangle)
	# Ariadne's bronze thread marks the route and carries through both tunnels.
	for x in range(8, Labyrinth.WIDTH - 96, 8):
		var y := Labyrinth.surface_at(x) + 2
		draw_line(Vector2(x, y), Vector2(x + 5, y), Color("bb8d48"), 0.6)


func _stonework(rectangle: Rect2) -> void:
	draw_set_transform(rectangle.position, 0, Vector2.ONE / 16.0)
	draw_texture_rect(MASONRY, Rect2(Vector2.ZERO, rectangle.size * 16), true, Color(0.42, 0.39, 0.36))
	draw_set_transform(Vector2.ZERO)
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("b29a70"), 1)
	draw_line(Vector2(rectangle.position.x, rectangle.end.y), rectangle.end, Color("887459"), 0.6)
