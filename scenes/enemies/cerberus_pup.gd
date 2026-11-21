extends "res://scenes/enemies/enemy.gd"

const ART := preload("res://assets/art/characters/cerberus_pup.png")
const POUNCE_SPEED := 128.0
const POUNCE_VELOCITY := -135.0
const WINDUP_SECONDS := 0.45
const RECOVERY_SECONDS := 0.65

@export var attack_delay := 0.3
var pack: Node
var _state := "run"
var _state_time := 0.0
var _cooldown := 0.0
var _contacted: Dictionary = {}


func _ready() -> void:
	max_hp = 2
	points = 100
	body_height = 22.0
	body_half_width = 14.0
	walk_speed = 54.0
	_cooldown = attack_delay
	super()


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, ART, "idle", [0], 1, true)
	_add_animation(frames, ART, "run", [1, 2, 3, 4], 10, true)
	_add_animation(frames, ART, "windup", [5], 1, true)
	_add_animation(frames, ART, "pounce", [6], 1, true)
	_add_animation(frames, ART, "recover", [7], 1, true)
	_bind_frames(frames)


func _draw() -> void:
	if alive:
		draw_rect(Rect2(-8, -36, 16, 3), Color(0.12, 0.08, 0.08))
		draw_rect(Rect2(-8, -36, 16.0 * hp / max_hp, 3), Color(0.78, 0.2, 0.16))


func _tick(delta: float) -> void:
	_update_focus(144, 48)
	if _has_focus and is_instance_valid(pack):
		pack.share_focus(self)
	_state_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if not is_on_floor() and _state != "pounce":
		velocity.x = 0.0
		if _state == "windup":
			_enter("recover")
		return
	match _state:
		"run":
			if not _has_focus and is_instance_valid(pack):
				velocity.x = direction * walk_speed if _floor_ahead() and not _wall_ahead() else 0.0
			else:
				_move_with_focus(walk_speed, 38.0, delta)
			_keep_pack_spacing()
			_play("run" if absf(velocity.x) > 1 else "idle")
			if ready_to_pounce() and (not is_instance_valid(pack) or pack.request_attack(self)):
				_enter("windup")
		"windup":
			velocity.x = 0
			if _state_time >= _telegraph(WINDUP_SECONDS):
				# Follow the telegraphed direction, even if Theseus crossed behind us.
				_enter("pounce" if _pounce_safe() else "recover")
		"pounce":
			if is_on_floor() and _state_time > 0.08:
				_enter("recover")
			elif is_on_wall():
				velocity.x = 0
		"recover", "stagger":
			velocity.x = 0
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			if _state_time >= _punish(RECOVERY_SECONDS):
				_release_attack()
				_cooldown = _rest(0.9)
				_enter("run")
	sprite.modulate = Color(1.15, 0.92, 0.75) if _state == "windup" else Color.WHITE


func ready_to_pounce() -> bool:
	var player := _player()
	return alive and _state == "run" and is_on_floor() and _cooldown <= 0 and player != null and player.get("health") != 0 and _player_close(64, 12) and _can_see_player() and _pounce_safe()


func _floor_ahead() -> bool:
	var at := global_position + Vector2(direction * (body_half_width + 5), 0)
	return _supported(at)


func _wall_ahead() -> bool:
	var origin := global_position + Vector2(0, -12)
	var ray := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(direction * (body_half_width + 5), 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _supported(at: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(at + Vector2(0, -4), at + Vector2(0, 8), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y < -0.7 and not hit.collider.has_meta("spike_pit")


func _pounce_safe() -> bool:
	var flight := -2.0 * POUNCE_VELOCITY / GRAVITY
	var launch := Vector2(direction * POUNCE_SPEED, POUNCE_VELOCITY)
	var destination := global_position + Vector2(launch.x * flight, 0)
	for edge in [-body_half_width - 2, body_half_width + 2]:
		if not _supported(destination + Vector2(edge, 0)):
			return false
	# Test the body along the arc as well as the landing: walls and low ceilings
	# must not turn a committed pounce into a leap through solid stone.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _body_shape
	query.collision_mask = 1
	var time := 0.04
	while time < flight - 0.04:
		var foot := global_position + launch * time + Vector2(0, 0.5 * GRAVITY * time * time)
		query.transform = Transform2D(0, foot + Vector2(0, -body_height * 0.5))
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
		time += 0.04
	return true


func _keep_pack_spacing() -> void:
	if is_zero_approx(velocity.x) or not is_instance_valid(pack):
		return
	for other in pack.get_children():
		if other == self or not other.alive or absf(other.global_position.y - global_position.y) > 12:
			continue
		var ahead: float = (other.global_position.x - global_position.x) * signf(velocity.x)
		if ahead > 0 and ahead < 36:
			velocity.x = 0


func _enter(next: String) -> void:
	_state = next
	_state_time = 0
	velocity.x = 0
	if next == "pounce":
		_contacted.clear()
		velocity = Vector2(direction * POUNCE_SPEED, POUNCE_VELOCITY)
	_play("recover" if next == "stagger" else next)


func _hurt_overlaps() -> void:
	if _state != "pounce":
		return
	# A cached Area overlap can be a frame behind a jumping player and hit after
	# their feet have already cleared the hound. Query the current body positions.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _body_shape
	query.transform = $CollisionShape2D.global_transform
	query.collision_mask = 2
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body: Node = result.collider
		if not body.is_in_group("player") or not body.has_method("hurt") or not _can_see_player():
			continue
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var our_rect: Rect2 = $CollisionShape2D.global_transform * _body_shape.get_rect()
		var their_rect: Rect2 = collision.global_transform * collision.shape.get_rect()
		var overlap := our_rect.intersection(their_rect)
		# Match the player's mutual collision rule: grazing a corner is harmless.
		if overlap.size.x < 4 or overlap.size.y < 4:
			continue
		var id := body.get_instance_id()
		if not _contacted.has(id):
			_contacted[id] = true
			body.hurt(1)


func sword_hit() -> void:
	if not alive:
		return
	take_damage(1)
	if alive:
		_release_attack()
		_enter("stagger")
		velocity.y = maxf(0, velocity.y)


func _release_attack() -> void:
	if is_instance_valid(pack):
		pack.release_attack(self)


func die() -> void:
	if not alive:
		return
	_release_attack()
	super()
