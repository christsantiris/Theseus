extends SceneTree

class Target:
	extends CharacterBody2D
	var health := 100
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var arena: Node2D
var boss: Node
var player: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count := 3) -> void:
	for tick in count:
		await physics_frame


func _fresh(real_player := false) -> void:
	paused = false
	for action in ["jump", "attack", "move_right", "move_left"]:
		Input.action_release(action)
	if is_instance_valid(arena):
		_stop_audio(arena)
		arena.free()
	arena = Node2D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 32)
	collision.shape = shape
	floor_body.position = Vector2(500, 296)
	floor_body.add_child(collision)
	arena.add_child(floor_body)
	if real_player:
		player = load("res://scenes/player/player.tscn").instantiate()
		player.position = Vector2(360, 280)
		arena.add_child(player)
		player.get_node("Camera2D").enabled = false
	else:
		player = Target.new()
		player.position = Vector2(380, 280)
		player.collision_layer = 2
		player.collision_mask = 1
		var body := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(14, 44)
		body.shape = rectangle
		body.position.y = -22
		player.add_child(body)
		arena.add_child(player)
		player.add_to_group("player")
	boss = load("res://scenes/enemies/minotaur.tscn").instantiate()
	boss.position = Vector2(240, 280)
	boss.patrol_left = 80
	boss.patrol_right = 800
	boss.tuning = load("res://scenes/levels/difficulty.gd").for_level(9, true)
	arena.add_child(boss)
	await _frames()


func _until(state: String, limit := 240) -> bool:
	for tick in limit:
		await physics_frame
		if boss._state == state:
			return true
	return false


func _run() -> void:
	await _fresh()
	_expect(boss.hp == 8, "Final boss gets exactly eight health")
	_expect(await _until("windup"), "Minotaur notices Theseus and telegraphs")
	var locked: int = boss.direction
	var origin: float = boss.position.x
	player.position.x = 120
	await _frames(12)
	_expect(boss.direction == locked and boss.position.x == origin, "Windup holds position and commits facing")
	_expect(await _until("charge"), "Windup becomes charge")
	_expect(boss._body_shape.size.y == 28, "Charge has a jumpable low silhouette")
	_expect(is_equal_approx(boss.sprite.scale.y * (boss.FEET[2] - boss.LOW_POSE_TOP[2]), 29), "Visible charging back matches its jumpable collision height")
	await _frames(8)
	_expect(boss.position.x > origin + 10 and boss.direction == locked, "Charge keeps committed direction after Theseus crosses behind")
	_expect(await _until("headbutt"), "Charge ends with a headbutt")
	player.position = boss.position + Vector2(locked * 28, 0)
	await _frames(18)
	_expect(player.hits == 1, "One headbutt damages once across its entire active window")
	_expect(await _until("recover"), "Headbutt leaves an exposed recovery")
	var health: int = boss.hp
	boss.sword_hit()
	_expect(boss.hp == health - 1 and boss._state == "recover", "Sword counters remove one health without resetting recovery")
	_expect(await _until("backstep"), "Recovery leads to backward retreat")
	origin = boss.position.x
	await _frames(12)
	_expect(boss.position.x < origin and boss.direction == locked, "Backstep moves away while facing the opponent")
	var elapsed: float = boss._state_time
	paused = true
	await _frames(8)
	_expect(boss._state_time == elapsed, "Pause freezes the boss attack cycle")
	paused = false
	_expect(await _until("windup"), "Boss repeats its attack rather than wandering off")
	# When Theseus has crossed behind, retreat reorients before backing away.
	player.position = boss.position + Vector2(-48, 0)
	boss._enter("backstep")
	origin = boss.position.x
	await _frames(8)
	_expect(boss.direction == -1 and boss.position.x > origin, "Retreat faces the player after a successful jump across the boss")
	boss.patrol_right = boss.position.x + 14
	await _frames(4)
	_expect(boss._state == "idle", "Backstep stops at the authored arena boundary")
	var defeats := {"count": 0}
	boss.defeated.connect(func(_points: int) -> void: defeats.count += 1)
	boss.set_physics_process(false)
	while boss.hp > 1:
		boss.sword_hit()
	_expect(boss.alive and defeats.count == 0, "Boss remains alive until all health is removed")
	boss.sword_hit()
	boss.sword_hit()
	_expect(not boss.alive and defeats.count == 1, "Final hit defeats the Minotaur exactly once")
	await _jump_clearance()
	_stop_audio(root)
	OS.delay_msec(150)
	print("PASS: Minotaur windup, committed charge, headbutt hit deduplication, exposed counters, backward retreat, repeat cycle, pause, eight-health defeat, and real-player jump clearance." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _jump_clearance() -> void:
	await _fresh(true)
	player.position = Vector2(350, 280)
	boss._enter("windup")
	# Start the jump as the committed charge begins, then pass over its back.
	_expect(await _until("charge"), "Real-player charge starts")
	await _frames(20)
	var controls := root.get_node("MobileControls")
	if controls.enabled:
		controls._set_pressed("jump", true)
	Input.action_press("jump")
	Input.action_press("move_left")
	for tick in 40:
		await physics_frame
		if tick == 2 and controls.enabled:
			# A touch thumb may leave Jump as soon as takeoff has registered.
			controls._set_pressed("jump", false)
			Input.action_release("jump")
	Input.action_release("jump")
	Input.action_release("move_left")
	_expect(player.health == 5 and player.position.x < boss.position.x - 20, "Timed full jump clears a charge without damage: HP=%d player=%s boss=%s" % [player.health, player.position, boss.position])
	# A real grounded sword attack can reach the exposed boss body.
	boss.set_physics_process(false)
	boss._enter("recover")
	player.position = boss.position + Vector2(-28, 0)
	player.velocity = Vector2.ZERO
	await _frames(4)
	Input.action_press("move_right")
	await _frames(1)
	Input.action_release("move_right")
	var hp_before: int = boss.hp
	Input.action_press("attack")
	await _frames(30)
	Input.action_release("attack")
	_expect(boss.hp == hp_before - 1, "A real sword swing deals exactly one health to the exposed boss")


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
