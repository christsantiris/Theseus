@tool
extends "res://scenes/levels/level_geometry.gd"

const Coast := preload("res://scenes/levels/level_2_layout.gd")
const PANORAMA_SHEETS := [
	preload("res://assets/art/backgrounds/level_2/coastal_road.png"),
	preload("res://assets/art/backgrounds/level_2/broken_quays.png"),
	preload("res://assets/art/backgrounds/level_2/sea_cliffs.png"),
	preload("res://assets/art/backgrounds/level_2/cyclopean_ruins.png"),
	preload("res://assets/art/backgrounds/level_2/rocky_sanctuary.png"),
]
const CLIFF := preload("res://assets/art/backgrounds/level_2/coastal_limestone.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const WAYSTONE := preload("res://assets/art/backgrounds/level_1/waystone.png")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const BLEND := preload("res://resources/shaders/landscape_blend.gdshader")
const PANEL_WIDTH := 480.0
const OVERLAP := 48.0
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Coast.FLOOR_Y, Coast.WIDTH, 64))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Coast.WIDTH, -128, 16, 512))
	for index in Coast.PLATFORMS.size():
		_make_solid("CoastalLedge%d" % index, Coast.PLATFORMS[index])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	sky.size = Vector2(Coast.WIDTH, Coast.HEIGHT)
	sky.color = Color("a6c4dc")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -2
	add_child(sky)
	backdrop = Node2D.new()
	backdrop.name = "SeaBackdrop"
	backdrop.z_index = -1
	add_child(backdrop)
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
		var material := ShaderMaterial.new()
		material.shader = BLEND
		material.set_shader_parameter("blend_left", index > 0)
		material.set_shader_parameter("overlap_width", OVERLAP * 2.0 / (PANEL_WIDTH + OVERLAP * 2.0))
		# Use the full shared width for sky, terrain and architecture alike.
		panorama.material = material
		backdrop.add_child(panorama)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null or Engine.is_editor_hint():
		backdrop.position.y = Coast.FLOOR_Y - 152.0
		return
	# Distant scenery stays at the horizon while the camera follows the taller
	# cliffs. The rock surfaces, actors, and every collision remain in world space.
	var logical_height := float(get_window().content_scale_size.y)
	if logical_height <= 0.0:
		logical_height = 180.0
	backdrop.position.y = camera.get_screen_center_position().y - logical_height * 0.5 / camera.zoom.y


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
	for x in [520, 1960, 4024]:
		draw_texture_rect(WAYSTONE, Rect2(x - 9, Coast.surface_at(x) - 21, 18, 21), false)


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
