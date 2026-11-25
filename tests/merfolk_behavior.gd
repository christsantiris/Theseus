extends SceneTree

class Target:
	extends CharacterBody2D
	var health := 100
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var floor_body: StaticBody2D
var player: Target
var enemy: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int) -> void:
	for tick in count:
		await physics_frame


func _solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	return body


func _pose(ducked: bool) -> void:
	var shape := player.get_node("Body") as CollisionShape2D
	shape.shape.size = Vector2(14, 36 if ducked else 44)
	shape.position.y = -18 if ducked else -22


func _reset(ducked := false) -> void:
	_pose(ducked)
	player.position = Vector2(232, 152)
	player.hits = 0
	enemy.position = Vector2(200, 152)
	enemy.velocity = Vector2.ZERO
	enemy.direction = 1
	enemy._has_focus = false
	enemy._cooldown = 0.0
	enemy._enter("patrol")


func _until(state: String, limit := 150) -> bool:
	for tick in limit:
		await physics_frame
		if enemy._state == state:
			return true
	return false


func _attack() -> void:
	_expect(await _until("windup"), "Close Merfolk enters windup")
	_expect(player.hits == 0, "Windup is harmless")
	_expect(await _until("strike"), "Windup commits to a held weapon strike")
	_expect(await _until("recover"), "Attack opens a recovery window")


func _role(blade: bool) -> void:
	if is_instance_valid(enemy):
		enemy.free()
	enemy = load("res://scenes/enemies/merfolk_reefblade.tscn" if blade else "res://scenes/enemies/merfolk_trident.tscn").instantiate()
	enemy.position = Vector2(200, 152)
	enemy.patrol_left = 48
	enemy.patrol_right = 400
	enemy.tuning = load("res://scenes/levels/difficulty.gd").for_level(7)
	root.add_child(enemy)
	await _frames(4)
	_art_anchors()
	_reset()
	await _attack()
	_expect(player.hits == 1, "Standing target takes exactly one weapon hit")
	_reset(true)
	await _attack()
	_expect(player.hits == (1 if blade else 0), "Duck avoids high tridents and cannot avoid low blades")
	_reset()
	_expect(await _until("windup"), "Defense case starts with a telegraph")
	player.position = Vector2(280, 152) if not blade else Vector2(232, 115)
	_expect(await _until("recover"), "Evaded attack still completes")
	_expect(player.hits == 0, "Retreat avoids a trident; full jump clears a low blade")
	_reset()
	_expect(await _until("windup"), "Facing case starts")
	player.position = Vector2(160, 152)
	_expect(await _until("strike") and enemy.direction == 1, "Attack facing stays locked after the windup")
	_expect(await _until("recover") and player.hits == 0, "Moving behind causes a committed miss")
	_reset()
	player.position.y = 120
	_expect(not enemy._can_engage(), "Different landings do not trigger attacks")
	_reset()
	var wall := _solid(Rect2(216, 72, 8, 80))
	await _frames(3)
	_expect(not enemy._can_engage(), "Walls prevent engagement")
	# Check active frames too: a wall appearing after windup blocks the weapon.
	enemy._enter("strike")
	await _frames(8)
	_expect(player.hits == 0, "Held weapons cannot damage through terrain")
	wall.free()
	await _frames(3)
	_reset()
	enemy._has_focus = true
	enemy._cooldown = 10.0
	enemy.patrol_right = 208
	player.position.x = 330
	await _frames(36)
	_expect(enemy._has_focus and enemy.direction == 1 and enemy.position.x > 208, "Focused Merfolk pursues beyond its patrol instead of wandering away")
	enemy.patrol_right = 400
	_reset()
	floor_body.free()
	floor_body = _solid(Rect2(0, 152, 210, 32))
	await _frames(4)
	_expect(not enemy._can_lunge() and not enemy._can_engage(), "Unsupported canal crossings prevent attacks")
	await _frames(60)
	_expect(enemy.position.x < 210 and enemy.alive, "Merfolk holds safely at the unsupported edge")
	floor_body.free()
	floor_body = _solid(Rect2(0, 152, 600, 32))
	await _frames(4)
	_reset()
	enemy.sword_hit()
	_expect(enemy.hp == 1 and enemy._state == "recover", "Sword interrupts a living Merfolk into vulnerable recovery")
	var score := {"value": 0}
	enemy.defeated.connect(func(points: int) -> void: score.value += points)
	enemy.sword_hit()
	_expect(not enemy.alive and score.value == (150 if blade else 125), "Two hits defeat a regular Merfolk and award its role score once")


