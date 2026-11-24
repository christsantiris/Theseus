extends "res://scenes/levels/level_1.gd"

const Pack := preload("res://scenes/enemies/cerberus_pack.gd")
const SPIKE_PIT := preload("res://scenes/objects/spike_pit.tscn")


func _ready() -> void:
	layout = preload("res://scenes/levels/level_5_layout.gd")
	level_number = 5
	next_level = "res://scenes/levels/level_6.tscn"
	objective = "Cross the gorge. Cut every Hydra head to open the temple."
	completion_text = "The gorge sanctuary is free of the Hydra."
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


func _build_enemies() -> void:
	var packs := {}
	for encounter: Dictionary in layout.ENEMIES:
		if encounter.name in _defeated:
			continue
		var enemy := _create_enemy(encounter)
		if not encounter.has("pack"):
			add_child(enemy)
			continue
		var pack_id: String = encounter.pack
		if not packs.has(pack_id):
			var pack := Pack.new()
			pack.name = pack_id
			pack.direction = -1
			pack.position = Vector2((encounter.patrol.x + encounter.patrol.y) * 0.5, encounter.position.y)
			pack.patrol_half_width = (encounter.patrol.y - encounter.patrol.x) * 0.5
			packs[pack_id] = pack
		var pack: Node2D = packs[pack_id]
		enemy.position -= pack.position
		enemy.attack_delay = encounter.delay
		pack.add_child(enemy)
	# Bind each pup's defeat separately before the pack enters the tree. Loading
	# a shrine can then restore just one survivor, with its attack turns intact.
	for pack: Node2D in packs.values():
		add_child(pack)


func _on_spike_damage(_body: CharacterBody2D) -> void:
	hud.show_message("Spikes! Hold jump and move to climb out.", 2.5, 3)
