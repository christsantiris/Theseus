extends SceneTree

# Run: godot --headless --path . --script res://tests/hades.gd --fixed-fps 60
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _await_scene(previous: Node) -> Node:
	for _frame in 90:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene != previous:
			return current_scene
	return current_scene


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null


func _run() -> void:
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	var state: Node = root.get_node("LevelRun")
	state.begin_level(1)
	var level: Node = load("res://scenes/levels/level_1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await _frames(2)
	level.player._die()
	var hades := await _await_scene(level)
	_expect(hades.name == "Hades", "Death opens Hades instead of reloading the level")
	var shade := hades.get_node("UI/Theseus") as AnimatedSprite2D
	var frame: AtlasTexture = shade.sprite_frames.get_frame_texture("idle", 0)
	_expect(shade.modulate.a == 1.0 and shade.material is ShaderMaterial and (shade.material as ShaderMaterial).shader == preload("res://resources/shaders/shade.gdshader"), "Theseus stands in Hades as an opaque shade")
	_expect(shade.animation == "idle" and frame.atlas.resource_path == "res://assets/art/characters/theseus.png", "The shade uses the existing Theseus artwork")
	_expect(hades.get_node("UI/Menu/Content/NewGame").text == "New Game" and hades.get_node("UI/Menu/Content/LoadGame").text == "Retry Level", "Hades offers New Game and Retry Level")
	hades.load_game()
	level = await _await_scene(hades)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _frames(2)
	_expect(level.level_number == 1 and level.player.health == 5 and absf(level.player.position.x - 48.0) < 1.0, "Load Game restores the level entrance at full health")
	_expect(level._score == 0 and level.has_node("Raider"), "Load Game resets the level encounters and score")
	level.player._die()
	hades = await _await_scene(level)
	_expect(hades.name == "Hades", "A second death returns to Hades")
	hades.new_game()
	level = await _await_scene(hades)
	await _frames(2)
	_expect(level.level_number == 1 and not state.can_load() and level.player.position.distance_to(Vector2(48, 152)) < 1.0, "New Game starts the road over")
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: death opens Hades, the shade is opaque, Load Game restarts the level, and New Game starts over.")
	else:
		print("FAILURES: ", failures)
	restore_scores.call()
	quit(0 if failures.is_empty() else 1)
