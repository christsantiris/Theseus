extends SceneTree

# Run: godot --headless --path . --script res://tests/hydra.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 100
	var hits := 0
	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

var failures: Array[String] = []
var arena: Node2D
var hydra: Node
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


func _fresh(real_player: bool = false) -> void:
	paused = false
	for action in ["attack", "duck", "jump", "move_left", "move_right"]:
		Input.action_release(action)
	if is_instance_valid(arena):
		_stop_audio(arena)
		arena.free()
	arena = Node2D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(arena)
	_solid(Rect2(0, 152, 1000, 32))
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
	hydra = load("res://scenes/enemies/hydra.tscn").instantiate()
	hydra.position = Vector2(200, 152)
	arena.add_child(hydra)
	await _frames()


func _until(state: String, limit: int = 180) -> bool:
	for frame in limit:
		await physics_frame
		if hydra._state == state:
			return true
	return false


func _heads_and_completion() -> void:
	await _fresh()
	var art: Image = hydra.Head.ART.get_image()
	_expect(art.get_size() == Vector2i(3072, 1152), "Head atlas has six cinematic poses")
	for index in 6:
		var used := art.get_region(Rect2i((index % 4) * 768, (index / 4) * 576, 768, 576)).get_used_rect()
		_expect(used.size.x > 240 and used.size.y > 420 and used.end.y == 544 and used.position.x > 0 and used.end.x < 768, "Each cinematic head pose keeps the common neck baseline and fits its cell")
	var body: Image = hydra.ART.get_image()
	_expect(body.get_size() == Vector2i(768, 448) and body.get_used_rect().end.y == 424, "Cinematic shared coils retain the original ground row")
	_expect(hydra.sprite.scale == Vector2.ONE / 8.0 and hydra.sprite.offset.y * hydra.sprite.scale.y == -25.0 and hydra._body_shape.size == Vector2(48, 16), "Hydra body keeps its world size, foot anchor, and terrain support")
	for head in hydra.heads:
		_expect(head.sprite.scale == Vector2.ONE / 8.0 and head.get_node("CollisionShape2D").shape.size == Vector2(18, 12), "Hydra head keeps its world size and mouth hit area")
		for index in 6:
			head.set_pose(index, head.base_y)
			var mouth: Vector2 = hydra.Head.MOUTHS[index]
			_expect(head.sprite.to_global(mouth * 8.0).is_equal_approx(head.global_position), "Every cinematic jaw stays registered to its gameplay mouth")
			_expect(head._atlas.region.size.x == 768 and head._atlas.region.size.y == minf(72, 68 - head.base_y) * 8.0, "Neck clipping stays above the floor at every head height")
		head.set_pose(0, head.base_y)
	_expect(get_nodes_in_group("enemies").size() == 3 and not hydra.is_in_group("enemies"), "Only the three independently damageable mouths participate in jump collisions")
	var awards := {"count": 0, "score": 0}
	hydra.defeated.connect(func(points: int) -> void:
		awards.count += 1
		awards.score += points
	)
	for index in 10:
		hydra.sword_hit()
		hydra.take_damage(10)
		hydra.die()
	_expect(hydra.alive and hydra.hp == 6 and hydra.living_heads() == 3 and awards.count == 0, "Body hits and direct death calls cannot bypass defeating every head")
	hydra.heads[0].take_damage(1)
	_expect(hydra.heads[0].hp == 1 and hydra.heads[1].hp == 2 and hydra.heads[2].hp == 2, "Damage belongs to the head that was hit")
	hydra.heads[0].take_damage(1)
	await _frames(15)
	_expect(hydra.alive and hydra.living_heads() == 2 and awards.count == 0, "Severing one head leaves the body and other heads alive without awarding a kill")
	_expect(hydra.heads[0].collision_layer == 0 and hydra.heads[0].get_node("CollisionShape2D").disabled and hydra.heads[0].sprite.modulate.a < 0.01, "A severed head fades out and loses its hit area")
	hydra.heads[0].take_damage(50)
	_expect(hydra.heads[1].hp == 2 and hydra.heads[2].hp == 2, "Further hits on a severed head cannot damage a survivor")
	hydra.heads[1].take_damage(2)
	_expect(hydra.alive and hydra.living_heads() == 1 and awards.count == 0, "The last head must still be defeated")
	await _frames(180)
	_expect(not hydra.heads[0].alive and not hydra.heads[1].alive and hydra.heads[2].hp == 2, "Severed heads do not regenerate or share a survivor's health")
	hydra.heads[2].take_damage(2)
	hydra.heads[2].take_damage(2)
	hydra.die()
	_expect(not hydra.alive and awards.count == 1 and awards.score == 450, "Only the final head awards one Hydra defeat and its score")
	await _frames(15)
	_expect(not is_instance_valid(hydra), "The defeated body and all head nodes clean up together")


