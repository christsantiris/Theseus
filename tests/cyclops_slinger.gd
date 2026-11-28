extends SceneTree

# Run: godot --headless --path . --script res://tests/cyclops_slinger.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 20
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

const ROCK := preload("res://scenes/projectiles/boulder.tscn")
var failures: Array[String] = []
var player: Target
var cyclops: Node
var fixture: Node2D
var throws := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _solid(parent: Node, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
	return body


func _until(next: String, limit: int = 180) -> bool:
	for frame in limit:
		await physics_frame
		if cyclops._state == next:
			return true
	return false


func _spawn_rock(parent: Node, at: Vector2, facing: int = -1) -> Node:
	var boulder = ROCK.instantiate()
	boulder.position = at
	boulder.launch(facing)
	parent.add_child(boulder)
	return boulder


func _clear_rocks() -> void:
	for rock in get_nodes_in_group("cyclops_boulders"):
		rock.free()


func _thuds(host: Node) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in host.get_children():
		if child is AudioStreamPlayer:
			players.append(child)
	return players


func _controller() -> void:
	fixture = Node2D.new()
	root.add_child(fixture)
	_solid(fixture, Rect2(0, 152, 600, 32))
	_solid(fixture, Rect2(200, 136, 160, 16))
	player = Target.new()
	player.position = Vector2(500, 152)
	player.collision_layer = 2
	player.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 44)
	shape_node.shape = shape
	shape_node.position.y = -22
	player.add_child(shape_node)
	fixture.add_child(player)
	player.add_to_group("player")
	cyclops = load("res://scenes/enemies/cyclops_slinger.tscn").instantiate()
	cyclops.position = Vector2(300, 136)
	cyclops.direction = -1
	fixture.add_child(cyclops)
	cyclops.boulder_thrown.connect(func(_rock: CharacterBody2D) -> void: throws += 1)
	await _frames(90)
	_expect(cyclops._state == "idle" and throws == 0, "Distant Cyclops does not throw at an unseen player")
	_expect(cyclops.hp == 3 and cyclops.points == 200, "Cyclops has three health and awards 200 points")
	var atlas: Image = cyclops.ART.get_image()
	_expect(atlas.get_size() == Vector2i(2560, 1280), "Cyclops atlas has eight cinematic 640-by-640 cells")
	_expect(cyclops.sprite.scale == Vector2.ONE / 8.0 and cyclops.sprite.offset.y * cyclops.sprite.scale.y == -37.0, "Cinematic Cyclops retains its world size and foot anchor")
	_expect(cyclops._body_shape.size == Vector2(34, 56), "Cyclops retains its standing collision geometry")
	var frames: SpriteFrames = cyclops.sprite.sprite_frames
	_expect(frames.get_frame_count("idle") == 2 and frames.get_frame_count("reload") == 2 and frames.get_animation_speed("windup") == 2.0, "Cyclops retains its breathing, windup, and reload cadence")
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			var pose := frames.get_frame_texture(animation, frame) as AtlasTexture
			_expect(pose.region.size == Vector2(640, 640) and Rect2(Vector2.ZERO, atlas.get_size()).encloses(pose.region), "Cyclops animation binds a complete cinematic pose")
	for index in 8:
		var used := atlas.get_region(Rect2i((index % 4) * 640, (index / 4) * 640, 640, 640)).get_used_rect()
		_expect(used.size.x > 280 and used.size.y > 360 and used.position.x > 0 and used.position.y > 0 and used.end.x < 640 and used.end.y == 624, "Pose %d fits the cell and stays grounded" % index)
	player.position = Vector2(160, 152)
	var wall := _solid(fixture, Rect2(240, 56, 8, 80))
	await _frames()
	_expect(not cyclops._can_engage(), "A wall blocks throw engagement")
	wall.free()
	await _frames()
	_expect(await _until("windup"), "A visible player triggers the slow windup")
	await _frames(45)
	_expect(cyclops._state == "windup" and throws == 0, "Windup is readable for at least 0.75 seconds without a projectile")
	player.position = Vector2(400, 152)
	_expect(await _until("throw"), "Windup reaches the release pose")
	_expect(throws == 1 and cyclops.direction == -1, "One boulder launches in the direction locked before the player changed sides")
	var rock = get_nodes_in_group("cyclops_boulders")[0]
	_expect(rock.velocity.x == -144 and rock.velocity.y <= -94, "Launch uses the fixed, non-homing arc")
	_expect(await _until("reload"), "Throw ends in a reload opening")
	_clear_rocks()
	player.position = cyclops.position
	var hits_before: int = player.hits
	await _frames(45)
	_expect(cyclops._state == "reload" and throws == 1 and player.hits == hits_before, "Reload is a long safe opening without extra throws or body-contact attacks")
	cyclops.sword_hit()
	_expect(cyclops.hp == 2 and cyclops.alive, "Reload is vulnerable to sword damage")
	player.position = Vector2(160, 152)
	_expect(await _until("recover"), "Cyclops rises after reloading")
	for frame in 420:
		await physics_frame
		if throws >= 3 and player.hits > hits_before:
			break
	_expect(throws >= 3 and player.hits > hits_before, "Cyclops repeatedly throws and a boulder deals damage (%d throws, %d hits)" % [throws, player.hits])
	_expect(cyclops.position.distance_to(Vector2(300, 136)) < 0.1, "Throwing and reloading keep Cyclops planted on the platform")
	var award := {"score": 0}
	cyclops.defeated.connect(func(points: int) -> void: award.score += points)
	cyclops.sword_hit()
	cyclops.sword_hit()
	cyclops.sword_hit()
	_expect(not cyclops.alive and award.score == 200, "Three hits defeat Cyclops and award points once")
	fixture.free()
	await _frames()


