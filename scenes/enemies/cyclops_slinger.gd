extends "res://scenes/enemies/enemy.gd"

signal boulder_thrown(boulder: CharacterBody2D)

const ART := preload("res://assets/art/characters/cyclops_slinger.png")
const BOULDER := preload("res://scenes/projectiles/boulder.tscn")
const CELL_SIZE := Vector2(80, 80)
const GROUND_ROW := 77.0
const WINDUP_SECONDS := 1.1
const THROW_SECONDS := 0.18
const RELOAD_SECONDS := 1.6
const RECOVERY_SECONDS := 0.4
const ATTACK_COOLDOWN := 0.6
const THROW_RANGE := 176.0
const LAUNCH_OFFSET := Vector2(36, -46)

var _state := "idle"
var _state_time := 0.0
var _cooldown := ATTACK_COOLDOWN
var _flash := 0.0


func _ready() -> void:
	points = 200
	max_hp = 3
	body_height = 56.0
	body_half_width = 17.0
	super()
	sprite.offset = Vector2(0, -(GROUND_ROW - CELL_SIZE.y * 0.5))
	_enter("idle")


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_pose_animation(frames, "idle", [0, 1], 3.0, true)
	_add_pose_animation(frames, "windup", [2, 3], 2.0)
	_add_pose_animation(frames, "throw", [4], 1.0)
	_add_pose_animation(frames, "reload", [5, 6], 1.25)
	_add_pose_animation(frames, "recover", [7], 1.0)
	_bind_frames(frames)


func _add_pose_animation(frames: SpriteFrames, animation_name: String, indices: Array, speed: float, looped: bool = false) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	for index in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = ART
		atlas.region = Rect2(Vector2(index * CELL_SIZE.x, 0), CELL_SIZE)
		frames.add_frame(animation_name, atlas)


func _deals_contact() -> bool:
	return false


func _draw() -> void:
	if not alive:
		return
	# The raised stone extends above the standard soldier atlas's health bar.
	draw_rect(Rect2(-10, -GROUND_ROW - 5, 20, 3), Color(0.12, 0.08, 0.08))
	draw_rect(Rect2(-10, -GROUND_ROW - 5, 20.0 * hp / max_hp, 3), Color(0.78, 0.2, 0.16))


func _tick(delta: float) -> void:
	_update_focus(THROW_RANGE, 64.0)
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
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			_cooldown = maxf(0.0, _cooldown - delta)
			if _cooldown <= 0.0 and _can_engage():
				_face_player(64.0)
				_enter("windup")
		"windup":
			# The direction and launch velocity stay fixed once the windup begins.
			if _state_time >= _telegraph(WINDUP_SECONDS):
				_enter("throw")
		"throw":
			if _state_time >= THROW_SECONDS:
				_enter("reload")
		"reload":
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			if _state_time >= _punish(RELOAD_SECONDS):
				_enter("recover")
		"recover":
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			if _state_time >= _punish(RECOVERY_SECONDS):
				_cooldown = _rest(ATTACK_COOLDOWN)
				_enter("idle")
	_tint()


func _can_engage() -> bool:
	var player := _player()
	if player == null or player.get("health") == 0 or not _player_close(THROW_RANGE, 64.0):
		return false
	if absf(player.global_position.x - global_position.x) < 28.0:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -36), player.global_position + Vector2(0, -24), 1
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func take_damage(amount: int) -> void:
	super(amount)
	if alive:
		_flash = 0.08


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0.0
	if next == "reload":
		_set_body(34.0, 40.0, Vector2(0, -20))
	else:
		_set_body(34.0, 56.0, Vector2(0, -28))
	_play(next)
	if next == "throw":
		_throw_boulder()
	_tint()


func _throw_boulder() -> void:
	var boulder := BOULDER.instantiate() as CharacterBody2D
	boulder.launch(direction)
	get_parent().add_child(boulder)
	boulder.global_position = global_position + Vector2(direction * LAUNCH_OFFSET.x, LAUNCH_OFFSET.y)
	boulder_thrown.emit(boulder)


func _tint() -> void:
	if _flash > 0.0:
		sprite.modulate = Color(1.6, 1.6, 1.6)
	elif _state == "windup":
		sprite.modulate = Color(1.12, 1.02, 0.85)
	else:
		sprite.modulate = Color.WHITE
