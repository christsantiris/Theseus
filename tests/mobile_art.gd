extends SceneTree

# GPU-safe dimensions and complete animation cells are required on both desktop
# and mobile. Run with --headless for asset checks or with a renderer to include
# texture readback on that graphics driver.
const MAX_TEXTURE_SIZE := 4096
const KINDS := ["raider", "peltast", "hoplite", "stymphalian_bird", "telchine", "spartoi", "lamia", "cyclops_slinger", "satyr", "bronze_bull", "cerberus_pup", "hydra", "merfolk_trident", "merfolk_reefblade"]
var failures: Array[String] = []
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _check_texture(texture: Texture2D, context: String) -> void:
	if texture == null:
		return
	var source: Texture2D = texture.atlas if texture is AtlasTexture else texture
	_expect(source.get_width() <= MAX_TEXTURE_SIZE and source.get_height() <= MAX_TEXTURE_SIZE, context + ": texture fits mobile GPU limits")
	if texture is AtlasTexture:
		_expect(Rect2(Vector2.ZERO, source.get_size()).encloses(texture.region), context + ": complete frame lies inside its atlas")
	var image := texture.get_image()
	_expect(image != null and not image.is_empty() and image.get_used_rect().has_area(), context + ": artwork has visible pixels")
	checked += 1


func _check_node(node: Node) -> void:
	if node is AnimatedSprite2D:
		var frames: SpriteFrames = node.sprite_frames
		for animation in frames.get_animation_names():
			for index in frames.get_frame_count(animation):
				_check_texture(frames.get_frame_texture(animation, index), str(node.get_path()) + "/" + animation + "/" + str(index))
	elif node is Sprite2D:
		_check_texture(node.texture, str(node.get_path()))
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_check_node(child)


func _run() -> void:
	for scene in ["res://scenes/player/player.tscn"] + KINDS.map(func(kind: String) -> String: return "res://scenes/enemies/" + kind + ".tscn"):
		var actor: Node = load(scene).instantiate()
		root.add_child(actor)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		_check_node(actor)
		actor.free()
	_check_node(root)
	OS.delay_msec(150)
	print("PASS: %d character frames fit mobile GPU limits and contain complete visible artwork." % checked if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
