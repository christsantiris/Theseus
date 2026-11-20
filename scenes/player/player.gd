extends CharacterBody2D

const FRAME_SIZE := Vector2i(72, 56)
const FOOT_ROW := 54
const SPEED := 90.0
const JUMP_VELOCITY := -260.0
const GRAVITY := 900.0
const SWING := preload("res://assets/audio/sfx/daviddumaisaudio-sword-slash-and-swing-185432.mp3")
const SWING_AUDIBLE_SECONDS := 0.92
const LAND := preload("res://assets/audio/sfx/u_qqkrn9bn55-jumplanding-398256.mp3")
const LAND_IMPACT_SECONDS := 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _attacking := false
var _swing: AudioStreamPlayer
var _swing_token := 0
var _land: AudioStreamPlayer
var _jumped := false
var _was_airborne := false


func _ready() -> void:
	_build_frames()
	sprite.offset = Vector2(0, -(FOOT_ROW - FRAME_SIZE.y * 0.5))
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
	_swing = AudioStreamPlayer.new()
	_swing.name = "Swing"
	_swing.bus = "SFX"
	_swing.stream = SWING
	add_child(_swing)
	_land = AudioStreamPlayer.new()
	_land.name = "Land"
	_land.bus = "SFX"
	_land.stream = LAND
	add_child(_land)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var jumped_this_frame := false
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_jumped = true
		jumped_this_frame = true
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	if Input.is_action_just_pressed("attack"):
		_attacking = true
		if sprite.animation == "attack":
			sprite.stop()
		sprite.play("attack")
		_play_swing()

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)

	move_and_slide()
	_update_landing(jumped_this_frame)
	_update_animation()


func _update_animation() -> void:
	if _attacking:
		return
	if not is_on_floor():
		_play("jump_rise" if velocity.y < 0.0 else "jump_fall")
	elif absf(velocity.x) > 5.0:
		_play("walk")
	else:
		_play("idle")


func _update_landing(jumped_this_frame: bool) -> void:
	if not is_on_floor():
		_was_airborne = true
		return
	if _was_airborne and _jumped:
		_play_land()
	elif not jumped_this_frame:
		_jumped = false
	_was_airborne = false


func _play_land() -> void:
	_jumped = false
	_land.stop()
	_land.play(LAND_IMPACT_SECONDS)


func _play(animation_name: String) -> void:
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		_attacking = false


func _play_swing() -> void:
	_swing_token += 1
	var token := _swing_token
	_swing.stop()
	_swing.play()
	get_tree().create_timer(SWING_AUDIBLE_SECONDS).timeout.connect(func() -> void:
		if token == _swing_token and is_instance_valid(_swing):
			_swing.stop()
	)


func _build_frames() -> void:
	var texture := preload("res://assets/art/characters/theseus.png")
	var frames := SpriteFrames.new()
	_add_animation(frames, texture, "idle", [0], 1.0, true)
	_add_animation(frames, texture, "walk", [1, 2, 3, 4], 8.0, true)
	_add_animation(frames, texture, "jump_rise", [5], 1.0, true)
	_add_animation(frames, texture, "jump_fall", [6], 1.0, true)
	_add_animation(frames, texture, "attack", [7, 8, 9], 12.0, false)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	sprite.sprite_frames = frames


func _add_animation(
	frames: SpriteFrames,
	texture: Texture2D,
	animation_name: String,
	indices: Array,
	speed: float,
	looped: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	for index in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(int(index) * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(animation_name, atlas)
