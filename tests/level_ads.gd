extends SceneTree

# Run: godot --headless --path . --script res://tests/level_ads.gd --fixed-fps 60
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


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
	var ads: Node = root.get_node("LevelAds")
	_expect(ads.has_method("prepare") and ads.has_method("show_then"), "Level ads autoload is present")
	_expect(not ads.requests_ads(), "Desktop and web do not request an interstitial")
	var continued := [false]
	ads.show_then(func() -> void:
		continued[0] = true
	)
	_expect(continued[0], "Continue proceeds immediately when no interstitial is ready")

	var state: Node = root.get_node("LevelRun")
	state.begin_level(1)
	var packed: PackedScene = load("res://scenes/levels/level_1.tscn")
	var level: Node = packed.instantiate()
	root.add_child(level)
	current_scene = level
	level._complete = true
	level._on_next_pressed()
	var next := await _await_scene(level)
	_expect(is_instance_valid(next) and next.get("level_number") == 2, "Continue still opens the next level")
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: between-level continue skips the ad off mobile and still opens the next level.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