func _run() -> void:
	floor_body = _solid(Rect2(0, 152, 600, 32))
	player = Target.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	var shape := CollisionShape2D.new()
	shape.name = "Body"
	shape.shape = RectangleShape2D.new()
	player.add_child(shape)
	root.add_child(player)
	await _role(false)
	await _role(true)
	if is_instance_valid(enemy):
		enemy.free()
	player.free()
	var review = load("res://scenes/reviews/merfolk_review.tscn").instantiate()
	root.add_child(review)
	current_scene = review
	review.player.position = Vector2(200, 152)
	review.merfolk._cooldown = 0.0
	enemy = review.merfolk
	_expect(await _until("windup"), "Actual hero triggers the guard telegraph")
	Input.action_press("duck")
	_expect(await _until("recover"), "Ducked attack finishes")
	_expect(review.player._ducked and review.player.health == 5 and enemy.hp == 2, "The actual crouch safely clears a high thrust")
	Input.action_release("duck")
	for strike in 2:
		Input.action_press("attack")
		await _frames(2)
		Input.action_release("attack")
		await _frames(20)
	_expect(not is_instance_valid(enemy) or not enemy.alive, "Releasing Duck allows two actual sword counters")
	review._choose(1)
	enemy = review.merfolk
	review.player.position = Vector2(200, 152)
	enemy._cooldown = 0.0
	_expect(await _until("windup"), "Actual hero triggers the blade telegraph")
	while enemy._state == "windup" and enemy._state_time < enemy._telegraph(0.65) - 0.22:
		await _frames(1)
	Input.action_press("jump")
	var controls := root.get_node("MobileControls")
	if controls.enabled:
		controls._set_pressed("jump", true)
	await _frames(2)
	if controls.enabled:
		Input.action_release("jump")
		controls._set_pressed("jump", false)
	_expect(await _until("recover"), "Jumped low lunge completes")
	_expect(review.player.health == 5 and enemy.hp == 2, "Actual jump counters the low blade without collision damage")
	Input.action_release("jump")
	if controls.enabled:
		controls._sync_scene()
		_expect(controls.buttons.jump.is_visible_in_tree(), "Merfolk review exposes actual mobile touch controls")
	review._choose(2)
	_expect(review.merfolk.hp == 3 and review.merfolk.points == 250, "Captain receives its elite health bonus exactly once")
	review._toggle_gallery()
	_expect(paused and review.gallery.visible, "Review gallery pauses combat")
	review._toggle_gallery()
	review._choose(1)
	_expect(review.merfolk.reefblade and review.merfolk.hp == 2, "Review switches to a fresh blade fighter")
	review._reset()
	_expect(review.player.health == 5, "Review reset restores player health")
	_stop_audio(root)
	OS.delay_msec(150)
	review.free()
	current_scene = null
	floor_body.free()
	paused = false
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await _frames(2)
	if failures.is_empty():
		print("PASS: Merfolk duck/jump/retreat counters, single-hit weapons, committed facing, recovery, terrain safety, focus, scores, elite health and review controls.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null


func _art_anchors() -> void:
	for animation in ["walk", "windup", "strike", "recover", "hurt"]:
		for frame in enemy.sprite.sprite_frames.get_frame_count(animation):
			enemy.sprite.animation = animation
			enemy.sprite.frame = frame
			enemy._anchor()
			var texture: Texture2D = enemy.sprite.sprite_frames.get_frame_texture(animation, frame)
			var pixels := texture.get_image()
			var foot := -1
			for y in range(pixels.get_height() - 1, -1, -1):
				for x in pixels.get_width():
					if pixels.get_pixel(x, y).a >= 0.5:
						foot = y + 1
						break
				if foot >= 0:
					break
			var contact: float = (foot - texture.get_height() * 0.5 + enemy.sprite.offset.y) * enemy.sprite.scale.y
			_expect(foot > 0 and absf(contact) < 0.3, "Every painted Merfolk tail stays on its floor anchor")
