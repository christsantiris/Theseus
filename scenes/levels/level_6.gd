extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_6_layout.gd")
	level_number = 6
	next_level = "res://scenes/levels/level_7.tscn"
	objective = "Cross the desert. Defeat the guard at the sun temple."
	completion_text = "The sun temple is open. Atlantis lies beyond the sands."
	$Player/Camera2D.position.y = -24
	super()
