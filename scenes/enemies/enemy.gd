extends CharacterBody2D

signal defeated(points: int)

const FRAME_SIZE := Vector2i(72, 56)
const FOOT_ROW := 53
const GRAVITY := 900.0
const FOCUS_RANGE := 224.0
const FOCUS_HEIGHT := 96.0
const Difficulty := preload("res://scenes/levels/difficulty.gd")

@export var points := 100
@export var direction := 1
@export var patrol_left := 0.0
@export var patrol_right := 960.0
@export var walk_speed := 32.0
@export var body_height := 30.0
@export var body_half_width := 8.0
@export var max_hp := 2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact: Area2D = $Contact

## Level difficulty, assigned by the level before the enemy enters the tree.
## Enemies placed elsewhere keep their authored timings.
var tuning: Dictionary = Difficulty.NEUTRAL
var alive := true
var hp := 2
var _body_shape := RectangleShape2D.new()
var _has_focus := false


func _ready() -> void:
	if tuning.elite:
		max_hp += 1
	hp = max_hp
	walk_speed *= tuning.speed
	add_to_group("enemies")
	_body_shape.size = Vector2(body_half_width * 2.0, body_height)
	$CollisionShape2D.shape = _body_shape
	$CollisionShape2D.position = Vector2(0, -body_height * 0.5)
	$Contact/CollisionShape2D.shape = _body_shape
	$Contact/CollisionShape2D.position = $CollisionShape2D.position
	_build_frames()
	# Keep the logical foot anchor for both native sheets and cinematic sheets
	# rendered at a smaller sprite scale.
	sprite.offset = Vector2(0, -(FOOT_ROW - FRAME_SIZE.y * 0.5) / sprite.scale.y)
	sprite.play(_initial_animation())
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	if not is_on_floor() and _uses_gravity():
		velocity.y += GRAVITY * delta
	_tick(delta)
	_face()
	move_and_slide()
	if alive:
		_hurt_overlaps()


func _tick(_delta: float) -> void:
	pass


## Windup before an attack lands, scaled for the level.
func _telegraph(seconds: float) -> float:
	return Difficulty.telegraph(seconds, tuning)


## Recovery after an attack, while the enemy can be countered.
func _punish(seconds: float) -> float:
	return Difficulty.punish(seconds, tuning)


## Pause before the next attack.
func _rest(seconds: float) -> float:
	return Difficulty.rest(seconds, tuning)


func _initial_animation() -> String:
	return "walk"


func _uses_gravity() -> bool:
	return true


func _deals_contact() -> bool:
	return true


func _build_frames() -> void:
	pass


func sword_hit() -> void:
	take_damage(1)


func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = maxi(hp - amount, 0)
	queue_redraw()
	if hp <= 0:
		die()


func _draw() -> void:
	if not alive or max_hp <= 0:
		return
	var width := 16.0
	var y := sprite.offset.y * sprite.scale.y - float(FRAME_SIZE.y) * 0.5 - 4.0
	draw_rect(Rect2(-width * 0.5, y, width, 3), Color(0.12, 0.08, 0.08))
	var filled := width * float(hp) / float(max_hp)
	if filled > 0.0:
		draw_rect(Rect2(-width * 0.5, y, filled, 3), Color(0.78, 0.2, 0.16))


func can_be_stomped() -> bool:
	return false


func stomp() -> bool:
	return false


func die() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	contact.set_deferred("monitoring", false)
	defeated.emit(points)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.16)
	tween.finished.connect(queue_free)


func _face() -> void:
	sprite.flip_h = direction < 0


func _play(animation_name: String) -> void:
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


func _patrol(speed: float) -> void:
	if global_position.x <= patrol_left:
		direction = 1
	elif global_position.x >= patrol_right:
		direction = -1
	elif is_on_floor() and (is_on_wall() or not _floor_ahead()):
		direction *= -1
	velocity.x = direction * speed


func _update_focus(notice_range: float = 96.0, notice_height: float = 48.0) -> void:
	var player := _player()
	if player == null or player.get("health") == 0:
		_has_focus = false
	elif _has_focus:
		# A jump, recovery, or temporary obstruction must not restart a patrol.
		_has_focus = _player_close(FOCUS_RANGE, FOCUS_HEIGHT)
	elif _player_close(notice_range, notice_height) and _can_see_player():
		_has_focus = true


func _can_see_player() -> bool:
	var player := _player()
	if player == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -24),
		player.global_position + Vector2(0, -24), 1
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _move_with_focus(speed: float, stand_off: float, delta: float) -> void:
	if not _has_focus:
		_patrol(speed)
		return
	velocity.x = 0.0
	_face_player(FOCUS_HEIGHT)
	var player := _player()
	if player == null or absf(player.global_position.x - global_position.x) <= stand_off:
		return
	# Patrol endpoints do not reverse a pursuit. Terrain still limits movement;
	# at a wall or unsupported edge, hold position and keep facing Theseus.
	if not _floor_ahead():
		return
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -12),
		global_position + Vector2(direction * (body_half_width + speed * delta + 2.0), -12), 1
	)
	if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		velocity.x = direction * speed


func _play_locomotion(animation_name: String) -> void:
	_play(animation_name)
	if _has_focus and is_zero_approx(velocity.x):
		# Use a planted standing pose while waiting for the next attack.
		sprite.pause()
		sprite.frame = 0


func _floor_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var origin := global_position + Vector2(direction * 12.0, -4.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, 20), 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _inside_patrol(margin: float) -> bool:
	return global_position.x > patrol_left + margin and global_position.x < patrol_right - margin


func _player() -> Node2D:
	var node := get_tree().get_first_node_in_group("player")
	return node as Node2D


func _player_close(reach: float, vertical: float = 48.0) -> bool:
	var player := _player()
	if player == null:
		return false
	return (
		absf(player.global_position.x - global_position.x) <= reach
		and absf(player.global_position.y - global_position.y) <= vertical
	)


func _face_player(vertical: float) -> void:
	var player := _player()
	if player == null:
		return
	if absf(player.global_position.y - global_position.y) > vertical:
		return
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 6.0:
		direction = 1 if dx > 0.0 else -1


func _hurt_overlaps() -> void:
	if not _deals_contact():
		return
	for body in contact.get_overlapping_bodies():
		if body.has_method("hurt"):
			body.hurt(1)


func _set_body(width: float, height: float, center: Vector2) -> void:
	_body_shape.size = Vector2(width, height)
	$CollisionShape2D.position = center
	$Contact/CollisionShape2D.position = center


func _add_animation(
	frames: SpriteFrames,
	texture: Texture2D,
	animation_name: String,
	indices: Array,
	speed: float,
	looped: bool,
	art_scale: float = 1.0
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	for index in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(int(index) * FRAME_SIZE.x * art_scale, 0, FRAME_SIZE.x * art_scale, FRAME_SIZE.y * art_scale)
		frames.add_frame(animation_name, atlas)


func _bind_frames(frames: SpriteFrames, art_scale: float = 1.0) -> void:
	if frames.has_animation("default"):
		frames.remove_animation("default")
	sprite.sprite_frames = frames
	if art_scale > 1.0:
		sprite.scale = Vector2.ONE / art_scale
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
