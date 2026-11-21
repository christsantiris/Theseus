extends SceneTree

# Run: godot --headless --path . --script res://tests/coastal_enemies.gd --fixed-fps 60
var failures: Array[String] = []
var level: Node
var player: Node
var enemy: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _reset(kind: String, position: Vector2) -> void:
	for action in ["move_right", "jump", "duck", "attack"]:
		Input.action_release(action)
	if is_instance_valid(enemy):
		enemy.free()
	player.position = Vector2(200, 280)
	player.velocity = Vector2.ZERO
	player.health = 5
	player._hurt_lock = 0.0
	player._finish_attack()
	player._set_ducked(false)
	player.sprite.flip_h = false
	await _frames()
	enemy = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
	enemy.position = position
	enemy.direction = -1
	enemy.patrol_left = 80
	enemy.patrol_right = 480
	level.add_child(enemy)


func _until(state_name: String) -> bool:
	for frame in 100:
		await physics_frame
		if enemy._state == state_name:
			return true
	return false


func _visible_bounds(sprite: AnimatedSprite2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := texture.get_image().get_used_rect()
	var origin := -Vector2(texture.get_size()) * 0.5 + sprite.offset + Vector2(used.position)
	return sprite.global_transform * Rect2(origin, Vector2(used.size))


func _verify_duck_clearance() -> void:
	var original_player: Vector2 = player.position
	var original_bird: Vector2 = enemy.position
	var original_frame: int = enemy.sprite.frame
	var layout := preload("res://scenes/levels/level_2_layout.gd")
	for encounter: Dictionary in layout.ENEMIES:
		if not String(encounter.name).begins_with("BirdHigh"):
			continue
		player.position = Vector2(encounter.position.x, layout.surface_at(encounter.position.x))
		enemy.position = encounter.position
		var duck_bounds := _visible_bounds(player.sprite)
		var duck_body: Rect2 = player._body.global_transform * player._body.shape.get_rect()
		_expect(absf(duck_bounds.position.y - duck_body.position.y) <= 1.0, "Ducking hitbox matches the visible helmet height")
		for wing_frame in enemy.sprite.sprite_frames.get_frame_count("walk"):
			enemy.sprite.frame = wing_frame
			var bird_bounds := _visible_bounds(enemy.sprite)
			_expect(bird_bounds.end.y <= duck_bounds.position.y - 3.0, "%s wing frame %d visibly clears the ducking helmet" % [encounter.name, wing_frame])
	player.position = original_player
	enemy.position = original_bird
	enemy.sprite.frame = original_frame


func _run() -> void:
	root.get_node("LevelRun").begin_level(2)
	level = load("res://scenes/levels/level_2.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	for old_enemy in get_nodes_in_group("enemies"):
		old_enemy.free()
	await _reset("stymphalian_bird", Vector2(248, 236))
	Input.action_press("duck")
	await _frames(110)
	_expect(player._ducked and player.health == 5 and enemy.alive, "Ducking safely clears an entire high-bird pass")
	_verify_duck_clearance()
	_expect(absf(enemy.position.y - 236.0) < 0.01 and absf(enemy.velocity.x) == 48.0, "Bird stays in its lane at a moderate fixed speed")
	await _reset("stymphalian_bird", Vector2(248, 236))
	await _frames(100)
	_expect(player.health == 4, "Standing in a high-bird lane costs one health bar")
	await _reset("stymphalian_bird", Vector2(248, 272))
	Input.action_press("duck")
	await _frames(100)
	_expect(player.health == 4, "Low birds cannot be avoided by ducking")
	await _reset("stymphalian_bird", Vector2(248, 272))
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(60)
	_expect(player.health == 5 and enemy.alive and player.position.x > enemy.position.x + 30, "Normal movement and a held jump safely clear a low bird")
	await _reset("stymphalian_bird", Vector2(240, 272))
	Input.action_press("attack")
	await _frames(8)
	_expect(not enemy.alive and player.health == 5 and level._score == 0, "Timed standing sword hits a low bird without contact damage")
	# Test actors are not registered encounters, so their score signal is unbound.
	await _reset("stymphalian_bird", Vector2(225, 236))
	Input.action_press("jump")
	Input.action_press("attack")
	await _frames(8)
	_expect(not enemy.alive and player.health == 5, "A timed jumping sword strike reaches a high bird")
	await _reset("stymphalian_bird", Vector2(200, 236))
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	await _frames()
	enemy._hurt_overlaps()
	player._hurt_lock = 0.0
	enemy._hurt_overlaps()
	_expect(player.health == 4, "Lingering overlap cannot deal repeated damage during one pass")
	enemy.position.x = 280
	await _frames()
	enemy._hurt_overlaps()
	enemy.position.x = 200
	await _frames()
	enemy._hurt_overlaps()
	_expect(player.health == 3, "A later distinct pass can deal damage again")
	player.set_physics_process(true)
	await _reset("telchine", Vector2(232, 280))
	_expect(enemy.hp == 2 and enemy.sprite.sprite_frames.has_animation("jab"), "Dog-headed Telchine uses the soldier's melee animation set and two HP")
	_expect(await _until("windup"), "Telchine telegraphs its close-range jab")
	var planted: float = enemy.position.x
	_expect(await _until("jab"), "Telchine performs a held-weapon jab")
	_expect(await _until("recover"), "Telchine exposes a recovery window")
	_expect(absf(enemy.position.x - planted) < 0.1 and player.health == 4, "Telchine stays planted and deals one melee damage")
	enemy.sword_hit()
	_expect(enemy.alive and enemy.hp == 1, "First sword hit damages Telchine")
	enemy.sword_hit()
	_expect(not enemy.alive, "Second sword hit defeats Telchine")
	await _reset("spartoi", Vector2(248, 280))
	_expect(enemy.hp == 2 and enemy.sprite.sprite_frames.has_animation("lunge"), "Skeletal Spartoi uses Raider lunge animations and two HP")
	_expect(await _until("windup"), "Spartoi telegraphs its lunge")
	_expect(await _until("lunge"), "Spartoi lunges like a Raider")
	_expect(await _until("recover"), "Spartoi has a punishable recovery")
	_expect(player.health == 4, "Spartoi lunge deals one damage")
	enemy.sword_hit()
	_expect(enemy.alive and enemy.hp == 1, "First sword hit damages Spartoi")
	enemy.sword_hit()
	_expect(not enemy.alive, "Second sword hit defeats Spartoi")
	for action in ["move_right", "jump", "duck", "attack"]:
		Input.action_release(action)
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: actual-player high duck, low jump, standing/jumping sword timing, bird speed/lanes/contact, Telchine held jab, Spartoi lunge, health and defeat.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
