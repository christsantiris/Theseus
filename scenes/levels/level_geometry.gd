@tool
extends Node2D

const Layout := preload("res://scenes/levels/level_1_layout.gd")
const STONE := Color("bba77e")
const CAP := Color("e4d8b4")
const SEAM := Color("8c8068")


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Layout.FLOOR_Y, Layout.WIDTH, 64))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 400))
	_make_solid("RightBoundary", Rect2(Layout.WIDTH, -128, 16, 400))
	for index in Layout.PLATFORMS.size():
		_make_solid("Terrace%d" % index, Layout.PLATFORMS[index])
	queue_redraw()


func _make_solid(body_name: String, rectangle: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rectangle.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _draw() -> void:
	# Flat pixel bands and repeated native geometry keep the test level's visual language.
	for y in range(0, Layout.HEIGHT, 6):
		var blend := float(y) / Layout.HEIGHT
		draw_rect(Rect2(0, y, Layout.WIDTH, 6), Color("628fa9").lerp(Color("d4cfad"), blend))
	for x in range(-120, Layout.WIDTH + 240, 240):
		var peak := 56.0 + 18.0 * sin(x * 0.013)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 132), Vector2(x + 130, peak), Vector2(x + 290, 132)]), Color("8c9d9c"))
	for x in range(-64, Layout.WIDTH + 128, 128):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 152), Vector2(x + 76, 112 + 8 * sin(x)), Vector2(x + 170, 152)]), Color("849373"))
	for x in range(80, 960, 192):
		_cypress(x, 64 + (x % 3) * 8)
	for x in range(1024, 1880, 112):
		_column(x, 64 if x % 3 == 0 else 46, false)
	for x in range(2000, 2850, 160):
		_olive(x)
	for x in range(2912, 3712, 128):
		_aqueduct(x)
	for x in range(3952, 4600, 128):
		_column(x, 76, true)
	_stone(Rect2(0, Layout.FLOOR_Y, Layout.WIDTH, 40))
	for platform: Rect2 in Layout.PLATFORMS:
		_stone(platform)
	for x in [624, 944, 1856, 2272, 2832, 3744, 4576]:
		_waystone(x)


func _stone(rectangle: Rect2) -> void:
	draw_rect(rectangle, STONE)
	for y in range(int(rectangle.position.y) + 12, int(rectangle.end.y), 12):
		draw_line(Vector2(rectangle.position.x, y), Vector2(rectangle.end.x, y), SEAM)
		var offset := 16 if (y / 12) % 2 == 0 else 0
		for x in range(int(rectangle.position.x) + offset, int(rectangle.end.x), 32):
			draw_line(Vector2(x, y - 10), Vector2(x, y), SEAM)
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 4)), CAP)
	draw_rect(Rect2(rectangle.position + Vector2(0, 4), Vector2(rectangle.size.x, 2)), Color("a18e67"))
	for x in range(int(rectangle.position.x) + 4, int(rectangle.end.x) - 4, 16):
		draw_rect(Rect2(x, rectangle.position.y + 1, 5, 1), Color("f3e8c9"))


func _cypress(x: float, height: float) -> void:
	draw_rect(Rect2(x - 2, 140, 4, 12), Color("665d42"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 145), Vector2(x - 6, 113), Vector2(x, 152 - height), Vector2(x + 8, 115), Vector2(x + 12, 145)]), Color("355940"))
	draw_line(Vector2(x, 152 - height + 10), Vector2(x + 4, 139), Color("54724c"), 2)


func _column(x: float, height: float, intact: bool) -> void:
	var top := 152 - height
	draw_rect(Rect2(x - 9, top, 18, height), Color("b9b294"))
	draw_rect(Rect2(x - 7, top, 4, height), Color("d4cdb0"))
	draw_line(Vector2(x + 3, top + 4), Vector2(x + 3, 146), Color("9f9d84"), 2)
	draw_rect(Rect2(x - 14, 147, 28, 5), Color("c7bd9c"))
	if intact:
		draw_rect(Rect2(x - 14, top - 5, 28, 6), CAP)
	else:
		draw_line(Vector2(x - 8, top + 2), Vector2(x + 7, top + 7), Color("777e6c"), 2)


func _olive(x: float) -> void:
	draw_line(Vector2(x, 152), Vector2(x - 4, 113), Color("74674b"), 5)
	draw_line(Vector2(x - 4, 123), Vector2(x + 15, 107), Color("74674b"), 3)
	for offset in [Vector2(-17, -35), Vector2(4, -49), Vector2(21, -33)]:
		draw_circle(Vector2(x, 152) + offset, 19, Color("617953"))
		draw_circle(Vector2(x - 4, 146) + offset, 12, Color("7b8c5c"))


func _aqueduct(x: float) -> void:
	draw_rect(Rect2(x, 90, 12, 62), Color("a6a88e"))
	draw_rect(Rect2(x - 4, 85, 128, 9), Color("c8c2a1"))
	draw_arc(Vector2(x + 62, 137), 45, PI, TAU, 16, Color("b9b89a"), 9)


func _waystone(x: float) -> void:
	draw_rect(Rect2(x - 3, 137, 6, 15), Color("7d785f"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 135), Vector2(x + 7, 135), Vector2(x + 13, 140), Vector2(x + 7, 145), Vector2(x - 7, 145)]), Color("d4bb83"))
	draw_line(Vector2(x - 2, 140), Vector2(x + 7, 140), Color("655c44"), 1)
