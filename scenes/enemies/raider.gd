extends "res://scenes/enemies/enemy.gd"

const TEXTURE := preload("res://assets/art/characters/raider.png")
const ENGAGE_RANGE := 64.0
const WINDUP_SECONDS := 0.45
const LUNGE_SECONDS := 0.22
const LUNGE_SPEED := 120.0
const RECOVERY_SECONDS := 0.85
const ATTACK_COOLDOWN := 1.25

@onready var sword_strike: Area2D = $SwordStrike

var _state := "patrol"
var _state_time := 0.0
var _cooldown := 0.8
var _flash := 0.0
var _strike_hits: Dictionary = {}


func _ready() -> void:
	points = 100
	max_hp = 2
	body_height = 36.0
	body_half_width = 8.0
	walk_speed = 32.0
	super()


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, TEXTURE, "walk", [0, 1, 2, 3], 8.0, true)
	_add_animation(frames, TEXTURE, "windup", [4], 1.0, true)
	_add_animation(frames, TEXTURE, "lunge", [5], 1.0, true)
	_add_animation(frames, TEXTURE, "recover", [6], 1.0, true)
	_bind_frames(frames)


func _deals_contact() -> bool:
	# Only the sword deals damage during a lunge, including when bodies overlap.
	return false


func _tick(delta: float) -> void:
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	if not is_on_floor():
		velocity.x = 0.0
		if _state == "lunge":
			_enter("recover")
		_tint()
		return
	if _state == "patrol":
		_patrol(walk_speed)
		_play("walk")
		_cooldown = maxf(_cooldown - delta, 0.0)
		if _cooldown <= 0.0 and _can_engage():
			_face_player(24.0)
			if _can_lunge():
				_enter("windup")
	elif _state == "windup":
		velocity.x = 0.0
		if _state_time >= WINDUP_SECONDS:
			# Commit to the telegraphed direction; stepping past him causes a miss.
			if _can_lunge():
				_enter("lunge")
			else:
				_enter("recover")
	elif _state == "lunge":
		if _state_time >= LUNGE_SECONDS or is_on_wall() or not _inside_patrol(4.0) or not _floor_ahead():
			_enter("recover")
		else:
			velocity.x = direction * LUNGE_SPEED
			_hurt_sword_overlaps()
	elif _state == "recover":
		velocity.x = 0.0
		if _state_time >= RECOVERY_SECONDS:
			_cooldown = ATTACK_COOLDOWN
			_enter("patrol")
	_tint()


func sword_hit() -> void:
	if not alive:
		return
	take_damage(1)
	if alive:
		_flash = 0.08


func _can_engage() -> bool:
	var player := _player()
	if player == null or player.get("health") == 0 or not _player_close(ENGAGE_RANGE, 24.0):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -20),
		player.global_position + Vector2(0, -20),
		1
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _can_lunge() -> bool:
	# Patrol limits constrain the body origin; terrain probes include its leading edge.
	var destination_x := global_position.x + direction * LUNGE_SPEED * LUNGE_SECONDS
	var leading_x := destination_x + direction * 24.0
	if destination_x <= patrol_left + 8.0 or destination_x >= patrol_right - 8.0:
		return false
	var space := get_world_2d().direct_space_state
	var wall := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -12),
		Vector2(leading_x, global_position.y - 12),
		1
	)
	if not space.intersect_ray(wall).is_empty():
		return false
	var floor_probe := PhysicsRayQueryParameters2D.create(
		Vector2(leading_x, global_position.y - 4),
		Vector2(leading_x, global_position.y + 16),
		1
	)
	return not space.intersect_ray(floor_probe).is_empty()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0.0
	sword_strike.position = Vector2(direction * 18.0, -20.0)
	if next == "lunge":
		_strike_hits.clear()
		_set_body(32.0, 24.0, Vector2(direction * 8.0, -12.0))
		velocity.x = direction * LUNGE_SPEED
		_play("lunge")
	else:
		_set_body(body_half_width * 2.0, body_height, Vector2(0, -body_height * 0.5))
		if next == "windup":
			_play("windup")
		elif next == "recover":
			_play("recover")


func _hurt_sword_overlaps() -> void:
	for body in sword_strike.get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("hurt"):
			continue
		var id := body.get_instance_id()
		if not _strike_hits.has(id):
			_strike_hits[id] = true
			body.hurt(1)


func _tint() -> void:
	if _flash > 0.0:
		sprite.modulate = Color(1.7, 1.7, 1.7)
	elif _state == "windup":
		sprite.modulate = Color(1.15, 0.95, 0.8)
	elif _state == "recover":
		sprite.modulate = Color(1.25, 1.05, 0.72)
	else:
		sprite.modulate = Color.WHITE
