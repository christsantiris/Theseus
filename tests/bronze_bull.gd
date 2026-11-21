extends SceneTree

# Run: godot --headless --path . --script res://tests/bronze_bull.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 30
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var arena: Node2D
var bull: Node
var player: Node


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
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)


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
		player.position = Vector2(500, 152)
		arena.add_child(player)
		player.get_node("Camera2D").enabled = false
	else:
		player = Target.new()
		player.position = Vector2(248, 152)
		player.collision_layer = 2
		player.collision_mask = 1
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(14, 44)
		collision.position.y = -22
		collision.shape = shape
		player.add_child(collision)
		arena.add_child(player)
		player.add_to_group("player")
	bull = load("res://scenes/enemies/bronze_bull.tscn").instantiate()
	bull.position = Vector2(200, 152)
	arena.add_child(bull)
	await _frames()


func _until(next: String) -> bool:
	for frame in 160:
		await physics_frame
		if bull._state == next:
			return true
	return false


func _charge() -> void:
	await _fresh()
	var image: Image = bull.ART.get_image()
	_expect(image.get_size() == Vector2i(768, 56), "Bull has eight native sprite cells")
	for index in 8:
		var used := image.get_region(Rect2i(index * 96, 0, 96, 56)).get_used_rect()
		_expect(used.end.y == 53 and used.position.x > 0 and used.end.x < 96, "Bull art remains within its cell and on its foot baseline")
	player.position.x = 600
	await _frames(100)
	_expect(bull._state == "idle" and bull.position.x == 200, "Bull waits rather than charging a distant player")
	player.position.x = 248
	_expect(await _until("windup"), "Nearby player triggers a windup")
	await _frames(25)
	_expect(bull._state == "windup" and player.hits == 0, "Windup is readable and harmless")
	player.position.x = 160
	_expect(await _until("charge"), "Bull follows through after winding up")
	_expect(bull.direction == 1, "Charge cannot turn toward a player who crossed behind it")
	_expect(await _until("recover"), "Charge ends in a recovery window")
	_expect(player.hits == 0, "Crossing behind the windup avoids the charge")
	await _fresh()
	_expect(await _until("charge"), "Damage case reaches charge")
	_expect(await _until("recover"), "Damage case completes charge")
	_expect(player.hits == 1, "A charge deals one contact hit")
	_expect(bull._has_focus, "Bull retains focus after the attack")
	bull.sword_hit()
	_expect(bull.hp == 3 and not bull.can_ride(), "A horizontal sword damages armor without opening the riding platform")
	await _fresh(false, 280)
	player.position.x = 252
	_expect(await _until("charge"), "Bull can charge along a short supported corridor")
	await _frames(80)
	_expect(bull.position.x <= 246 and bull.position.y < 153, "Bull brakes before an unsupported edge")
	await _fresh()
	_solid(Rect2(280, 80, 16, 72))
	player.position.x = 252
	_expect(await _until("charge"), "Wall test reaches charge")
	await _frames(80)
	_expect(bull.position.x <= 246, "Bull brakes before a wall")
	await _fresh(true)
	# Actual held jump, timed against a charging bull approaching from the right.
	player.position = Vector2(200, 152)
	bull.position = Vector2(264, 152)
	bull.direction = -1
	bull._enter("charge")
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(34)
	Input.action_release("jump")
	Input.action_release("move_right")
	_expect(player.health == 5 and bull.hp == 4 and player.position.x > bull.position.x, "Theseus can actually jump over a charging bull without either taking damage")
	# Normal jump height and real inputs must also be enough for a back thrust.
	await _fresh(true)
	player.position = Vector2(200, 152)
	bull.position = Vector2(264, 152)
	bull.direction = -1
	bull._enter("charge")
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(9)
	Input.action_release("move_right")
	Input.action_press("duck")
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	Input.action_release("duck")
	await _frames(16)
	Input.action_release("jump")
	_expect(bull.can_ride() and bull.hp == 3 and player.health == 5 and player.is_on_floor(), "A real normal-height jump and timed downward thrust can stagger and board a charging bull")


func _thrust_and_ride() -> void:
	await _fresh(true)
	# The input starts above the back with enough room for the sword windup.
	player.position = Vector2(190, 106)
	player.velocity = Vector2(0, 0)
	bull.direction = 1
	bull._cooldown = 10
	Input.action_press("duck")
	Input.action_press("attack")
	await _frames(3)
	_expect(player._downward_attack and player.sprite.animation == "down_thrust" and bull.hp == 4, "Airborne Duck + Sword selects a harmless downward windup")
	Input.action_release("attack")
	Input.action_release("duck")
	for frame in 24:
		await physics_frame
		if bull.can_ride() and player.is_on_floor():
			break
	_expect(bull.hp == 3 and bull.can_ride(), "One downward strike damages the back once despite body and back hit areas")
	_expect(player.health == 5 and player.is_on_floor(), "A real downward strike lands Theseus safely on the exposed back")
	_expect(absf(player.position.y - (bull.position.y - 30)) < 2, "Standing feet align with the back platform")
	await _frames(24)
	var start: float = bull.position.x
	var relative: float = player.position.x - bull.position.x
	await _frames(40)
	_expect(absf(bull.position.x - start) > 20, "Staggered bull resumes slow forward motion")
	_expect(player.health == 5 and player.is_on_floor() and absf(player.position.x - bull.position.x - relative) < 2, "The moving back actually carries Theseus without damage or sliding out beneath him")
	var time: float = bull._state_time
	var at: Vector2 = bull.position
	paused = true
	await _frames(20)
	_expect(time == bull._state_time and at == bull.position, "Pause freezes the ride window and platform")
	paused = false
	Input.action_press("jump")
	await _frames(5)
	_expect(player.velocity.y < 0 and not player.is_on_floor(), "Theseus can jump off the moving back")
	Input.action_release("jump")
	player.position.x = 600
	await _frames(180)
	_expect(not bull.can_ride() and bull.platform.collision_layer == 0, "Ride expires and the back stops being a permanent platform")
	_expect(not player._downward_attack and player.sprite.offset.y == -26, "Finishing the thrust restores normal sprite anchoring")
	# Re-arm for a death case, then verify the platform is removed immediately.
	bull.downward_hit(player)
	player.position = bull.position + Vector2(0, -40)
	bull.downward_hit(player)
	_expect(bull.can_ride(), "A later back strike can open another riding window")
	bull.take_damage(10)
	_expect(not bull.alive and not bull.can_ride() and bull.platform.collision_layer == 0, "A defeated bull cannot leave an invisible riding platform")
	await _fresh(true)
	player.position = Vector2(500, 152)
	await _frames()
	Input.action_press("duck")
	Input.action_press("attack")
	await _frames(3)
	_expect(not player._downward_attack and player.sprite.animation == "duck", "Grounded Duck + Sword remains a duck")


func _run() -> void:
	await _charge()
	await _thrust_and_ride()
	paused = false
	for action in ["attack", "duck", "jump", "move_left", "move_right"]:
		Input.action_release(action)
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Bronze Bull art, charge telegraph/commitment/damage, wall/ledge braking, actual jump clearance, downward input/hit deduplication, safe landing, moving-platform carry, dismount, pause, expiration, and death cleanup.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
