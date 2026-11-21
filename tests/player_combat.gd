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
		_expect(setup.player.sprite.animation == "attack", kind + ": the first regular attack is a stab")
		_expect(enemy.hp == 2, kind + ": sword windup cannot deal invisible damage")
		await _frames(18)
		_expect(enemy.hp == 1 and enemy.alive, kind + ": one visible thrust deals one HP across all active physics frames")
		await _frames(90)
		_expect(enemy.hp == 1 and enemy.alive, kind + ": an expired swing cannot keep damaging enemies")
		await _begin_attack()
		_expect(setup.player.sprite.animation == "swing" and enemy.hp == 1, kind + ": the next attack swings and its windup is harmless")
		await _frames(18)
		_expect(not is_instance_valid(enemy) or not enemy.alive, kind + ": two real sword attacks defeat the enemy")
		_expect(not setup.player._attacking, kind + ": the swing finishes and closes its damage window")
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
	await _verify_attack_variations()
	await _verify_air_attacks()
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: all three enemy types, passive contact, mutual jump damage, grounded stab/slash alternation, rising/falling and simultaneous-jump slashes, takeoff/ledge transitions, downward variation, interrupted attacks, facing and scoring.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)


func _verify_attack_variations() -> void:
	var setup = await _fixture("raider")
	setup.enemy.position.x = 500
	await _begin_attack()
	_expect(setup.player.sprite.animation == "attack", "A fresh player starts with a stab")
	await _frames(18)
	Input.action_press("jump")
	await _frames(3)
	Input.action_press("duck")
	await _begin_attack()
	_expect(setup.player.sprite.animation == "down_thrust", "Airborne Duck + Sword still selects a downward thrust")
	Input.action_release("jump")
	Input.action_release("duck")
	await _frames(45)
	await _begin_attack()
	_expect(setup.player.sprite.animation == "swing", "A downward thrust does not consume the next regular swing")
	setup.player.sprite.play("idle")
	setup.enemy.position.x = setup.player.position.x + 25
	await _frames(25)
	_expect(not setup.player._attacking and setup.enemy.hp == 2, "An interrupted swing cannot deal invisible damage")
	await _begin_attack()
	_expect(setup.player.sprite.animation == "attack", "The regular sequence returns to a stab after a swing")
	await _frames(18)
	_expect(setup.enemy.hp == 1, "The stab after a swing still deals exactly one HP")


func _verify_air_attacks() -> void:
	var setup = await _fixture("raider")
	var player = setup.player
	setup.enemy.position.x = 500
	# Jump and Sword in the same physics tick must not use the stale floor flag.
	Input.action_press("jump")
	await _begin_attack()
	_expect(not player.is_on_floor() and player.velocity.y < 0 and player.sprite.animation == "swing", "Jump + Sword together selects a rising slash")
	await _frames(18)
	_expect(not player.is_on_floor() and player.velocity.y > 0, "The next attack starts while falling")
	await _begin_attack()
	_expect(player.sprite.animation == "swing", "A second airborne attack is also a slash")
	Input.action_release("jump")
	await _frames(35)
	_expect(player.is_on_floor(), "Air-attack fixture lands before testing grounded attacks")
	await _begin_attack()
	_expect(player.sprite.animation == "attack", "Airborne slashes leave the first grounded stab available")
	await _frames(18)
	Input.action_press("jump")
	await _frames(3)
	await _begin_attack()
	_expect(player.sprite.animation == "swing", "An airborne attack after a grounded stab slashes")
	Input.action_release("jump")
	await _frames(40)
	await _begin_attack()
	_expect(player.is_on_floor() and player.sprite.animation == "swing", "An airborne slash does not consume the next grounded slash")
	await _frames(18)
	await _begin_attack()
	_expect(player.sprite.animation == "attack", "Only grounded attacks advance slash/stab alternation")
	await _frames(18)
	setup = await _fixture("raider")
	player = setup.player
	await _begin_attack()
	await _frames(5)
	_expect(setup.enemy.hp == 1, "The grounded stab hits once before Theseus takes off")
	var phase: float = player.sprite.frame + player.sprite.frame_progress
	Input.action_press("jump")
	await _frames(2)
	_expect(not player.is_on_floor() and player._attacking and player.sprite.animation == "swing", "Jumping during a grounded stab converts it to a slash")
	_expect(player.sprite.frame + player.sprite.frame_progress >= phase, "Converting a stab preserves attack progress instead of restarting its hit window")
	_expect(setup.enemy.hp == 1, "Converting an active stab to a slash cannot hit the same enemy twice")
	Input.action_release("jump")
	await _frames(40)
	# Walking off an edge must convert a stab even without Jump input.
	setup = await _fixture("raider")
	player = setup.player
	setup.enemy.position.x = 300
	player.position = Vector2(595, 152)
	await _frames(4)
	Input.action_press("move_right")
	await _begin_attack()
	_expect(player.sprite.animation == "attack", "A ledge attack begins as a grounded stab")
	await _frames(8)
	_expect(not player.is_on_floor() and player._attacking and player.sprite.animation == "swing", "Leaving a ledge converts the active stab to a falling slash")
	Input.action_release("move_right")
