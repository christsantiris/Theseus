extends "res://scenes/enemies/raider.gd"

const SKELETON_ART := preload("res://assets/art/characters/spartoi.png")


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, SKELETON_ART, "walk", [0, 1, 2, 3], 8.0, true)
	_add_animation(frames, SKELETON_ART, "windup", [4], 1.0, true)
	_add_animation(frames, SKELETON_ART, "lunge", [5], 1.0, true)
	_add_animation(frames, SKELETON_ART, "recover", [6], 1.0, true)
	_bind_frames(frames)
