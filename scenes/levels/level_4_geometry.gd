@tool
extends "res://scenes/levels/level_geometry.gd"

const Mountain := preload("res://scenes/levels/level_4_layout.gd")


func _ready() -> void:
	_add_terrain("Ground", Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Mountain.WIDTH, -128, 16, 512))
	for index in Mountain.PLATFORMS.size():
		_add_terrain("MountainTerrace%d" % index, Mountain.PLATFORMS[index])
	queue_redraw()


func _add_terrain(prefix: String, rectangle: Rect2) -> void:
	var index := 0
	for piece in Mountain.terrain_pieces(rectangle):
		var body_name := "%sPart%d" % [prefix, index]
		_make_solid(body_name, piece)
		if Mountain.is_spike_floor(piece):
			get_node(body_name).set_meta("spike_pit", true)
		index += 1


func _draw() -> void:
	for y in range(0, Mountain.HEIGHT, 8):
		draw_rect(Rect2(0, y, Mountain.WIDTH, 8), Color("6e99ac").lerp(Color("d6d4b6"), float(y) / Mountain.HEIGHT))
	# Layered rocky ridges follow the climbing path, remaining visible from the
	# foothills through the high pass without overwhelming the actor silhouettes.
	for x in range(-384, Mountain.WIDTH + 384, 384):
		var ground := _ridge_ground(x + 192)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 64, ground + 100), Vector2(x + 72, ground - 54), Vector2(x + 112, ground - 62), Vector2(x + 160, ground - 112), Vector2(x + 192, ground - 88), Vector2(x + 236, ground - 96), Vector2(x + 448, ground + 100)]), Color("94aaa5"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 160, ground - 112), Vector2(x + 192, ground - 88), Vector2(x + 236, ground - 96), Vector2(x + 292, ground - 8), Vector2(x + 178, ground - 38)]), Color("b5bbad"))
	for x in range(-160, Mountain.WIDTH + 240, 240):
		var ground := _ridge_ground(x + 120)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 80, ground + 80), Vector2(x + 42, ground - 30), Vector2(x + 74, ground - 62), Vector2(x + 96, ground - 50), Vector2(x + 138, ground - 54), Vector2(x + 288, ground + 80)]), Color("7d927e"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 74, ground - 62), Vector2(x + 96, ground - 50), Vector2(x + 138, ground - 54), Vector2(x + 170, ground - 10), Vector2(x + 106, ground - 16)]), Color("a4aa8d"))
	# Terraced retaining walls and olive scrub sit behind the bright walkable caps.
	for x in range(32, Mountain.WIDTH, 192):
		var base := _ridge_ground(x + 80) + 12
		_background_wall(Rect2(x, base - 20, 144, 22))
		_background_wall(Rect2(x + 24, base - 44, 112, 18))
		for shrub_x in [x + 18, x + 108]:
			draw_rect(Rect2(shrub_x, base - 25, 20, 4), Color("88966f"))
			draw_rect(Rect2(shrub_x + 5, base - 29, 12, 4), Color("9da078"))
	for x in [96, 208, 448, 656, 816, 1080, 1424, 1600, 1880, 2120, 2360, 2616, 2864, 3040, 3264, 3520, 3760, 4024, 4176, 4400, 4592]:
		_cypress_at(x, _ridge_ground(x) + 6, 68 + posmod(x, 3) * 8)
	for x in [1984, 4048, 4632]:
		var base := _ridge_ground(x)
		draw_rect(Rect2(x - 6, base - 36, 12, 36), Color("b5b093"))
		draw_rect(Rect2(x - 4, base - 35, 3, 32), Color("d3c8a6"))
		draw_rect(Rect2(x - 9, base - 41, 18, 6), Color("c7be9b"))
	_draw_terrain(Rect2(0, Mountain.FLOOR_Y, Mountain.WIDTH, 72))
	for platform: Rect2 in Mountain.PLATFORMS:
		_draw_terrain(platform)


func _ridge_ground(x: float) -> float:
	var ground := float(Mountain.FLOOR_Y)
	for platform: Rect2 in Mountain.PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			ground = minf(ground, platform.position.y)
	return ground


func _background_wall(rectangle: Rect2) -> void:
	draw_rect(rectangle, Color("989f86"))
	for y in range(int(rectangle.position.y) + 8, int(rectangle.end.y), 8):
		draw_line(Vector2(rectangle.position.x, y), Vector2(rectangle.end.x, y), Color("7b8976"))
		for x in range(int(rectangle.position.x) + posmod(y, 3) * 8, int(rectangle.end.x), 24):
			draw_line(Vector2(x, y - 7), Vector2(x, y), Color("7b8976"))
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 2)), Color("b3b49a"))


func _cypress_at(x: float, base: float, height: float) -> void:
	draw_rect(Rect2(x - 2, base - 20, 4, 20), Color("706b4e"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 11, base - 12), Vector2(x - 7, base - 44), Vector2(x, base - height), Vector2(x + 7, base - 42), Vector2(x + 11, base - 12)]), Color("355b4c"))
	draw_line(Vector2(x, base - height + 12), Vector2(x + 4, base - 18), Color("5a7957"), 2)
	draw_line(Vector2(x - 4, base - 45), Vector2(x - 5, base - 20), Color("446846"), 2)


func _draw_terrain(rectangle: Rect2) -> void:
	for piece in Mountain.terrain_pieces(rectangle):
		_retaining_stone(piece)


func _retaining_stone(rectangle: Rect2) -> void:
	draw_rect(rectangle, Color("aca084"))
	for y in range(int(rectangle.position.y) + 12, int(rectangle.end.y), 12):
		draw_line(Vector2(rectangle.position.x, y), Vector2(rectangle.end.x, y), Color("817e68"))
		var shift := 12 if y % 24 == 0 else 0
		for x in range(int(rectangle.position.x) + shift, int(rectangle.end.x) - 3, 28):
			draw_line(Vector2(x, y - 10), Vector2(x + 2, y), Color("85816a"))
			draw_rect(Rect2(x + 4, y - 8, minf(16, rectangle.end.x - x - 5), 2), Color("bcb296"))
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 4)), Color("e9dcba"))
	draw_rect(Rect2(rectangle.position + Vector2(0, 4), Vector2(rectangle.size.x, 2)), Color("bfb08b"))
	for x in range(int(rectangle.position.x) + 4, int(rectangle.end.x) - 4, 24):
		draw_rect(Rect2(x, rectangle.position.y + 1, 7, 1), Color("f6ebcf"))
