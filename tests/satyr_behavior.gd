extends SceneTree

# Run: godot --headless --path . --script res://tests/satyr_behavior.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 30
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var arena: Node2D
var satyr: Node
var target: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	node.shape = shape
	body.add_child(node)
	arena.add_child(body)


func _fresh(real_player: bool = false) -> void:
	paused = false
	for action in ["attack", "jump", "move_right", "move_left", "duck"]:
		Input.action_release(action)
	if is_instance_valid(arena):
		arena.free()
	arena = Node2D.new()
	root.add_child(arena)
	_solid(Rect2(0, 152, 1200, 32))
	if real_player:
		target = load("res://scenes/player/player.tscn").instantiate()
		target.position = Vector2(500, 152)
		arena.add_child(target)
		target.get_node("Camera2D").enabled = false
	else:
		target = Target.new()
		target.position = Vector2(248, 152)
		target.collision_layer = 2
		target.collision_mask = 1
		var node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(14, 44)
		node.position.y = -22
		node.shape = shape
		target.add_child(node)
		arena.add_child(target)
		target.add_to_group("player")
	satyr = load("res://scenes/enemies/satyr.tscn").instantiate()
	satyr.position = Vector2(200, 152)
	satyr.patrol_left = 32
	satyr.patrol_right = 416
	satyr.direction = 1
	satyr.wine_drop_chance = 0
	arena.add_child(satyr)
	satyr._rng.seed = 7
	satyr._cooldown = 0.0
	await _frames()


func _until(next: String) -> bool:
	for frame in 160:
		await physics_frame
		if satyr._state == next:
			return true
	return false


func _combat() -> void:
	await _fresh()
	var image: Image = satyr.ART.get_image()
	_expect(image.get_size() == Vector2i(2304, 896), "Satyr has eight cinematic sprite cells")
	_expect(satyr.sprite.scale == Vector2.ONE / 8.0 and satyr.sprite.offset.y * satyr.sprite.scale.y == -25.0, "Satyr keeps his world size and foot anchor")
	_expect(satyr._body_shape.size == Vector2(18, 36), "Satyr keeps his standing collision geometry")
	var frames: SpriteFrames = satyr.sprite.sprite_frames
	_expect(frames.get_frame_count("idle") == 2 and frames.get_animation_speed("idle") == 4, "Satyr keeps both breathing poses and their cadence")
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			var pose := frames.get_frame_texture(animation, frame) as AtlasTexture
			_expect(pose.region.size == Vector2(576, 448) and Rect2(Vector2.ZERO, image.get_size()).encloses(pose.region), "Every Satyr animation binds a complete cinematic pose")
	for index in 8:
		var used := image.get_region(Rect2i((index % 4) * 576, (index / 4) * 448, 576, 448)).get_used_rect()
		_expect(used.size.x > 190 and used.size.y > 220 and used.position.x > 0 and used.end.x < 576 and used.end.y >= 352 and used.end.y <= 432, "Satyr poses fit the atlas, including tucked hooves during hops")
		if index not in [3, 4]:
			_expect(used.end.y == 432, "Planted Satyr poses retain their original foot row")
	_expect(await _until("windup"), "A nearby player triggers a horn windup")
	await _frames(12)
	_expect(satyr._state == "windup" and target.hits == 0, "Horn attack has a readable, harmless windup")
	target.position = satyr.position + Vector2(-20, 0)
	_expect(await _until("charge"), "Satyr follows through with its charge")
	_expect(satyr.direction == 1, "Horn charge commits to its original direction")
	_expect(await _until("recover"), "Charge exposes a recovery window")
	_expect(target.hits == 0, "Moving behind the windup avoids the horns")
	await _fresh()
	_expect(await _until("charge"), "Hit case reaches active horns")
	_expect(await _until("recover"), "Hit case completes")
	_expect(target.hits == 1, "Short horn charge deals one hit per target")
	_expect(satyr._has_focus, "Satyr retains the player after attacking")
	satyr.sword_hit()
	_expect(satyr.hp == 1 and satyr.alive, "Sword damages Satyr during recovery")
	satyr.sword_hit()
	_expect(not satyr.alive and get_nodes_in_group("stolen_wine").is_empty(), "Zero drop chance creates no wine")
	await _fresh()
	satyr.wine_drop_chance = 1
	var award := {"score": 0}
	satyr.defeated.connect(func(points: int) -> void: award.score += points)
	satyr.take_damage(2)
	satyr.die()
	_expect(award.score == 125 and get_nodes_in_group("stolen_wine").size() == 1, "A guaranteed drop creates exactly one wine and awards score once")


