extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_2_layout.gd")
	level_number = 2
	next_level = ""
	objective = "Follow the rocky coast. Duck high birds; jump low birds."
	completion_text = "The coastal sanctuary is clear."
	super()
