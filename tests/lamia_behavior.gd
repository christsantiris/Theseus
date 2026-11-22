extends SceneTree

# Run: godot --headless --path . --script res://tests/lamia_behavior.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 20
	var hits := 0

	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var lamia: Node
var player: Target


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _solid(rectangle: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rectangle.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body


func _until(next: String, limit: int = 120) -> bool:
	for frame in limit:
		await physics_frame
		if lamia._state == next:
			return true
	return false


func _reset() -> void:
	lamia.position = Vector2(200, 152)
	lamia.direction = 1
	lamia._cooldown = 0.0
	lamia._enter("idle")
	player.position = Vector2(256, 152)


func _run() -> void:
	var floor := _solid(Rect2(0, 152, 600, 32))
	player = Target.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector2(500, 152)
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 44)
	shape_node.shape = shape
	shape_node.position.y = -22
	player.add_child(shape_node)
	root.add_child(player)
	player.add_to_group("player")
	lamia = load("res://scenes/enemies/lamia.tscn").instantiate()
	lamia.position = Vector2(200, 152)
	root.add_child(lamia)
	var original_children := root.get_child_count()
	await _frames(100)
	_expect(lamia._state == "idle" and lamia.position.x == 200 and player.hits == 0, "Distant Lamia stays coiled on her platform without timed attacks")
	_expect(lamia.hp == 2 and lamia.points == 150, "Lamia has two health and awards 150 points")
	var art: Image = lamia.ART.get_image()
	_expect(art.get_size() == Vector2i(6144, 448), "Lamia has eight cinematic sprite cells")
	_expect(lamia.sprite.scale == Vector2.ONE / 8.0 and lamia.sprite.offset.y * lamia.sprite.scale.y == -25.0, "Lamia keeps her world size and foot anchor")
	_expect(lamia._body_shape.size == Vector2(26, 42), "Lamia keeps her standing collision geometry")
	var frames: SpriteFrames = lamia.sprite.sprite_frames
	_expect(frames.get_frame_count("idle") == 2 and frames.get_animation_speed("idle") == 4 and frames.get_frame_count("guard") == 2 and frames.get_animation_speed("guard") == 6, "Idle and protective coil retain their poses and cadence")
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			var pose := frames.get_frame_texture(animation, frame) as AtlasTexture
			_expect(pose.region.size == Vector2(768, 448) and Rect2(Vector2.ZERO, art.get_size()).encloses(pose.region), "Every Lamia animation binds a complete cinematic pose")
	for index in 8:
		var used := art.get_region(Rect2i(index * 768, 0, 768, 448)).get_used_rect()
		_expect(used.size.x > 220 and used.size.y > 260 and used.position.x > 0 and used.end.x < 768 and used.end.y == 432, "Pose %d fits its cell and stays on the ground row" % index)
	lamia.set_physics_process(false)
	player.position = Vector2(256, 120)
	_expect(not lamia._can_engage(), "Lamia does not strike at another terrace height")
	player.position = Vector2(272, 152)
	_expect(not lamia._can_engage(), "Lamia cannot engage outside her long reach")
	player.position = Vector2(256, 152)
	var wall := _solid(Rect2(224, 72, 8, 80))
	await _frames()
	_expect(not lamia._can_engage(), "Walls block engagement")
	wall.free()
	await _frames()
	_reset()
	lamia.set_physics_process(true)
	_expect(await _until("windup"), "An approaching player triggers a readable windup")
	await _frames(25)
	_expect(lamia._state == "windup" and player.hits == 0, "Windup lasts over 0.4 seconds and causes no passive damage")
	player.position = Vector2(184, 152)
	_expect(await _until("strike"), "Lamia uncoils into her long strike")
	_expect(lamia.direction == 1, "Strike stays committed when the player moves behind her")
	_expect(await _until("retreat"), "Strike is followed by retreat into the coils")
	_expect(player.hits == 0 and lamia.position.x == 200, "Moving behind the windup avoids the strike and the anchored tail stays planted")
	lamia.sword_hit()
	lamia.take_damage(1)
	_expect(lamia.is_protected() and lamia.hp == 2, "Retreat blocks sword and collision damage")
	_expect(await _until("guard"), "Retreat leads to a visibly protected coil")
	lamia.sword_hit()
	_expect(lamia.is_protected() and lamia.hp == 2, "Protected coils are invulnerable")
	await _frames(25)
	_expect(lamia._state == "guard" and player.hits == 0, "Protection is brief and causes no contact damage")
	_expect(await _until("recover"), "Lamia exposes herself after the protective coil")
	lamia.sword_hit()
	_expect(not lamia.is_protected() and lamia.hp == 1 and lamia.alive, "Recovery is vulnerable to a sword counter")
	_reset()
	_expect(await _until("windup"), "Second attack begins")
	_expect(await _until("strike"), "Second attack reaches its active pose")
	_expect(await _until("retreat"), "Second strike completes")
	_expect(player.hits == 1 and player.health == 19, "Long strike reaches a target 56 pixels away and hits once")
	_expect(lamia.strike.get_parent() == lamia and root.get_child_count() == original_children, "Strike remains attached and creates no projectiles or hazards")
	_reset()
	_expect(await _until("windup"), "Jump defense case begins")
	player.position.y -= 37
	_expect(await _until("strike"), "Jumped strike follows through")
	_expect(await _until("retreat"), "Jumped strike completes")
	_expect(player.hits == 1, "Existing full jump clears the extended strike")
	_reset()
	_expect(await _until("windup"), "Retreat defense case begins")
	player.position.x = 300
	_expect(await _until("strike"), "A baited attack still follows through")
	_expect(await _until("retreat"), "Retreated attack completes")
	_expect(player.hits == 1, "Backing out of reach avoids damage")
	_reset()
	_expect(await _until("windup"), "Dynamic wall case begins")
	wall = _solid(Rect2(224, 72, 8, 80))
	_expect(await _until("strike"), "Committed strike still animates behind a wall")
	_expect(await _until("retreat"), "Blocked strike completes")
	_expect(player.hits == 1, "Strike cannot damage through terrain introduced during windup")
	wall.free()
	lamia.set_physics_process(false)
	lamia._enter("strike")
	lamia.direction = -1
	lamia._enter("strike")
	lamia._face()
	_expect(lamia.sprite.flip_h and lamia.sprite.offset.x * lamia.sprite.scale.x == -20 and lamia.strike.position.x == -36, "Artwork anchor and strike hitbox mirror together")
	var award := {"score": 0}
	lamia.defeated.connect(func(points: int) -> void: award.score += points)
	lamia._enter("recover")
	lamia.sword_hit()
	_expect(not lamia.alive and award.score == 150, "Second unprotected sword hit defeats Lamia and awards points once")
	lamia.sword_hit()
	_expect(award.score == 150, "Repeated hits cannot award extra points")
	lamia.free()
	player.free()
	floor.free()
	await _review_scene()
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Lamia atlas, range/elevation/LOS, windup, anchored committed strike, single damage, jump/retreat counters, protected coil, recovery vulnerability, facing, score and review scene.")
	quit(0 if failures.is_empty() else 1)