func _attack_rotation() -> void:
	await _fresh()
	await _frames(100)
	_expect(hydra._state == "idle" and player.hits == 0, "A distant player cannot trigger periodic bites")
	player.position = Vector2(262, 152)
	var turns: Array[int] = []
	var previous := ""
	for frame in 480:
		await physics_frame
		if hydra._state == "windup" and previous != "windup":
			turns.append(hydra.heads.find(hydra._active_head))
		previous = hydra._state
		if turns.size() == 4:
			break
	_expect(turns == [0, 1, 2, 0], "The three living heads attack one at a time in a repeating rotation: %s" % [turns])
	_expect(hydra._has_focus and hydra.position.distance_to(Vector2(200, 152)) < 1, "The Hydra remains anchored and retains player focus between attacks")
	# Interrupt the selected head; kill it and ensure it is never selected again.
	var chosen: Node = hydra._active_head
	chosen.sword_hit()
	_expect(chosen.hp == 1 and hydra._state == "recover", "A sword hit on the winding-up head interrupts its bite")
	chosen.sword_hit()
	for frame in 340:
		await physics_frame
		_expect(hydra._state != "windup" or hydra._active_head != chosen, "A severed head never re-enters the attack rotation")
	_expect(hydra.living_heads() == 2 and player.hits > 0, "Surviving heads continue attacking and can hit the player")
	await _fresh()
	player.position = Vector2(262, 152)
	_expect(await _until("windup"), "Nearby player triggers an open-jaw windup")
	await _frames(24)
	_expect(hydra._state == "windup" and player.hits == 0, "Bite windup is long enough to react and cannot deal damage")
	player.position.x = 150
	_expect(await _until("strike"), "Hydra follows through with the telegraphed bite")
	_expect(hydra.direction == 1 and hydra._active_head.position.x > 40, "The active head commits to its original direction")
	_expect(await _until("recover"), "Bite retracts into a recovery window")
	_expect(player.hits == 0, "Crossing behind the windup avoids the bite")
	await _fresh()
	player.position = Vector2(262, 152)
	_expect(await _until("strike"), "Damage case reaches bite")
	await _frames(24)
	_expect(player.hits == 1, "A committed bite deals one hit across all active overlap frames")
	await _fresh()
	player.position = Vector2(262, 152)
	_expect(await _until("windup"), "Wall test reaches windup")
	_solid(Rect2(230, 80, 8, 72))
	await _frames(50)
	_expect(player.hits == 0 and hydra._state == "recover", "A wall introduced during windup blocks the head's strike path")
	await _fresh()
	player.position = Vector2(262, 152)
	_expect(await _until("windup"), "Pause test reaches windup")
	var time: float = hydra._state_time
	var at: Vector2 = hydra._active_head.position
	paused = true
	await _frames(50)
	_expect(hydra._state_time == time and hydra._active_head.position == at, "Pause freezes attack timing and head poses")
	paused = false
	_expect(await _until("strike"), "Unpausing resumes the pending bite")


func _swing() -> void:
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")


