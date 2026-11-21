extends SceneTree

const Art := preload("res://scenes/player/theseus_art.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.get_node("Camera2D").enabled = false
	var frames: SpriteFrames = player.sprite.sprite_frames
	var expected := {"idle": 4, "walk": 8, "duck": 2, "jump_rise": 2, "jump_fall": 2, "hurt": 2, "attack": 6, "swing": 6, "death": 4, "down_thrust": 6}
	for animation: String in expected:
		_expect(frames.has_animation(animation), animation + " has cinematic artwork")
		_expect(frames.get_frame_count(animation) == expected[animation], animation + " has its full animation sequence")
		Art.anchor(player.sprite, animation)
		for index in frames.get_frame_count(animation):
			var texture: Texture2D = frames.get_frame_texture(animation, index)
			var image := texture.get_image()
			var used := image.get_used_rect()
			_expect(used.has_area(), "%s frame %d is visible" % [animation, index])
			_expect(used.position.x > 1 and used.end.x < image.get_width() - 1 and used.position.y > 1 and used.end.y < image.get_height() - 1, "%s frame %d has no clipped silhouette or opaque background" % [animation, index])
			if animation in ["idle", "walk", "duck", "attack", "swing"]:
				var top: float = (-texture.get_height() * 0.5 + player.sprite.offset.y + used.position.y) * player.sprite.scale.y
				var foot: float = (-texture.get_height() * 0.5 + player.sprite.offset.y + used.end.y) * player.sprite.scale.y
				_expect(absf(foot) < 0.5, "%s frame %d keeps its soles on the collision floor" % [animation, index])
				_expect(absf(top + (36.0 if animation == "duck" else 44.0)) < 1.5, "%s frame %d matches the collision head height" % [animation, index])
	for animation in ["attack", "swing", "down_thrust"]:
		var duration := 0.0
		for index in frames.get_frame_count(animation):
			duration += frames.get_frame_duration(animation, index) / frames.get_animation_speed(animation)
		_expect(is_equal_approx(duration, 0.25), animation + " retains the original quarter-second attack")
		var windup := float(player.ATTACK_HIT_FRAMES[0]) / frames.get_animation_speed(animation)
		var hit_window := float(player.ATTACK_HIT_FRAMES.size()) / frames.get_animation_speed(animation)
		_expect(is_equal_approx(windup, 1.0 / 12.0) and is_equal_approx(hit_window, 1.0 / 12.0), animation + " retains its windup and damage window")
	for index in [2, 3]:
		var used := frames.get_frame_texture("down_thrust", index).get_image().get_used_rect()
		_expect(used.end.y > Art.FOOT_ROW + 48, "Active downward blade visibly extends below the sandals")
	player._speed_boost_left = 6.0
	player._play("walk")
	_expect(is_equal_approx(player.sprite.speed_scale, 1.35), "Wine still increases walking cadence by 35 percent")
	player._play("idle")
	_expect(player.sprite.speed_scale == 1.0, "Wine does not speed up idle or combat animations")
	player.sprite.play("walk")
	await process_frame
	paused = true
	var frame: int = player.sprite.frame
	var progress: float = player.sprite.frame_progress
	for tick in 5:
		await process_frame
	_expect(player.sprite.frame == frame and player.sprite.frame_progress == progress, "Pause freezes cinematic animation progress")
	paused = false
	_stop_audio(root)
	player.free()
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: 42 cinematic frames, transparent unclipped silhouettes, standing/crouch heights, foot registration, stab/swing/downward attack timing, visible downward blades, wine cadence and pause.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