func _review_scene() -> void:
	var review = load("res://scenes/reviews/lamia_review.tscn").instantiate()
	root.add_child(review)
	current_scene = review
	await _frames()
	var state := root.get_node("LevelRun")
	var saved_level: int = state.level_number
	var saved_checkpoint: int = state.checkpoint_index
	review._toggle_gallery()
	_expect(paused and review.gallery.visible, "Pose gallery pauses combat for artwork review")
	review._toggle_gallery()
	_expect(not paused and not review.gallery.visible, "Returning from the gallery resumes combat")
	_expect(state.level_number == saved_level and state.checkpoint_index == saved_checkpoint, "Review scene does not change campaign progress")
	Input.action_press("move_right")
	var jumped := false
	for frame in 130:
		await physics_frame
		if not jumped and review.player.position.x >= 133:
			Input.action_press("jump")
			jumped = true
		if jumped and review.player.is_on_floor() and review.player.position.y < 140:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(jumped and review.player.position.x > 160 and review.player.position.y < 140, "Theseus can reach Lamia's review platform using his actual jump")
	review.lamia.set_physics_process(false)
	review.lamia._enter("guard")
	review.player.position = Vector2(220, 136)
	review.player.velocity = Vector2.ZERO
	await _frames()
	Input.action_press("attack")
	await _frames(8)
	_expect(review.lamia.hp == 2, "Actual sword query cannot damage the protected coil")
	Input.action_release("attack")
	await _frames(16)
	review.lamia._enter("recover")
	Input.action_press("attack")
	await _frames(8)
	_expect(review.lamia.hp == 1, "Actual sword query damages Lamia during exposed recovery")
	Input.action_release("attack")
	await _frames(16)
	Input.action_press("attack")
	await _frames(8)
	_expect(not review.lamia.alive, "Second timed player sword strike defeats an exposed Lamia")
	Input.action_release("attack")
	review._on_reset()
	await _frames()
	_expect(current_scene.lamia.hp == 2 and current_scene.player.health == 5, "Review Reset restores the enemy and player")


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
