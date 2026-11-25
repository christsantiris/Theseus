@tool
extends "res://scenes/levels/level_geometry.gd"

const Coast := preload("res://scenes/levels/level_2_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/level_2/aegean_landscape.png")]
const OUTCROP := preload("res://assets/art/backgrounds/level_2/coastal_outcrop.png")
const QUAY := preload("res://assets/art/backgrounds/level_2/ruined_quay.png")
const CYCLOPEAN_GATE := preload("res://assets/art/backgrounds/level_2/cyclopean_gate.png")
const CLIFF := preload("res://assets/art/backgrounds/level_2/coastal_limestone.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const WAYSTONE := preload("res://assets/art/backgrounds/level_1/waystone.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const LANDSCAPE_HEIGHT := 288.0
const FAR_SCROLL := 0.10
const FAR_VERTICAL_SCROLL := 0.25
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Coast.FLOOR_Y, Coast.WIDTH, 64))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Coast.WIDTH, -128, 16, 512))
	for index in Coast.PLATFORMS.size():
		_make_solid("CoastalLedge%d" % index, Coast.PLATFORMS[index])
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
	backdrop.name = "SeaBackdrop"
	backdrop.z_index = -3
	add_child(backdrop)
	var sea := Sprite2D.new()
	sea.name = "ContinuousLandscape"
	sea.texture = PANORAMA_SHEETS[0]
	sea.centered = false
	sea.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	sea.scale = Vector2.ONE * LANDSCAPE_HEIGHT / sea.texture.get_height()
	backdrop.add_child(sea)

	midground = Node2D.new()
	midground.name = "CoastalLandmarks"
	midground.z_index = -2
	add_child(midground)
	# These complete objects stand on authored landings. Keep them in world
	# space so their feet never drift off the narrow ledges during a climb.
	for point in [Vector2(260, 108), Vector2(616, 52), Vector2(2016, 56),
		Vector2(2360, 48), Vector2(2760, 64), Vector2(4832, 40), Vector2(5060, 80)]:
		_landmark(OUTCROP, point.x, point.y, "CoastalOutcrop")
	for point in [Vector2(1080, 42), Vector2(1496, 48), Vector2(1776, 40), Vector2(5240, 34)]:
		_landmark(QUAY, point.x, point.y, "RuinedQuay")
	for point in [Vector2(3032, 88), Vector2(3464, 88), Vector2(5368, 84)]:
		_landmark(CYCLOPEAN_GATE, point.x, point.y, "CyclopeanGate")
	_landmark(OUTCROP, 4120, 80, "CoastalOutcrop")
	_landmark(CYCLOPEAN_GATE, 4576, 80, "CyclopeanGate")
	_sync_backdrop()


func _landmark(texture: Texture2D, route_x: float, height: float, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(route_x))
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, route_x, Coast.surface_at(route_x), height)
	midground.add_child(sprite)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var view_top_left := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		view_top_left = camera.get_screen_center_position() - view * 0.5
	# One 864x288 painting covers all 4,800 route units. Its vertical overscan
	# accommodates the full 0..140 camera range without wrapping or aprons.
	backdrop.position = Vector2(view_top_left.x * (1.0 - FAR_SCROLL),
		view_top_left.y * (1.0 - FAR_VERTICAL_SCROLL) - 48.0)


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
	_draw_cliff(Rect2(0, Coast.FLOOR_Y, Coast.WIDTH, 64))
	for platform: Rect2 in Coast.PLATFORMS:
		_draw_cliff(platform)
	for x in [520, 1960, 4984]:
		draw_texture_rect(WAYSTONE, GROUNDING.rect(WAYSTONE, x, Coast.surface_at(x), 21.0, 18.0), false)


func _draw_cliff(rectangle: Rect2) -> void:
	draw_set_transform(rectangle.position, 0.0, Vector2.ONE / MATERIAL_DENSITY)
	draw_texture_rect(CLIFF, Rect2(Vector2.ZERO, rectangle.size * MATERIAL_DENSITY), true)
	draw_set_transform(Vector2.ZERO)
	var x := rectangle.position.x
	while x < rectangle.end.x:
		var width := minf(CAP_STONE.get_width() / MATERIAL_DENSITY, rectangle.end.x - x)
		draw_texture_rect_region(CAP_STONE, Rect2(x, rectangle.position.y, width, 4), Rect2(0, 96, width * MATERIAL_DENSITY, 64), Color(1.10, 1.10, 1.08))
		x += width
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("f0e8d2"), 0.35, true)
	draw_line(rectangle.position + Vector2(0, 4), Vector2(rectangle.end.x, rectangle.position.y + 4), Color(0.24, 0.26, 0.24, 0.35), 0.45, true)
