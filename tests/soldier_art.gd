extends SceneTree

# Run: godot --headless --path . --script res://tests/soldier_art.gd
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.2:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE)


func _run() -> void:
	var actors := {}
	for kind in ["raider", "peltast", "hoplite", "spartoi", "telchine"]:
		var actor = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
		root.add_child(actor)
		actor.set_physics_process(false)
		actors[kind] = actor
		var cinematic: bool = kind in ["raider", "peltast", "hoplite", "spartoi", "telchine"]
		var art_scale := 8.0 if cinematic else 1.0
		_expect(actor.sprite.scale == Vector2.ONE / art_scale, kind + ": world size is independent of texture resolution")
		_expect(is_equal_approx(actor.sprite.offset.y * actor.sprite.scale.y, -25.0), kind + ": feet and health bar retain their logical anchor")
		var frames: SpriteFrames = actor.sprite.sprite_frames
		var locomotion := "march" if kind == "hoplite" else "walk"
		_expect(frames.get_frame_count(locomotion) == 4, kind + ": all four locomotion poses are bound")
		_expect(frames.get_animation_speed(locomotion) == (6.0 if kind == "hoplite" else 8.0), kind + ": existing cadence is preserved")
		var seen := {}
		for animation in frames.get_animation_names():
			for index in frames.get_frame_count(animation):
				var atlas := frames.get_frame_texture(animation, index) as AtlasTexture
				_expect(atlas != null and atlas.region.size == Vector2(72, 56) * art_scale, kind + ": every pose uses the correct atlas region")
				_expect(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), kind + ": atlas region contains a complete pose")
				if not cinematic or seen.has(atlas.region.position):
					continue
				seen[atlas.region.position] = true
				var image := atlas.get_image()
				var bounds := _bounds(image)
				_expect(bounds.size.x > 80 and bounds.size.y > 150, kind + ": each pose contains a detailed figure")
				_expect(bounds.position.x > 1 and bounds.end.x < image.get_width() - 1 and bounds.position.y > 1, kind + ": figures and weapons are not clipped")
				_expect(absf(bounds.end.y - 424.0) <= 3.0, kind + ": every pose keeps its soles on the ground")
				_expect(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(575, 447).a == 0.0, kind + ": transparent surroundings")
		if cinematic:
			_expect(seen.size() == (9 if kind == "hoplite" else 7), kind + ": every generated pose is used")

	var raider = actors.raider
	_expect(raider.get_node("CollisionShape2D").shape.size == Vector2(16, 36), "Raider standing collision is unchanged")
	raider._enter("lunge")
	_expect(raider.get_node("CollisionShape2D").shape.size == Vector2(32, 24), "Raider low lunge collision is unchanged")
	raider._enter("recover")
	_expect(raider.get_node("CollisionShape2D").shape.size == Vector2(16, 36), "Raider recovers its standing collision")
	_expect(raider.get_node("SwordStrike/CollisionShape2D").shape.size == Vector2(26, 12), "Raider sword reach is unchanged")
	var peltast = actors.peltast
	_expect(peltast.get_node("CollisionShape2D").shape.size == Vector2(16, 36), "Peltast body is unchanged")
	_expect(peltast.get_node("JavelinStrike/CollisionShape2D").shape.size == Vector2(24, 8), "Peltast held-javelin reach is unchanged")
	var hoplite = actors.hoplite
	var previous_height := 0
	for pose in 3:
		hoplite._show_rise(pose)
		_expect(hoplite.get_node("CollisionShape2D").shape.size == Vector2(16, 24 + 6 * pose), "Hoplite crouch-to-standing collision is unchanged")
		var texture: Texture2D = hoplite.sprite.sprite_frames.get_frame_texture("rise", pose)
		var height := _bounds(texture.get_image()).size.y
		_expect(height > previous_height, "Hoplite rise artwork visibly rises through all three poses")
		previous_height = height
	_expect(hoplite.get_node("Strike").get_child(0).shape.size == Vector2(26, 8), "Hoplite spear reach is unchanged")
	for actor in actors.values():
		actor.free()
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Cinematic soldier atlas coverage, transparency, complete poses, foot registration, cadence, body/weapon collisions, Hoplite rise, and cinematic Spartoi/Telchine coverage.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
