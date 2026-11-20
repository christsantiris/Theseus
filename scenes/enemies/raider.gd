extends "res://scenes/enemies/enemy.gd"

const TEXTURE := preload("res://assets/art/characters/raider.png")
const FIRE_PATCH := preload("res://scenes/enemies/fire_patch.tscn")

var _state := "patrol"
var _state_time := 0.0
var _cooldown := 0.8
var _flash := 0.0
var _second_fire := false


func _ready() -> void:
	points = 100
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


func _tick(delta: float) -> void:
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	if not is_on_floor():
		velocity.x = 0.0
		_tint()
		return
	if _state == "patrol":
		_patrol(walk_speed)
		_play("walk")
		_cooldown -= delta
		var ready := _cooldown <= 0.0 and (_player_close(110.0) or _state_time > 2.2)
		if ready:
			if _player_close(110.0):
				_face_player(48.0)
			if _can_lunge():
				_enter("windup")
	elif _state == "windup":
		velocity.x = 0.0
		_play("windup")
		if _state_time >= 0.22:
			_second_fire = false
			_enter("lunge")
			_drop_fire()
	elif _state == "lunge":
		velocity.x = direction * 130.0
		_play("lunge")
		_set_body(32.0, 24.0, Vector2(direction * 8.0, -12.0))
		if _state_time >= 0.12 and not _second_fire:
			_second_fire = true
			_drop_fire()
		if _state_time >= 0.24 or not _inside_patrol(4.0):
			_set_body(body_half_width * 2.0, body_height, Vector2(0, -body_height * 0.5))
			_enter("recover")
	elif _state == "recover":
		velocity.x = 0.0
		_play("recover")
		_set_body(body_half_width * 2.0, body_height, Vector2(0, -body_height * 0.5))
		if _state_time >= 0.85:
			_cooldown = 1.25
			_enter("patrol")
	_tint()


func sword_hit() -> void:
	if not alive:
		return
	if _state == "recover":
		die()
	else:
		_flash = 0.08


func _can_lunge() -> bool:
	var dest := global_position.x + direction * 36.0
	return dest > patrol_left + 8.0 and dest < patrol_right - 8.0


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0


func _drop_fire() -> void:
	var fire := FIRE_PATCH.instantiate()
	fire.global_position = global_position + Vector2(direction * 8.0, 0.0)
	fire.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_parent().add_child(fire)


func _tint() -> void:
	if _flash > 0.0:
		sprite.modulate = Color(1.7, 1.7, 1.7)
	elif _state == "recover":
		sprite.modulate = Color(1.25, 1.05, 0.72)
	else:
		sprite.modulate = Color.WHITE
