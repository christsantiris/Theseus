@tool
extends "res://scenes/levels/level_geometry.gd"

const Town := preload("res://scenes/levels/level_3_layout.gd")
const PANORAMA_SHEETS := [
	preload("res://assets/art/backgrounds/level_3/city_gate.png"),
	preload("res://assets/art/backgrounds/level_3/potters_quarter.png"),
	preload("res://assets/art/backgrounds/level_3/agora_terraces.png"),
	preload("res://assets/art/backgrounds/level_3/temple_district.png"),
	preload("res://assets/art/backgrounds/level_3/acropolis_approach.png"),
]
const MASONRY := preload("res://assets/art/backgrounds/level_3/city_masonry.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const AMPHORA := preload("res://assets/art/backgrounds/level_3/amphora.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const PANELS := preload("res://scenes/levels/landscape_panels.gd")
const PANEL_WIDTH := 480.0
const OVERLAP := 48.0
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D


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
	var sky := ColorRect.new()
	sky.name = "DistantSky"
	sky.size = Vector2(Town.WIDTH, Town.HEIGHT)
	sky.color = Color("a6c4dc")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -2
	add_child(sky)
	backdrop = Node2D.new()
	backdrop.name = "CityBackdrop"
	backdrop.z_index = -1
	add_child(backdrop)
	# Continue the dusty street below the panoramas where descending terraces
	# reveal the distance behind them.
	var road := ColorRect.new()
	road.name = "RoadContinuation"
	road.position.y = 180.0
	road.size = Vector2(Town.WIDTH, Town.HEIGHT)
	road.color = Color("d4c1a3")
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(road)
	var overlap_width := OVERLAP * 2.0 / (PANEL_WIDTH + OVERLAP * 2.0)
	var previous: Texture2D
	for index in PANORAMA_SHEETS.size() * 2:
		var sheet: Texture2D = PANORAMA_SHEETS[index / 2]
		var image := AtlasTexture.new()
		image.atlas = sheet
		image.region = Rect2(0, (index % 2) * sheet.get_height() / 2, sheet.get_width(), sheet.get_height() / 2)
		var panorama := Sprite2D.new()
		panorama.name = "Landscape%d" % index
		panorama.texture = image
		panorama.centered = false
		panorama.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		var factor := (PANEL_WIDTH + OVERLAP * 2.0) / image.get_width()
		panorama.scale = Vector2.ONE * factor
		panorama.position = Vector2(index * PANEL_WIDTH - OVERLAP, 180.0 - image.get_height() * factor)
		PANELS.prepare(panorama, index > 0, overlap_width, previous)
		PANELS.extend_downward(panorama, Town.HEIGHT)
		backdrop.add_child(panorama)
		previous = image


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null or Engine.is_editor_hint():
		backdrop.position.y = Town.FLOOR_Y - 152.0
		return
	# Keep the background buildings above the local landing through the climb,
	# rather than hiding their facades behind the tall foreground terraces.
	var logical_height := float(get_window().content_scale_size.y)
	if logical_height <= 0.0:
		logical_height = 180.0
	var center := camera.get_screen_center_position()
	var view_top := center.y - logical_height * 0.5 / camera.zoom.y
	backdrop.position.y = minf(view_top, _skyline_surface(center.x) - 160.0)


func _skyline_surface(x: float) -> float:
	# Average the nearby route height so the skyline glides over step edges.
	var height := float(Town.FLOOR_Y)
	for terrace: Rect2 in Town.PLATFORMS:
		var overlap := maxf(0.0, minf(x + 64.0, terrace.end.x) - maxf(x - 64.0, terrace.position.x))
		height -= overlap / 128.0 * (Town.FLOOR_Y - terrace.position.y)
	return height


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
	for x in [1184, 1808, 2944, 3712, 4400]:
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
