extends "res://scenes/enemies/enemy.gd"

const TEXTURE := preload("res://assets/art/characters/hoplite.png")

var _state := "crouch"
var _state_time := 0.0
var _stun := 0.0
var _thrust_lock := 0.4
var _strike: Area2D


func _ready() -> void:
	points = 150
	max_hp = 2
	body_height = 36.0
	body_half_width = 8.0
	walk_speed = 20.0
	super()
	_strike = Area2D.new()
	_strike.name = "Strike"
	_strike.collision_layer = 0
	_strike.collision_mask = 2
	_strike.monitoring = false
	_strike.monitorable = false
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 8)
	shape_node.shape = shape
	_strike.add_child(shape_node)
	add_child(_strike)
	_show_rise(0)


func _initial_animation() -> String:
	return "rise"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, TEXTURE, "rise", [0, 1, 2], 1.0, false)
	_add_animation(frames, TEXTURE, "march", [3, 4, 5, 6], 6.0, true)
	_add_animation(frames, TEXTURE, "windup", [7], 1.0, true)
	_add_animation(frames, TEXTURE, "thrust", [8], 1.0, true)
	_bind_frames(frames)


func _deals_contact() -> bool:
	return _state != "crouch" and _state != "rise"


func _tick(delta: float) -> void:
	_state_time += delta
	_stun = maxf(_stun - delta, 0.0)
	_strike.monitoring = false
	if _state == "crouch":
		velocity.x = 0.0
		_show_rise(0)
		if _player_close(80.0, 36.0):
			_enter("rise")
	elif _state == "rise":
		velocity.x = 0.0
		var frame := 0
		if _state_time >= 0.2:
			frame = 1
		if _state_time >= 0.4:
			frame = 2
		_show_rise(frame)
		if _state_time >= 0.66:
			_thrust_lock = 0.45
			_enter("march")
	elif _state == "stun":
		velocity.x = 0.0
		_play("windup")
		sprite.modulate = Color(1.45, 1.35, 0.85)
		if _stun <= 0.0:
			_thrust_lock = 0.4
			_enter("march")
	elif _state == "march":
		_patrol(walk_speed)
		_play("march")
		sprite.modulate = Color.WHITE
		_thrust_lock -= delta
		if _thrust_lock <= 0.0 and _player_in_front(42.0):
			_enter("windup")
	elif _state == "windup":
		velocity.x = 0.0
		_play("windup")
		if _state_time >= 0.22:
			_enter("thrust")
	elif _state == "thrust":
		velocity.x = 0.0
		_play("thrust")
		_strike.monitoring = true
		_strike.position = Vector2(direction * 18.0, -24.0)
		for body in _strike.get_overlapping_bodies():
			if body.has_method("hurt"):
				body.hurt(1)
		if _state_time >= 0.18:
			_thrust_lock = 1.15
			_enter("march")


func sword_hit() -> void:
	if not alive or _state == "crouch" or _state == "rise":
		return
	take_damage(1)
	if not alive:
		return
	_stun = 1.0
	_state = "stun"
	_state_time = 0.0


func _show_rise(frame: int) -> void:
	if sprite.animation != "rise":
		sprite.play("rise")
	sprite.pause()
	sprite.frame = frame
	var height := 24.0 + frame * 6.0
	_set_body(body_half_width * 2.0, height, Vector2(0, -height * 0.5))


func _player_in_front(reach: float) -> bool:
	var player := _player()
	if player == null:
		return false
	var dx := (player.global_position.x - global_position.x) * direction
	var dy := absf(player.global_position.y - global_position.y)
	return dx > 4.0 and dx < reach and dy < 28.0


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
