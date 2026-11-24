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
	_expect(world.midground.get_child_count() == [13, 14, 12, 13, 11, 13, 6][number - 1], "Level %d has complete independent scenery objects" % number)
	_expect(level.find_children("*Shrine", "Area2D", true, false).is_empty(), "Level %d has no checkpoint triggers" % number)
	current_scene = null
	level.free()


func _run() -> void:
	for number in range(1, 8):
		_verify_level(number)
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: all seven continuous landscapes, complete scenery objects, removed checkpoint triggers.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
