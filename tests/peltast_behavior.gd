extends SceneTree

# Run: godot --headless --path . --script res://tests/peltast_behavior.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 10
	var hits := 0

	func hurt(amount: int) -> void:
		health -= amount
		hits += 1


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int) -> void:
	for index in count:
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


func _until(peltast: Node, state: String, limit: int = 100) -> bool:
	for frame in limit:
		await physics_frame
		if peltast._state == state:
			return true
	return false


func _reset_attack(peltast: Node, player: Target) -> void:
	peltast.position = Vector2(200, 152)
	peltast.direction = 1
	peltast._enter("patrol")
	peltast._cooldown = 0.0
	player.position = Vector2(232, 152)


func _run() -> void:
	_solid(Rect2(0, 152, 600, 32))
	var player := Target.new()
	player.position = Vector2(500, 152)
	player.collision_layer = 2
	player.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 36)
	collision.shape = shape
	collision.position.y = -18
	player.add_child(collision)
	root.add_child(player)
	player.add_to_group("player")
	var peltast = load("res://scenes/enemies/peltast.tscn").instantiate()
	peltast.position = Vector2(200, 152)
	peltast.direction = -1
	peltast.patrol_left = 48.0
	peltast.patrol_right = 400.0
	root.add_child(peltast)
	var original_children := root.get_child_count()
	await _frames(200)
	_expect(peltast._state_time == 0.0 and peltast.position.x == 200.0, "Distant Peltast remains dormant without timer attacks")
	player.position = Vector2(340, 152)
	await _frames(40)
	_expect(peltast._state_time > 0.0 and peltast._state == "patrol", "Nearby Peltast patrols without attacking at range")
	_expect(root.get_child_count() == original_children, "Patrolling spawns no projectiles")
	peltast.set_physics_process(false)
	peltast.position = Vector2(200, 152)
	player.position = Vector2(232, 120)
	_expect(not peltast._can_engage(), "No jab against a player on a different terrace")
	player.position = Vector2(232, 152)
	var wall := _solid(Rect2(216, 72, 8, 80))
	await _frames(3)
	_expect(not peltast._can_engage(), "Walls block engagement")
	wall.free()
	await _frames(3)
	_reset_attack(peltast, player)
	peltast.set_physics_process(true)
	_expect(await _until(peltast, "windup"), "Close targets trigger the jab windup")
	var planted_x: float = peltast.position.x
	player.position = peltast.position + Vector2(10, 0)
	await _frames(15)
	_expect(peltast._state == "windup" and player.hits == 0, "Readable windup causes no body-contact damage")
	player.position = peltast.position + Vector2(80, 0)
	_expect(await _until(peltast, "jab"), "Windup advances to the jab")
	_expect(root.get_child_count() == original_children, "Jab never creates a thrown weapon")
	_expect(peltast.javelin_strike.get_parent() == peltast, "Weapon hitbox remains attached to Peltast")
	_expect(await _until(peltast, "recover"), "Jab ends in recovery")
	_expect(absf(peltast.position.x - planted_x) < 0.1 and player.hits == 0, "Jab is stationary and cannot hit a retreating target at range")
	player.position = peltast.position
	await _frames(15)
	_expect(peltast._state == "recover" and player.hits == 0, "Recovery is safe for counterattacking")
	_reset_attack(peltast, player)
	_expect(await _until(peltast, "windup"), "Another jab can begin")
	player.position = peltast.position + Vector2(-12, 0)
	_expect(await _until(peltast, "jab"), "A baited jab still follows through")
	_expect(peltast.direction == 1, "Jab does not turn after the windup")
	_expect(await _until(peltast, "recover"), "Baited jab recovers")
	_expect(player.hits == 0, "Moving behind the windup avoids the strike")
	_reset_attack(peltast, player)
	_expect(await _until(peltast, "windup"), "Jump-defense case begins")
	player.position.y -= 37.0
	_expect(await _until(peltast, "jab"), "Jumped jab still follows through")
	_expect(await _until(peltast, "recover"), "Jumped jab recovers")
	_expect(player.hits == 0, "Existing full-jump height clears the held javelin")
	_reset_attack(peltast, player)
	_expect(await _until(peltast, "windup"), "Hit case begins")
	_expect(await _until(peltast, "jab"), "Hit case reaches active frames")
	_expect(await _until(peltast, "recover"), "Hit case completes")
	_expect(player.hits == 1 and player.health == 9, "Jab deals exactly one damage per target")
	var awarded := {"points": 0}
	peltast.defeated.connect(func(points: int) -> void: awarded.points += points)
	peltast.sword_hit()
	_expect(peltast.alive and peltast.hp == 1, "Sword damage still works during recovery")
	_expect(not peltast.can_be_stomped() and not peltast.stomp(), "Legacy stomp callback cannot automatically defeat Peltast")
	_expect(peltast.alive and peltast.hp == 1, "Legacy stomp callback leaves enemy health unchanged")
	peltast.sword_hit()
	_expect(not peltast.alive and awarded.points == 100, "Second sword hit defeats Peltast and awards its existing score")
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Peltast dormancy, melee range, elevation, walls, windup, stationary held jab, retreat/jump/side-step counters, recovery, single-hit damage, no automatic stomp kills, and score.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
