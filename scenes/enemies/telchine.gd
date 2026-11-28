extends "res://scenes/enemies/peltast.gd"

const DAEMON_ART := preload("res://assets/art/characters/telchine.png")
const THRUST_WINDUP := 0.35
const THRUST_COOLDOWN := 0.75


func _ready() -> void:
	super()
	_cooldown = 0.05
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 8)
	javelin_strike.get_node("CollisionShape2D").shape = shape


func _uses_throw() -> bool:
	return false


func _engage_range() -> float:
	return JAB_RANGE


func _engage_height() -> float:
	return 12.0


func _windup_seconds() -> float:
	return THRUST_WINDUP


func _attack_cooldown() -> float:
	return THRUST_COOLDOWN


func _notice_range() -> float:
	return 96.0


func _notice_height() -> float:
	return 48.0


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, DAEMON_ART, "walk", [0, 1, 2, 3], 8.0, true, ART_SCALE)
	_add_animation(frames, DAEMON_ART, "windup", [4], 1.0, true, ART_SCALE)
	_add_animation(frames, DAEMON_ART, "jab", [5], 1.0, true, ART_SCALE)
	_add_animation(frames, DAEMON_ART, "recover", [6], 1.0, true, ART_SCALE)
	_bind_frames(frames, ART_SCALE)
