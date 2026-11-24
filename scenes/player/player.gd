extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal speed_boost_changed(seconds_remaining: int)

const Art := preload("res://scenes/player/theseus_art.gd")
const SPEED := 90.0
const SPEED_BOOST_MULTIPLIER := 1.35
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
const ATTACK_HIT_FRAMES := [2, 3]
const SWING := preload("res://assets/audio/sfx/daviddumaisaudio-sword-slash-and-swing-185432.mp3")
const SWING_AUDIBLE_SECONDS := 0.92
const LAND := preload("res://assets/audio/sfx/u_qqkrn9bn55-jumplanding-398256.mp3")
const LAND_IMPACT_SECONDS := 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _body: CollisionShape2D = $CollisionShape2D

var health := MAX_HEALTH
var _attacking := false
var _downward_attack := false
var _attack_animation := "attack"
var _next_ground_swing := false
var _swing: AudioStreamPlayer
var _swing_token := 0
var _land: AudioStreamPlayer
var _jumped := false
# Touch jumps always reach full height. The right thumb has to leave Jump to
# press Sword, so lifting it must not cut the jump short. Keyboard and gamepad
# jumps keep hold-for-height.
var _full_jump := false
var _was_airborne := false
var _hurt_lock := 0.0
var _sword: Area2D
var _sword_shape: CollisionShape2D
var _swing_hits := {}
var _body_hits := {}
var _ducked := false
var _speed_boost_left := 0.0
# Local environment drag; other levels keep the default 1.0.
var _environment_speed_multiplier := 1.0


func _ready() -> void:
	add_to_group("player")
	# Enemies move first. Theseus resolves shared space after their step.
	process_priority = -1
	_build_frames()
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
	if _speed_boost_left > 0.0:
		var before := ceili(_speed_boost_left)
		_speed_boost_left = maxf(0.0, _speed_boost_left - delta)
		if ceili(_speed_boost_left) != before:
			speed_boost_changed.emit(ceili(_speed_boost_left))
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
		_full_jump = _jump_touched()
		jumped_this_frame = true
		ducking = false
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not _full_jump:
		velocity.y *= 0.45

	if Input.is_action_just_pressed("attack") and not ducking:
		_attacking = true
		var airborne := jumped_this_frame or not is_on_floor()
		_downward_attack = airborne and Input.is_action_pressed("duck")
		sprite.speed_scale = 1.0
		_swing_hits.clear()
		if _downward_attack:
			_attack_animation = "down_thrust"
		elif airborne:
			_attack_animation = "air_swing"
		else:
			_attack_animation = "swing" if _next_ground_swing else "attack"
			# Only attacks started on the ground advance the alternating sequence.
			_next_ground_swing = not _next_ground_swing
		if sprite.animation == _attack_animation:
			sprite.stop()
		Art.anchor(sprite, _attack_animation)
		sprite.play(_attack_animation)
		_play_swing()

	var direction := Input.get_axis("move_left", "move_right")
	var speed := movement_speed()
	if direction != 0.0:
		sprite.flip_h = direction < 0.0
	if ducking:
		velocity.x = 0.0
	elif direction != 0.0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
	_set_ducked(ducking)

	move_and_slide()
	_resolve_character_collision()
	if health <= 0:
		return
	_sync_attack_pose()
	_strike()
	_update_landing(jumped_this_frame)
	_update_animation()


func heal(amount: int) -> bool:
	if health <= 0 or health >= MAX_HEALTH:
		return false
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	return true


func movement_speed() -> float:
	return SPEED * (SPEED_BOOST_MULTIPLIER if _speed_boost_left > 0.0 else 1.0) * _environment_speed_multiplier


func set_environment_speed_multiplier(value: float) -> void:
	_environment_speed_multiplier = clampf(value, 0.1, 1.0)


func grant_speed_boost(seconds: float = 6.0) -> bool:
	if health <= 0 or seconds <= 0.0:
		return false
	# Further wine refreshes the timer without stacking speed or duration.
	_speed_boost_left = minf(seconds, 6.0)
	speed_boost_changed.emit(ceili(_speed_boost_left))
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
	_speed_boost_left = 0.0
	speed_boost_changed.emit(0)
	_finish_attack()
	set_physics_process(false)
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0
	Art.anchor(sprite, "death")
	sprite.play("death")
	var tree := get_tree()
	tree.create_timer(0.7).timeout.connect(func() -> void:
		tree.paused = false
		tree.change_scene_to_file("res://scenes/hades/hades.tscn")
	)


func _resolve_character_collision() -> void:
	if health <= 0:
		return
	var touching := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_rect := _enemy_body_rect(enemy)
		if enemy_rect.size == Vector2.ZERO:
			continue
		var player_rect := _body_rect()
		var overlap := player_rect.intersection(enemy_rect)
		if overlap.size.x <= 0.05 or overlap.size.y <= 0.05:
			continue
		var id: int = enemy.get_instance_id()
		var bounce_depth := maxf(8.0, velocity.y * get_physics_process_delta_time() + 1.0)
		var from_above := player_rect.end.y <= enemy_rect.position.y + bounce_depth and velocity.y > 0.0
		var side_press := overlap.size.y >= 8.0 and overlap.size.y > overlap.size.x
		var embedded := overlap.size.x >= 4.0 and overlap.size.y >= 4.0
		var landing := from_above and overlap.size.x >= 4.0
		# A sword can reach an attack area. Falling onto that area still collides.
		var collides: bool = enemy is CharacterBody2D and (side_press or embedded or landing)
		if not collides and (landing or (embedded and from_above)):
			collides = true
		if collides:
			touching[id] = true
			if _trade_contact(enemy, id, from_above):
				_separate_from(enemy_rect, true)
				velocity.y = JUMP_VELOCITY
				_jumped = true
				_was_airborne = true
			else:
				_separate_from(enemy_rect)
		elif enemy is CharacterBody2D:
			_separate_from(enemy_rect)
		if health <= 0:
			return
	# A one-frame gap while Theseus is still pressed against a fighter is the same
	# collision. The hurt hop is remembered until that recovery ends.
	for id in _body_hits:
		if _hurt_lock > 0.0:
			touching[id] = true
			continue
		var previous := instance_from_id(id)
		var previous_rect := _enemy_body_rect(previous)
		if previous_rect.size != Vector2.ZERO and _body_rect().grow(1.5).intersects(previous_rect):
			touching[id] = true
	_body_hits = touching


