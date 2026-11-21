extends SceneTree

# Run: godot --headless --path . --script res://tests/player_combat.gd --fixed-fps 60
var failures: Array[String] = []
var _arena: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null


func _fixture(kind: String) -> Dictionary:
	Input.action_release("attack")
	Input.action_release("move_left")
	Input.action_release("move_right")
	if is_instance_valid(_arena):
		_stop_audio(_arena)
		_arena.free()
	_arena = Node2D.new()
	root.add_child(_arena)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(300, 168)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(600, 32)
	collision.shape = shape
	floor_body.add_child(collision)
	_arena.add_child(floor_body)
	var player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(200, 152)
	_arena.add_child(player)
	player.get_node("Camera2D").enabled = false
	var enemy = load("res://scenes/enemies/" + kind + ".tscn").instantiate()
	enemy.position = Vector2(225, 152)
	_arena.add_child(enemy)
	enemy.set_physics_process(false)
	if kind == "hoplite":
		enemy._show_rise(2)
		enemy._enter("march")
	elif kind == "peltast":
		enemy._enter("recover")
	var result := {"player": player, "enemy": enemy, "points": {"total": 0}}
	enemy.defeated.connect(func(points: int) -> void: result.points.total += points)
	await _frames(4)
	return result


func _begin_attack() -> void:
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")


func _run() -> void:
	for kind in ["raider", "peltast", "hoplite"]:
		var setup = await _fixture(kind)
		var player = setup.player
		var enemy = setup.enemy
		Input.action_press("move_right")
		await _frames(40)
		Input.action_release("move_right")
		await _frames(30)
		_expect(enemy.alive and enemy.hp == 2 and setup.points.total == 0, kind + ": walking past cannot kill or damage an enemy")
		var top: float = enemy.get_node("CollisionShape2D").global_position.y - enemy.get_node("CollisionShape2D").shape.size.y * 0.5
		player.position = Vector2(enemy.position.x, top - 2.0)
		player.velocity = Vector2(0, 60)
		await _frames(10)
		_expect(player.health == 4 and enemy.hp == 1 and enemy.alive, kind + ": stomp collision costs both fighters exactly one HP")
		_expect(setup.points.total == 0, kind + ": a full-health enemy survives the collision without awarding points")
		player.position = Vector2(enemy.position.x, top - 2.0)
		player.velocity = Vector2(0, 60)
		await _frames(4)
		_expect(player.health == 4 and enemy.hp == 1, kind + ": invulnerability prevents repeated collision damage to either fighter")
		await _frames(40)
		_expect(enemy.alive and enemy.hp == 1, kind + ": lingering overlap does not drain enemy health")
		player.position = Vector2(enemy.position.x, top - 2.0)
		player.velocity = Vector2(0, 60)
		await _frames(6)
		_expect(player.health == 3 and not enemy.alive, kind + ": a second distinct collision pays another player HP and depletes the final enemy HP")
		_expect(setup.points.total == (150 if kind == "hoplite" else 100), kind + ": collision defeat awards points once")
		setup = await _fixture(kind)
		player = setup.player
		enemy = setup.enemy
		top = enemy.get_node("CollisionShape2D").global_position.y - enemy.get_node("CollisionShape2D").shape.size.y * 0.5
		player.position = Vector2(enemy.position.x - 8.0, top + 6.0)
		player.velocity = Vector2(0, 60)
		await _frames(15)
		_expect(player.health == 4 and enemy.hp == 1 and enemy.alive, kind + ": falling into the body costs both fighters exactly one HP")
		setup = await _fixture(kind)
		enemy = setup.enemy
		await _begin_attack()
		_expect(enemy.hp == 2, kind + ": sword windup cannot deal invisible damage")
		await _frames(18)
		_expect(enemy.hp == 1 and enemy.alive, kind + ": one visible thrust deals one HP across all active physics frames")
		await _frames(90)
		_expect(enemy.hp == 1 and enemy.alive, kind + ": an expired swing cannot keep damaging enemies")
		await _begin_attack()
		await _frames(18)
		_expect(not is_instance_valid(enemy) or not enemy.alive, kind + ": two real sword attacks defeat the enemy")
		_expect(setup.points.total == (150 if kind == "hoplite" else 100), kind + ": sword defeat awards points once")
	var setup = await _fixture("raider")
	await _begin_attack()
	setup.player.sprite.play("idle")
	await _frames(25)
	_expect(not setup.player._attacking and setup.enemy.hp == 2, "Interrupted animation cancels its damage window")
	setup = await _fixture("raider")
	await _begin_attack()
	setup.player.sprite.flip_h = true
	await _frames(18)
	_expect(setup.enemy.hp == 2, "Turning away during windup cannot hit behind the current blade")
	setup.enemy.position.x = 175
	await _frames(4)
	await _begin_attack()
	await _frames(18)
	_expect(setup.enemy.hp == 1, "Left-facing sword query hits the correct side")
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: all three enemy types, passive contact, mutual one-HP jump collisions, collision cooldown, body impacts, visible sword strikes, expired/interrupted swings, facing and scoring.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
