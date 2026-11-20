@tool
extends Node2D

signal entered
signal entry_started(player: Node2D)

var unlocked := false
var entering := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		$Finish.body_entered.connect(_on_body_entered)


func unlock() -> void:
	unlocked = true
	$Barrier/CollisionShape2D.set_deferred("disabled", true)
	queue_redraw()
	call_deferred("_try_enter_overlaps")


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint() and unlocked and not entering:
		_try_enter_overlaps()


func _try_enter_overlaps() -> void:
	for body in $Finish.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if not unlocked or entering or not body.is_in_group("player") or body.health <= 0:
		return
	if not $Finish.overlaps_body(body) or not body.is_on_floor():
		return
	entering = true
	entry_started.emit(body)
	var sprite := body.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.flip_h = false
	sprite.modulate = Color.WHITE
	sprite.play("walk")
	# Keep the hero in front while he walks up the visible stair treads.
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var steps := [Vector2(-46, -6), Vector2(-30, -11), Vector2(-16, -16), Vector2(0, -16)]
	for step: Vector2 in steps:
		var destination := to_global(step)
		if destination.x > body.global_position.x:
			tween.tween_property(body, "global_position", destination, 0.18)
	# A small inward step and a darkening, shrinking silhouette suggest doorway depth.
	tween.tween_property(body, "global_position", to_global(Vector2(2, -20)), 0.3)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.72, 0.72), 0.3)
	tween.parallel().tween_property(sprite, "modulate", Color(0.35, 0.4, 0.45, 0.0), 0.3)
	tween.tween_callback(func() -> void: entered.emit())


func _draw() -> void:
	var marble := Color("e2d4ad")
	var highlight := Color("f4e7c7")
	var shadow := Color("b7a47d")
	var step := Color("cbb98a")
	# Three centered steps. The widest is the bottom course.
	draw_rect(Rect2(-48, -6, 96, 6), step)
	draw_rect(Rect2(-48, -6, 96, 2), highlight)
	draw_rect(Rect2(-40, -11, 80, 5), marble)
	draw_rect(Rect2(-34, -16, 68, 5), Color("d8c89a"))
	# Door void, centered between the inner pair of columns.
	draw_rect(Rect2(-10, -74, 20, 58), Color("343e40"))
	for x in [-36, -14, 14, 36]:
		_pillar(x, marble, highlight, shadow)
	draw_rect(Rect2(-46, -90, 92, 8), marble)
	draw_rect(Rect2(-46, -90, 92, 2), highlight)
	draw_colored_polygon(PackedVector2Array([Vector2(-46, -90), Vector2(0, -114), Vector2(46, -90)]), marble)
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -90), Vector2(0, -106), Vector2(34, -90)]), Color("8d4d3c"))
	draw_rect(Rect2(-4, -118, 8, 6), Color("e2b34a"))
	if not unlocked:
		for x in range(-8, 9, 4):
			draw_rect(Rect2(x, -72, 2, 56), Color("ad8442"))
		draw_rect(Rect2(-10, -52, 20, 3), Color("c99a4d"))
		draw_rect(Rect2(-10, -32, 20, 3), Color("c99a4d"))
	else:
		draw_rect(Rect2(-12, -72, 3, 56), Color("ad8442"))
		draw_rect(Rect2(9, -72, 3, 56), Color("ad8442"))


func _pillar(x: int, marble: Color, highlight: Color, shadow: Color) -> void:
	draw_rect(Rect2(x - 7, -20, 14, 4), shadow)
	draw_rect(Rect2(x - 5, -76, 10, 56), marble)
	draw_rect(Rect2(x - 5, -76, 3, 56), highlight)
	draw_line(Vector2(x + 3, -74), Vector2(x + 3, -20), shadow, 1)
	draw_rect(Rect2(x - 7, -82, 14, 6), highlight)
