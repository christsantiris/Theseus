@tool
extends "res://scenes/levels/level_geometry.gd"

const PANORAMA_SHEETS := [
	preload("res://assets/art/backgrounds/level_1/kings_road.png"),
	preload("res://assets/art/backgrounds/level_1/broken_colonnade.png"),
	preload("res://assets/art/backgrounds/level_1/olive_terraces.png"),
	preload("res://assets/art/backgrounds/level_1/ruined_aqueduct.png"),
	preload("res://assets/art/backgrounds/level_1/temple_approach.png"),
]
const WALL := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const WAYSTONE := preload("res://assets/art/backgrounds/level_1/waystone.png")
const PANELS := preload("res://scenes/levels/landscape_panels.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const PANEL_WIDTH := 480.0
const OVERLAP := 48.0
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D


func _ready() -> void:
	# Keep every original collision body, surface height and node name.
	super()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	process_priority = 10
	_build_landscape()
	_sync_backdrop()
	if not Engine.is_editor_hint():
		call_deferred("_decorate_temple")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _build_landscape() -> void:
	var sky := ColorRect.new()
	sky.name = "DistantSky"
	sky.size = Vector2(Layout.WIDTH, Layout.HEIGHT)
	sky.color = Color("a6c4dc")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -2
	add_child(sky)
	backdrop = Node2D.new()
	backdrop.name = "RoadBackdrop"
	backdrop.z_index = -1
	add_child(backdrop)
	var road := ColorRect.new()
	road.name = "RoadContinuation"
	road.position.y = 180.0
	road.size = Vector2(Layout.WIDTH, Layout.HEIGHT)
	road.color = Color("d4c1a3")
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Same layer as the panoramas, so their downward aprons draw over this fill.
	road.z_index = -1
	backdrop.add_child(road)
	# Each section sheet contains west/east panoramas stacked vertically.
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
		var scale_factor := (PANEL_WIDTH + OVERLAP * 2.0) / image.get_width()
		panorama.scale = Vector2.ONE * scale_factor
		panorama.position = Vector2(index * PANEL_WIDTH - OVERLAP, 180.0 - image.get_height() * scale_factor)
		panorama.z_index = -1
		PANELS.prepare(panorama, index > 0, overlap_width, previous)
		PANELS.extend_downward(panorama, Layout.HEIGHT)
		backdrop.add_child(panorama)
		previous = image


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null or Engine.is_editor_hint():
		backdrop.position.y = 0
		return
	var logical_height := float(get_window().content_scale_size.y)
	if logical_height <= 0:
		logical_height = 180
	var center := camera.get_screen_center_position()
	var view_top := center.y - logical_height * 0.5 / camera.zoom.y
	backdrop.position.y = minf(view_top, _skyline_surface(center.x) - 160)


func _skyline_surface(x: float) -> float:
	# Match the later levels: blend nearby terrain heights so the skyline glides
	# over terrace edges while the actual platforms stay fixed in world space.
	var height := float(Layout.FLOOR_Y)
	for terrace: Rect2 in Layout.PLATFORMS:
		var overlap := maxf(0, minf(x + 64, terrace.end.x) - maxf(x - 64, terrace.position.x))
		height -= overlap / 128 * (Layout.FLOOR_Y - terrace.position.y)
	return height


func _decorate_temple() -> void:
	var gate := get_parent().get_node_or_null("TempleGate") as Node2D
	if gate == null:
		return
	# self_modulate hides only the old facade; the replacement child stays visible.
	# Gate collision, unlocking, entry movement and completion remain on the gate.
	gate.self_modulate.a = 0.0
	var facade := Node2D.new()
	facade.name = "CinematicFacade"
	facade.set_script(TEMPLE)
	gate.add_child(facade)


func _draw() -> void:
	# Extend only the visible foundation to cover the newly revealed lower view;
	# super._ready() still creates the original 64-pixel ground collision.
	_draw_masonry(Rect2(0, Layout.FLOOR_Y, Layout.WIDTH, Layout.HEIGHT - Layout.FLOOR_Y))
	for platform: Rect2 in Layout.PLATFORMS:
		_draw_masonry(platform)
	for x in [624, 944, 1856, 2272, 2832, 3744, 4576]:
		draw_texture_rect(WAYSTONE, Rect2(x - 9, 131, 18, 21), false)


func _draw_masonry(rectangle: Rect2) -> void:
	# Render detailed stone at source resolution while retaining exact flat ledges.
	draw_set_transform(rectangle.position, 0.0, Vector2.ONE / MATERIAL_DENSITY)
	draw_texture_rect(WALL, Rect2(Vector2.ZERO, rectangle.size * MATERIAL_DENSITY), true)
	draw_set_transform(Vector2.ZERO)
	var x := rectangle.position.x
	while x < rectangle.end.x:
		var width := minf(WALL.get_width() / MATERIAL_DENSITY, rectangle.end.x - x)
		draw_texture_rect_region(WALL, Rect2(x, rectangle.position.y, width, 4), Rect2(0, 96, width * MATERIAL_DENSITY, 64), Color(1.12, 1.10, 1.06))
		x += width
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("f0e5ca"), 0.35, true)
	draw_line(rectangle.position + Vector2(0, 4), Vector2(rectangle.end.x, rectangle.position.y + 4), Color(0.28, 0.23, 0.16, 0.35), 0.45, true)
