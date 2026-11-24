@tool
extends "res://scenes/levels/level_geometry.gd"

const Atlantis := preload("res://scenes/levels/level_6_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/level_6/atlantis_landscape.png")]
const WAVE_WALL := preload("res://assets/art/backgrounds/level_6/wave_wall.png")
const STATUE := preload("res://assets/art/backgrounds/level_6/poseidon_statue.png")
const ARCH := preload("res://assets/art/backgrounds/level_2/cyclopean_gate.png")
const COLONNADE := preload("res://assets/art/backgrounds/level_1/colonnade.png")
const MASONRY := preload("res://assets/art/backgrounds/level_3/city_masonry.png")
const CANAL := preload("res://scenes/objects/shallow_canal.gd")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 304.0
const FAR_SCROLL := 0.13
const FAR_VERTICAL_SCROLL := 0.25
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_add_terrain("Ground", Rect2(0, Atlantis.FLOOR_Y, Atlantis.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Atlantis.WIDTH, -128, 16, 512))
	for index in Atlantis.PLATFORMS.size():
		_add_terrain("AtlantisTerrace%d" % index, Atlantis.PLATFORMS[index])
	for definition: Dictionary in Atlantis.CANALS:
		var canal := CANAL.new()
		canal.name = definition.name
		canal.position = definition.position
		canal.canal_width = definition.width
		canal.canal_depth = definition.depth
		add_child(canal)
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
	for piece in Atlantis.terrain_pieces(rectangle):
		var body_name := "%sPart%d" % [prefix, index]
		_make_solid(body_name, piece)
		index += 1


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _build_landscape() -> void:
	backdrop = Node2D.new()
	backdrop.name = "AtlantisBackdrop"
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
	midground.name = "AtlantisLandmarks"
	midground.z_index = -2
	add_child(midground)
	# Complete objects stay on authored landings; only the distant landscape
	# uses parallax. Painted bases overlap the terrain through GROUNDING.
	for point in [Vector2(848, 52), Vector2(1760, 64), Vector2(2512, 64), Vector2(3264, 72), Vector2(4496, 40)]:
		_landmark(WAVE_WALL, point.x, point.y, "WaveWall")
	for point in [Vector2(192, 118), Vector2(1152, 100), Vector2(2128, 72), Vector2(4216, 110)]:
		_landmark(STATUE, point.x, point.y, "PoseidonStatue")
	for point in [Vector2(512, 88), Vector2(2816, 80)]:
		_landmark(ARCH, point.x, point.y, "HarborArch")
	for point in [Vector2(3616, 56), Vector2(3896, 56)]:
		_landmark(COLONNADE, point.x, point.y, "Colonnade")
	_sync_backdrop()


func _landmark(texture: Texture2D, route_x: float, height: float, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(route_x))
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, route_x, Atlantis.surface_at(route_x), height)
	midground.add_child(sprite)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var corner := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		corner = camera.get_screen_center_position() - view * 0.5
	# Overscan covers the full camera range, including canal bottoms and jumps.
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
	_draw_terrain(Rect2(0, Atlantis.FLOOR_Y, Atlantis.WIDTH, 72))
	for platform: Rect2 in Atlantis.PLATFORMS:
		_draw_terrain(platform)



func _draw_terrain(rectangle: Rect2) -> void:
	for piece in Atlantis.terrain_pieces(rectangle):
		_retaining_stone(piece)


func _retaining_stone(rectangle: Rect2) -> void:
	draw_set_transform(rectangle.position, 0.0, Vector2.ONE / MATERIAL_DENSITY)
	draw_texture_rect(MASONRY, Rect2(Vector2.ZERO, rectangle.size * MATERIAL_DENSITY), true, Color(0.90, 1.0, 0.98))
	draw_set_transform(Vector2.ZERO)
	var x := rectangle.position.x
	while x < rectangle.end.x:
		var width := minf(CAP_STONE.get_width() / MATERIAL_DENSITY, rectangle.end.x - x)
		draw_texture_rect_region(CAP_STONE, Rect2(x, rectangle.position.y, width, 4), Rect2(0, 96, width * MATERIAL_DENSITY, 64), Color(1.10, 1.10, 1.08))
		x += width
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("f0e8d2"), 0.35, true)
	draw_line(rectangle.position + Vector2(0, 4), Vector2(rectangle.end.x, rectangle.position.y + 4), Color(0.24, 0.26, 0.24, 0.35), 0.45, true)
