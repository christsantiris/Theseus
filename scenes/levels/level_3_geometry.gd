@tool
extends "res://scenes/levels/level_geometry.gd"

const Town := preload("res://scenes/levels/level_3_layout.gd")


func _ready() -> void:
	_make_solid("Ground", Rect2(0, Town.FLOOR_Y, Town.WIDTH, 64))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Town.WIDTH, -128, 16, 512))
	for index in Town.PLATFORMS.size():
		_make_solid("TownTerrace%d" % index, Town.PLATFORMS[index])
	queue_redraw()


func _draw() -> void:
	for y in range(0, Town.HEIGHT, 8):
		draw_rect(Rect2(0, y, Town.WIDTH, 8), Color("789ba9").lerp(Color("e2d4b1"), float(y) / Town.HEIGHT))
	for x in range(-160, Town.WIDTH, 320):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 280), Vector2(x + 80, 106), Vector2(x + 176, 84), Vector2(x + 320, 280)]), Color("a5b2a5"))
	# Muted distant rooflines sit behind the warmer, detailed town buildings.
	for x in range(-64, Town.WIDTH, 96):
		var base := Town.surface_at(x + 48) + 16
		var height := 70 + (posmod(x, 5) * 8)
		draw_rect(Rect2(x, base - height, 84, height), Color("acb5a6"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base - height), Vector2(x + 42, base - height - 16), Vector2(x + 88, base - height)]), Color("a69d8b"))
	for x in range(-32, Town.WIDTH - 64, 160):
		var base := Town.surface_at(x + 48) + 12
		_house(x, base, 72 + posmod(x, 3) * 8, posmod(x, 2) == 0)
	for x in [352, 1376, 2048, 2736, 3408, 4528]:
		_background_temple(x, Town.surface_at(x) + 10)
	_colonnade(2240, 280, 4)
	_colonnade(3008, 216, 3)
	for x in [152, 1504, 2000, 4000, 4160]:
		_town_cypress(x, Town.surface_at(x))
	for x in [1184, 1808, 2944, 3712, 4400]:
		var base := Town.surface_at(x)
		_amphora(x, base + 2)
	_paving(Rect2(0, Town.FLOOR_Y, Town.WIDTH, 40))
	for platform: Rect2 in Town.PLATFORMS:
		_paving(platform)


func _house(x: float, base: float, height: float, blue_door: bool) -> void:
	var top := base - height
	draw_rect(Rect2(x, top, 120, height), Color("c8bda0"))
	draw_rect(Rect2(x + 4, top + 4, 84, height - 4), Color("d6ccb0"))
	draw_rect(Rect2(x + 105, top + 6, 15, height - 6), Color("b5aa91"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 8, top), Vector2(x + 54, top - 20), Vector2(x + 128, top)]), Color("a16c54"))
	for row in 3:
		draw_line(Vector2(x + row * 18 - 2, top - row * 5), Vector2(x + 126 - row * 18, top - row * 5), Color("bd8d68"))
	draw_rect(Rect2(x - 6, top, 132, 4), Color("d9c5a3"))
	draw_rect(Rect2(x + 48, base - 37, 22, 37), Color("55777a") if blue_door else Color("877556"))
	draw_rect(Rect2(x + 50, base - 35, 3, 35), Color("789391") if blue_door else Color("a58a61"))
	draw_rect(Rect2(x + 46, base - 40, 26, 4), Color("b3a68a"))
	for window_x in [18, 86]:
		draw_rect(Rect2(x + window_x, top + 14, 14, 19), Color("7c8d86"))
		draw_rect(Rect2(x + window_x - 2, top + 33, 18, 3), Color("e0d5b8"))
		draw_line(Vector2(x + window_x + 7, top + 15), Vector2(x + window_x + 7, top + 31), Color("b2b79f"))
	for stone_x in range(8, 116, 24):
		draw_rect(Rect2(x + stone_x, base - 8, 18, 2), Color("b8ad92"))


func _background_temple(x: float, base: float) -> void:
	draw_rect(Rect2(x - 52, base - 6, 104, 6), Color("b9b198"))
	draw_rect(Rect2(x - 45, base - 68, 90, 62), Color("a4a896"))
	for column_x in [-36, -12, 12, 36]:
		draw_rect(Rect2(x + column_x - 5, base - 67, 10, 61), Color("d3ccb1"))
		draw_rect(Rect2(x + column_x - 5, base - 65, 3, 57), Color("e1d8ba"))
		draw_rect(Rect2(x + column_x - 7, base - 72, 14, 6), Color("d9d0b4"))
	draw_rect(Rect2(x - 49, base - 80, 98, 9), Color("d7cdb0"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 51, base - 80), Vector2(x, base - 106), Vector2(x + 51, base - 80)]), Color("d1c5a8"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 37, base - 82), Vector2(x, base - 99), Vector2(x + 37, base - 82)]), Color("ad8265"))
	draw_rect(Rect2(x - 3, base - 110, 6, 6), Color("cfb46d"))


func _colonnade(x: float, base: float, columns: int) -> void:
	for index in columns:
		var at := x + index * 40
		draw_rect(Rect2(at - 5, base - 65, 10, 65), Color("c1baa0"))
		draw_rect(Rect2(at - 5, base - 64, 3, 62), Color("d9d0b1"))
		draw_rect(Rect2(at - 8, base - 70, 16, 6), Color("ded3b4"))
	draw_rect(Rect2(x - 12, base - 78, (columns - 1) * 40 + 24, 9), Color("cabd9e"))


func _town_cypress(x: float, base: float) -> void:
	draw_rect(Rect2(x - 2, base - 20, 4, 20), Color("7d7458"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 10, base - 12), Vector2(x - 5, base - 42), Vector2(x, base - 72), Vector2(x + 6, base - 43), Vector2(x + 10, base - 12)]), Color("59745d"))
	draw_line(Vector2(x, base - 58), Vector2(x + 3, base - 18), Color("7e8c65"), 2)


func _amphora(x: float, base: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base), Vector2(x - 7, base - 13), Vector2(x - 3, base - 20), Vector2(x - 3, base - 24), Vector2(x + 3, base - 24), Vector2(x + 3, base - 20), Vector2(x + 7, base - 13), Vector2(x + 4, base)]), Color("ae7853"))
	draw_line(Vector2(x - 2, base - 18), Vector2(x - 3, base - 5), Color("c99b6c"), 2)
	draw_arc(Vector2(x - 5, base - 16), 5, PI * 0.5, PI * 1.6, 8, Color("a17653"), 2)
	draw_arc(Vector2(x + 5, base - 16), 5, -PI * 0.6, PI * 0.5, 8, Color("a17653"), 2)


func _paving(rectangle: Rect2) -> void:
	draw_rect(rectangle, Color("b1a383"))
	for y in range(int(rectangle.position.y) + 12, int(rectangle.end.y), 12):
		draw_line(Vector2(rectangle.position.x, y), Vector2(rectangle.end.x, y), Color("8e846e"))
		var shift := 16 if y % 24 == 0 else 0
		for x in range(int(rectangle.position.x) + shift, int(rectangle.end.x), 32):
			draw_line(Vector2(x, y - 10), Vector2(x, y), Color("958a70"))
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 4)), Color("eee1be"))
	draw_rect(Rect2(rectangle.position + Vector2(0, 4), Vector2(rectangle.size.x, 3)), Color("cbbb94"))
	for x in range(int(rectangle.position.x) + 5, int(rectangle.end.x) - 8, 24):
		draw_rect(Rect2(x, rectangle.position.y + 1, 9, 1), Color("fbf0d0"))
