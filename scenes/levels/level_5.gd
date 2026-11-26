extends "res://scenes/levels/level_1.gd"

const SPIKE_PIT := preload("res://scenes/objects/spike_pit.tscn")


func _ready() -> void:
	layout = preload("res://scenes/levels/level_5_layout.gd")
	level_number = 5
	next_level = "res://scenes/levels/level_6.tscn"
	objective = "Climb the mountain. Jump pits; jump out if you fall."
	completion_text = "The mountain sanctuary is clear."
	$Player/Camera2D.position.y = -24
	super()
	for definition: Dictionary in layout.PITS:
		var pit = SPIKE_PIT.instantiate()
		pit.name = definition.name
		pit.position = definition.position
		pit.pit_width = definition.width
		pit.pit_depth = definition.depth
		pit.damaged.connect(_on_spike_damage)
		add_child(pit)


func _on_spike_damage(_body: CharacterBody2D) -> void:
	hud.show_message("Spikes! Hold jump and move to climb out.", 2.5, 3)