func _reset_slam(facing := 1) -> void:
	player.position = Vector2(300 + facing * 32, 152)
	player.health = 20
	player.hits = 0
	cyclops.position = Vector2(300, 152)
	cyclops.direction = facing
	cyclops._enter("idle")
	cyclops._cooldown = 0.0


func _melee_controller() -> void:
	fixture = Node2D.new()
	root.add_child(fixture)
	_solid(fixture, Rect2(0, 152, 600, 32))
	player = Target.new()
	player.position = Vector2(500, 152)
	player.collision_layer = 2
	player.collision_mask = 1
	var collision := CollisionShape2D.new()
	var body := RectangleShape2D.new()
	body.size = Vector2(14, 44)
	collision.shape = body
	collision.position.y = -22
	player.add_child(collision)
	fixture.add_child(player)
	player.add_to_group("player")
	cyclops = load("res://scenes/enemies/cyclops_slinger.tscn").instantiate()
	cyclops.position = Vector2(300, 152)
	fixture.add_child(cyclops)
	throws = 0
	cyclops.boulder_thrown.connect(func(_rock: CharacterBody2D) -> void: throws += 1)
	await _frames()
	for facing in [-1, 1]:
		_reset_slam(facing)
		_expect(await _until("slam_windup", 10), "Nearby Theseus triggers a close slam in either direction")
		await _frames(20)
		_expect(cyclops._state == "slam_windup" and player.hits == 0 and throws == 0, "Raised-stone warning is safe and does not release a boulder")
		paused = true
		var before: float = cyclops._state_time
		await _frames(8)
		_expect(cyclops._state_time == before and player.hits == 0, "Pause freezes the slam windup")
		paused = false
		_expect(await _until("slam", 45), "The warning leads to a held-boulder impact")
		_expect(cyclops._slam_thud.playing, "The close impact uses the existing boulder thud")
		_expect(await _until("slam_recover", 20), "The slam exposes a separate recovery window")
		_expect(player.hits == 1 and player.health == 19 and throws == 0,
			"Each close slam deals one hit, without a projectile or repeated overlap damage")
		_expect(cyclops.position == Vector2(300, 152), "Close attacks keep Cyclops planted")
		await _frames(20)
		_expect(cyclops._state == "slam_recover" and player.hits == 1, "Slam recovery is safe for counters")
		_expect(await _until("idle", 60), "The slam returns to the normal attack selection")
		_expect(cyclops._cooldown > 0.0, "A completed slam keeps the normal attack cooldown")

	_reset_slam()
	player.position = Vector2(332, 120)
	_expect(not cyclops._can_slam(), "A player on a substantially higher ledge cannot trigger a ground slam")
	player.position = Vector2(332, 152)
	var wall := _solid(fixture, Rect2(318, 70, 4, 82))
	await _frames()
	_expect(not cyclops._can_slam() and cyclops._state == "idle", "A wall blocks the melee attack")
	wall.free()
	await _frames()

	_reset_slam()
	_expect(await _until("slam_windup", 10), "Retreat counter starts with a warning")
	player.position.x = 380
	_expect(await _until("slam_recover", 90), "A baited slam follows through")
	_expect(player.hits == 0 and throws == 0, "Retreat avoids the committed close attack")
	_reset_slam()
	_expect(await _until("slam_windup", 10), "Side-step counter starts with a warning")
	player.position.x = 268
	_expect(await _until("slam", 60), "The close attack commits to its original side")
	_expect(cyclops.direction == 1, "Cyclops does not turn its slam after the windup")
	_expect(await _until("slam_recover", 20), "Missed slam recovers normally")
	_expect(player.hits == 0, "Moving behind Cyclops avoids the front-only impact")

	_reset_slam()
	_expect(await _until("slam_windup", 10), "Fatal-counter case begins with a close attack")
	cyclops.sword_hit()
	_expect(cyclops.hp == 2, "Cyclops remains vulnerable during the melee warning")
	_expect(await _until("slam", 60), "Fatal-counter case reaches the impact pose")
	var award := {"score": 0}
	cyclops.defeated.connect(func(points: int) -> void: award.score += points)
	cyclops.sword_hit()
	cyclops.sword_hit()
	await _frames(20)
	_expect(player.hits == 0 and award.score == 200, "Defeating Cyclops cancels late slam damage and retains its score")
	fixture.free()
	await _frames()


