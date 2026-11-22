extends "res://scenes/enemies/enemy.gd"

const ART := preload("res://assets/art/characters/bronze_bull.png")
const ART_SCALE := 8.0
const CHARGE_SPEED := 180.0
const RIDE_SPEED := 40.0
const WINDUP_SECONDS := 0.8
const CHARGE_SECONDS := 0.75
const RIDE_SECONDS := 2.2

@onready var platform: AnimatableBody2D = $BackPlatform
var _state := "idle"
var _state_time := 0.0
var _cooldown := 0.7
var _contacted: Dictionary = {}


func _ready() -> void:
	max_hp = 4
	points = 250
	body_height = 24.0
	body_half_width = 22.0
	super()
	add_collision_exception_with(platform)
	_enter("idle")


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_bull_animation(frames, "idle", [0], 1)
	_add_bull_animation(frames, "windup", [1], 1)
	_add_bull_animation(frames, "charge", [2, 3, 4, 5], 12)
	_add_bull_animation(frames, "stagger", [6], 1)
	_add_bull_animation(frames, "ride", [2, 3, 4, 5], 4)
	_add_bull_animation(frames, "recover", [7], 1)
	_bind_frames(frames, ART_SCALE)


func _add_bull_animation(frames: SpriteFrames, animation_name: String, indices: Array, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, true)
	for index in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = ART
		atlas.region = Rect2(index * 96 * ART_SCALE, 0, 96 * ART_SCALE, 56 * ART_SCALE)
		frames.add_frame(animation_name, atlas)


func _draw() -> void:
	if alive:
		# Keep the bull's health clear of the rider's body.
		var y := -84.0 if can_ride() else -44.0
		draw_rect(Rect2(-14, y, 28, 3), Color(0.12, 0.08, 0.08))
		draw_rect(Rect2(-14, y, 28.0 * hp / max_hp, 3), Color(0.78, 0.2, 0.16))


func _tick(delta: float) -> void:
	_update_focus(176, 48)
	_state_time += delta
	velocity.x = 0
	if not is_on_floor():
		if _state in ["windup", "charge"]:
			_enter("recover")
		return
	match _state:
		"idle":
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			_cooldown = maxf(0, _cooldown - delta)
			if _cooldown <= 0 and _can_engage():
				_enter("windup")
		"windup":
			if _state_time >= _telegraph(WINDUP_SECONDS):
				_enter("charge" if _corridor_clear(40) else "recover")
		"charge":
			if _state_time >= CHARGE_SECONDS or not _corridor_clear(36):
				_enter("recover")
			else:
				velocity.x = direction * CHARGE_SPEED
		"stagger":
			if _state_time >= 0.3:
				_enter("ride")
		"ride":
			if _state_time >= RIDE_SECONDS:
				_enter("recover")
			elif _corridor_clear(32):
				velocity.x = direction * RIDE_SPEED
		"recover":
			if _state_time >= _punish(0.5):
				_cooldown = _rest(1.0)
				_enter("idle")
	# A cool sheen marks the exposed back; amber warns that the ride is ending.
	sprite.modulate = Color(1.15, 0.88, 0.65) if _state == "recover" else Color(0.85, 1.1, 1.15) if can_ride() else Color.WHITE


func _can_engage() -> bool:
	var player := _player()
	return player != null and player.get("health") != 0 and _player_close(176, 12) and _can_see_player() and _corridor_clear(40)


func _corridor_clear(distance: float) -> bool:
	var ahead := global_position + Vector2(direction * distance, 0)
	var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -12), ahead + Vector2(0, -12), 1)
	var floor_probe := PhysicsRayQueryParameters2D.create(ahead + Vector2(0, -4), ahead + Vector2(0, 4), 1)
	wall.exclude = [platform.get_rid()]
	floor_probe.exclude = [platform.get_rid()]
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(wall).is_empty() and not space.intersect_ray(floor_probe).is_empty()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0
	if next == "charge":
		_contacted.clear()
	if next == "idle":
		platform.collision_layer = 0
		$BackPlatform/CollisionShape2D.set_deferred("disabled", true)
	_play(next)
	queue_redraw()


func can_ride() -> bool:
	return alive and platform.collision_layer == 1


func downward_hit(attacker: Node2D) -> void:
	var offset := attacker.global_position - global_position
	if not alive or absf(offset.x) > 20 or offset.y > -24:
		return
	take_damage(1)
	if alive and not can_ride():
		_enter("stagger")
		platform.collision_layer = 1
		$BackPlatform/CollisionShape2D.set_deferred("disabled", false)


func _hurt_overlaps() -> void:
	if _state != "charge" or can_ride():
		return
	for body in contact.get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("hurt"):
			continue
		var id := body.get_instance_id()
		if not _contacted.has(id):
			_contacted[id] = true
			body.hurt(1)


func die() -> void:
	platform.collision_layer = 0
	$BackPlatform/CollisionShape2D.set_deferred("disabled", true)
	super()
