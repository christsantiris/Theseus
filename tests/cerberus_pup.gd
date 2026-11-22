extends SceneTree

# Run: godot --headless --path . --script res://tests/cerberus_pup.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 100
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var arena: Node2D
var pack: Node
var player: Node
var pup: Node
var buddy: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)
	return body


func _fresh(real_player: bool = false, floor_width: float = 1000) -> void:
	paused = false
	for action in ["attack", "duck", "jump", "move_left", "move_right"]:
		Input.action_release(action)
	if is_instance_valid(arena):
		_stop_audio(arena)
		arena.free()
	arena = Node2D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(arena)
	_solid(Rect2(0, 152, floor_width, 32))
	if real_player:
		player = load("res://scenes/player/player.tscn").instantiate()
		player.position = Vector2(600, 152)
		arena.add_child(player)
		player.get_node("Camera2D").enabled = false
	else:
		player = Target.new()
		player.position = Vector2(600, 152)
		player.collision_layer = 2
		player.collision_mask = 1
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(14, 44)
		collision.position.y = -22
		collision.shape = shape
		player.add_child(collision)
		arena.add_child(player)
		player.add_to_group("player")
	pack = load("res://scenes/enemies/cerberus_pack.tscn").instantiate()
	pack.position = Vector2(200, 152)
	pack.direction = 1
	arena.add_child(pack)
	pup = pack.get_node("PupA")
	buddy = pack.get_node("PupB")
	await _frames()


func _alone() -> void:
	buddy.position.x = 700
	buddy.set_physics_process(false)
	pup.global_position = Vector2(200, 152)
	pup.direction = 1
	pup._cooldown = 0
	player.position = Vector2(238, 152)
	await _frames(2)


func _until(state: String, limit: int = 180) -> bool:
	for frame in limit:
		await physics_frame
		if pup._state == state:
			return true
	return false


func _pack_behavior() -> void:
	await _fresh()
	_expect(pack.get_child_count() == 2 and get_nodes_in_group("enemies").size() == 2, "A pack spawns exactly two independently damageable pups")
	var art: Image = pup.ART.get_image()
	_expect(art.get_size() == Vector2i(4608, 448), "Pup has eight cinematic art cells")
	_expect(pup.sprite.scale == Vector2.ONE / 8.0 and pup.sprite.offset.y * pup.sprite.scale.y == -25.0, "Cinematic pup retains its world size and foot anchor")
	_expect(pup._body_shape.size == Vector2(28, 22), "Cinematic pup retains its contact geometry")
	var frames: SpriteFrames = pup.sprite.sprite_frames
	_expect(frames.get_frame_count("run") == 4 and frames.get_animation_speed("run") == 10, "Pup keeps four running poses at the original cadence")
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			var pose := frames.get_frame_texture(animation, frame) as AtlasTexture
			_expect(pose.region.size == Vector2(576, 448) and Rect2(Vector2.ZERO, art.get_size()).encloses(pose.region), "Pup animation binds a complete cinematic pose")
	for index in 8:
		var used := art.get_region(Rect2i(index * 576, 0, 576, 448)).get_used_rect()
		_expect(used.size.x > 240 and used.size.y > 170 and used.position.x > 0 and used.end.x < 576, "Pup poses are complete with transparent cell margins")
		_expect(used.end.y >= 376 and used.end.y <= 424, "Running and pouncing paws stay at or just above the ground")
		if index in [0, 5, 7]:
			_expect(used.end.y == 424, "Planted pup poses share the original foot baseline")
	var patrol_left: float = pup.global_position.x
	var patrol_right: float = patrol_left
	var closest := 1000.0
	for frame in 300:
		await physics_frame
		patrol_left = minf(patrol_left, pup.global_position.x)
		patrol_right = maxf(patrol_right, pup.global_position.x)
		closest = minf(closest, absf(pup.position.x - buddy.position.x))
	_expect(pup._state == "run" and buddy._state == "run" and player.hits == 0, "Distant player does not trigger timer-driven leaps")
	_expect(patrol_right - patrol_left > 60 and closest >= 34 and pup.direction == buddy.direction, "The pair patrols and turns together without stacking or getting stuck nose-to-nose")
	player.position = Vector2(330, 152)
	var attacks := [0, 0]
	var previous := ["", ""]
	var simultaneous := false
	var max_spacing := 0.0
	for frame in 720:
		await physics_frame
		var active := 0
		for index in 2:
			var dog: Node = pack.get_child(index)
			if dog._state in ["windup", "pounce"]:
				active += 1
			if dog._state == "pounce" and previous[index] != "pounce":
				attacks[index] += 1
			previous[index] = dog._state
		simultaneous = simultaneous or active > 1
		max_spacing = maxf(max_spacing, absf(pup.position.x - buddy.position.x))
	_expect(not simultaneous and attacks[0] >= 2 and attacks[1] >= 2, "Both pack members repeatedly leap, with only one attacking at a time: %s" % [attacks])
	_expect(max_spacing < 144 and pup._has_focus and buddy._has_focus, "The pair stays near the player and retains focus after attacking")
	_expect(player.hits > 0, "Unavoided pack leaps actually hit")
	# An interrupt releases the shared turn; killing a pup cannot deadlock it.
	await _fresh()
	await _alone()
	_expect(await _until("windup"), "Interrupt test reaches windup")
	pup.sword_hit()
	_expect(pup.hp == 1 and pup._state == "stagger" and pack._attacker == null, "Sword interrupts the windup and releases the pack's attack turn")
	await _frames(45)
	pup._cooldown = 0
	_expect(await _until("pounce"), "A surviving interrupted pup can attack again")
	var award := {"points": 0}
	pup.defeated.connect(func(points: int) -> void: award.points += points)
	buddy.defeated.connect(func(points: int) -> void: award.points += points)
	pup.sword_hit()
	_expect(pack._attacker == null and award.points == 100, "Death releases the current attacker and awards score once")
	buddy.set_physics_process(true)
	buddy.global_position = Vector2(200, 152)
	buddy._cooldown = 0
	var survivor_attacked := false
	for frame in 120:
		await physics_frame
		if buddy._state == "pounce":
			survivor_attacked = true
			break
	_expect(survivor_attacked and buddy._has_focus, "The surviving pup continues pursuing and leaping after its partner is freed")
	buddy.take_damage(2)
	buddy.die()
	_expect(award.points == 200, "Defeating the pack awards exactly two independent scores")