func _projectiles() -> void:
	fixture = Node2D.new()
	root.add_child(fixture)
	var a = _spawn_rock(fixture, Vector2(300, -100), 1)
	var b = _spawn_rock(fixture, Vector2(300, -100), -1)
	a.collision_mask = 0
	b.collision_mask = 0
	await _frames(20)
	_expect(_thuds(fixture).is_empty(), "Throwing a boulder does not play the impact thud")
	_expect(is_equal_approx(a.position.y, b.position.y) and is_equal_approx(a.position.x + b.position.x, 600), "Mirrored throws follow the same predictable arc")
	_expect(a.velocity.y > 0 and a.position.y < -100, "Boulder rises to an apex then descends under gravity")
	a.free()
	b.free()
	_solid(fixture, Rect2(360, -180, 8, 160))
	var rock = _spawn_rock(fixture, Vector2(320, -100), 1)
	var breaks := {"count": 0}
	rock.shattered.connect(func() -> void: breaks.count += 1)
	await _frames(40)
	_expect(breaks.count == 1 and not is_instance_valid(rock), "Boulder shatters once on a wall and cleans up")
	var thuds := _thuds(fixture)
	_expect(thuds.size() == 1 and thuds[0].playing and thuds[0].get_playback_position() < 1.0, "Wall impact plays about one second of the boulder thud")
	rock = _spawn_rock(fixture, Vector2(40, -100))
	breaks.count = 0
	rock.shattered.connect(func() -> void: breaks.count += 1)
	rock.sword_hit()
	rock.sword_hit()
	_expect(rock._broken and rock.collision_layer == 0 and breaks.count == 1, "One sword hit disables the projectile; repeated hits cannot break it twice")
	_expect(_thuds(fixture).size() == 1, "A sword break does not play the impact thud")
	await _frames(12)
	_expect(not is_instance_valid(rock), "Sword-broken boulder finishes its short break effect")
	rock = _spawn_rock(fixture, Vector2(40, -200))
	rock.collision_mask = 0
	await _frames(200)
	_expect(not is_instance_valid(rock), "An offscreen boulder expires instead of leaking")
	_expect(_thuds(fixture).is_empty(), "The impact thud stops after about one second")
	fixture.free()


func _fresh_review() -> Node:
	paused = false
	for action in ["jump", "attack", "move_right", "move_left"]:
		Input.action_release(action)
	if is_instance_valid(current_scene):
		current_scene.free()
	var review = load("res://scenes/reviews/cyclops_review.tscn").instantiate()
	root.add_child(review)
	current_scene = review
	review.cyclops.set_physics_process(false)
	review.player.position = Vector2(92, 152)
	await _frames()
	return review


func _review_throw(review: Node) -> Node:
	review.cyclops._throw_boulder()
	return get_nodes_in_group("cyclops_boulders").back()


