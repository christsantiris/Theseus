extends "res://scenes/enemies/enemy.gd"

const TRIDENT_ART := preload("res://assets/art/characters/merfolk_trident.png")
const BLADE_ART := preload("res://assets/art/characters/merfolk_reefblade.png")
# Offline-measured opaque tail rows in each source cell; no runtime readbacks.
const TRIDENT_FEET := [400, 401, 401, 401, 402, 402, 402, 403]
const BLADE_FEET := [401, 402, 401, 401, 405, 406, 405, 405]
const ACTIVE_SECONDS := 0.18
const LUNGE_SPEED := 100.0
@export var reefblade := false
@onready var weapon: Area2D = $Weapon
var _state := "patrol"
var _state_time := 0.0
var _cooldown := 0.9
var _flash := 0.0
var _strike_hits := {}
var _cell_size := Vector2.ZERO


func _ready() -> void:
	points = 150 if reefblade else (250 if tuning.elite else 125)
	body_height = 36.0 if reefblade else 44.0
	body_half_width = 9.0
	walk_speed = 30.0 if reefblade else 26.0
	max_hp = 2
	super()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 12) if reefblade else Vector2(26, 6)
	$Weapon/CollisionShape2D.shape = shape
	sprite.frame_changed.connect(_anchor)
	_anchor()
	_enter("patrol")


func _build_frames() -> void:
	var art := BLADE_ART if reefblade else TRIDENT_ART
	_cell_size = art.get_size() / Vector2(4, 2)
	var frames := SpriteFrames.new()
	for animation in {"walk": [0, 1, 2, 3], "windup": [4], "strike": [5], "recover": [6], "hurt": [7]}:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 7.0 if animation == "walk" else 1.0)
		frames.set_animation_loop(animation, true)
		var indices: Array = {"walk": [0, 1, 2, 3], "windup": [4], "strike": [5], "recover": [6], "hurt": [7]}[animation]
		for index: int in indices:
			var atlas := AtlasTexture.new()
			atlas.atlas = art
			atlas.region = Rect2(Vector2(index % 4, index / 4) * _cell_size, _cell_size)
			# The held weapon extends into the next cell's empty gutter, not its
			# artwork. Preserve the whole tip and compensate its root below.
			if index == 5:
				atlas.region.size.x += 32
			atlas.filter_clip = true
			frames.add_frame(animation, atlas)
	_bind_frames(frames)
	sprite.scale = Vector2.ONE * (48.0 if reefblade else 56.0) / _cell_size.y
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _anchor() -> void:
	var pose: int = sprite.frame if sprite.animation == "walk" else {"windup": 4, "strike": 5, "recover": 6, "hurt": 7}.get(sprite.animation, 0)
	var feet: Array = BLADE_FEET if reefblade else TRIDENT_FEET
	sprite.offset = Vector2(direction * 16.0 if pose == 5 else 0.0, _cell_size.y * 0.5 - feet[pose])


func _face() -> void:
	super()
	_anchor()


func _deals_contact() -> bool:
	# The player controller handles ordinary body collisions for both fighters.
	return false


func _tick(delta: float) -> void:
	_update_focus()
	_state_time += delta
	_flash = maxf(0.0, _flash - delta)
	if not is_on_floor():
		velocity.x = 0.0
		if _state in ["windup", "strike"]:
			_enter("recover")
		return
	match _state:
		"patrol":
			_move_with_focus(walk_speed, 34.0 if reefblade else 28.0, delta)
			_play_locomotion("walk")
			_cooldown = maxf(0.0, _cooldown - delta)
			if _cooldown <= 0.0 and _can_engage() and (not reefblade or _can_lunge()):
				_enter("windup")
		"windup":
			velocity.x = 0.0
			if _state_time >= _telegraph(0.65 if reefblade else 0.70):
				_enter("strike" if not reefblade or _can_lunge() else "recover")
		"strike":
			if _state_time >= ACTIVE_SECONDS or (reefblade and (is_on_wall() or not _floor_ahead())):
				_enter("recover")
			else:
				velocity.x = direction * LUNGE_SPEED if reefblade else 0.0
				_strike()
		"recover":
			velocity.x = 0.0
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			_play("hurt" if _flash > 0.0 else "recover")
			if _state_time >= _punish(1.05 if reefblade else 1.10):
				_cooldown = _rest(1.25)
				_enter("patrol")
	sprite.modulate = Color(1.5, 1.5, 1.5) if _flash > 0.0 else Color.WHITE
	queue_redraw()


func _can_engage() -> bool:
	var target := _player()
	if target == null or target.get("health") == 0 or not _player_close(48.0 if reefblade else 38.0, 12.0 if reefblade else 1.5):
		return false
	return _can_see_player() and _supported_path(absf(target.global_position.x - global_position.x))


func _can_lunge() -> bool:
	var origin := global_position + Vector2(0, -8)
	var ahead := body_half_width + LUNGE_SPEED * ACTIVE_SECONDS + 2.0
	var space := get_world_2d().direct_space_state
	var wall := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(direction * ahead, 0), 1)
	if not space.intersect_ray(wall).is_empty():
		return false
	return _supported_path(ahead)


func _supported_path(distance: float) -> bool:
	var space := get_world_2d().direct_space_state
	for step in range(4, ceili(distance) + 4, 4):
		var point := global_position + Vector2(direction * step, -4)
		var floor_probe := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, 20), 1)
		if space.intersect_ray(floor_probe).is_empty():
			return false
	return true



func _enter(next: String) -> void:
	_state = next
	_state_time = 0.0
	velocity.x = 0.0
	weapon.position = Vector2(direction * 18.0, -14.0 if reefblade else -41.0)
	if next == "strike":
		_strike_hits.clear()
	if next != "patrol":
		_play(next)


func _strike() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $Weapon/CollisionShape2D.shape
	query.transform = weapon.global_transform
	query.collision_mask = 2
	var space := get_world_2d().direct_space_state
	for hit: Dictionary in space.intersect_shape(query):
		var target: Node2D = hit.collider
		if not target.is_in_group("player") or not target.has_method("hurt") or _strike_hits.has(target.get_instance_id()):
			continue
		# A player moving behind terrain during the windup is still protected.
		var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, weapon.position.y), target.global_position + Vector2(0, weapon.position.y), 1)
		if not space.intersect_ray(wall).is_empty():
			continue
		_strike_hits[target.get_instance_id()] = true
		target.hurt(1)


func sword_hit() -> void:
	if not alive:
		return
	take_damage(1)
	if alive:
		_enter("recover")
		_flash = 0.12


func _draw() -> void:
	super()
	if alive and tuning.elite:
		# A small bronze fin crest distinguishes the captain at gameplay scale.
		var crest := PackedVector2Array([Vector2(-5, -46), Vector2(-5, -52), Vector2(-2, -49), Vector2(0, -54), Vector2(2, -49), Vector2(5, -52), Vector2(5, -46)])
		draw_colored_polygon(crest, Color("d4ad50"))
		draw_polyline(crest, Color("6c4c21"), 0.5, true)
