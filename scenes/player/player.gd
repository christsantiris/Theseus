extends CharacterBody2D

signal health_changed(current: int, maximum: int)

const FRAME_SIZE := Vector2i(72, 56)
const FOOT_ROW := 54
const SPEED := 90.0
const JUMP_VELOCITY := -260.0
const GRAVITY := 900.0
# Match the visible head heights; bird lanes must clear the pose, not just a
# shorter invisible body. Both shapes keep the same feet and horizontal width.
const STAND_SIZE := Vector2(14, 44)
const STAND_CENTER := Vector2(0, -22)
const DUCK_SIZE := Vector2(14, 36)
const DUCK_CENTER := Vector2(0, -18)
const MAX_HEALTH := 5
const HURT_LOCK := 0.5
const ATTACK_HIT_FRAME := 1
const SWING := preload("res://assets/audio/sfx/daviddumaisaudio-sword-slash-and-swing-185432.mp3")
const SWING_AUDIBLE_SECONDS := 0.92
const LAND := preload("res://assets/audio/sfx/u_qqkrn9bn55-jumplanding-398256.mp3")
const LAND_IMPACT_SECONDS := 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _body: CollisionShape2D = $CollisionShape2D

var health := MAX_HEALTH
var _attacking := false
var _swing: AudioStreamPlayer
var _swing_token := 0
var _land: AudioStreamPlayer
var _jumped := false
var _was_airborne := false
var _hurt_lock := 0.0
var _sword: Area2D
var _sword_shape: CollisionShape2D
var _swing_hits := {}
var _ducked := false


func _ready() -> void:
	add_to_group("player")
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
	_sword = Area2D.new()
	_sword.name = "Sword"
	_sword.collision_layer = 0
	_sword.collision_mask = 4 | 16
	_sword.monitoring = false
	_sword.monitorable = false
	_sword_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 14)
	_sword_shape.shape = shape
	_sword.add_child(_sword_shape)
	add_child(_sword)
	var body_shape := RectangleShape2D.new()
	body_shape.size = STAND_SIZE
	_body.shape = body_shape
	_body.position = STAND_CENTER


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if _hurt_lock > 0.0:
		_hurt_lock = maxf(_hurt_lock - delta, 0.0)
		sprite.modulate.a = 0.4 if int(_hurt_lock * 14.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var jumped_this_frame := false
	var ducking := _wants_duck()
	if Input.is_action_just_pressed("jump") and is_on_floor() and not ducking:
		velocity.y = JUMP_VELOCITY
		_jumped = true
		jumped_this_frame = true
		ducking = false
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	if Input.is_action_just_pressed("attack") and not ducking:
		_attacking = true
		_swing_hits.clear()
		if sprite.animation == "attack":
			sprite.stop()
		sprite.play("attack")
		_play_swing()

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		sprite.flip_h = direction < 0.0
	if ducking:
		velocity.x = 0.0
	elif direction != 0.0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
	_set_ducked(ducking)

	_resolve_landing_collision(delta)
	if health <= 0:
		return
	move_and_slide()
	_strike()
	_update_landing(jumped_this_frame)
	_update_animation()


func heal(amount: int) -> bool:
	if health <= 0 or health >= MAX_HEALTH:
		return false
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	return true


func hurt(amount: int) -> void:
	if health <= 0 or _hurt_lock > 0.0:
		return
	health -= amount
	_hurt_lock = HURT_LOCK
	velocity.y = minf(velocity.y, -90.0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()


func _die() -> void:
	health = 0
	_finish_attack()
	set_physics_process(false)
	sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		get_tree().reload_current_scene()
	)


func _resolve_landing_collision(delta: float) -> void:
	if velocity.y <= 0.0 or _hurt_lock > 0.0:
		return
	var player_rect: Rect2 = _body.global_transform * _body.shape.get_rect()
	var foot := player_rect.end.y
	var next_foot := foot + velocity.y * delta
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.alive or not enemy.has_method("take_damage"):
			continue
		var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var enemy_rect: Rect2 = collision.global_transform * collision.shape.get_rect()
		var overlap := minf(player_rect.end.x, enemy_rect.end.x) - maxf(player_rect.position.x, enemy_rect.position.x)
		# Require a genuine crossing of the current head height, not a side graze.
		if overlap <= 2.0 or foot > enemy_rect.position.y + 1.0 or next_foot < enemy_rect.position.y:
			continue
		global_position.y += enemy_rect.position.y - foot - 1.0
		# Hurt supplies the existing recoil and invulnerability window. The enemy
		# loses exactly one HP as well, rather than being defeated outright.
		hurt(1)
		enemy.take_damage(1)
		return


func _strike() -> void:
	if not _attacking:
		return
	if sprite.animation != "attack" or not sprite.is_playing():
		_finish_attack()
		return
	# The middle frame is the extended blade; windup and recovery cannot hit.
	if sprite.frame != ATTACK_HIT_FRAME:
		return
	var facing := -1.0 if sprite.flip_h else 1.0
	_sword_shape.position = Vector2(18.0 * facing, -16.0)
	# Query the blade's current transform, avoiding cached overlaps from a previous
	# frame or facing direction.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _sword_shape.shape
	query.transform = _sword_shape.global_transform
	query.collision_mask = _sword.collision_mask
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var target: Object = result.collider
		var id := target.get_instance_id()
		if _swing_hits.has(id):
			continue
		if target.has_method("sword_hit"):
			_swing_hits[id] = true
			target.sword_hit()
		elif target.has_method("cut"):
			_swing_hits[id] = true
			target.cut()


func _finish_attack() -> void:
	_attacking = false
	_swing_hits.clear()


func _wants_duck() -> bool:
	if _attacking or not is_on_floor():
		return false
	if Input.is_action_pressed("duck"):
		return true
	return _ducked and not _can_stand()


func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(STAND_SIZE.x, STAND_SIZE.y - 2.0)
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + STAND_CENTER + Vector2(0, -1))
	query.collision_mask = collision_mask
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_ducked(ducking: bool) -> void:
	if ducking == _ducked:
		return
	_ducked = ducking
	var shape := _body.shape as RectangleShape2D
	shape.size = DUCK_SIZE if ducking else STAND_SIZE
	_body.position = DUCK_CENTER if ducking else STAND_CENTER


func _update_animation() -> void:
	if _attacking:
		return
	if _wants_duck():
		_play("duck")
	elif not is_on_floor():
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
		_finish_attack()


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
	_add_animation(frames, texture, "duck", [5], 1.0, true)
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
