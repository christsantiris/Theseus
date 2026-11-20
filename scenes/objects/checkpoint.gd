@tool
extends Area2D

signal activated(checkpoint: Area2D)

@export var checkpoint_index := 0
@export var spawn_position := Vector2.ZERO
var lit := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func set_lit(value: bool) -> void:
	lit = value
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if lit or not body.is_in_group("player") or body.health <= 0:
		return
	set_lit(true)
	activated.emit(self)


func _draw() -> void:
	draw_rect(Rect2(-14, -6, 28, 6), Color("c8ba94"))
	draw_rect(Rect2(-9, -22, 18, 16), Color("9c967b"))
	draw_rect(Rect2(-11, -24, 22, 5), Color("e8d6a5"))
	draw_line(Vector2(-3, -19), Vector2(-3, -9), Color("c3bda1"), 2)
	draw_rect(Rect2(-7, -28, 14, 4), Color("756548"))
	if lit:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -28), Vector2(-3, -38), Vector2(0, -33), Vector2(3, -42), Vector2(7, -30), Vector2(3, -26)]), Color("e8a13f"))
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -28), Vector2(1, -35), Vector2(4, -29)]), Color("fff0ab"))
	else:
		draw_rect(Rect2(-3, -31, 6, 3), Color("80765d"))
