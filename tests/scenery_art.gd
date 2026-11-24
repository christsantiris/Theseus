extends SceneTree

# Requires a rendering backend:
# godot --path . --script res://tests/scenery_art.gd
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)


func _verify_level(number: int) -> void:
	root.get_node("LevelRun").begin_level(number)
	var layout = load("res://scenes/levels/level_%d_layout.gd" % number)
	var level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var world: Node = level.get_node("World")
	var parent: Node = world.backdrop
	var continuous := parent.get_node("ContinuousLandscape") as Sprite2D
	_expect(parent.get_child_count() == 1 and continuous.material == null and continuous.texture == world.PANORAMA_SHEETS[0], "Level %d uses one unblended painting" % number)
	_expect(continuous.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED, "Level %d never wraps its landscape" % number)
	_expect(world.midground.get_child_count() == [13, 14, 12, 13, 11][number - 1], "Level %d has complete independent scenery objects" % number)
	for definition in layout.CHECKPOINTS:
		var shrine := level.get_node(String(definition.name)) as Area2D
		var collision := shrine.get_node("CollisionShape2D") as CollisionShape2D
		_expect(collision.shape.size == Vector2(48, 56) and collision.position == Vector2(0, -24), "Cinematic shrine keeps its original activation area")
		_expect(shrine.position == definition.position and shrine.spawn_position == definition.spawn, "Shrine and saved spawn stay in their authored positions")
		_expect(shrine.ART.get_size() == Vector2(1024, 768), "Both detailed shrine states are available")
		shrine.set_lit(false)
		var activations := {"count": 0}
		shrine.activated.connect(func(_checkpoint: Area2D) -> void: activations.count += 1)
		shrine._on_body_entered(level.player)
		shrine._on_body_entered(level.player)
		_expect(shrine.lit and activations.count == 1, "Entering a shrine lights it and saves once")
		_expect(root.get_node("LevelRun").checkpoint_index == shrine.checkpoint_index, "The lit shrine still saves the active checkpoint")
	current_scene = null
	level.free()


func _run() -> void:
	for number in range(1, 6):
		_verify_level(number)
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: all five continuous landscapes, complete scenery objects, both shrine states, all ten shrine triggers and checkpoint saves.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
