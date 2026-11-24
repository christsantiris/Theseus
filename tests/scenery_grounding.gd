extends SceneTree

# Requires a renderer. This samples painted pixels immediately above the floor,
# rather than accepting a full image rectangle that includes transparent padding.
const GROUNDING := preload("res://scenes/levels/scenery_grounding.gd")
var failures: Array[String] = []
var feet := {}
const SAMPLES := [
	["level_1/olive_grove", 116.0], ["level_1/colonnade", 106.0],
	["level_1/aqueduct", 152.0], ["level_1/waystone", 21.0],
	["level_2/coastal_outcrop", 108.0], ["level_2/ruined_quay", 48.0],
	["level_2/cyclopean_gate", 88.0], ["level_3/amphora", 24.0],
	["level_3/workshop", 100.0], ["level_3/stoa", 68.0],
	["level_4/terrace_wall", 44.0], ["level_5/cliff_temple", 104.0],
	["level_4/broken_column", 41.0], ["level_4/broken_column", 44.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _foot(texture: Texture2D) -> float:
	if feet.has(texture.resource_path):
		return feet[texture.resource_path]
	var image := texture.get_image()
	_expect(not image.is_compressed(), "Scenery alpha stays lossless")
	for y in range(image.get_height() - 1, -1, -1):
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				var row := float(y + 1)
				feet[texture.resource_path] = row
				return row
	_expect(false, "Scenery contains visible painted pixels")
	return 0.0


func _contact_pixels(image: Image, scale: int) -> int:
	var count := 0
	for x in image.get_width():
		var color := image.get_pixel(x, 140 * scale - 1)
		if color.r + color.g > 0.45:
			count += 1
	return count


func _render_contact(texture: Texture2D, height: float, scale: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 180) * scale
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * scale)
	var background := ColorRect.new()
	background.size = Vector2(512, 180)
	background.color = Color.BLUE
	viewport.add_child(background)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	GROUNDING.place(sprite, 256, 140, height)
	viewport.add_child(sprite)
	var ground := ColorRect.new()
	ground.position.y = 140
	ground.size = Vector2(512, 40)
	ground.color = Color(0.3, 0.3, 0.3)
	viewport.add_child(ground)
	await process_frame
	RenderingServer.force_draw(false)
	var pixels := _contact_pixels(viewport.get_texture().get_image(), scale)
	_expect(pixels > 0, "%s contacts the floor at %dx resolution" % [texture.resource_path, scale])
	if texture.resource_path.ends_with("olive_grove.png"):
		# Reproduce the old bug as a negative control: image edge on the floor,
		# with the roots still above it. The same pixel test must reject it.
		sprite.position.y = 140 - height
		await process_frame
		RenderingServer.force_draw(false)
		_expect(_contact_pixels(viewport.get_texture().get_image(), scale) == 0, "Regression detects the original floating tree at %dx" % scale)
	viewport.free()


func _actual_landmarks(number: int) -> void:
	root.get_node("LevelRun").begin_level(number)
	var level = load("res://scenes/levels/level_%d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var camera: Camera2D = level.player.get_node("Camera2D")
	var world: Node2D = level.get_node("World")
	for point in [Vector2(48, level.layout.FLOOR_Y), Vector2(2704, level.layout.surface_at(2704)), Vector2(3464, 66), Vector2(4640, level.layout.FLOOR_Y)]:
		level.player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		level._set_paused(false)
		await process_frame
		world._sync_backdrop()
		for sprite: Sprite2D in world.midground.get_children():
			var base := sprite.global_position.y + _foot(sprite.texture) * sprite.global_scale.y
			var center_x := sprite.position.x + sprite.texture.get_width() * sprite.scale.x * 0.5
			var surface: float = level.layout.FLOOR_Y if number == 1 else level.layout.surface_at(center_x)
			_expect(base >= surface + 0.5 and base <= surface + 1.5, "Level %d painted base stays in the ground at %s: %s" % [number, point, sprite.name])
	current_scene = null
	level.free()


func _run() -> void:
	for sample in SAMPLES:
		var texture: Texture2D = load("res://assets/art/backgrounds/%s.png" % sample[0])
		var target := GROUNDING.rect(texture, 256, 140, sample[1])
		var painted_base := target.position.y + _foot(texture) * target.size.y / texture.get_height()
		_expect(painted_base >= 140.5 and painted_base <= 141.5, "Imported painted pixels overlap the floor: " + sample[0])
		for scale in [1, 3, 4, 5]: # Preview, 540p, 720p, and desktop sampling.
			await _render_contact(texture, sample[1], scale)
	for number in range(1, 6):
		await _actual_landmarks(number)
	print("PASS: painted scenery contacts, floating-tree negative control, preview/540p/720p/desktop pixels, and moving-camera landmark bases." if failures.is_empty() else "FAIL: " + str(failures))
	quit(0 if failures.is_empty() else 1)
