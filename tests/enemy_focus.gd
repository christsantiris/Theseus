extends SceneTree

# Run: godot --headless --path . --script res://tests/enemy_focus.gd --fixed-fps 60
class Target:
	extends CharacterBody2D
	var health := 1000
	var hits := 0

	func hurt(amount: int) -> void:
		health -= amount
		hits += 1

const TYPES := ["raider", "spartoi", "peltast", "telchine", "hoplite"]
var failures: Array[String] = []
var player: Target
var enemy: Node
var floor_body: StaticBody2D


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for frame in count:
		await physics_frame


func _solid(rectangle: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rectangle.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	node.shape = shape
	body.add_child(node)
	root.add_child(body)
	return body


func _setup(kind: String, enemy_x: float = 200, player_x: float = 248, floor_width: float = 700) -> void:
	for old in [enemy, player, floor_body]:
		if is_instance_valid(old):
			old.free()
	floor_body = _solid(Rect2(0, 152, floor_width, 32))
	player = Target.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector2(player_x, 152)
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 44)
	shape_node.shape = shape
	shape_node.position.y = -22
	player.add_child(shape_node)
	root.add_child(player)
	player.add_to_group("player")
	enemy = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
	enemy.position = Vector2(enemy_x, 152)
	enemy.direction = -1
	enemy.patrol_left = enemy_x - 16
	enemy.patrol_right = enemy_x + 16
	root.add_child(enemy)
	await _frames()


func _mobile_state(kind: String) -> String:
	return "march" if kind == "hoplite" else "patrol"


func _active_state(kind: String) -> String:
	if kind == "hoplite":
		return "thrust"
	return "lunge" if kind in ["raider", "spartoi"] else "jab"


func _battle(kind: String) -> void:
	await _setup(kind)
	var attacks := 0
	var previous := ""
	var turned_away := false
	var walked_away := false
	var ever_focused := false
	for frame in 420:
		await physics_frame
		var current: String = enemy._state
		var dx: float = player.position.x - enemy.position.x
		ever_focused = ever_focused or enemy._has_focus
		if current == _active_state(kind) and previous != current:
			attacks += 1
		# The first frame of recovery still belongs to the completed strike;
		# subsequent recovery and locomotion must track the live target.
		if current == _mobile_state(kind) or (current == "recover" and previous == current):
			if absf(dx) > 6:
				turned_away = turned_away or enemy.direction * dx < 0
			walked_away = walked_away or enemy.velocity.x * dx < -0.1
		previous = current
	_expect(ever_focused and enemy._has_focus, kind + " retains focus through the fight")
	_expect(attacks >= 2 and player.hits >= 2, "%s attacks repeatedly instead of leaving after one hit (%d attacks, %d hits, state %s, x %.1f)" % [kind, attacks, player.hits, enemy._state, enemy.position.x])
	_expect(player.hits <= attacks, kind + " deals at most one weapon hit per attack")
	_expect(not turned_away and not walked_away, kind + " keeps facing and moving toward Theseus between attacks")
	_expect(enemy.position.x > enemy.patrol_right, kind + " can pursue and attack beyond its old patrol endpoint")
	# Passing behind a committed strike remains a counter; the soldier must
	# reacquire the new side after the attack rather than resume wandering.
	player.position.x = enemy.position.x - enemy.direction * 64
	var tracked_new_side := false
	for frame in 130:
		await physics_frame
		var dx: float = player.position.x - enemy.position.x
		if enemy._state == _mobile_state(kind) and absf(dx) > 6:
			_expect(enemy.direction * dx > 0 and enemy.velocity.x * dx >= 0, kind + " turns toward the player after a side switch")
			tracked_new_side = true
			break
	_expect(tracked_new_side, kind + " resumes focused movement after the committed attack")
	player.position = enemy.position + Vector2(20, -37)
	await _frames(8)
	_expect(enemy._has_focus, kind + " does not forget a jumping player")
	player.position = enemy.position + Vector2(160, 0)
	await _frames()
	_expect(enemy._has_focus, kind + " retains a target beyond initial notice range")
	player.position = enemy.position + Vector2(300, 0)
	await _frames()
	_expect(not enemy._has_focus, kind + " releases a player who escapes the encounter")


func _obstacles(kind: String) -> void:
	await _setup(kind, 340, 420, 360)
	if kind != "hoplite":
		enemy._cooldown = 30.0
	await _frames(180)
	_expect(enemy._has_focus and enemy.direction == 1, kind + " keeps watching Theseus at an unsupported edge")
	_expect(enemy.is_on_floor() and enemy.position.x + enemy.body_half_width < 360 and is_zero_approx(enemy.velocity.x), kind + " stops safely at the edge without reversing")
	await _setup(kind, 200, 280)
	if kind != "hoplite":
		enemy._cooldown = 30.0
	_expect(enemy._has_focus, kind + " notices an unobstructed player")
	var wall := _solid(Rect2(232, 72, 8, 80))
	await _frames(180)
	_expect(enemy._has_focus and enemy.direction == 1 and enemy.position.x <= 224 and is_zero_approx(enemy.velocity.x), kind + " holds focus and position at a wall")
	_expect(player.hits == 0, kind + " cannot attack through the wall")
	player.health = 0
	await _frames()
	_expect(not enemy._has_focus, kind + " releases a dead player")
	wall.free()
	# A blocked target must not be acquired before the enemy has ever seen it.
	await _setup(kind, 200, 400)
	wall = _solid(Rect2(232, 72, 8, 80))
	player.position.x = 280
	await _frames(12)
	_expect(not enemy._has_focus, kind + " cannot acquire focus through a wall")
	wall.free()


func _run() -> void:
	for kind in TYPES:
		await _battle(kind)
		await _obstacles(kind)
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Raider, Spartoi, Peltast, Telchine and Hoplite repeat attacks, persistent facing/pursuit beyond patrols, side switches, jump retention, escape/death release, line of sight and wall/ledge holding.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
