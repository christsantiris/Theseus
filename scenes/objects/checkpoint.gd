@tool
extends Area2D

signal activated(checkpoint: Area2D)

const ART := preload("res://assets/art/objects/checkpoint_shrine.png")
const ART_FRAME_SIZE := Vector2(512, 768)
const ART_SCALE := 16.0
const ART_FOOT_ROW := 736.0

@export var checkpoint_index := 0
@export var spawn_position := Vector2.ZERO
var lit := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	var source := Rect2(Vector2(ART_FRAME_SIZE.x if lit else 0.0, 0), ART_FRAME_SIZE)
	var target := Rect2(Vector2(-ART_FRAME_SIZE.x * 0.5, -ART_FOOT_ROW) / ART_SCALE, ART_FRAME_SIZE / ART_SCALE)
	draw_texture_rect_region(ART, target, source)
