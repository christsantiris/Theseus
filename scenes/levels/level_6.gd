extends "res://scenes/levels/level_1.gd"


const Tide := preload("res://scenes/objects/atlantis_tide.gd")
var tide: Node2D


func _ready() -> void:
	layout = preload("res://scenes/levels/level_6_layout.gd")
	level_number = 6
	next_level = ""
	objective = "Tides slow you, not Merfolk. Watch the waterline."
	completion_text = "Poseidon's sanctuary is free of the Merfolk captain."
	$Player/Camera2D.position.y = -24
	super()
	tide = Tide.new()
	tide.name = "AtlantisTide"
	tide.player = player
	tide.hud = hud
	add_child(tide)
