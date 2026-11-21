@tool
extends Node2D

const ART := preload("res://assets/art/backgrounds/level_1/temple_gate.png")
var _last_unlocked := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func _process(_delta: float) -> void:
	var unlocked := bool(get_parent().get("unlocked"))
	if unlocked != _last_unlocked:
		_last_unlocked = unlocked
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(ART, Rect2(-48, -118, 96, 118), false)
	var unlocked := bool(get_parent().get("unlocked"))
	if not unlocked:
		for x in range(-8, 9, 4):
			_bronze(Rect2(x, -72, 2, 56))
		_bronze(Rect2(-10, -52, 20, 3))
		_bronze(Rect2(-10, -32, 20, 3))
	else:
		_bronze(Rect2(-12, -72, 3, 56))
		_bronze(Rect2(9, -72, 3, 56))


func _bronze(rectangle: Rect2) -> void:
	draw_rect(rectangle, Color("79532d"))
	draw_rect(Rect2(rectangle.position + Vector2(0.25, 0.1), rectangle.size - Vector2(0.65, 0.2)), Color("b99251"))
	draw_line(rectangle.position + Vector2(0.25, 0.1), Vector2(rectangle.position.x + 0.25, rectangle.end.y - 0.1), Color("dcc38a"), 0.3, true)
