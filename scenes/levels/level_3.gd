extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_3_layout.gd")
	level_number = 3
	next_level = "res://scenes/levels/level_4.tscn"
	objective = "Cross the town. Wait for Lamia's coils to open."
	completion_text = "The city's sacred road is clear."
	super()


func _build_timing_obstacle() -> void:
	for definition: Dictionary in layout.KILNS:
		_add_timing_obstacle(definition)
