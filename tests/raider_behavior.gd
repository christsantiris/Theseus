extends SceneTree

# Run: godot --headless --path . --script res://tests/raider_behavior.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 5
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


func _until(raider: Node, state: String, limit: int = 90) -> bool:
	for frame in limit:
		await physics_frame
		if raider._state == state:
			return true
	return false


func _run() -> void:
	_solid(Rect2(0, 152, 600, 32))
	var player := Target.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector2(500, 152)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 36)
	collision.shape = shape
	collision.position.y = -18
	player.add_child(collision)
	root.add_child(player)
	player.add_to_group("player")
	var raider = load("res://scenes/enemies/raider.tscn").instantiate()
	raider.position = Vector2(200, 152)
	raider.direction = -1
	raider.patrol_left = 48.0
	raider.patrol_right = 400.0
	root.add_child(raider)
	await _frames(200)
	_expect(raider._state == "patrol", "No timer-driven attacks against a distant player")
	player.position = raider.position + Vector2(32, -72)
	await _frames(20)
	_expect(raider._state == "patrol", "No attacks against a player on a different elevation")
	raider.set_physics_process(false)
	raider.position = Vector2(200, 152)
	player.position = Vector2(248, 152)
	raider.direction = 1
	var wall := _solid(Rect2(224, 72, 8, 80))
	await _frames(3)
	_expect(not raider._can_engage(), "A wall blocks engagement")
	_expect(not raider._can_lunge(), "A wall blocks the lunge path")
	wall.free()
	await _frames(3)
	raider.position = Vector2(570, 152)
	raider.patrol_right = 800.0
	_expect(not raider._can_lunge(), "Raider will not charge off an unsupported edge")
	raider.position = Vector2(200, 152)
	raider.patrol_right = 400.0
	player.position = Vector2(240, 152)
	raider._cooldown = 0.0
	raider.set_physics_process(true)
	_expect(await _until(raider, "windup"), "Nearby visible player triggers a windup")
	player.position = raider.position + Vector2(10, 0)
	await _frames(12)
	_expect(raider._state == "windup", "Windup remains readable for at least 0.2 seconds")
	_expect(player.hits == 0, "Overlapping during windup causes no contact damage")
	player.position = raider.position + Vector2(-12, 0)
	_expect(await _until(raider, "lunge"), "Windup leads to a sword lunge")
	_expect(raider.direction == 1, "Lunge commits to the telegraphed direction")
	_expect(await _until(raider, "recover"), "Lunge ends in recovery")
	_expect(player.hits == 0, "Stepping behind the windup baits a miss")
	player.position = raider.position
	await _frames(15)
	_expect(player.hits == 0 and raider._state == "recover", "Recovery is a safe counterattack opening")
	raider.position = Vector2(200, 152)
	raider.direction = 1
	raider._enter("patrol")
	raider._cooldown = 0.0
	player.position = Vector2(240, 152)
	_expect(await _until(raider, "windup"), "A second attack can begin")
	_expect(await _until(raider, "lunge"), "Second attack reaches its active phase")
	_expect(await _until(raider, "recover"), "Second attack completes")
	_expect(player.hits == 1 and player.health == 4, "A sword lunge deals exactly one damage, without repeated contact hits")
	_expect(root.get_child_count() == 6, "Attacks spawn no extra hazard nodes")
	var awarded := {"points": 0}
	raider.defeated.connect(func(points: int) -> void: awarded.points += points)
	raider.sword_hit()
	_expect(raider.alive and raider.hp == 1, "First sword hit still damages Raider")
	raider.sword_hit()
	_expect(not raider.alive and awarded.points == 100, "Second sword hit defeats Raider and awards 100 points")
	for child in root.get_node("GameMusic").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Raider proximity, elevation, line of sight, wall/ledge safety, telegraph, committed lunge, single sword hit, recovery, no spawned hazards, damage and score.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
