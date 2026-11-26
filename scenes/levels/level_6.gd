extends "res://scenes/levels/level_1.gd"

const Pack := preload("res://scenes/enemies/cerberus_pack.gd")
const SPIKE_PIT := preload("res://scenes/objects/spike_pit.tscn")


func _ready() -> void:
	layout = preload("res://scenes/levels/level_6_layout.gd")
	level_number = 6
	next_level = "res://scenes/levels/level_7.tscn"
	objective = "Wait for the bridges. Cut every Hydra head to open the temple."
	completion_text = "The gorge sanctuary is free of the Hydra."
	$Player/Camera2D.position.y = -24
	super()
	for definition: Dictionary in layout.PITS:
		var pit = SPIKE_PIT.instantiate()
		pit.name = definition.name
		pit.position = definition.position
		pit.pit_width = definition.width
		pit.pit_depth = definition.depth
		pit.damaged.connect(_on_spike_damage.bind(get_node(definition.bridge)))
		add_child(pit)


func _build_timing_obstacle() -> void:
	for pit: Dictionary in layout.PITS:
		_add_timing_obstacle({
			"name": pit.bridge, "kind": TimingObstacle.Kind.BRIDGE,
			"position": pit.position, "width": pit.width, "durations": layout.BRIDGE_TIMING,
		})


func _build_enemies() -> void:
	var packs := {}
	for encounter: Dictionary in layout.ENEMIES:
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
	# Each pup awards its own score within the coordinated pack.
	for pack: Node2D in packs.values():
		add_child(pack)


func _on_spike_damage(body: CharacterBody2D, bridge: Node2D) -> void:
	if body.health > 0:
		bridge.return_to_bridge_bank()
		hud.show_message("Wait for the bridge to extend before crossing.", 2.5, 3)
