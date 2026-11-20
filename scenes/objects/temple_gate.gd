@tool
extends Node2D

signal entered

var unlocked := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		$Finish.body_entered.connect(_on_body_entered)


func unlock() -> void:
	unlocked = true
	$Barrier/CollisionShape2D.set_deferred("disabled", true)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if unlocked and body.is_in_group("player") and body.health > 0:
		entered.emit()


func _draw() -> void:
	for x in [-32, 32]:
		draw_rect(Rect2(x - 6, -80, 12, 80), Color("e2d4ad"))
		draw_rect(Rect2(x - 8, -82, 16, 5), Color("f4e7c7"))
		draw_rect(Rect2(x - 8, -4, 16, 4), Color("b7a47d"))
		draw_line(Vector2(x + 2, -76), Vector2(x + 2, -6), Color("b7a47d"), 2)
	draw_rect(Rect2(-40, -89, 80, 9), Color("e2d4ad"))
	draw_rect(Rect2(-26, -79, 52, 79), Color("343e40"))
	if not unlocked:
		for x in range(-22, 27, 8):
			draw_rect(Rect2(x, -76, 3, 76), Color("ad8442"))
		draw_rect(Rect2(-24, -48, 48, 4), Color("c99a4d"))
		draw_rect(Rect2(-24, -24, 48, 4), Color("c99a4d"))
	else:
		draw_rect(Rect2(-23, -76, 4, 76), Color("ad8442"))
		draw_rect(Rect2(20, -76, 4, 76), Color("ad8442"))
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -29), Vector2(4, -29), Vector2(4, -35), Vector2(14, -26), Vector2(4, -17), Vector2(4, -23), Vector2(-10, -23)]), Color("f0d185"))