func _hops() -> void:
	await _fresh()
	satyr.position = Vector2(136, 152)
	satyr._enter("idle")
	satyr._cooldown = 30
	satyr._hop_wait = 0
	target.position = Vector2(380, 120)
	_solid(Rect2(160, 136, 96, 16))
	_solid(Rect2(272, 120, 144, 32))
	var visited_lower := false
	var visited_upper := false
	var hops := 0
	var previous := ""
	for frame in 900:
		await physics_frame
		if satyr._state == "hop" and previous != "hop":
			hops += 1
		if satyr.is_on_floor():
			visited_lower = visited_lower or absf(satyr.position.y - 136) < 1
			visited_upper = visited_upper or absf(satyr.position.y - 120) < 1
		previous = satyr._state
		if visited_upper:
			break
	_expect(visited_lower and visited_upper and hops >= 2, "Satyr actually hops up and across the gap between separate platforms; x=%.1f y=%.1f" % [satyr.position.x, satyr.position.y])
	# A wall and low ceiling must reject a landing whose path crosses solid stone.
	satyr.set_physics_process(false)
	satyr.position = Vector2(200, 136)
	satyr.direction = 1
	_solid(Rect2(216, 40, 8, 96))
	await _frames()
	_expect(not satyr._plan_hop(), "Solid wall blocks an otherwise nearby hop target")
	satyr.position = Vector2(1170, 152)
	satyr.direction = 1
	satyr._has_focus = true
	_expect(not satyr._charge_safe(), "Horn charge cannot run off unsupported ground")
	satyr.position = Vector2(1220, 152)
	_expect(not satyr._plan_hop(), "No hop is allowed without a supported destination")


func _bounce_and_wine() -> void:
	await _fresh(true)
	satyr.set_physics_process(false)
	var top: float = satyr.position.y - 36
	target.position = Vector2(satyr.position.x, top - 2)
	target.velocity = Vector2(0, 100)
	await _frames(8)
	_expect(target.health == 5 and satyr.hp == 1 and satyr.alive, "A real landing bounces safely and removes one Satyr health")
	_expect(target.velocity.y < 0 and target.position.y < top - 4, "Bounce launches Theseus visibly upward")
	await _frames(3)
	_expect(satyr.hp == 1, "One bounce cannot drain health repeatedly")
	satyr._enter("charge")
	satyr.velocity = Vector2.ZERO
	top = satyr.get_node("CollisionShape2D").global_position.y - 14
	target.position = Vector2(satyr.get_node("CollisionShape2D").global_position.x, top - 2)
	target.velocity = Vector2(0, 100)
	await _frames(8)
	_expect(target.health == 5 and not satyr.alive and target.velocity.y < 0, "A second bounce also defeats a charging Satyr without player damage")
	await _fresh(true)
	satyr.set_physics_process(false)
	target.position = Vector2(satyr.position.x - 8, satyr.position.y - 24)
	target.velocity = Vector2(0, 60)
	await _frames(8)
	_expect(target.health == 4 and satyr.hp == 1, "An airborne side collision keeps the existing mutual damage rule")
	target.position = Vector2(500, 152)
	target.velocity = Vector2.ZERO
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	arena.add_child(hud)
	target.speed_boost_changed.connect(hud.set_speed_boost)
	var wine = load("res://scenes/pickups/stolen_wine.tscn").instantiate()
	wine.position = target.position
	arena.add_child(wine)
	await _frames(8)
	_expect(not is_instance_valid(wine) and is_equal_approx(target.movement_speed(), 121.5), "Wine is collected and grants a 35 percent speed boost")
	_expect(hud._speed_status.visible and hud._speed_status.text.contains("6"), "HUD shows the temporary speed timer")
	Input.action_press("move_right")
	await _frames(4)
	_expect(is_equal_approx(target.velocity.x, 121.5) and is_equal_approx(target.sprite.speed_scale, 1.35), "Movement and stride animation use the boosted speed")
	Input.action_press("attack")
	await _frames(3)
	_expect(target.sprite.animation == "attack" and target.sprite.speed_scale == 1.0, "Speed boost does not speed up sword attacks")
	Input.action_release("attack")
	Input.action_release("move_right")
	target.grant_speed_boost()
	_expect(target._speed_boost_left <= 6.0 and is_equal_approx(target.movement_speed(), 121.5), "Another wine refreshes the boost without stacking")
	target.grant_speed_boost(0.25)
	var remaining: float = target._speed_boost_left
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = true
	await _frames(12)
	_expect(target._speed_boost_left == remaining, "Pausing stops the boost timer")
	paused = false
	await _frames(20)
	_expect(target.movement_speed() == 90 and not hud._speed_status.visible, "Boost expires back to normal speed and hides its indicator")
	Input.action_press("move_right")
	await _frames(3)
	_expect(target.velocity.x == 90, "Normal movement speed is restored after expiration")
	Input.action_release("move_right")
	# Dropped wine falls to terrain and expires if it is left behind.
	wine = load("res://scenes/pickups/stolen_wine.tscn").instantiate()
	wine.position = Vector2(900, 40)
	arena.add_child(wine)
	await _frames(70)
	_expect(wine.is_on_floor() and absf(wine.position.y - 152) < 1, "Airborne wine drops settle on supported ground")
	wine._age = wine.LIFETIME - 0.05
	await _frames(8)
	_expect(not is_instance_valid(wine), "Uncollected wine cleans itself up")


func _run() -> void:
	await _combat()
	await _hops()
	await _bounce_and_wine()
	paused = false
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Satyr art, horn telegraph/commitment/damage, platform hopping and safety, actual-player safe bounces and side collisions, drops, wine pickup, speed/stride/timer, pause and expiration.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
