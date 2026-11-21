extends "res://scenes/enemies/enemy.gd"

const ART := preload("res://assets/art/characters/hydra_body.png")
const Head := preload("res://scenes/enemies/hydra_head.gd")
const REACH := 84.0
const WINDUP_SECONDS := 0.65
const STRIKE_SECONDS := 0.22
const RETREAT_SECONDS := 0.2
const RECOVERY_SECONDS := 0.65

@onready var heads: Array[Node] = $Heads.get_children()
var _state := "idle"
var _state_time := 0.0
var _age := 0.0
var _cooldown := 0.8
var _active_head: Node
var _last_head := -1
var _strike_hits: Dictionary = {}


func _ready() -> void:
	max_hp = 6
	points = 450
	body_height = 16
	body_half_width = 24
	super()
	# Only the three mouths participate in sword and mutual jump damage.
	# The coiled body provides terrain support and cannot bypass their health.
	remove_from_group("enemies")
	for head in heads:
		head.damaged.connect(_on_head_damaged)
		head.severed.connect(_on_head_severed)
	_face()
	_update_heads()


func _initial_animation() -> String:
	return "idle"


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	var atlas := AtlasTexture.new()
	atlas.atlas = ART
	atlas.region = Rect2(0, 0, 96, 56)
	frames.add_frame("idle", atlas)
	_bind_frames(frames)


func _draw() -> void:
	pass # Each head displays its own health, instead of a shared body bar.


func _deals_contact() -> bool:
	return false


func _face() -> void:
	super()
	$Heads.scale.x = direction


func _tick(delta: float) -> void:
	_update_focus(160, 64)
	_age += delta
	_state_time += delta
	velocity.x = 0
	if not is_on_floor():
		_enter("idle")
		_cooldown = 0.4
		_update_heads()
		return
	match _state:
		"idle":
			if _has_focus:
				_face_player(FOCUS_HEIGHT)
			_cooldown = maxf(0, _cooldown - delta)
			if _cooldown <= 0 and _can_engage():
				_active_head = _next_head()
				if _active_head != null:
					_enter("windup")
		"windup":
			if _state_time >= _telegraph(WINDUP_SECONDS):
				_enter("strike" if _bite_clear() else "recover")
		"strike":
			if _state_time >= STRIKE_SECONDS:
				_enter("retreat")
		"retreat":
			if _state_time >= RETREAT_SECONDS:
				_enter("recover")
		"recover":
			if _state_time >= _punish(RECOVERY_SECONDS):
				_cooldown = _rest(0.35)
				_enter("idle")
	_update_heads()


func _can_engage() -> bool:
	var player := _player()
	return player != null and player.get("health") != 0 and _player_close(REACH, 16) and _can_see_player()


func _next_head() -> Node:
	for step in heads.size():
		var index := (_last_head + 1 + step) % heads.size()
		if heads[index].alive:
			_last_head = index
			return heads[index]
	return null


func _bite_clear() -> bool:
	if _active_head == null or not _active_head.alive:
		return false
	var reach: float = _active_head.base_x + Head.MOUTHS[3].x - Head.BASE.x
	var origin := global_position + Vector2(0, -22)
	var destination := global_position + Vector2(direction * reach, -22)
	var ray := PhysicsRayQueryParameters2D.create(origin, destination, 1)
	var space := get_world_2d().direct_space_state
	if not space.intersect_ray(ray).is_empty():
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _active_head.get_node("CollisionShape2D").shape
	query.transform = Transform2D(0, destination)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()


func _enter(next: String) -> void:
	_state = next
	_state_time = 0
	if next == "strike":
		_strike_hits.clear()


func _update_heads() -> void:
	var idle_frame := int(_age * 3) % 2
	var bite_height: float = Head.BASE.y - Head.MOUTHS[3].y - 22
	for head in heads:
		if not head.alive:
			continue
		var frame := idle_frame
		var height: float = head.base_y
		if head == _active_head:
			match _state:
				"windup":
					frame = 2
				"strike":
					frame = 3
					height = bite_height
				"retreat":
					frame = 4
					height = lerpf(bite_height, head.base_y, minf(1, _state_time / RETREAT_SECONDS))
				"recover":
					frame = 5
		head.set_pose(frame, height)


func _hurt_overlaps() -> void:
	if _state != "strike" or _active_head == null or not _active_head.alive:
		return
	var player := _player()
	if player == null or player.get("health") == 0 or not player.has_method("hurt"):
		return
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null or not _can_see_player():
		return
	var mouth: CollisionShape2D = _active_head.get_node("CollisionShape2D")
	var head_rect: Rect2 = mouth.global_transform * mouth.shape.get_rect()
	var player_rect: Rect2 = collision.global_transform * collision.shape.get_rect()
	var overlap := head_rect.intersection(player_rect)
	if overlap.size.x < 4 or overlap.size.y < 4:
		return
	var id := player.get_instance_id()
	if not _strike_hits.has(id):
		_strike_hits[id] = true
		player.hurt(1)


func take_damage(_amount: int) -> void:
	pass # A shared body hit must never substitute for defeating a head.


func living_heads() -> int:
	var count := 0
	for head in heads:
		if head.alive:
			count += 1
	return count


func _on_head_damaged(head: Node) -> void:
	hp = 0
	for other in heads:
		hp += other.hp
	if head.alive and head == _active_head and _state in ["windup", "strike"]:
		_enter("recover")
		_update_heads()


func _on_head_severed(head: Node) -> void:
	if living_heads() == 0:
		die()
	elif head == _active_head:
		_enter("recover")
		_update_heads()


func die() -> void:
	if not alive or living_heads() > 0:
		return
	super()
