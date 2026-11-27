extends "res://scenes/enemies/enemy.gd"

const ART := preload("res://assets/art/characters/minotaur.png")
const FEET := [403, 404, 403, 404, 413, 415, 412, 415]
const LOW_POSE_TOP := {2: 133, 3: 113, 4: 109}
const POSES := {"idle": [0], "windup": [1], "charge": [2, 3], "headbutt": [4], "recover": [5], "backstep": [6, 7]}
const CHARGE_SPEED := 126.0
const WINDUP := 1.15
const RECOVERY := 1.45
const RETURN_WINDUP := 1.0
var _state := "idle"
var _state_time := 0.0
var _cooldown := 0.65
var _flash := 0.0
var _hits := {}
var _cell := Vector2.ZERO
var _charges_left := 1


func _ready() -> void:
	# The campaign gate's elite bonus brings this boss to eight health.
	max_hp = 7
	points = 1500
	body_height = 46
	body_half_width = 13
	super()
	sprite.frame_changed.connect(_anchor)
	_enter("idle")


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	_cell = ART.get_size() / Vector2(4, 2)
	var frames := SpriteFrames.new()
	for animation: String in POSES:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 10.0 if animation == "charge" else 6.0)
		for pose: int in POSES[animation]:
			var atlas := AtlasTexture.new()
			atlas.atlas = ART
			atlas.region = Rect2(Vector2(pose % 4, pose / 4) * _cell, _cell)
			atlas.filter_clip = true
			frames.add_frame(animation, atlas)
	_bind_frames(frames)
	sprite.scale = Vector2.ONE * 0.13
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _anchor() -> void:
	var pose: int = POSES.get(sprite.animation, [0])[sprite.frame]
	# Keep the visible lowered back as jumpable as its collision body. These
	# offline alpha bounds avoid texture readbacks and preserve a planted hoof.
	var scale_factor := 29.0 / float(FEET[pose] - LOW_POSE_TOP[pose]) if LOW_POSE_TOP.has(pose) else 0.13
	sprite.scale = Vector2(0.13, scale_factor)
	sprite.offset = Vector2(0, _cell.y * 0.5 - FEET[pose])


func _face() -> void:
	super()
	_anchor()


func _deals_contact() -> bool:
	return false # Player body contacts already exchange one health each.


func _tick(delta: float) -> void:
	_update_focus(192, 64)
	_state_time += delta
	_flash = maxf(0, _flash - delta)
	velocity.x = 0
	if not is_on_floor():
		return
	match _state:
		"idle":
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			_cooldown = maxf(0, _cooldown - delta)
			if _has_focus and _cooldown <= 0:
				_enter("windup")
		"windup":
			if _state_time >= _telegraph(WINDUP):
				_enter("charge")
		"return_windup":
			if _state_time >= _telegraph(RETURN_WINDUP):
				_enter("charge")
		"charge":
			var target := _player()
			var close_ahead: bool = target != null and (target.global_position.x - global_position.x) * direction >= 0 and _player_close(34, 12)
			if _state_time >= 1.1 or close_ahead or not _clear(direction, 18):
				_enter("headbutt")
			else:
				velocity.x = direction * CHARGE_SPEED
		"headbutt":
			if _state_time >= 0.10 and _state_time < 0.25:
				_horn_strike()
			if _state_time >= 0.35:
				_charges_left -= 1
				if _charges_left > 0:
					_enter("return_windup")
				else:
					_enter("recover")
		"recover":
			if _state_time >= _punish(RECOVERY):
				_enter("backstep")
		"backstep":
			# Back away while still facing Theseus; never reverse into a patrol.
			if _state_time >= _rest(0.9) or not _clear(-direction, 18):
				_cooldown = _rest(0.45)
				_enter("idle")
			else:
				velocity.x = -direction * 38.0 * tuning.speed
	sprite.modulate = Color(1.45, 1.3, 1.1) if _flash > 0 else Color.WHITE
	queue_redraw()


func _clear(facing: int, distance: float) -> bool:
	var x := global_position.x + facing * distance
	if x < patrol_left or x > patrol_right:
		return false
	var space := get_world_2d().direct_space_state
	var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -12), Vector2(x, global_position.y - 12), 1)
	var floor_probe := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - 4), Vector2(x, global_position.y + 12), 1)
	return space.intersect_ray(wall).is_empty() and not space.intersect_ray(floor_probe).is_empty()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0
	velocity.x = 0
	if next == "windup":
		_charges_left = 2 if hp * 2 <= max_hp else 1
	if next in ["windup", "return_windup", "backstep"]:
		_face_player(FOCUS_HEIGHT)
	if next == "headbutt":
		_hits.clear()
	# Lowered horns and torso have a genuinely jumpable collision silhouette.
	var height := 28.0 if next in ["charge", "headbutt"] else 46.0
	_set_body(26, height, Vector2(0, -height * 0.5))
	_play("windup" if next == "return_windup" else next)
	_anchor()


func _horn_strike() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 14)
	query.shape = shape
	query.transform = Transform2D(0, global_position + Vector2(direction * 24, -17))
	query.collision_mask = 2
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node2D = hit.collider
		if not target.is_in_group("player") or not target.has_method("hurt") or _hits.has(target.get_instance_id()):
			continue
		var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -17), target.global_position + Vector2(0, -17), 1)
		if get_world_2d().direct_space_state.intersect_ray(wall).is_empty():
			_hits[target.get_instance_id()] = true
			target.hurt(1)


func sword_hit() -> void:
	if alive:
		take_damage(1)
		_flash = 0.12


func _draw() -> void:
	if not alive:
		return
	draw_rect(Rect2(-24, -62, 48, 4), Color("241b1b"))
	draw_rect(Rect2(-24, -62, 48.0 * hp / max_hp, 4), Color("c34729"))
	if _state in ["windup", "return_windup"]:
		var double_charge := _state == "return_windup" or _charges_left > 1
		var cue := Color("ff9168") if double_charge else Color("ffc369")
		draw_line(Vector2(direction * 18, -4), Vector2(direction * 38, -4), cue, 1.5)
		if double_charge:
			draw_line(Vector2(direction * 18, -8), Vector2(direction * 38, -8), cue, 1.5)
