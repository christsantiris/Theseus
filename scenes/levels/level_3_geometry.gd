@tool
extends "res://scenes/levels/level_geometry.gd"

const Town := preload("res://scenes/levels/level_3_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/level_3/city_landscape.png")]
const WORKSHOP := preload("res://assets/art/backgrounds/level_3/workshop.png")
const STOA := preload("res://assets/art/backgrounds/level_3/stoa.png")
const GROVE := preload("res://assets/art/backgrounds/level_1/olive_grove.png")
const COLONNADE := preload("res://assets/art/backgrounds/level_1/colonnade.png")
const MASONRY := preload("res://assets/art/backgrounds/level_3/city_masonry.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const AMPHORA := preload("res://assets/art/backgrounds/level_3/amphora.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 288.0
const FAR_SCROLL := 0.10
const FAR_VERTICAL_SCROLL := 0.25
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Town.FLOOR_Y, Town.WIDTH, 64))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Town.WIDTH, -128, 16, 512))
	for index in Town.PLATFORMS.size():
		_make_solid("TownTerrace%d" % index, Town.PLATFORMS[index])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	process_priority = 10
	_build_landscape()
	_sync_backdrop()
	if not Engine.is_editor_hint():
		call_deferred("_decorate_temple")
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _build_landscape() -> void:
	backdrop = Node2D.new()
	backdrop.name = "CityBackdrop"
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
	midground.name = "CityLandmarks"
	midground.z_index = -2
	add_child(midground)
	# Complete objects stay on authored landings; only the distant landscape
	# uses parallax. Painted bases overlap the terrain through GROUNDING.
	for point in [Vector2(240, 100), Vector2(1008, 100), Vector2(1680, 90), Vector2(2544, 94), Vector2(5408, 100)]:
		_landmark(WORKSHOP, point.x, point.y, "Workshop")
	for point in [Vector2(608, 56), Vector2(2784, 60), Vector2(3488, 68), Vector2(5112, 56)]:
		_landmark(STOA, point.x, point.y, "Stoa")
	for point in [Vector2(2048, 104), Vector2(3784, 60)]:
		_landmark(GROVE, point.x, point.y, "OliveGrove")
	for point in [Vector2(3264, 68)]:
		_landmark(COLONNADE, point.x, point.y, "Colonnade")
	_landmark(WORKSHOP, 3904, 90, "Workshop")
	_landmark(STOA, 4272, 52, "Stoa")
	_sync_backdrop()


func _landmark(texture: Texture2D, route_x: float, height: float, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(route_x))
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, route_x, Town.surface_at(route_x), height)
	midground.add_child(sprite)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var corner := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		corner = camera.get_screen_center_position() - view * 0.5
	# Overscan covers the full camera range, including pit bottoms and jumps.
	backdrop.position = Vector2(corner.x * (1.0 - FAR_SCROLL),
		corner.y * (1.0 - FAR_VERTICAL_SCROLL) - 48.0)


func _decorate_temple() -> void:
	var gate := get_parent().get_node_or_null("TempleGate") as Node2D
	if gate == null:
		return
	gate.self_modulate.a = 0.0
	var facade := Node2D.new()
	facade.name = "CinematicFacade"
	facade.set_script(TEMPLE)
	gate.add_child(facade)


func _draw() -> void:
	_draw_paving(Rect2(0, Town.FLOOR_Y, Town.WIDTH, 64))
	for platform: Rect2 in Town.PLATFORMS:
		_draw_paving(platform)
	for x in [1184, 1808, 2944, 3712, 5360]:
		var height := 24.0
		draw_texture_rect(AMPHORA, GROUNDING.rect(AMPHORA, x, Town.surface_at(x), height), false)


func _draw_paving(rectangle: Rect2) -> void:
	draw_set_transform(rectangle.position, 0.0, Vector2.ONE / MATERIAL_DENSITY)
	draw_texture_rect(MASONRY, Rect2(Vector2.ZERO, rectangle.size * MATERIAL_DENSITY), true)
	draw_set_transform(Vector2.ZERO)
	var x := rectangle.position.x
	while x < rectangle.end.x:
		var width := minf(CAP_STONE.get_width() / MATERIAL_DENSITY, rectangle.end.x - x)
		draw_texture_rect_region(CAP_STONE, Rect2(x, rectangle.position.y, width, 4), Rect2(0, 96, width * MATERIAL_DENSITY, 64), Color(1.10, 1.10, 1.08))
		x += width
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("f0e8d2"), 0.35, true)
	draw_line(rectangle.position + Vector2(0, 4), Vector2(rectangle.end.x, rectangle.position.y + 4), Color(0.24, 0.26, 0.24, 0.35), 0.45, true)
