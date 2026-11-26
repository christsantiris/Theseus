@tool
extends "res://scenes/levels/level_geometry.gd"

const Gorge := preload("res://scenes/levels/level_6_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/level_5/gorge_landscape.png")]
const CLIFF_TEMPLE := preload("res://assets/art/backgrounds/level_5/cliff_temple.png")
const OUTCROP := preload("res://assets/art/backgrounds/level_2/coastal_outcrop.png")
const COLONNADE := preload("res://assets/art/backgrounds/level_1/colonnade.png")
const MASONRY := preload("res://assets/art/backgrounds/level_5/gorge_masonry.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const COLUMN := preload("res://assets/art/backgrounds/level_4/broken_column.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 304.0
const FAR_SCROLL := 0.105
const FAR_VERTICAL_SCROLL := 0.25
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_add_terrain("Ground", Rect2(0, Gorge.FLOOR_Y, Gorge.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Gorge.WIDTH, -128, 16, 512))
	for index in Gorge.PLATFORMS.size():
		_add_terrain("GorgeTerrace%d" % index, Gorge.PLATFORMS[index])
	for index in Gorge.BONUS_LEDGES.size():
		var body_name := "BullLedge%d" % index
		_make_solid(body_name, Gorge.BONUS_LEDGES[index])
		var collision := get_node(body_name).get_child(0) as CollisionShape2D
		collision.one_way_collision = true
		collision.one_way_collision_margin = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	process_priority = 10
	_build_landscape()
	_sync_backdrop()
	if not Engine.is_editor_hint():
		call_deferred("_decorate_temple")
	queue_redraw()


func _add_terrain(prefix: String, rectangle: Rect2) -> void:
	var index := 0
	for piece in Gorge.terrain_pieces(rectangle):
		var body_name := "%sPart%d" % [prefix, index]
		_make_solid(body_name, piece)
		if Gorge.is_spike_floor(piece):
			get_node(body_name).set_meta("spike_pit", true)
		index += 1


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _build_landscape() -> void:
	backdrop = Node2D.new()
	backdrop.name = "GorgeBackdrop"
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
	midground.name = "GorgeLandmarks"
	midground.z_index = -2
	add_child(midground)
	# Complete objects stay on authored landings; only the distant landscape
	# uses parallax. Painted bases overlap the terrain through GROUNDING.
	for point in [Vector2(1056, 100), Vector2(3152, 104), Vector2(4880, 96), Vector2(5424, 90)]:
		_landmark(CLIFF_TEMPLE, point.x, point.y, "CliffTemple")
	for point in [Vector2(336, 104), Vector2(1432, 72), Vector2(1900, 72), Vector2(2520, 72), Vector2(3640, 44)]:
		_landmark(OUTCROP, point.x, point.y, "RockyOutcrop")
	for point in [Vector2(2904, 48), Vector2(5304, 56)]:
		_landmark(COLONNADE, point.x, point.y, "Colonnade")
	_landmark(OUTCROP, 4220, 64, "RockyOutcrop")
	_landmark(CLIFF_TEMPLE, 4688, 96, "CliffTemple")
	_sync_backdrop()


func _landmark(texture: Texture2D, route_x: float, height: float, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(route_x))
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, route_x, Gorge.surface_at(route_x), height)
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
	_draw_terrain(Rect2(0, Gorge.FLOOR_Y, Gorge.WIDTH, 72))
	for platform: Rect2 in Gorge.PLATFORMS:
		_draw_terrain(platform)
	for ledge: Rect2 in Gorge.BONUS_LEDGES:
		_retaining_stone(ledge)
	for x in [96, 688, 1392, 1936, 2704, 3552, 5272]:
		var height := 44.0
		draw_texture_rect(COLUMN, GROUNDING.rect(COLUMN, x, Gorge.surface_at(x), height), false)


func _draw_terrain(rectangle: Rect2) -> void:
	for piece in Gorge.terrain_pieces(rectangle):
		_retaining_stone(piece)


func _retaining_stone(rectangle: Rect2) -> void:
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
