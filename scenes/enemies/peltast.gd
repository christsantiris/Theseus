extends "res://scenes/enemies/enemy.gd"

const TEXTURE := preload("res://assets/art/characters/peltast.png")
const AWARENESS_RANGE := 192.0
const JAB_RANGE := 38.0
const WINDUP_SECONDS := 0.5
const JAB_SECONDS := 0.18
const RECOVERY_SECONDS := 0.8
const ATTACK_COOLDOWN := 1.0

@onready var javelin_strike: Area2D = $JavelinStrike

var _state := "patrol"
var _state_time := 0.0
var _cooldown := 0.9
var _flash := 0.0
var _strike_hits: Dictionary = {}


func _ready() -> void:
	points = 100
	max_hp = 2
	body_height = 36.0
	body_half_width = 8.0
	walk_speed = 26.0
	super()


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, TEXTURE, "walk", [0, 1, 2, 3], 8.0, true)
	_add_animation(frames, TEXTURE, "windup", [4], 1.0, true)
	_add_animation(frames, TEXTURE, "jab", [5], 1.0, true)
	_add_animation(frames, TEXTURE, "recover", [6], 1.0, true)
	_bind_frames(frames)


func _physics_process(delta: float) -> void:
	# Distant patrols wait. A committed attack finishes even if the player retreats.
	if alive and _state == "patrol" and not _has_focus and not _player_close(AWARENESS_RANGE, 96.0):
		velocity = Vector2.ZERO
		return
	super(delta)


func _deals_contact() -> bool:
	return false


func _tick(delta: float) -> void:
	_update_focus()
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	if not is_on_floor():
		velocity.x = 0.0
		if _state == "jab":
			_enter("recover")
		_tint()
		return
	if _state == "patrol":
		_move_with_focus(walk_speed, 28.0, delta)
		_play_locomotion("walk")
		_cooldown = maxf(0.0, _cooldown - delta)
		if _cooldown <= 0.0 and _can_engage():
			_face_player(12.0)
			_enter("windup")
	elif _state == "windup":
		velocity.x = 0.0
		if _state_time >= _telegraph(WINDUP_SECONDS):
			_enter("jab")
	elif _state == "jab":
		velocity.x = 0.0
		if _state_time >= JAB_SECONDS:
			_enter("recover")
		else:
			_hurt_javelin_overlaps()
	elif _state == "recover":
		velocity.x = 0.0
		if _has_focus:
			_face_player(FOCUS_HEIGHT)
		if _state_time >= _punish(RECOVERY_SECONDS):
			_cooldown = _rest(ATTACK_COOLDOWN)
			_enter("patrol")
	_tint()


func _can_engage() -> bool:
	var player := _player()
	if player == null or player.get("health") == 0 or not _player_close(JAB_RANGE, 12.0):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -26),
		player.global_position + Vector2(0, -26),
		1
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0.0
	javelin_strike.position = Vector2(direction * 22.0, -26.0)
	if next == "jab":
		_strike_hits.clear()
	if next != "patrol":
		_play(next)


func _hurt_javelin_overlaps() -> void:
	for body in javelin_strike.get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("hurt"):
			continue
		var id := body.get_instance_id()
		if not _strike_hits.has(id):
			_strike_hits[id] = true
			body.hurt(1)


func sword_hit() -> void:
	if not alive:
		return
	take_damage(1)
	if alive:
		_flash = 0.08


func _tint() -> void:
	if _flash > 0.0:
		sprite.modulate = Color(1.7, 1.7, 1.7)
	elif _state == "windup":
		sprite.modulate = Color(0.85, 1.15, 1.1)
	else:
		sprite.modulate = Color.WHITE