func _leap_and_terrain() -> void:
	await _fresh()
	await _alone()
	_expect(await _until("windup"), "Nearby target triggers a leap windup")
	await _frames(15)
	_expect(pup._state == "windup" and player.hits == 0 and pup.is_on_floor(), "Crouched windup is readable and harmless")
	player.position.x = 160
	_expect(await _until("pounce"), "Windup commits to a leap")
	_expect(pup.direction == 1, "Pup does not turn or home in after the player crosses behind it")
	var launch_x: float = pup.position.x
	var highest := 152.0
	for frame in 24:
		await physics_frame
		highest = minf(highest, pup.position.y)
	_expect(pup.position.x > launch_x + 24 and highest < 145 and pup._state == "recover", "Pounce physically travels forward, rises and lands in recovery")
	_expect(player.hits == 0, "Crossing behind the windup avoids the attack")
	await _fresh()
	await _alone()
	_expect(await _until("pounce"), "Contact test reaches pounce")
	await _frames(28)
	_expect(player.hits == 1, "One leap deals one contact hit across all overlapping physics frames")
	await _frames(10)
	_expect(player.hits == 1, "Recovery overlap cannot cause more contact damage")
	await _fresh(false, 250)
	await _alone()
	pup.set_physics_process(false)
	await _frames()
	_expect(not pup._pounce_safe(), "A pounce is rejected when its full landing would overhang an edge")
	await _fresh()
	await _alone()
	pup.set_physics_process(false)
	var wall := _solid(Rect2(222, 70, 8, 82))
	await _frames()
	_expect(not pup._pounce_safe() and not pup.ready_to_pounce(), "A solid wall blocks the leap path and engagement")
	wall.free()
	var ceiling := _solid(Rect2(184, 116, 88, 8))
	await _frames()
	_expect(not pup._pounce_safe(), "A low ceiling blocks an otherwise supported leap")
	ceiling.free()
	# The pit floor is solid but hazardous; it cannot be selected as a landing.
	var hazard := _solid(Rect2(230, 150, 60, 2))
	hazard.set_meta("spike_pit", true)
	await _frames()
	_expect(not pup._pounce_safe(), "A spike-marked floor is rejected as a leap landing")
	await _fresh()
	await _alone()
	_expect(await _until("windup"), "Pause test reaches windup")
	var time: float = pup._state_time
	var at: Vector2 = pup.position
	paused = true
	await _frames(40)
	_expect(pup._state_time == time and pup.position == at, "Pause freezes pack movement and windup")
	paused = false
	_expect(await _until("pounce"), "Unpausing resumes the pending leap")


func _real_player() -> void:
	await _fresh(true)
	await _alone()
	_expect(await _until("windup"), "Real-player jump test reaches windup")
	await _frames(18)
	Input.action_press("jump")
	Input.action_press("move_left")
	await _frames(34)
	Input.action_release("jump")
	Input.action_release("move_left")
	_expect(player.health == 5 and pup.hp == 2, "A timed normal jump clears the pup's leap without damage to either fighter")
	await _fresh(true)
	await _alone()
	player.position = Vector2(175, 152)
	pup.direction = -1
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	_expect(pup.hp == 2, "Real sword windup cannot damage a pup")
	await _frames(18)
	_expect(pup.hp == 1 and pup.alive and player.health == 5, "One real sword attack removes exactly one pup health and interrupts its attack")
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _frames(18)
	_expect(not is_instance_valid(pup) or not pup.alive, "A second real sword attack defeats the pup")
	await _fresh(true)
	await _alone()
	pup.set_physics_process(false)
	pup._enter("run")
	player.position = Vector2(200, 128)
	player.velocity = Vector2(0, 60)
	await _frames(12)
	_expect(player.health == 4 and pup.hp == 1 and pup.alive, "Landing on a pup preserves the normal mutual one-health collision rule")


func _run() -> void:
	await _pack_behavior()
	await _leap_and_terrain()
	await _real_player()
	paused = false
	for action in ["attack", "duck", "jump", "move_left", "move_right"]:
		Input.action_release(action)
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Cerberus Pup art, two-member pursuit and alternating attacks, windup/commitment/leap/contact/recovery, interruption and survivor scoring, wall/ceiling/ledge/spike safety, pause, real-player jump avoidance, sword attacks, and mutual landing damage.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
