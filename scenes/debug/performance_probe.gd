extends Node

# Opt-in benchmark scene; excluded from normal mobile exports. Results describe
# this scripted entrance encounter, not every encounter or a cold disk cache.
var seconds := 20.0
var number := 1
var output := "user://performance.json"
var report: Dictionary = {}
var intervals: Array[float] = []
var samples: Array[Dictionary] = []
var level: Node
var started := 0
var previous := 0
var sample_at := 0.0
var measuring := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			seconds = maxf(5.0, argument.get_slice("=", 1).to_float())
		elif argument.begins_with("--level="):
			number = clampi(argument.get_slice("=", 1).to_int(), 1, 5)
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()


func _memory() -> Dictionary:
	return {
		"static_bytes": OS.get_static_memory_usage(),
		"static_peak_bytes": OS.get_static_memory_peak_usage(),
		"video_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"texture_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
	}


func _drawn() -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)


func _run() -> void:
	# Exclude letterbox margins. Window ViewportTexture dimensions can include
	# an extra stretch factor; this is the actual drawable 2D target instead.
	var ui_pixels := Vector2i((get_window().get_visible_rect().size * get_window().get_stretch_transform().get_scale()).round())
	report = {
		"os": OS.get_name(), "architecture": Engine.get_architecture_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"window_pixels": [get_window().size.x, get_window().size.y],
		"logical_size": [get_window().content_scale_size.x, get_window().content_scale_size.y],
		"scale_mode": get_window().content_scale_mode,
		"render_profile": MobileRendering.profile,
		"world_target_pixels": [MobileRendering.world_viewport.size.x, MobileRendering.world_viewport.size.y] if is_instance_valid(MobileRendering.world_viewport) else [ui_pixels.x, ui_pixels.y],
		"ui_target_pixels": [ui_pixels.x, ui_pixels.y],
		"level": number, "requested_seconds": seconds,
	}
	var title_start := Time.get_ticks_usec()
	var title := load("res://scenes/main/main.tscn").instantiate() as Node
	get_tree().root.add_child(title)
	await _drawn()
	report.title_first_draw_ms = (Time.get_ticks_usec() - title_start) / 1000.0
	report.process_to_title_ms = Time.get_ticks_msec()
	report.title_memory = _memory()
	title.free()
	await get_tree().process_frame
	var load_start := Time.get_ticks_usec()
	get_node("/root/LevelRun").begin_level(number)
	level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	report.level_ready_ms = (Time.get_ticks_usec() - load_start) / 1000.0
	await _drawn()
	report.level_first_draw_ms = (Time.get_ticks_usec() - load_start) / 1000.0
	report.level_memory = _memory()
	# Warm textures/shaders for two seconds; report this separately from loading.
	await get_tree().create_timer(2.0).timeout
	started = Time.get_ticks_usec()
	previous = started
	measuring = true
	print("BENCHMARK_STARTED ", JSON.stringify(report))


func _process(_delta: float) -> void:
	if not measuring:
		return
	var now := Time.get_ticks_usec()
	var elapsed := (now - started) / 1000000.0
	intervals.append((now - previous) / 1000.0)
	previous = now
	# Repeat the same short walk, jump and sword exercise on every target. Keep
	# the benchmark alive without changing game scripts or campaign progress.
	level.player.health = level.player.MAX_HEALTH
	level.player._hurt_lock = 10000.0
	var phase := fmod(elapsed, 8.0)
	Input.action_press("move_right" if phase < 4.0 else "move_left")
	Input.action_release("move_left" if phase < 4.0 else "move_right")
	if fmod(elapsed, 2.0) < 0.15:
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	if fmod(elapsed, 1.2) < 0.15:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	if elapsed >= sample_at:
		samples.append({"seconds": elapsed, "memory": _memory(),
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0})
		sample_at += 1.0
	if elapsed >= seconds:
		_finish(elapsed)


func _finish(elapsed: float) -> void:
	measuring = false
	for action in ["move_left", "move_right", "jump", "attack"]:
		Input.action_release(action)
	intervals.sort()
	var over_50 := 0
	for interval in intervals:
		if interval > 50.0:
			over_50 += 1
	report.merge({
		"measured_seconds": elapsed, "frames": intervals.size(),
		"average_fps": intervals.size() / elapsed,
		"frame_ms_p50": intervals[int((intervals.size() - 1) * 0.5)],
		"frame_ms_p95": intervals[int((intervals.size() - 1) * 0.95)],
		"frame_ms_p99": intervals[int((intervals.size() - 1) * 0.99)],
		"frame_ms_max": intervals.back(), "frames_over_50ms": over_50,
		"samples": samples, "final_memory": _memory(),
	})
	# Inspect the loaded resource after timing; do not include CPU inspection in
	# the measured exercise. Web/mobile return decoded RGBA readbacks even
	# when GPU storage is compressed; this field describes the returned Image.
	var geometry = level.get_node("World")
	var panorama: Texture2D = geometry.PANORAMA_SHEETS[0]
	var pixels := panorama.get_image()
	report["panorama_readback"] = {"format": pixels.get_format(),
		"compressed": pixels.is_compressed(), "bytes": pixels.get_data_size(),
		"mipmaps": pixels.has_mipmaps()}
	var json := JSON.stringify(report, "\t")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file:
		file.store_string(json + "\n")
	else:
		push_error("Cannot write benchmark output: " + output)
	print("BENCHMARK_RESULT ", JSON.stringify(report))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.theseusBenchmark = " + JSON.stringify(report), true)
	else:
		get_tree().quit(0 if file else 1)
