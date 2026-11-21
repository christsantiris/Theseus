extends SceneTree

# Run: godot --headless --path . --script res://tests/spike_pits.gd --fixed-fps 60
const Mountain := preload("res://scenes/levels/level_4_layout.gd")
var failures: Array[String] = []
var level: Node
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


func _place(at: Vector2) -> void:
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)
	player.position = at
	player.velocity = Vector2.ZERO
	player.health = 5
	player._hurt_lock = 0.0
	for pit in get_nodes_in_group("spike_pits"):
		pit._cooldowns.clear()
	await _frames()
	_expect(player.health == 5, "Moving clear of a pit cannot take damage from a cached overlap")


func _cross(definition: Dictionary, facing: int) -> void:
	var near_x: float = definition.position.x - 12 if facing == 1 else definition.position.x + definition.width + 12
	await _place(Vector2(near_x, definition.position.y))
	var action := "move_right" if facing == 1 else "move_left"
	Input.action_press(action)
	Input.action_press("jump")
	await _frames(44)
	Input.action_release(action)
	Input.action_release("jump")
	var cleared: bool = player.position.x > definition.position.x + definition.width if facing == 1 else player.position.x < definition.position.x
	_expect(cleared and player.health == 5 and player.position.y <= definition.position.y + 1, "%s clears in direction %d using normal speed and a held jump" % [definition.name, facing])


func _fall_and_escape(definition: Dictionary, facing: int) -> void:
	await _place(definition.position + Vector2(definition.width * 0.5, 0))
	await _frames(40)
	_expect(player.health == 4, String(definition.name) + " removes one bar after a fall")
	_expect(player.is_on_floor() and absf(player.position.y - definition.position.y - definition.depth) < 1, String(definition.name) + " has a real recessed floor and does not eject the player")
	Input.action_press("move_right" if facing == 1 else "move_left")
	Input.action_press("jump")
	await _frames(40)
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump")
	var escaped: bool = player.position.x > definition.position.x + definition.width if facing == 1 else player.position.x < definition.position.x
	_expect(escaped and player.position.y <= definition.position.y + 1 and player.health == 4, "%s is escapable to side %d without a second unavoidable hit" % [definition.name, facing])


func _run() -> void:
	root.get_node("LevelRun").begin_level(4)
	level = load("res://scenes/levels/level_4.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	for definition: Dictionary in Mountain.FLASKS:
		level.get_node(definition.name).free()
	await _frames()
	_expect(get_nodes_in_group("spike_pits").size() == 4, "Four spike pits spawn")
	for definition: Dictionary in Mountain.PITS:
		await _cross(definition, 1)
		await _cross(definition, -1)
		await _fall_and_escape(definition, 1)
		await _fall_and_escape(definition, -1)
	var first: Dictionary = Mountain.PITS[0]
	await _place(first.position + Vector2(-20, 0))
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_expect(player.health == 4 and player.position.y > first.position.y + 20, "Walking into the pit really falls in; damage recoil cannot automatically climb out")
	var pit := level.get_node(first.name)
	var before: Dictionary = pit._cooldowns.duplicate()
	level._set_paused(true)
	await _frames(100)
	_expect(player.health == 4 and pit._cooldowns == before, "Pause freezes pit damage and recovery timing")
	level._set_paused(false)
	await _frames(90)
	_expect(player.health == 3, "Remaining on the spikes eventually costs another bar without per-frame damage")
	# Every required jump also works with the optional wine boost.
	var wide: Dictionary = Mountain.PITS[1]
	await _place(wide.position + Vector2(-12, 0))
	player.grant_speed_boost()
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(40)
	Input.action_release("move_right")
	Input.action_release("jump")
	_expect(player.health == 5 and player.position.x > wide.position.x + wide.width, "A speed boost does not prevent clearing a wide pit (health %d, position %s, velocity %s)" % [player.health, player.position, player.velocity])
	# Satyr's supported-ground planner must reject spike beds as landing targets.
	var satyr = load("res://scenes/enemies/satyr.tscn").instantiate()
	satyr.position = Vector2(wide.position.x + 4, wide.position.y)
	satyr.patrol_left = wide.position.x - 64
	satyr.patrol_right = wide.position.x + 128
	satyr.direction = 1
	level.add_child(satyr)
	satyr.set_physics_process(false)
	satyr._has_focus = true
	var bed: Dictionary = satyr._landing_at(wide.position.x + wide.width * 0.5)
	_expect(not bed.is_empty() and bed.collider.has_meta("spike_pit"), "Spike beds are marked as unsafe for hopping enemies")
	if satyr._plan_hop():
		var launch: Vector2 = satyr._planned_hop
		var flight: float = -2.0 * launch.y / satyr.GRAVITY
		var destination: Dictionary = satyr._landing_at(satyr.position.x + launch.x * flight)
		_expect(not destination.is_empty() and not destination.collider.has_meta("spike_pit"), "A Satyr can choose safe ground instead of hopping into spikes")
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: all four pits jump both ways at normal speed, falls deal one bar, escape both ways, no automatic ejection, pause, repeat damage grace, wine boost and Satyr landing safety.")
	quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
