extends "res://scenes/enemies/enemy.gd"

const TEXTURE := preload("res://assets/art/characters/peltast.png")
const GLOB := preload("res://scenes/enemies/poison_glob.tscn")

var _state := "patrol"
var _state_time := 0.0
var _cooldown := 0.9
var _thrown := false


func _ready() -> void:
	points = 100
	body_height = 36.0
	body_half_width = 8.0
	walk_speed = 26.0
	super()


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, TEXTURE, "walk", [0, 1, 2, 3], 8.0, true)
	_add_animation(frames, TEXTURE, "cock", [4], 1.0, true)
	_add_animation(frames, TEXTURE, "throw", [5], 1.0, true)
	_add_animation(frames, TEXTURE, "follow", [6], 1.0, true)
	_bind_frames(frames)


func _tick(delta: float) -> void:
	_state_time += delta
	if not is_on_floor():
		velocity.x = 0.0
		return
	if _state == "patrol":
		_patrol(walk_speed)
		_play("walk")
		sprite.modulate = Color.WHITE
		_cooldown -= delta
		if _cooldown <= 0.0:
			_face_player(80.0)
			_thrown = false
			_enter("throw")
	elif _state == "throw":
		velocity.x = 0.0
		sprite.modulate = Color(0.82, 1.2, 1.15)
		if _state_time < 0.18:
			_play("cock")
		elif not _thrown:
			_play("throw")
			_spawn_glob()
			_thrown = true
		else:
			_play("follow")
		if _state_time >= 0.5:
			_cooldown = 1.35
			_enter("patrol")


func can_be_stomped() -> bool:
	return alive


func stomp() -> bool:
	if _state == "throw":
		die()
	return true


func sword_hit() -> void:
	if not alive:
		return
	if _state == "throw":
		die()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0


func _spawn_glob() -> void:
	var glob := GLOB.instantiate()
	glob.global_position = global_position + Vector2(direction * 16.0, -28.0)
	glob.velocity = Vector2(direction * 120.0, -170.0)
	glob.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_parent().add_child(glob)
