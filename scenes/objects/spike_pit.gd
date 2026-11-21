@tool
extends Node2D

signal damaged(player: CharacterBody2D)

@export var pit_width := 32.0
@export var pit_depth := 24.0
const HIT_INTERVAL := 1.25
var _cooldowns: Dictionary = {}


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(pit_width - 4, 8)
	$Spikes/CollisionShape2D.shape = shape
	$Spikes.position = Vector2(pit_width * 0.5, pit_depth - 4)
	if not Engine.is_editor_hint():
		add_to_group("spike_pits")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0:
			_cooldowns.erase(id)
	for body in $Spikes.get_overlapping_bodies():
		if not body.is_in_group("player") or body.health <= 0 or not body.is_on_floor():
			continue
		# Area overlaps are cached until the next physics step. Check the actual
		# body position too, so leaving or loading past a pit cannot cause a hit.
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var body_rect: Rect2 = collision.global_transform * collision.shape.get_rect()
		var spikes: Rect2 = global_transform * Rect2(2, pit_depth - 8, pit_width - 4, 9)
		if not body_rect.intersects(spikes):
			continue
		var id: int = body.get_instance_id()
		if _cooldowns.has(id):
			continue
		var before: int = body.health
		body.hurt(1)
		if body.health < before:
			_cooldowns[id] = HIT_INTERVAL
			damaged.emit(body)


func _draw() -> void:
	draw_rect(Rect2(0, 0, pit_width, pit_depth), Color("454941"))
	draw_rect(Rect2(1, 2, pit_width - 2, pit_depth - 2), Color("59594a"))
	for x in range(0, int(pit_width), 8):
		draw_colored_polygon(PackedVector2Array([Vector2(x + 1, pit_depth), Vector2(x + 4, pit_depth - 8), Vector2(x + 7, pit_depth)]), Color("aaa98f"))
		draw_line(Vector2(x + 4, pit_depth - 7), Vector2(x + 6, pit_depth - 1), Color("e0d9ba"))
	draw_rect(Rect2(0, pit_depth - 1, pit_width, 2), Color("787763"))
