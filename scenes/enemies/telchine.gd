extends "res://scenes/enemies/peltast.gd"

const DAEMON_ART := preload("res://assets/art/characters/telchine.png")


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, DAEMON_ART, "walk", [0, 1, 2, 3], 8.0, true, ART_SCALE)
	_add_animation(frames, DAEMON_ART, "windup", [4], 1.0, true, ART_SCALE)
	_add_animation(frames, DAEMON_ART, "jab", [5], 1.0, true, ART_SCALE)
	_add_animation(frames, DAEMON_ART, "recover", [6], 1.0, true, ART_SCALE)
	_bind_frames(frames, ART_SCALE)
