@tool
extends "res://scenes/levels/level_geometry.gd"

const Gorge := preload("res://scenes/levels/level_5_layout.gd")


func _ready() -> void:
	_add_terrain("Ground", Rect2(0, Gorge.FLOOR_Y, Gorge.WIDTH, 72))
	_make_solid("LeftBoundary", Rect2(-16, -128, 16, 512))
	_make_solid("RightBoundary", Rect2(Gorge.WIDTH, -128, 16, 512))
	for index in Gorge.PLATFORMS.size():
		_add_terrain("GorgeTerrace%d" % index, Gorge.PLATFORMS[index])
	for index in Gorge.BONUS_LEDGES.size():
		var body_name := "BullLedge%d" % index
		_make_solid(body_name, Gorge.BONUS_LEDGES[index])
		var collision := get_node(body_name).get_child(0) as CollisionShape2D
		collision.one_way_collision = true
		collision.one_way_collision_margin = 2
	queue_redraw()


func _add_terrain(prefix: String, rectangle: Rect2) -> void:
	var index := 0
	for piece in Gorge.terrain_pieces(rectangle):
		var body_name := "%sPart%d" % [prefix, index]
		_make_solid(body_name, piece)
		if Gorge.is_spike_floor(piece):
			get_node(body_name).set_meta("spike_pit", true)
		index += 1


func _draw() -> void:
	for y in range(0, Gorge.HEIGHT, 8):
		draw_rect(Rect2(0, y, Gorge.WIDTH, 8), Color("8ca6a5").lerp(Color("d9d3b7"), float(y) / Gorge.HEIGHT))
	# Pale, flat-topped limestone faces replace the open mountain ridgelines.
	# Their darker clefts descend below the causeway rather than forming water.
	for x in range(-256, Gorge.WIDTH + 320, 320):
		var base := _road_height(x + 160)
		var top := base - 156 - posmod(x, 3) * 8
		draw_colored_polygon(PackedVector2Array([Vector2(x - 48, Gorge.HEIGHT), Vector2(x - 24, top + 48), Vector2(x + 20, top + 48), Vector2(x + 34, top + 8), Vector2(x + 132, top), Vector2(x + 156, top + 32), Vector2(x + 230, top + 32), Vector2(x + 300, Gorge.HEIGHT)]), Color("a7b1a4"))
		for row in range(int(top) + 24, Gorge.HEIGHT, 24):
			draw_line(Vector2(x + 34, row), Vector2(x + 200, row + 4), Color("b9bdac"), 2)
	for x in range(-96, Gorge.WIDTH + 224, 224):
		_cliff_face(x, _road_height(x + 80) - 86 - posmod(x, 5) * 5)
	# Small sanctuaries are set back on the cliff shelves. Their muted doors and
	# roofs distinguish them from the larger, interactive exit temple.
	for x in [256, 1056, 1824, 2496, 3168, 4000, 4464]:
		_ruined_temple(x, _road_height(x) + 8)
	for x in [96, 688, 1392, 1936, 2704, 3552, 4216]:
		_broken_column(x, _road_height(x) + 4)
	for x in [176, 704, 1312, 1968, 2176, 2816, 3536, 4080, 4336]:
		_scrub(x, _road_height(x) + 3)
	_draw_terrain(Rect2(0, Gorge.FLOOR_Y, Gorge.WIDTH, 72))
	for platform: Rect2 in Gorge.PLATFORMS:
		_draw_terrain(platform)
	for ledge: Rect2 in Gorge.BONUS_LEDGES:
		_paving(ledge)
		for x in [ledge.position.x + 12, ledge.end.x - 20]:
			draw_colored_polygon(PackedVector2Array([Vector2(x, ledge.end.y), Vector2(x + 8, ledge.end.y), Vector2(x, ledge.end.y + 10)]), Color("9c947c"))


func _road_height(x: float) -> float:
	var ground := float(Gorge.FLOOR_Y)
	for platform: Rect2 in Gorge.PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			ground = minf(ground, platform.position.y)
	return ground


