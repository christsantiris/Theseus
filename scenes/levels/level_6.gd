extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_6_layout.gd")
	level_number = 6
	next_level = ""
	objective = "Cross Atlantis. Duck high tridents; jump low blades."
	completion_text = "Poseidon's sanctuary is free of the Merfolk captain."
	$Player/Camera2D.position.y = -24
	super()
