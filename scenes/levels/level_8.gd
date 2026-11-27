extends "res://scenes/levels/level_1.gd"


const Tide := preload("res://scenes/objects/atlantis_tide.gd")
var tide: Node2D


func _ready() -> void:
	layout = preload("res://scenes/levels/level_8_layout.gd")
	level_number = 8
	next_level = "res://scenes/levels/level_9.tscn"
	objective = "Tides slow you, not Merfolk. Watch the waterline."
	completion_text = "Poseidon's sanctuary is free of the Merfolk captain."
	$Player/Camera2D.position.y = -24
	super()
	tide = Tide.new()
	tide.name = "AtlantisTide"
	tide.player = player
	add_child(tide)


func _build_timing_obstacle() -> void:
	for definition: Dictionary in layout.JET_BANKS:
		_add_timing_obstacle(definition)
