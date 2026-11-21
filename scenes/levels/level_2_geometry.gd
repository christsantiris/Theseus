@tool
extends "res://scenes/levels/level_geometry.gd"

const Coast := preload("res://scenes/levels/level_2_layout.gd")


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Coast.FLOOR_Y, Coast.WIDTH, 64))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Coast.WIDTH, -128, 16, 512))
	for index in Coast.PLATFORMS.size():
		_make_solid("CoastalLedge%d" % index, Coast.PLATFORMS[index])
	queue_redraw()


func _draw() -> void:
	for y in range(0, Coast.HEIGHT, 8):
		draw_rect(Rect2(0, y, Coast.WIDTH, 8), Color("638fa9").lerp(Color("d6d9c3"), float(y) / 280.0))
	# Aegean horizon, distant dry islands, and restrained pixel wave bands.
	draw_rect(Rect2(0, 174, Coast.WIDTH, 146), Color("427e93"))
	for y in range(180, 280, 8):
		draw_rect(Rect2(0, y, Coast.WIDTH, 3), Color("5599a5") if y % 16 == 4 else Color("4b899b"))
		for x in range((y * 7) % 80, Coast.WIDTH, 80):
			draw_rect(Rect2(x, y, 18 + y % 13, 1), Color("8ab8b4"))
	for x in range(-160, Coast.WIDTH, 400):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 180), Vector2(x + 72, 152), Vector2(x + 94, 152), Vector2(x + 126, 139), Vector2(x + 151, 147), Vector2(x + 192, 145), Vector2(x + 274, 180)]), Color("8ba3a2"))
	# Jagged offshore limestone outcrops, clearly separated from walkable terrain.
	for x in range(128, Coast.WIDTH, 448):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 274), Vector2(x + 28, 230), Vector2(x + 39, 230), Vector2(x + 54, 204), Vector2(x + 70, 212), Vector2(x + 91, 251), Vector2(x + 112, 274)]), Color("929f98"))
		draw_line(Vector2(x + 52, 213), Vector2(x + 65, 256), Color("bac0a9"), 3)
	for x in [96, 512, 1744, 2080, 3680, 4160]:
		_coastal_cypress(x, Coast.surface_at(x))
	for x in [1056, 1440, 2480, 3088, 3440, 4384]:
		_ruined_column(x, Coast.surface_at(x), 52 if x % 3 else 36)
	_limestone(Rect2(0, Coast.FLOOR_Y, Coast.WIDTH, 40))
	for platform: Rect2 in Coast.PLATFORMS:
		_limestone(platform)
	for x in [520, 1960, 4024]:
		var y := Coast.surface_at(x)
		draw_rect(Rect2(x - 2, y - 18, 4, 18), Color("796d50"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y - 20), Vector2(x + 7, y - 20), Vector2(x + 13, y - 15), Vector2(x + 7, y - 10), Vector2(x - 8, y - 10)]), Color("d9c38e"))


func _limestone(rectangle: Rect2) -> void:
	draw_rect(rectangle, Color("a69c80"))
	for y in range(int(rectangle.position.y) + 10, int(rectangle.end.y), 16):
		var shift := 13 if y % 32 < 16 else 0
		for x in range(int(rectangle.position.x) + shift, int(rectangle.end.x) - 12, 32):
			draw_rect(Rect2(x + 3, y, 20, 7), Color("bcb397"))
			draw_line(Vector2(x + 2, y + 8), Vector2(x + 23, y + 8), Color("877e68"))
			draw_line(Vector2(x + 25, y - 3), Vector2(x + 22, y + 4), Color("877e68"))
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 4)), Color("e7dbb7"))
	draw_rect(Rect2(rectangle.position + Vector2(0, 4), Vector2(rectangle.size.x, 2)), Color("cec19c"))
	for x in range(int(rectangle.position.x) + 6, int(rectangle.end.x) - 5, 24):
		draw_rect(Rect2(x, rectangle.position.y + 1, 8, 1), Color("f3e9cd"))


func _coastal_cypress(x: float, base: float) -> void:
	draw_rect(Rect2(x - 2, base - 24, 4, 24), Color("70674d"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 10, base - 12), Vector2(x - 7, base - 40), Vector2(x, base - 76), Vector2(x + 7, base - 46), Vector2(x + 11, base - 12)]), Color("405c4c"))
	draw_line(Vector2(x, base - 62), Vector2(x + 4, base - 20), Color("647c58"), 2)


func _ruined_column(x: float, base: float, height: float) -> void:
	draw_rect(Rect2(x - 10, base - height, 20, height), Color("b7b297"))
	draw_rect(Rect2(x - 8, base - height, 5, height), Color("d0c9aa"))
	draw_line(Vector2(x + 4, base - height + 6), Vector2(x + 4, base - 6), Color("8d927f"), 2)
	draw_line(Vector2(x - 10, base - height), Vector2(x + 9, base - height + 5), Color("e0d6b5"), 2)
	draw_rect(Rect2(x - 14, base - 5, 28, 5), Color("c8bea0"))
