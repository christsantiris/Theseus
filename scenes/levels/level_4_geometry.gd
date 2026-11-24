@tool
extends "res://scenes/levels/level_geometry.gd"

const Mountain := preload("res://scenes/levels/level_4_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/level_4/mountain_landscape.png")]
const TERRACE_WALL := preload("res://assets/art/backgrounds/level_4/terrace_wall.png")
const GROVE := preload("res://assets/art/backgrounds/level_1/olive_grove.png")
const OUTCROP := preload("res://assets/art/backgrounds/level_2/coastal_outcrop.png")
const MASONRY := preload("res://assets/art/backgrounds/level_4/mountain_stone.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const COLUMN := preload("res://assets/art/backgrounds/level_4/broken_column.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 304.0
const FAR_SCROLL := 0.13
const FAR_VERTICAL_SCROLL := 0.25
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_add_terrain("Ground", Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Mountain.WIDTH, -128, 16, 512))
	for index in Mountain.PLATFORMS.size():
		_add_terrain("MountainTerrace%d" % index, Mountain.PLATFORMS[index])
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
	for piece in Mountain.terrain_pieces(rectangle):
		var body_name := "%sPart%d" % [prefix, index]
		_make_solid(body_name, piece)
		if Mountain.is_spike_floor(piece):
			get_node(body_name).set_meta("spike_pit", true)
		index += 1


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _build_landscape() -> void:
	backdrop = Node2D.new()
	backdrop.name = "MountainBackdrop"
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
	midground.name = "MountainLandmarks"
	midground.z_index = -2
	add_child(midground)
	# Complete objects stay on authored landings; only the distant landscape
	# uses parallax. Painted bases overlap the terrain through GROUNDING.
	for point in [Vector2(144, 104), Vector2(608, 104), Vector2(2104, 104), Vector2(3440, 96), Vector2(4136, 84)]:
		_landmark(GROVE, point.x, point.y, "CypressGrove")
	for point in [Vector2(1784, 64), Vector2(2512, 64), Vector2(4504, 64)]:
		_landmark(OUTCROP, point.x, point.y, "RockyOutcrop")
	for point in [Vector2(1008, 44), Vector2(1528, 34), Vector2(2760, 32), Vector2(2992, 40), Vector2(4376, 32)]:
		_landmark(TERRACE_WALL, point.x, point.y, "TerraceWall")
	_sync_backdrop()


func _landmark(texture: Texture2D, route_x: float, height: float, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(route_x))
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, route_x, Mountain.surface_at(route_x), height)
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
	_draw_terrain(Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72))
	for platform: Rect2 in Mountain.PLATFORMS:
		_draw_terrain(platform)
	for x in [1984, 4048, 4632]:
		var height := 41.0
		draw_texture_rect(COLUMN, GROUNDING.rect(COLUMN, x, Mountain.surface_at(x), height), false)


func _draw_terrain(rectangle: Rect2) -> void:
	for piece in Mountain.terrain_pieces(rectangle):
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