func _player_defenses() -> void:
	var review = await _fresh_review()
	_review_throw(review)
	await _frames(65)
	_expect(review.player.health == 4, "Standing in the landing lane costs exactly one health bar")
	review = await _fresh_review()
	var rock = _review_throw(review)
	var hit := {"broken": false, "x": 0.0}
	rock.shattered.connect(func() -> void:
		hit.broken = true
		hit.x = rock.position.x
	)
	await _frames(41)
	Input.action_press("attack")
	await _frames(12)
	Input.action_release("attack")
	_expect(review.player.health == 5 and hit.broken and hit.x > 97, "Theseus's actual timed sword destroys the incoming boulder before contact or ground impact")
	review = await _fresh_review()
	_review_throw(review)
	await _frames(30)
	Input.action_press("jump")
	await _frames(17)
	_expect(review.player.position.y < 120, "Actual held jump reaches a safe height")
	await _frames(22)
	Input.action_release("jump")
	_expect(review.player.health == 5 and get_nodes_in_group("cyclops_boulders").is_empty(), "An ordinary timed jump clears the boulder and its ground impact")
	await _frames(6)
	_expect(review.player.is_on_floor(), "Jump defense returns Theseus safely to the ground")
	rock = _review_throw(review)
	review._toggle_gallery()
	var original: Vector2 = rock.position
	await _frames(12)
	_expect(paused and review.gallery.visible and rock.position == original, "Pose gallery pauses live boulders")
	review._toggle_gallery()
	await _frames()
	_expect(not paused and rock.position != original, "Boulders resume with the review scene")
	_clear_rocks()
	review.player.position = Vector2(210, 136)
	review.player.velocity = Vector2.ZERO
	review.player.sprite.flip_h = false
	review.cyclops._enter("reload")
	await _frames()
	for expected_hp in [2, 1, 0]:
		Input.action_press("attack")
		await _frames(8)
		Input.action_release("attack")
		_expect(review.cyclops.hp == expected_hp, "Real sword counter during reload leaves %d Cyclops health" % expected_hp)
		if expected_hp > 0:
			await _frames(16)
	_expect(not review.cyclops.alive, "Three actual sword strikes defeat the reloading brute")
	var state := root.get_node("LevelRun")
	var saved_level: int = state.level_number
	var saved_score: int = state.level_start_score
	review._on_reset()
	await _frames()
	_expect(current_scene.cyclops.hp == 3 and current_scene.player.health == 5, "Review Reset restores both actors")
	_expect(state.level_number == saved_level and state.level_start_score == saved_score, "Enemy review leaves campaign progress untouched")


func _action(action: String, pressed: bool, finger := 0) -> void:
	var controls := root.get_node("MobileControls")
	if controls.enabled:
		var touch := InputEventScreenTouch.new()
		touch.index = finger
		touch.position = controls.buttons[action].position
		touch.pressed = pressed
		root.push_input(touch, true)
		Input.flush_buffered_events()
	elif pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _fresh_slam_level(facing: int) -> Node:
	paused = false
	for action in ["jump", "attack", "duck", "move_left", "move_right"]:
		Input.action_release(action)
	root.get_node("LevelRun").begin_level(5)
	change_scene_to_file("res://scenes/levels/level_5.tscn")
	await scene_changed
	var level := current_scene
	cyclops = level.get_node("CyclopsFoothills")
	for enemy in get_nodes_in_group("enemies"):
		if enemy != cyclops:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.remove_from_group("enemies")
			enemy.collision_layer = 0
	cyclops.set_physics_process(false)
	level.player.position = cyclops.position + Vector2(facing * 32, 0)
	level.player.velocity = Vector2.ZERO
	await _frames()
	cyclops.direction = facing
	cyclops._enter("idle")
	cyclops._cooldown = 0.0
	cyclops.set_physics_process(true)
	return level


func _melee_player_defenses() -> void:
	var level := await _fresh_slam_level(1)
	_expect(await _until("slam_recover", 100), "The placed Cyclops performs a close slam against the real player")
	_expect(level.player.health == 4 and get_nodes_in_group("cyclops_boulders").is_empty(), "Standing close costs one health without a ranged projectile")
	for facing in [-1, 1]:
		level = await _fresh_slam_level(facing)
		_expect(await _until("slam_windup", 20), "A close player receives the ground-slam warning")
		var warning_frames := ceili(cyclops._telegraph(cyclops.SLAM_WINDUP_SECONDS) * 60.0)
		await _frames(maxi(0, warning_frames - 14))
		_action("jump", true, 1)
		_expect(await _until("slam_recover", 50), "The close slam follows through under a timed jump")
		_action("jump", false, 1)
		_expect(level.player.health == 5 and get_nodes_in_group("cyclops_boulders").is_empty(), "A normal keyboard or touch jump clears the close impact in both directions")
		level = await _fresh_slam_level(facing)
		_expect(await _until("slam_windup", 20), "The retreat defense begins during the close warning")
		var action := "move_right" if facing > 0 else "move_left"
		_action(action, true)
		_expect(await _until("slam_recover", 100), "The slam does not chase a retreating player")
		_action(action, false)
		_expect(level.player.health == 5, "Walking away during the warning avoids the impact in either direction")


func _run() -> void:
	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	await _controller()
	await _melee_controller()
	await _projectiles()
	await _player_defenses()
	await _melee_player_defenses()
	paused = false
	_stop_audio(root)
	restore_scores.call()
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Cyclops art, slow committed windup, fixed arc, repeated throws, reload opening, close slam selection/commitment/pause/one-hit/recovery, actual-player melee jump/retreat, damage/score, projectile collisions/lifetime, actual-player sword and jump defenses, gallery pause and Reset.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
