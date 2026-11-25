@tool
extends "res://scenes/levels/level_geometry.gd"

const Troy := preload("res://scenes/levels/level_4_layout.gd")
const CONTINUOUS_LANDSCAPE := true
const PANORAMA_SHEETS := [preload("res://assets/art/backgrounds/troy/fortifications_landscape.png")]
const TROJAN_HORSE := preload("res://assets/art/backgrounds/troy/trojan_horse.png")
const BASTION := preload("res://assets/art/backgrounds/troy/bastion.png")
const GATEWAY := preload("res://assets/art/backgrounds/level_2/cyclopean_gate.png")
const LOW_WALL := preload("res://assets/art/backgrounds/level_4/terrace_wall.png")
const MASONRY := preload("res://assets/art/backgrounds/level_3/city_masonry.png")
const CAP_STONE := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
const LANDSCAPE_HEIGHT := 304.0
const FAR_SCROLL := 0.105
const FAR_VERTICAL_SCROLL := 0.25
var backdrop: Node2D
var midground: Node2D


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Troy.FLOOR_Y, Troy.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Troy.WIDTH, -128, 16, 512))
	for index in Troy.PLATFORMS.size():
		_make_solid("Rampart%d" % index, Troy.PLATFORMS[index])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	process_priority = 10
	backdrop = Node2D.new()
	backdrop.name = "TroyBackdrop"
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
	midground.name = "TrojanFortifications"
	midground.z_index = -2
	add_child(midground)
	for point in [Vector2(224, 112), Vector2(960, 108), Vector2(1456, 96), Vector2(2752, 102), Vector2(3360, 110), Vector2(4160, 104), Vector2(5248, 116)]:
		_landmark(BASTION, point, "Bastion")
	_landmark(TROJAN_HORSE, Vector2(2112, 112), "TrojanHorse")
	for point in [Vector2(1136, 80), Vector2(2288, 80), Vector2(4352, 88), Vector2(5728, 112)]:
		_landmark(GATEWAY, point, "Gateway")
	for point in [Vector2(688, 36), Vector2(1856, 36), Vector2(3616, 36), Vector2(4776, 40)]:
		_landmark(LOW_WALL, point, "RetainingWall")
	_sync_backdrop()
	if not Engine.is_editor_hint():
		call_deferred("_decorate_exit")
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_backdrop()


func _landmark(texture: Texture2D, point: Vector2, label: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label + str(int(point.x))
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	GROUNDING.place(sprite, point.x, Troy.surface_at(point.x), point.y)
	midground.add_child(sprite)


func _sync_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	var camera := get_viewport().get_camera_2d()
	var corner := Vector2.ZERO
	if camera != null and not Engine.is_editor_hint():
		var view := Vector2(get_window().content_scale_size) / camera.zoom
		corner = camera.get_screen_center_position() - view * 0.5
	backdrop.position = Vector2(corner.x * (1.0 - FAR_SCROLL), corner.y * (1.0 - FAR_VERTICAL_SCROLL) - 48)


func _decorate_exit() -> void:
	var gate := get_parent().get_node_or_null("TempleGate") as Node2D
	if gate != null:
		# The Cyclopean gateway supplies the Trojan facade; keep the shared
		# collision, captain lock and doorway entry animation.
		gate.self_modulate.a = 0.0


func _draw() -> void:
	_paving(Rect2(0, Troy.FLOOR_Y, Troy.WIDTH, 72))
	for rectangle: Rect2 in Troy.PLATFORMS:
		_paving(rectangle)


func _paving(rectangle: Rect2) -> void:
	draw_set_transform(rectangle.position, 0, Vector2.ONE / 16.0)
	draw_texture_rect(MASONRY, Rect2(Vector2.ZERO, rectangle.size * 16), true, Color(1.06, 0.93, 0.78))
	draw_set_transform(Vector2.ZERO)
	var x := rectangle.position.x
	while x < rectangle.end.x:
		var width := minf(CAP_STONE.get_width() / 16.0, rectangle.end.x - x)
		draw_texture_rect_region(CAP_STONE, Rect2(x, rectangle.position.y, width, 4), Rect2(0, 96, width * 16, 64), Color(1.08, 1.0, 0.88))
		x += width
	draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Color("f5ddb0"), 0.6)
