extends "res://scenes/levels/level_1.gd"


const QuaySlab := preload("res://scenes/objects/quay_slab.gd")
const SPIKE_PIT := preload("res://scenes/objects/spike_pit.tscn")


func _ready() -> void:
	layout = preload("res://scenes/levels/level_2_layout.gd")
	level_number = 2
	next_level = "res://scenes/levels/level_3.tscn"
	objective = "Follow the rocky coast. Duck high birds; jump low birds."
	completion_text = "The coastal sanctuary is clear."
	super()


func _build_timing_obstacle() -> void:
	for crossing: Dictionary in layout.QUAY_CROSSINGS:
		var pit = SPIKE_PIT.instantiate()
		pit.name = "%sQuayPit" % crossing.name
		pit.position = crossing.position
		pit.z_index = -1
		pit.pit_width = layout.QUAY_PIT_WIDTH
		pit.pit_depth = layout.QUAY_PIT_DEPTH
		pit.damaged.connect(_on_quay_spike_damage)
		add_child(pit)
		for index in layout.QUAY_SLAB_COUNT:
			var slab := QuaySlab.new()
			slab.name = "%sQuaySlab%d" % [crossing.name, index + 1]
			slab.position = crossing.position + Vector2(index * layout.QUAY_SLAB_WIDTH, 0)
			slab.width = layout.QUAY_SLAB_WIDTH
			slab.player = player
			add_child(slab)


func _on_quay_spike_damage(_body: CharacterBody2D) -> void:
	hud.show_message("Spikes! Move toward a bank and jump out.", 2.5, 3)
