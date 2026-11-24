@tool
extends Node2D

# Visual water above a real recessed stone bed. No damage or physics area.
var canal_width := 32.0
var canal_depth := 24.0
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 1
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var top := canal_depth - 7.0
	draw_rect(Rect2(0, top, canal_width, 7), Color(0.10, 0.60, 0.66, 0.52))
	for index in 3:
		var x := fposmod(index * canal_width / 3.0 + _time * 3.0, canal_width)
		var y := top + 1.0 + sin(_time * 2.0 + index) * 0.6
		draw_line(Vector2(x, y), Vector2(minf(x + 6, canal_width), y), Color(0.74, 0.96, 0.94, 0.8), 0.4, true)