func _real_combat() -> void:
	await _fresh(true)
	hydra._cooldown = 100
	player.position = Vector2(238, 152)
	# Hydra faces right while Theseus faces back toward the closest low mouth.
	player.sprite.flip_h = true
	await _swing()
	_expect(hydra.hp == 6, "Real sword windup cannot damage heads")
	await _frames(18)
	_expect(hydra.heads[0].hp == 1 and hydra.heads[1].hp == 2 and hydra.heads[2].hp == 2, "A grounded sword removes one health only from the low head it reaches")
	await _swing()
	await _frames(18)
	_expect(hydra.living_heads() == 2 and not hydra.heads[0].alive and hydra.alive, "Two real sword swings sever the low head without defeating the Hydra")
	# The higher mouth remains reachable using an ordinary held jump and sword.
	player.position = Vector2(228, 152)
	player.velocity = Vector2.ZERO
	await _frames(4)
	Input.action_press("jump")
	await _frames(9)
	await _swing()
	await _frames(18)
	Input.action_release("jump")
	_expect(hydra.heads[2].hp < 2 and player.health == 5, "An actual normal jump and sword reaches the high head without touching the body")
	await _frames(20)
	Input.action_press("jump")
	await _frames(9)
	await _swing()
	await _frames(18)
	Input.action_release("jump")
	await _frames(15)
	_expect(not hydra.heads[2].alive and hydra.heads[1].hp == 2, "High-head attacks leave the middle head's health intact")
	# An earlier swing on the next jump reaches the middle mouth on the way up.
	for index in 2:
		await _frames(20)
		Input.action_press("jump")
		await _frames(1)
		await _swing()
		await _frames(18)
		Input.action_release("jump")
	await _frames(15)
	_expect(not is_instance_valid(hydra) or not hydra.alive, "Grounded and jumping sword swings can actually defeat all three heads")
	await _fresh(true)
	hydra._cooldown = 100
	player.position = Vector2(162, 152)
	player.sprite.flip_h = false
	await _frames()
	await _swing()
	await _frames(18)
	_expect(hydra.direction == -1 and hydra.heads[0].hp == 1 and hydra.heads[1].hp == 2, "Mirrored artwork and mouth hit areas stay aligned when approached from the left")
	await _fresh(true)
	player.position = Vector2(262, 152)
	_expect(await _until("windup"), "Real-player defense test reaches windup")
	await _frames(25)
	Input.action_press("jump")
	await _frames(35)
	Input.action_release("jump")
	_expect(player.health == 5 and hydra.hp == 6, "A timed ordinary jump clears a low bite without harming either fighter")
	await _fresh(true)
	hydra._cooldown = 100
	player.position = hydra.heads[2].global_position + Vector2(0, -7)
	player.velocity = Vector2(0, 60)
	await _frames(10)
	_expect(player.health == 4 and hydra.heads[2].hp == 1 and hydra.heads[2].alive and hydra.heads[0].hp == 2, "Landing on a mouth costs one player and one head health, rather than automatically killing it")


func _review() -> void:
	if is_instance_valid(arena):
		_stop_audio(arena)
		arena.free()
	arena = null
	var review = load("res://scenes/reviews/hydra_review.tscn").instantiate()
	root.add_child(review)
	await _frames()
	_expect(get_nodes_in_group("enemies").size() == 3, "The art gallery adds no hidden enemy colliders")
	review._toggle_gallery()
	var time: float = review.hydra._age
	await _frames(20)
	_expect(paused and review.hydra._age == time, "The review gallery pauses the playable Hydra")
	review._toggle_gallery()
	for head in review.hydra.heads:
		head.take_damage(2)
	await _frames(15)
	_expect(not is_instance_valid(review.hydra), "The review scene handles completion without dangling head references")
	_stop_audio(review)
	review.free()


func _run() -> void:
	await _heads_and_completion()
	await _attack_rotation()
	await _real_combat()
	await _review()
	paused = false
	for action in ["attack", "duck", "jump", "move_left", "move_right"]:
		Input.action_release(action)
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Hydra art, independent head health/removal, body immunity, all-head completion and score, surviving-head rotation, telegraph/commitment/bite/recovery, interrupts, walls, pause, actual sword/jump combat and mutual landing damage, review gallery and cleanup.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
