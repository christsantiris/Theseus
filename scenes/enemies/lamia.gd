extends "res://scenes/enemies/enemy.gd"

const ART := preload("res://assets/art/characters/lamia.png")
const ART_SCALE := 8.0
const CELL_SIZE := Vector2(96, 56)
const ANCHOR_X := 28.0
const REACH := 68.0
const WINDUP_SECONDS := 0.6
const STRIKE_SECONDS := 0.2
const RETREAT_SECONDS := 0.18
const GUARD_SECONDS := 0.65
const RECOVERY_SECONDS := 0.7
const ATTACK_COOLDOWN := 0.8

@onready var strike: Area2D = $Strike

var _state := "idle"
var _state_time := 0.0
var _cooldown := 0.6
var _flash := 0.0
var _strike_hits: Dictionary = {}


func _ready() -> void:
	points = 150
	max_hp = 2
	body_height = 42.0
	body_half_width = 13.0
	super()
	# Wider cells let the uncoiling attack reach forward while its tail stays put.
	sprite.offset.x = (CELL_SIZE.x * 0.5 - ANCHOR_X) * ART_SCALE
	_enter("idle")


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_pose_animation(frames, "idle", [0, 1], 4.0)
	_add_pose_animation(frames, "windup", [2])
	_add_pose_animation(frames, "strike", [3])
	_add_pose_animation(frames, "retreat", [4])
	_add_pose_animation(frames, "guard", [5, 6], 6.0)
	_add_pose_animation(frames, "recover", [7])
	_bind_frames(frames, ART_SCALE)


func _add_pose_animation(frames: SpriteFrames, animation_name: String, indices: Array, speed: float = 1.0) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, true)
	for index in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = ART
		atlas.region = Rect2(Vector2(index * CELL_SIZE.x, 0) * ART_SCALE, CELL_SIZE * ART_SCALE)
		frames.add_frame(animation_name, atlas)


func _face() -> void:
	super()
	# Mirror around the tail anchor, rather than around the wide atlas cell.
	sprite.offset.x = direction * (CELL_SIZE.x * 0.5 - ANCHOR_X) * ART_SCALE


func _deals_contact() -> bool:
	return false


func _tick(delta: float) -> void:
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	velocity.x = 0.0
	if not is_on_floor():
		if _state != "idle":
			_enter("idle")
		_tint()
		return
	match _state:
		"idle":
			_cooldown = maxf(0.0, _cooldown - delta)
			if _cooldown <= 0.0 and _can_engage():
				_face_player(16.0)
				_enter("windup")
		"windup":
			if _state_time >= _telegraph(WINDUP_SECONDS):
				_enter("strike")
		"strike":
			if _state_time >= STRIKE_SECONDS:
				_enter("retreat")
			else:
				_hurt_strike_overlaps()
		"retreat":
			if _state_time >= RETREAT_SECONDS:
				_enter("guard")
		"guard":
			if _state_time >= GUARD_SECONDS:
				_enter("recover")
		"recover":
			if _state_time >= _punish(RECOVERY_SECONDS):
				_cooldown = _rest(ATTACK_COOLDOWN)
				_enter("idle")
	_tint()


func _can_engage() -> bool:
	var player := _player()
	return (
		player != null and player.get("health") != 0
		and _player_close(REACH, 16.0) and _clear_path(player)
	)


func _clear_path(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -24),
		target.global_position + Vector2(0, -24), 1
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func is_protected() -> bool:
	return _state == "retreat" or _state == "guard"


func take_damage(amount: int) -> void:
	if not alive or is_protected():
		return
	super(amount)
	if alive:
		_flash = 0.08


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0.0
	strike.position = Vector2(direction * 36.0, -24.0)
	match next:
		"strike":
			_strike_hits.clear()
			# Keep terrain support under the anchored tail. The reaching hands
			# use Strike, so extending across a ledge cannot move the body.
			_set_body(30.0, 38.0, Vector2(0, -19))
		"retreat":
			_set_body(30.0, 40.0, Vector2(0, -20))
		"guard":
			_set_body(34.0, 32.0, Vector2(0, -16))
		_:
			_set_body(26.0, 42.0, Vector2(0, -21))
	_play(next)
	_tint()


func _hurt_strike_overlaps() -> void:
	for body in strike.get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("hurt") or not _clear_path(body):
			continue
		var id := body.get_instance_id()
		if not _strike_hits.has(id):
			_strike_hits[id] = true
			body.hurt(1)


func _tint() -> void:
	if _flash > 0.0:
		sprite.modulate = Color(1.6, 1.6, 1.6)
	elif is_protected():
		sprite.modulate = Color(0.72, 0.92, 1.12)
	elif _state == "windup":
		sprite.modulate = Color(1.15, 0.98, 0.82)
	else:
		sprite.modulate = Color.WHITE
