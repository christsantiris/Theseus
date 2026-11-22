extends "res://scenes/enemies/enemy.gd"

const BIRD_ART_SCALE := 8.0
const BIRD_ART := preload("res://assets/art/characters/stymphalian_bird.png")
const FLIGHT_SPEED := 48.0
var _contacted: Dictionary = {}


func _ready() -> void:
	points = 75
	max_hp = 1
	body_half_width = 11.0
	body_height = 8.0
	super()
	$CollisionShape2D.position = Vector2.ZERO
	$Contact/CollisionShape2D.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO


func _uses_gravity() -> bool:
	return false


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, BIRD_ART, "walk", [0, 1, 2, 3], 8.0, true, BIRD_ART_SCALE)
	_bind_frames(frames, BIRD_ART_SCALE)


func _tick(_delta: float) -> void:
	if not _player_close(256.0, 128.0):
		velocity = Vector2.ZERO
		return
	if global_position.x <= patrol_left:
		direction = 1
	elif global_position.x >= patrol_right:
		direction = -1
	velocity = Vector2(direction * FLIGHT_SPEED, 0)


func _hurt_overlaps() -> void:
	var touching: Dictionary = {}
	for body in contact.get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("hurt"):
			continue
		var id := body.get_instance_id()
		touching[id] = true
		if not _contacted.has(id):
			_contacted[id] = true
			body.hurt(1)
	for id in _contacted.keys():
		if not touching.has(id):
			_contacted.erase(id)
