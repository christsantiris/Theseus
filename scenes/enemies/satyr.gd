extends "res://scenes/enemies/enemy.gd"

const ART := preload("res://assets/art/characters/satyr.png")
const WINE := preload("res://scenes/pickups/stolen_wine.tscn")
const HOP_VELOCITY := -260.0
const CHARGE_SPEED := 130.0
const WINDUP_SECONDS := 0.35
const CHARGE_SECONDS := 0.18
const RECOVERY_SECONDS := 0.55

@export_range(0.0, 1.0) var wine_drop_chance := 0.35
@onready var horns: Area2D = $Horns
var _state := "idle"
var _state_time := 0.0
var _cooldown := 0.6
var _hop_wait := 0.45
var _planned_hop := Vector2.ZERO
var _strike_hits: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	points = 125
	max_hp = 2
	body_height = 36.0
	body_half_width = 9.0
	_rng.randomize()
	super()
	_enter("idle")


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, ART, "idle", [0, 1], 4.0, true)
	for pose in [["hop_ready", 2], ["jump_rise", 3], ["jump_fall", 4], ["windup", 5], ["charge", 6], ["recover", 7]]:
		_add_animation(frames, ART, pose[0], [pose[1]], 1.0, true)
	_bind_frames(frames)


func _deals_contact() -> bool:
	return false


func _tick(delta: float) -> void:
	_update_focus(112.0, 64.0)
	_state_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if not is_on_floor() and _state != "hop":
		velocity.x = 0.0
		if _state in ["windup", "charge", "hop_ready"]:
			_enter("recover")
		return
	match _state:
		"idle":
			velocity.x = 0.0
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			elif global_position.x <= patrol_left + 16:
				direction = 1
			elif global_position.x >= patrol_right - 16:
				direction = -1
			_hop_wait -= delta
			if _cooldown <= 0.0 and _can_charge():
				_enter("windup")
			elif _hop_wait <= 0.0 and (not _has_focus or not _player_close(34.0, 96.0)):
				if _plan_hop():
					_enter("hop_ready")
				else:
					_hop_wait = 0.3
		"hop_ready":
			if _state_time >= 0.18:
				_enter("hop")
				velocity = _planned_hop
		"hop":
			if is_on_floor() and _state_time > 0.1:
				_enter("recover")
			else:
				if is_on_wall():
					velocity.x = 0.0
				_play("jump_rise" if velocity.y < 0 else "jump_fall")
		"windup":
			if _state_time >= _telegraph(WINDUP_SECONDS):
				_enter("charge" if _charge_safe() else "recover")
		"charge":
			if _state_time >= CHARGE_SECONDS or not _charge_safe():
				_enter("recover")
			else:
				velocity.x = direction * CHARGE_SPEED
				_hurt_horn_overlaps()
		"recover", "stagger":
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			if _state_time >= _punish(RECOVERY_SECONDS):
				_hop_wait = _rng.randf_range(0.3, 0.8)
				_enter("idle")


func _landing_at(x: float) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(x, global_position.y - 34), Vector2(x, global_position.y + 40), 1
	)
	return get_world_2d().direct_space_state.intersect_ray(query)


func _plan_hop() -> bool:
	var lengths := [24.0, 40.0, 56.0]
	var first := _rng.randi_range(0, lengths.size() - 1)
	for index in lengths.size():
		var distance: float = lengths[(first + index) % lengths.size()]
		var target_x := global_position.x + direction * distance
		if not _has_focus and (target_x < patrol_left or target_x > patrol_right):
			continue
		var landing := _landing_at(target_x)
		if landing.is_empty() or landing.normal.y > -0.7 or landing.collider.has_meta("spike_pit"):
			continue
		var dy: float = landing.position.y - global_position.y
		if dy < -32.0 or dy > 32.0:
			continue
		var supported := true
		for edge_x in [target_x - 10, target_x + 10]:
			var edge := _landing_at(edge_x)
			if edge.is_empty() or absf(edge.position.y - landing.position.y) > 1.0:
				supported = false
		if not supported:
			continue
		var flight := (-HOP_VELOCITY + sqrt(HOP_VELOCITY * HOP_VELOCITY + 2 * GRAVITY * dy)) / GRAVITY
		var speed := direction * distance / flight
		if absf(speed) > 112.0 or not _hop_path_clear(Vector2(speed, HOP_VELOCITY), flight):
			continue
		_planned_hop = Vector2(speed, HOP_VELOCITY)
		return true
	return false


func _hop_path_clear(launch: Vector2, flight: float) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _body_shape
	query.collision_mask = 1
	var time := 0.06
	while time < flight - 0.06:
		var foot := global_position + launch * time + Vector2(0, GRAVITY * time * time * 0.5)
		query.transform = Transform2D(0, foot + Vector2(0, -18))
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
		time += 0.06
	return true


func _can_charge() -> bool:
	var player := _player()
	return player != null and player.get("health") != 0 and _player_close(52.0, 12.0) and _can_see_player() and _charge_safe()


func _charge_safe() -> bool:
	var ahead := global_position + Vector2(direction * 38, 0)
	var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -12), ahead + Vector2(0, -12), 1)
	var floor_probe := PhysicsRayQueryParameters2D.create(ahead + Vector2(0, -4), ahead + Vector2(0, 8), 1)
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(wall).is_empty() and not space.intersect_ray(floor_probe).is_empty()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0.0
	horns.position = Vector2(direction * 18, -24)
	if next == "charge":
		_cooldown = _rest(1.1)
		_strike_hits.clear()
		_set_body(26, 28, Vector2(direction * 5, -14))
		velocity.x = direction * CHARGE_SPEED
	else:
		_set_body(18, 36, Vector2(0, -18))
	_play("jump_rise" if next == "hop" else "recover" if next == "stagger" else next)


func _hurt_horn_overlaps() -> void:
	for body in horns.get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("hurt") or not _can_see_player():
			continue
		var id := body.get_instance_id()
		if not _strike_hits.has(id):
			_strike_hits[id] = true
			body.hurt(1)


func bounce_on() -> bool:
	if not alive:
		return false
	take_damage(1)
	if alive:
		_enter("stagger")
		velocity.y = maxf(0.0, velocity.y)
	return true


func die() -> void:
	if not alive:
		return
	if _rng.randf() < wine_drop_chance:
		var wine = WINE.instantiate()
		get_parent().add_child(wine)
		wine.global_position = global_position
	super()
