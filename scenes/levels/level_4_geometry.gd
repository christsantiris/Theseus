@tool
extends "res://scenes/levels/level_geometry.gd"

const Mountain := preload("res://scenes/levels/level_4_layout.gd")
const PANORAMA_SHEETS := [
	preload("res://assets/art/backgrounds/level_4/cypress_foothills.png"),
	preload("res://assets/art/backgrounds/level_4/stone_switchbacks.png"),
	preload("res://assets/art/backgrounds/level_4/mountain_gardens.png"),
	preload("res://assets/art/backgrounds/level_4/high_pass.png"),
	preload("res://assets/art/backgrounds/level_4/summit_sanctuary.png"),
]
const MASONRY := preload("res://assets/art/backgrounds/level_4/mountain_stone.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const COLUMN := preload("res://assets/art/backgrounds/level_4/broken_column.png")
const TEMPLE := preload("res://scenes/levels/level_1_temple.gd")
const BLEND := preload("res://resources/shaders/landscape_blend.gdshader")
const PANEL_WIDTH := 480.0
const OVERLAP := 48.0
const MATERIAL_DENSITY := 16.0
var backdrop: Node2D


func _ready() -> void:
	_add_terrain("Ground", Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Mountain.WIDTH, -128, 16, 512))
	for index in Mountain.PLATFORMS.size():
		_add_terrain("MountainTerrace%d" % index, Mountain.PLATFORMS[index])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	var sky := ColorRect.new()
	sky.name = "DistantSky"
	sky.size = Vector2(Mountain.WIDTH, Mountain.HEIGHT)
	sky.color = Color("a6c4dc")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -2
	add_child(sky)
	backdrop = Node2D.new()
	backdrop.name = "MountainBackdrop"
	backdrop.z_index = -1
	add_child(backdrop)
	# Continue the dusty mountainside below the panoramas where descending
	# terraces reveal the distance behind them.
	var road := ColorRect.new()
	road.name = "SlopeContinuation"
	road.position.y = 180.0
	road.size = Vector2(Mountain.WIDTH, Mountain.HEIGHT)
	road.color = Color("d4c1a3")
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(road)
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
		backdrop.position.y = Mountain.FLOOR_Y - 152.0
		return
	# Keep the slopes and distant ridges visible above the local landing
	# through the climb. Every terrain and spike collision stays in world space.
	var logical_height := float(get_window().content_scale_size.y)
	if logical_height <= 0.0:
		logical_height = 180.0
	var center := camera.get_screen_center_position()
	var view_top := center.y - logical_height * 0.5 / camera.zoom.y
	backdrop.position.y = minf(view_top, _ridge_surface(center.x) - 160.0)


func _ridge_surface(x: float) -> float:
	# Average the nearby route height so the skyline glides over step edges.
	var height := float(Mountain.FLOOR_Y)
	for terrace: Rect2 in Mountain.PLATFORMS:
		var overlap := maxf(0.0, minf(x + 64.0, terrace.end.x) - maxf(x - 64.0, terrace.position.x))
		height -= overlap / 128.0 * (Mountain.FLOOR_Y - terrace.position.y)
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
	_draw_terrain(Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72))
	for platform: Rect2 in Mountain.PLATFORMS:
		_draw_terrain(platform)
	for x in [1984, 4048, 4632]:
		var height := 41.0
		var width := height * COLUMN.get_width() / float(COLUMN.get_height())
		draw_texture_rect(COLUMN, Rect2(x - width * 0.5, Mountain.surface_at(x) - height, width, height), false)


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