func _cliff_face(x: float, top: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - 20, Gorge.HEIGHT), Vector2(x + 6, top + 38), Vector2(x + 18, top + 38), Vector2(x + 30, top + 8), Vector2(x + 84, top), Vector2(x + 108, top + 18), Vector2(x + 138, top + 18), Vector2(x + 160, Gorge.HEIGHT)]), Color("9ba18d"))
	draw_colored_polygon(PackedVector2Array([Vector2(x + 84, top), Vector2(x + 108, top + 18), Vector2(x + 138, top + 18), Vector2(x + 160, Gorge.HEIGHT), Vector2(x + 100, Gorge.HEIGHT), Vector2(x + 96, top + 60)]), Color("858e7f"))
	draw_colored_polygon(PackedVector2Array([Vector2(x + 160, top + 76), Vector2(x + 184, top + 38), Vector2(x + 176, Gorge.HEIGHT), Vector2(x + 150, Gorge.HEIGHT)]), Color("657a74"))
	for row in range(int(top) + 20, Gorge.HEIGHT, 16):
		var inset := posmod(row, 3) * 8
		draw_line(Vector2(x + 28 + inset, row), Vector2(x + 92, row + 2), Color("b3b39b"), 2)
		draw_line(Vector2(x + 104, row + 5), Vector2(x + 132, row + 8), Color("929984"))
	draw_line(Vector2(x + 60, top + 16), Vector2(x + 54, top + 46), Color("858e7c"))
	draw_line(Vector2(x + 54, top + 46), Vector2(x + 64, top + 68), Color("858e7c"))


func _ruined_temple(x: float, base: float) -> void:
	var roof := base - 77
	draw_rect(Rect2(x - 48, base - 6, 96, 6), Color("a8a58c"))
	draw_rect(Rect2(x - 39, roof + 14, 78, 57), Color("8f9b8b"))
	draw_rect(Rect2(x - 10, base - 43, 20, 37), Color("737f75"))
	for column_x in [-32, -11, 11, 32]:
		var height := 50 if column_x != 32 else 34
		draw_rect(Rect2(x + column_x - 4, base - height - 6, 8, height), Color("c1bda2"))
		draw_rect(Rect2(x + column_x - 4, base - height - 6, 2, height - 2), Color("d4ceb0"))
		draw_rect(Rect2(x + column_x - 6, base - height - 9, 12, 4), Color("c8c2a6"))
	draw_rect(Rect2(x - 44, roof + 8, 88, 7), Color("c1b89b"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 47, roof + 8), Vector2(x - 3, roof - 14), Vector2(x + 12, roof - 8), Vector2(x + 38, roof + 4)]), Color("c9bda0"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 32, roof + 6), Vector2(x - 3, roof - 8), Vector2(x + 25, roof + 6)]), Color("9d8167"))
	draw_rect(Rect2(x + 22, base - 12, 18, 6), Color("b7ae92"))
	draw_line(Vector2(x + 25, base - 11), Vector2(x + 35, base - 11), Color("d0c5a6"))


func _broken_column(x: float, base: float) -> void:
	draw_rect(Rect2(x - 7, base - 6, 14, 6), Color("aaa38a"))
	draw_rect(Rect2(x - 4, base - 44, 8, 38), Color("c4bca0"))
	draw_rect(Rect2(x - 4, base - 43, 2, 35), Color("dbd0af"))
	draw_line(Vector2(x - 4, base - 44), Vector2(x + 4, base - 39), Color("8b907c"))
	draw_rect(Rect2(x + 12, base - 6, 14, 6), Color("b9b095"))


func _scrub(x: float, base: float) -> void:
	draw_rect(Rect2(x - 11, base - 6, 22, 6), Color("7b8b69"))
	draw_rect(Rect2(x - 7, base - 10, 15, 4), Color("8f9870"))
	draw_rect(Rect2(x - 3, base - 13, 7, 4), Color("9da178"))


func _draw_terrain(rectangle: Rect2) -> void:
	for piece in Gorge.terrain_pieces(rectangle):
		_paving(piece)


func _paving(rectangle: Rect2) -> void:
	draw_rect(rectangle, Color("a89b7d"))
	for y in range(int(rectangle.position.y) + 12, int(rectangle.end.y), 12):
		draw_line(Vector2(rectangle.position.x, y), Vector2(rectangle.end.x, y), Color("7e7c65"))
		var offset := 12 if y % 24 == 0 else 0
		for x in range(int(rectangle.position.x) + offset, int(rectangle.end.x), 28):
			draw_line(Vector2(x, y - 10), Vector2(x + 1, y), Color("7e7c65"))
			var width := minf(16, rectangle.end.x - x - 4)
			if width > 0:
				draw_rect(Rect2(x + 3, y - 8, width, 2), Color("bab092"))
	draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 4)), Color("e5d9b4"))
	draw_rect(Rect2(rectangle.position + Vector2(0, 4), Vector2(rectangle.size.x, 2)), Color("b8a783"))
	for x in range(int(rectangle.position.x) + 4, int(rectangle.end.x) - 4, 24):
		draw_rect(Rect2(x, rectangle.position.y + 1, 7, 1), Color("f4e9c9"))
