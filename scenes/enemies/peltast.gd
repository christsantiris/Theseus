extends "res://scenes/enemies/enemy.gd"

const ART_SCALE := 8.0
const TEXTURE := preload("res://assets/art/characters/peltast.png")
const WEAPON := preload("res://scenes/projectiles/thrown_weapon.gd")
const AWARENESS_RANGE := 192.0
const THROW_RANGE := 156.0
const THROW_HEIGHT := 24.0
const JAB_RANGE := 38.0
const WINDUP_SECONDS := 0.5
const JAB_SECONDS := 0.18
const RECOVERY_SECONDS := 0.8
const ATTACK_COOLDOWN := 1.0
const OPEN_COOLDOWN := 0.2

@onready var javelin_strike: Area2D = $JavelinStrike

var _state := "patrol"
var _state_time := 0.0
var _cooldown := OPEN_COOLDOWN
var _ranged := false
var _javelin_thrown := false
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
	_add_animation(frames, TEXTURE, "walk", [0, 1, 2, 3], 8.0, true, ART_SCALE)
	_add_animation(frames, TEXTURE, "windup", [4], 1.0, true, ART_SCALE)
	_add_animation(frames, TEXTURE, "jab", [5], 1.0, true, ART_SCALE)
	_add_animation(frames, TEXTURE, "recover", [6], 1.0, true, ART_SCALE)
	_bind_frames(frames, ART_SCALE)


func _physics_process(delta: float) -> void:
	# Distant patrols wait. A committed attack finishes even if the player retreats.
	if alive and _state == "patrol" and not _has_focus and not _player_close(AWARENESS_RANGE, 96.0):
		velocity = Vector2.ZERO
		return
	super(delta)


func _deals_contact() -> bool:
	return false


func _weapon_name() -> String:
	return "javelin"


func _uses_throw() -> bool:
	return true


func _can_throw() -> bool:
	return _uses_throw() and not _javelin_thrown


func _engage_range() -> float:
	return THROW_RANGE if _can_throw() else JAB_RANGE


func _engage_height() -> float:
	return THROW_HEIGHT if _can_throw() else 12.0


func _windup_seconds() -> float:
	return WINDUP_SECONDS


func _attack_cooldown() -> float:
	return ATTACK_COOLDOWN


func _notice_range() -> float:
	return THROW_RANGE


func _notice_height() -> float:
	return THROW_HEIGHT


func _tick(delta: float) -> void:
	_update_focus(_notice_range(), _notice_height())
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
			_face_player(_engage_height())
			_ranged = _can_throw() and not _player_close(JAB_RANGE, 12.0)
			_enter("windup")
	elif _state == "windup":
		velocity.x = 0.0
		if _state_time >= _telegraph(_windup_seconds()):
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
			_cooldown = _rest(_attack_cooldown())
			_enter("patrol")
	_tint()


func _can_engage() -> bool:
	var player := _player()
	if player == null or player.get("health") == 0:
		return false
	var in_reach := _player_close(JAB_RANGE, 12.0) or _player_close(_engage_range(), _engage_height())
	if not in_reach:
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
	_reset_strike_shape()
	if next == "jab":
		_strike_hits.clear()
		if _ranged:
			_present_ranged_attack()
	if next != "patrol":
		_play(next)


func _reset_strike_shape() -> void:
	var shape := javelin_strike.get_node("CollisionShape2D").shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(24, 8)


func _present_ranged_attack() -> void:
	if _uses_throw():
		_throw_weapon()


func _throw_weapon() -> void:
	if not _can_throw():
		return
	var parent := get_parent()
	if parent == null:
		return
	_javelin_thrown = true
	var weapon := CharacterBody2D.new()
	weapon.set_script(WEAPON)
	parent.add_child(weapon)
	weapon.global_position = global_position + Vector2(direction * 22.0, -26.0)
	weapon.launch(direction, _weapon_name())


func _hurt_javelin_overlaps() -> void:
	if _ranged and _uses_throw():
		return
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
