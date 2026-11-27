extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_9_layout.gd")
	level_number = 9
	next_level = ""
	objective = "Follow the torchlight. Defeat the Minotaur to escape."
	completion_text = "The Minotaur has fallen. Theseus escapes the labyrinth!"
	$Player/Camera2D.position.y = -24
	super()


func _build_timing_obstacle() -> void:
	super()
	for definition: Dictionary in layout.SPIKE_BALLS:
		_add_timing_obstacle(definition)


func _on_gate_entered() -> void:
	super()
	pause_heading.text = "Theseus Victorious"
