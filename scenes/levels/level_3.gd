extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_3_layout.gd")
	level_number = 3
	next_level = ""
	objective = "Cross the town. Wait for Lamia's coils to open."
	completion_text = "The city's sacred road is clear."
	super()
