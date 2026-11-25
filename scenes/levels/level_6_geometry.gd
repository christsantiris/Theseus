@tool
extends "res://scenes/levels/level_geometry.gd"

const Desert := preload("res://scenes/levels/level_6_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/egypt/desert_landscape.png")]
const OBELISK := preload("res://assets/art/backgrounds/egypt/obelisk.png")
const PYLON := preload("res://assets/art/backgrounds/egypt/pylon_gate.png")
const MASONRY := preload("res://assets/art/backgrounds/level_3/city_masonry.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const LANDSCAPE_HEIGHT := 304.0
const FAR_SCROLL := 0.13
const FAR_VERTICAL_SCROLL := 0.25
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Desert.FLOOR_Y, Desert.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Desert.WIDTH, -128, 16, 512))
	for index in Desert.PLATFORMS.size():
		_make_solid("SandstoneTerrace%d" % index, Desert.PLATFORMS[index])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	process_priority = 10
	backdrop = Node2D.new()
	backdrop.name = "DesertBackdrop"
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
	midground.name = "DesertLandmarks"
	midground.z_index = -2
	add_child(midground)
	for point in [Vector2(208, 110), Vector2(800, 90), Vector2(1984, 100), Vector2(3136, 136), Vector2(3860, 112), Vector2(4352, 90)]:
		_landmark(OBELISK, point, "Obelisk")
	for point in [Vector2(1024, 92), Vector2(2176, 76), Vector2(3136, 82), Vector2(4640, 120)]:
		_landmark(PYLON, point, "Pylon")
	_sync_backdrop()
	if not Engine.is_editor_hint():
		call_deferred("_decorate_exit")
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _landmark(texture: Texture2D, point: Vector2, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(point.x))
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, point.x, Desert.surface_at(point.x), point.y)
	midground.add_child(sprite)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var corner := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		corner = camera.get_screen_center_position() - view * 0.5
	backdrop.position = Vector2(corner.x * (1.0 - FAR_SCROLL), corner.y * (1.0 - FAR_VERTICAL_SCROLL) - 48)


func _decorate_exit() -> void:
	var gate := get_parent().get_node_or_null("TempleGate") as Node2D
	if gate != null:
		# The Egyptian pylon supplies the facade; retain the shared gate collision
		# and entry animation, which are identical on desktop and mobile.
		gate.self_modulate.a = 0.0


func _draw() -> void:
	_sandstone(Rect2(0, Desert.FLOOR_Y, Desert.WIDTH, 72))
	for rectangle: Rect2 in Desert.PLATFORMS:
		_sandstone(rectangle)


func _sandstone(rectangle: Rect2) -> void:
	draw_set_transform(rectangle.position, 0, Vector2.ONE / 16.0)
	draw_texture_rect(MASONRY, Rect2(Vector2.ZERO, rectangle.size * 16), true, Color(1.18, 0.88, 0.55))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 3)), Color("eac17f"))
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("ffe0a1"), 0.6)
	draw_line(rectangle.position + Vector2(0, 3), Vector2(rectangle.end.x, rectangle.position.y + 3), Color("9b703f"), 0.5)