func _trade_contact(enemy: Object, id: int, from_above: bool) -> bool:
	if _body_hits.has(id) or _hurt_lock > 0.0:
		_body_hits[id] = true
		return false
	_body_hits[id] = true
	if from_above and enemy.has_method("bounce_on") and enemy.bounce_on():
		return true
	hurt(1)
	if is_instance_valid(enemy) and enemy.get("alive") == true:
		enemy.take_damage(1)
	return false


func _separate_from(enemy_rect: Rect2, bouncing: bool = false) -> void:
	var player_rect := _body_rect()
	var overlap := player_rect.intersection(enemy_rect)
	if overlap.size.x <= 0.05 or overlap.size.y <= 0.05:
		return
	# Normal fighters cannot support Theseus. Repeated upward separation during
	# hurt immunity used to cancel gravity and turn their heads into platforms,
	# including when an enemy stood just below a ledge. Satyr bounces explicitly
	# keep the upward separation; the bull's ride uses its real terrain platform.
	var above := player_rect.get_center().y < enemy_rect.get_center().y
	if overlap.size.x <= overlap.size.y or (above and not bouncing):
		var dir := -1.0 if player_rect.get_center().x < enemy_rect.get_center().x else 1.0
		if is_equal_approx(player_rect.get_center().x, enemy_rect.get_center().x):
			dir = -1.0 if velocity.x >= 0.0 else 1.0
		global_position.x += dir * (overlap.size.x + 0.5)
		if velocity.x * dir < 0.0:
			velocity.x = 0.0
	else:
		var dir := -1.0 if player_rect.get_center().y < enemy_rect.get_center().y else 1.0
		global_position.y += dir * (overlap.size.y + 0.5)
		if dir < 0.0 and velocity.y > 0.0:
			velocity.y = 0.0


func _body_rect() -> Rect2:
	return _body.global_transform * _body.shape.get_rect()


func _enemy_body_rect(enemy: Object) -> Rect2:
	if not is_instance_valid(enemy) or enemy.get("alive") != true or not enemy.has_method("take_damage"):
		return Rect2()
	if not enemy is CollisionObject2D or (enemy as CollisionObject2D).collision_layer == 0:
		return Rect2()
	var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.disabled or collision.shape == null:
		return Rect2()
	return collision.global_transform * collision.shape.get_rect()


func _sync_attack_pose() -> void:
	if not _attacking or sprite.animation != _attack_animation:
		return
	var animation := _attack_animation
	if not is_on_floor() and animation in ["attack", "swing"]:
		animation = "air_swing"
	elif is_on_floor() and animation == "air_swing":
		animation = "swing"
	if animation == _attack_animation:
		return
	# Takeoff, ledge exits, and landing change the pose without restarting the
	# strike, its damage window, or the set of enemies already hit.
	var frame := sprite.frame
	var progress := sprite.frame_progress
	_attack_animation = animation
	Art.anchor(sprite, _attack_animation)
	sprite.play(_attack_animation)
	sprite.set_frame_and_progress(frame, progress)


func _strike() -> void:
	if not _attacking:
		return
	if sprite.animation != _attack_animation or not sprite.is_playing():
		_finish_attack()
		return
	# Both extended-blade frames share the original 1/12-second hit window.
	if sprite.frame not in ATTACK_HIT_FRAMES:
		return
	var facing := -1.0 if sprite.flip_h else 1.0
	var blade := _sword_shape.shape as RectangleShape2D
	blade.size = Vector2(8, 12) if _downward_attack else Vector2(26, 14)
	_sword_shape.position = Vector2(10.0 * facing, 6) if _downward_attack else Vector2(18.0 * facing, -16.0)
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
		if target.has_method("attack_target"):
			target = target.attack_target()
		var id := target.get_instance_id()
		if _swing_hits.has(id):
			continue
		if _downward_attack and target.has_method("downward_hit"):
			_swing_hits[id] = true
			target.downward_hit(self)
		elif target.has_method("sword_hit"):
			_swing_hits[id] = true
			target.sword_hit()
		elif target.has_method("cut"):
			_swing_hits[id] = true
			target.cut()


func _jump_touched() -> bool:
	var controls := get_node_or_null("/root/MobileControls")
	return controls != null and controls.enabled and controls.is_touching("jump")


func _finish_attack() -> void:
	_attacking = false
	_downward_attack = false
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
	if _hurt_lock > HURT_LOCK - 1.0 / 6.0 and not _ducked:
		_play("hurt")
	elif _wants_duck():
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
	Art.anchor(sprite, animation_name)
	sprite.speed_scale = (SPEED_BOOST_MULTIPLIER if _speed_boost_left > 0.0 else 1.0) * _environment_speed_multiplier if animation_name == "walk" else 1.0
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func _on_animation_finished() -> void:
	if sprite.animation in ["attack", "swing", "air_swing", "down_thrust"]:
		_finish_attack()
		_update_animation()


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
	Art.configure(sprite)
