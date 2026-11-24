extends SceneTree

var failures: Array[String] = []
var store: Node
var state: Node
var restore_scores: Callable


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count := 4) -> void:
	for tick in count:
		if is_instance_valid(current_scene) and current_scene.has_method("_set_paused") and not current_scene._complete:
			current_scene._set_paused(false)
		await physics_frame
		await process_frame


func _open(path: String) -> Node:
	paused = false
	change_scene_to_file(path)
	await scene_changed
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0
	await _frames()
	return current_scene


func _scores() -> Array:
	return store.entries.map(func(entry: Dictionary): return entry.score)


func _storage() -> void:
	for score in [300, 100, 500, 200, 400, 50, 600]:
		store.submit(score)
	_expect(_scores() == [600, 500, 400, 300, 200], "Only the five highest scores are kept in descending order")
	var tie: Dictionary = store.submit(200)
	_expect(not store.entries.any(func(entry: Dictionary): return entry.id == tie.id), "A tie with fifth place keeps the earlier score")
	var tied_high: Dictionary = store.submit(500)
	_expect(_scores() == [600, 500, 500, 400, 300] and store.entries[2].id == tied_high.id, "Equal qualifying scores have distinct IDs and preserve earlier rank")
	var saved: Array = store.entries.duplicate(true)
	var fresh := load("res://scenes/ui/high_scores.gd").new() as Node
	fresh.storage_path = store.storage_path
	root.add_child(fresh)
	_expect(fresh.entries == saved, "A fresh service restores the top five and their IDs from disk")
	fresh.free()
	var config := ConfigFile.new()
	config.set_value("scores", "entries", ["invalid", {"id": "bad", "score": -1}, {"id": "badtype", "score": "900"}, {"id": "valid", "score": 700}, {"id": "valid", "score": 800}])
	config.save(store.storage_path)
	store.load_scores()
	_expect(_scores() == [700], "Malformed and duplicate records are ignored safely")
	var file := FileAccess.open(store.storage_path, FileAccess.WRITE)
	file.store_string("[broken\n")
	file.close()
	var print_errors := Engine.print_error_messages
	Engine.print_error_messages = false # This malformed file is intentional.
	store.load_scores()
	Engine.print_error_messages = print_errors
	_expect(store.entries.is_empty(), "A damaged file does not stop the game from starting")
	store.submit(10)
	store.load_scores()
	_expect(_scores() == [10], "A valid result replaces a damaged file")
	store.entries.clear()


func _run() -> void:
	store = root.get_node("HighScores")
	state = root.get_node("LevelRun")
	restore_scores = preload("res://tests/high_score_data.gd").isolate(store)
	_storage()
	state.begin_run()
	var level := await _open("res://scenes/levels/level_1.tscn")
	level._on_enemy_defeated(100, "Raider")
	level._on_enemy_defeated(250, "SecondEnemy")
	_expect(state.current_score == 350 and state.level_start_score == 0, "The death score includes all points earned during the attempt")
	level.player._die()
	for tick in 90:
		await _frames(1)
		if is_instance_valid(current_scene) and current_scene.name == "Hades":
			break
	var hades := current_scene
	_expect(hades.name == "Hades" and _scores() == [350], "Being sent to Hades records the live score")
	_expect(hades.high_score_table.highlighted_rank == 1, "Hades highlights the current entry")
	var result_id: String = state.record_result().id
	hades = await _open("res://scenes/hades/hades.tscn")
	_expect(store.entries.size() == 1 and state.record_result().id == result_id, "Reopening Hades does not duplicate a result")
	_check_bounds(hades.get_node("UI/Menu"))
	hades.load_game()
	await scene_changed
	await _frames()
	level = current_scene
	_expect(state.current_score == 0 and state.level_start_score == 0 and level._score == 0, "Retry restores the level entrance score without changing the recorded result")
	state.current_score = 350
	hades = await _open("res://scenes/hades/hades.tscn")
	_expect(_scores() == [350, 350] and hades.high_score_table.highlighted_rank == 2, "A new life may tie a previous score and highlights only its own row")
	state.begin_level(1, 500)
	level = await _open("res://scenes/levels/level_1.tscn")
	var count: int = store.entries.size()
	level._on_gate_entered()
	_expect(store.entries.size() == count and level.high_score_table == null, "Intermediate level completions do not record high scores")
	var final_number := 1
	while ResourceLoader.exists("res://scenes/levels/level_%d.tscn" % (final_number + 1)):
		final_number += 1
	state.begin_level(final_number, 900)
	level = await _open("res://scenes/levels/level_%d.tscn" % final_number)
	level._on_enemy_defeated(1500, level.layout.GATE_GUARD)
	level._on_gate_entered()
	await _frames()
	_expect(store.entries[0].score == 2400 and level.high_score_table.highlighted_rank == 1, "Final victory records the cumulative campaign score and highlights it")
	count = store.entries.size()
	level._on_gate_entered()
	_expect(store.entries.size() == count, "Repeated final completion signals do not duplicate the victory")
	_check_bounds(level.pause_panel)
	_check_bounds(level.high_score_table)
	var rows: Array = level.high_score_table.rows
	_expect(rows.size() == 5 and rows[0].get_child(0).get_child(2).text == "YOU", "Five slots and the YOU marker make the current result clear")
	level._on_replay_pressed()
	await scene_changed
	await _frames()
	_expect(state.current_score == 900 and store.entries.size() == count, "Replay starts another attempt without clearing high scores")
	# A nonqualifying result still shows its score, with no false highlight.
	for score in [5000, 4000, 3000, 2000, 1000]:
		store.submit(score)
	state.begin_attempt(100)
	hades = await _open("res://scenes/hades/hades.tscn")
	_expect(hades.high_score_table.highlighted_rank == -1 and hades.high_score_table._current.text == "Your score 100", "A score outside the top five has no highlighted row")
	_check_bounds(hades.get_node("UI/Menu"))
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(900, 1800)]:
		root.size = dimensions
		await _frames()
		_check_bounds(hades.get_node("UI/Menu"))
	paused = false
	_stop_audio(root)
	restore_scores.call()
	OS.delay_msec(150)
	print("PASS: persistent top five, ties, file recovery, live death score, duplicate protection, retry/replay behavior, final victory, highlighting, and result-screen bounds." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _check_bounds(control: Control) -> void:
	_expect(root.get_visible_rect().encloses(control.get_global_rect()), "Result UI fits the logical viewport: " + String(control.name) + " " + str(control.get_global_rect()))
	for child in control.get_children():
		if child is Control and child.is_visible_in_tree():
			_check_bounds(child)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
