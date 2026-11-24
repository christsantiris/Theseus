@tool
extends "res://scenes/levels/level_geometry.gd"

# One authored landscape, never cross-faded or repeated. The camera traverses
# a slow parallax window across it while complete midground objects mark areas.
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/level_1/attic_landscape.png")]
const GROVE := preload("res://assets/art/backgrounds/level_1/olive_grove.png")
const COLONNADE := preload("res://assets/art/backgrounds/level_1/colonnade.png")
const AQUEDUCT := preload("res://assets/art/backgrounds/level_1/aqueduct.png")
const WALL := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const WAYSTONE := preload("res://assets/art/backgrounds/level_1/waystone.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 256.0
const FAR_SCROLL := 0.1
const FAR_VERTICAL_SCROLL := 0.3
const MID_SCROLL := 0.82
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	# Keep every original collision body, surface height and node name.
	super()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	backdrop = Node2D.new()
	backdrop.name = "RoadBackdrop"
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
	midground.name = "RoadLandmarks"
	midground.z_index = -2
	add_child(midground)
	# Positions refer to the route, heights to the visible object. Every arch,
	# column and tree is drawn whole, with genuine transparent space around it.
	for grove in [Vector2(220, 116), Vector2(720, 100), Vector2(1940, 98),
		Vector2(2300, 126), Vector2(2630, 104), Vector2(3930, 108), Vector2(4240, 96)]:
		_landmark(GROVE, grove.x, grove.y, "OliveGrove")
	for ruin in [Vector2(1150, 106), Vector2(1530, 92), Vector2(1770, 76),
		Vector2(3680, 78), Vector2(4470, 110)]:
		_landmark(COLONNADE, ruin.x, ruin.y, "Colonnade")
	_landmark(AQUEDUCT, 3300, 152, "Aqueduct")
	_sync_backdrop()


func _landmark(texture: Texture2D, route_x: float, height: float, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(route_x))
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, route_x * MID_SCROLL + 160.0 * (1.0 - MID_SCROLL), Layout.FLOOR_Y, height)
	midground.add_child(sprite)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var view_top_left := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		view_top_left = camera.get_screen_center_position() - view * 0.5
	# At the last camera position the right edge of this single 768-unit
	# painting meets the viewport exactly. No wrapping, stitching or image readback.
	backdrop.position = Vector2(view_top_left.x * (1.0 - FAR_SCROLL),
		view_top_left.y * (1.0 - FAR_VERTICAL_SCROLL) - 40.0)
	midground.position.x = view_top_left.x * (1.0 - MID_SCROLL)


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
		draw_texture_rect(WAYSTONE, GROUNDING.rect(WAYSTONE, x, Layout.surface_at(x), 21.0, 18.0), false)


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
