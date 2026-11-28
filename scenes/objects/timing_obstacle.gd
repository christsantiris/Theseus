extends Node2D
## The physics clock drives both the visible cue and the contact region.

enum Kind { WEIGHT, KILN, ARROWS, ROCKFALL, BRIDGE, SUNBEAM, JETS, STONE_GATE }

# The sprites are tightly packed in a padded four-column atlas.
enum Sprite { PIVOT, LINK, WEIGHT, BOULDER, KILN, DRAIN, MIRROR, DECK,
	SLAB, LINTEL, ARROW_SLITS, ARROW, WAVE, FLAME, JET, DUST }
const ART := preload("res://assets/art/objects/timing_obstacles.png")
const LABYRINTH_PENDULUM := preload("res://assets/art/objects/labyrinth_pendulum.png")
const GOLD := Color("ffe1a0")
const FOAM := Color("d4fcf7")
# The Level 1 weight clears the 36-pixel duck pose, including its painted
# lower edge, while still reaching the 44-pixel standing body.
const WEIGHT_PIVOT_Y := -101.0
const LABYRINTH_PIVOT_Y := -94.0
const GATE_HEIGHT := 72.0
const GATE_TRAVEL := 0.45
const GATE_APPROACH := 48.0
const ROCK_APPROACH := 136.0
const ROCK_INTERVAL := 1.0
const ROCK_FALL_SECONDS := 0.88
const ROCK_DUST_SECONDS := 0.37
const ROCK_RADIUS := 11.0

var kind: Kind
var variant := ""
var arrow_height := 40.0
var width: float
# Seconds spent in rest, warning, and active phases. The gate uses the first
# and last values for time fully closed and fully open.
var durations: Vector3
var player: CharacterBody2D
var elapsed := 0.0
var _solid: StaticBody2D
var _player_shape: CollisionShape2D
var _hit_this_cycle := false
var _bridge_from_right := false
var _rockfall_started := false
var _gate_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 9
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_player_shape = player.get_node("CollisionShape2D")
	if kind == Kind.ARROWS:
		_add_arrow_housing()
	if kind == Kind.BRIDGE or kind == Kind.STONE_GATE:
		_solid = StaticBody2D.new()
		_solid.collision_mask = 0
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		if kind == Kind.BRIDGE:
			rectangle.size = Vector2(width, 4)
			collider.position = Vector2(width / 2, 2)
			collider.one_way_collision = true
		else:
			rectangle.size = Vector2(width, GATE_HEIGHT)
			collider.position = Vector2(width / 2, -GATE_HEIGHT / 2)
		collider.shape = rectangle
		_solid.add_child(collider)
		add_child(_solid)
		_update_solid()


func _physics_process(delta: float) -> void:
	if kind == Kind.BRIDGE:
		var x := player.global_position.x - global_position.x
		if x <= -7.0 or x >= width + 7.0:
			_bridge_from_right = x > width
	if kind == Kind.ROCKFALL and not _rockfall_started:
		var player_x := player.global_position.x - global_position.x
		if player_x < -ROCK_APPROACH or player_x > width + ROCK_APPROACH:
			return
		_rockfall_started = true
		elapsed = durations.x
	if kind == Kind.STONE_GATE and not _gate_started:
		var player_x := player.global_position.x - global_position.x
		if player_x < -GATE_APPROACH or player_x > width + GATE_APPROACH:
			return
		_gate_started = true
	var cycle := durations.x + durations.y + durations.z
	if kind == Kind.STONE_GATE:
		cycle += 2.0 * GATE_TRAVEL
	elapsed += delta
	if elapsed >= cycle:
		elapsed = fposmod(elapsed, cycle)
		_hit_this_cycle = false
	if kind == Kind.STONE_GATE and player.health > 0:
		_resolve_gate_contact()
	_update_solid()
	if kind != Kind.STONE_GATE and player.health > 0 and not _hit_this_cycle:
		var dangers: Array[Rect2] = []
		if kind == Kind.ARROWS:
			dangers = _arrow_rects()
		else:
			dangers.append(_danger_rect())
		for danger: Rect2 in dangers:
			if danger.has_area() and danger.intersects(_player_rect()):
				_hurt_player()
				break
	# All art fits inside a small region. Refresh once on re-entry to the view.
	var camera := get_viewport().get_camera_2d()
	if camera == null or absf(camera.get_screen_center_position().x - global_position.x) < 320.0:
		queue_redraw()


func _player_rect() -> Rect2:
	var bounds: Rect2 = _player_shape.global_transform * _player_shape.shape.get_rect()
	bounds.position = to_local(bounds.position)
	return bounds


func _hurt_player() -> void:
	var health_before: int = player.health
	player.hurt(1)
	_hit_this_cycle = player.health < health_before


func _warning() -> bool:
	return elapsed >= durations.x and _active_time() < 0.0


func _active_time() -> float:
	return elapsed - durations.x - durations.y


func _update_solid() -> void:
	match kind:
		Kind.BRIDGE:
			_solid.collision_layer = int(_active_time() < 0.0)
		Kind.STONE_GATE:
			_solid.collision_layer = int(_gate_bottom() >= 0.0)


func return_to_bridge_bank() -> void:
	var bank_x := width + 8.0 if _bridge_from_right else -8.0
	player.global_position = to_global(Vector2(bank_x, 0.0))
	player.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.reset_smoothing()


func _gate_open_time() -> float:
	return elapsed - durations.x - GATE_TRAVEL


func _gate_bottom() -> float:
	if elapsed < durations.x:
		return 0.0
	var open_time := _gate_open_time()
	if open_time < 0.0:
		return lerpf(0.0, -GATE_HEIGHT, 1.0 + open_time / GATE_TRAVEL)
	return lerpf(-GATE_HEIGHT, 0.0, clampf((open_time - durations.z) / GATE_TRAVEL, 0.0, 1.0))


func _resolve_gate_contact() -> void:
	var bottom := _gate_bottom()
	var slab := Rect2(0, -GATE_HEIGHT, width, bottom + GATE_HEIGHT)
	var body := _player_rect()
	if not slab.has_area() or not slab.intersects(body):
		return
	var relative_x := player.global_position.x - global_position.x
	var half_body := body.size.x / 2
	var exit_x := -half_body - 0.1 if relative_x < width / 2 else width + half_body + 0.1
	player.move_and_collide(Vector2(exit_x - relative_x, 0), false, 0.08, false)
	if _gate_open_time() >= durations.z and not _hit_this_cycle:
		_hurt_player()


func _weight_anchor() -> Vector2:
	return Vector2(width / 2, LABYRINTH_PIVOT_Y if variant == "labyrinth" else WEIGHT_PIVOT_Y)


func _weight_center() -> Vector2:
	var angle := cos(TAU * elapsed / durations.z) * 0.92
	return _weight_anchor() + Vector2(sin(angle), cos(angle)) * 55.0


func _rock_x(index: int) -> float:
	return width * (0.25 + index * 0.5)


func _rock_center(index: int, time: float) -> Vector2:
	var fall := clampf(time / ROCK_FALL_SECONDS, 0.0, 1.0)
	return Vector2(_rock_x(index), lerpf(-112.0, -ROCK_RADIUS, fall * fall))


func _danger_rect() -> Rect2:
	if kind == Kind.WEIGHT:
		return Rect2(_weight_center() - Vector2(7, 7), Vector2(14, 14))
	var time := _active_time()
	if time < 0.0:
		return Rect2()
	var progress := time / durations.z
	match kind:
		Kind.KILN, Kind.JETS:
			return Rect2(0, -28, width, 28)
		Kind.ARROWS:
			var arrows := _arrow_rects()
			return arrows[0] if not arrows.is_empty() else Rect2()
		Kind.ROCKFALL:
			var index := int(time >= ROCK_INTERVAL)
			var fall_time := time - index * ROCK_INTERVAL
			if fall_time > ROCK_FALL_SECONDS + 0.07:
				return Rect2()
			var radius := Vector2(ROCK_RADIUS, ROCK_RADIUS)
			return Rect2(_rock_center(index, fall_time) - radius, radius * 2.0)
		Kind.SUNBEAM:
			var left := lerpf(width, -10.0, progress)
			return Rect2(maxf(0, left), -13, clampf(left + 10, 0, width) - maxf(0, left), 13)
	return Rect2()


func _draw() -> void:
	var warning := _warning()
	var danger := _danger_rect()
	match kind:
		Kind.WEIGHT:
			_draw_weight()
		Kind.KILN, Kind.JETS:
			_draw_vents(warning, danger.has_area())
		Kind.ARROWS:
			_draw_volley(warning)
		Kind.ROCKFALL:
			_draw_rockfall(warning, danger)
		Kind.SUNBEAM:
			_draw_mirror(warning, danger)
		Kind.BRIDGE:
			_draw_bridge(warning)
		Kind.STONE_GATE:
			_draw_gate()


func _sprite_region(sprite: Sprite) -> Rect2:
	return Rect2((sprite % 4) * 128 + 2, floori(sprite / 4.0) * 128 + 2, 124, 124)


func _art(sprite: Sprite, bounds: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect_region(ART, bounds, _sprite_region(sprite), tint)


func _labyrinth_region(cell: int) -> Rect2:
	return Rect2(cell * 128 + 2, 2, 124, 124)


func _draw_weight() -> void:
	var anchor := _weight_anchor()
	var weight := _weight_center()
	var angle := (weight - anchor).angle() - PI / 2
	if variant == "labyrinth":
		draw_texture_rect_region(LABYRINTH_PENDULUM, Rect2(anchor - Vector2(13, 20), Vector2(26, 26)), _labyrinth_region(0))
		for link in range(1, 11):
			draw_set_transform(anchor.lerp(weight, link / 12.0), angle)
			draw_texture_rect_region(LABYRINTH_PENDULUM, Rect2(-2.1, -3.3, 4.2, 6.6), _labyrinth_region(1))
		draw_set_transform(weight, angle)
		draw_texture_rect_region(LABYRINTH_PENDULUM, Rect2(-12, -13, 24, 24), _labyrinth_region(2))
		draw_set_transform(Vector2.ZERO)
		return
	_art(Sprite.PIVOT, Rect2(anchor - Vector2(15, 11), Vector2(30, 19)))
	for link in range(1, 12):
		draw_set_transform(anchor.lerp(weight, link / 12.0), angle)
		_art(Sprite.LINK, Rect2(-1.9, -3.2, 3.8, 6.4))
	draw_set_transform(Vector2.ZERO)
	_art(Sprite.WEIGHT, Rect2(weight - Vector2(8, 8), Vector2(16, 16)))


func _draw_vents(warning: bool, active: bool) -> void:
	var water := kind == Kind.JETS
	var grate := Sprite.DRAIN if water else Sprite.KILN
	var plume := Sprite.JET if water else Sprite.FLAME
	var light := FOAM if water else GOLD
	for x in range(5, int(width), 10):
		var grate_tint := Color.WHITE if warning or active else Color(0.67, 0.62, 0.58)
		_art(grate, Rect2(x - 5, -4, 10, 5), grate_tint)
		if active:
			var plume_height := 27.0 + sin(x + elapsed * 22) * 2.0
			var sway := sin(x + elapsed * 30)
			_art(plume, Rect2(x - 5 + sway, -plume_height, 10, plume_height - 1))
		elif warning and water:
			for bubble in 3:
				var lift := fposmod(elapsed * 23 + x + bubble * 6, 16)
				draw_arc(Vector2(x + sin(lift) * 2, -5 - lift), 1.35, 0, TAU, 12, light, 0.6, true)
		elif warning:
			var flicker := 0.55 + 0.25 * sin(x + elapsed * 29)
			_art(plume, Rect2(x - 3, -5, 6, 4), Color(1, 0.9, 0.7, flicker))


func _add_arrow_housing() -> void:
	var texture := AtlasTexture.new()
	texture.atlas = ART
	texture.region = _sprite_region(Sprite.ARROW_SLITS)
	var housing := Sprite2D.new()
	housing.name = "ArrowHousing"
	housing.texture = texture
	housing.centered = false
	housing.position = Vector2(width / 2.0 - 16.5, -arrow_height - 13.0)
	housing.scale = Vector2(33, 25) / texture.region.size
	# The masonry sits behind Theseus while the arrow cues stay in front.
	housing.z_as_relative = false
	housing.z_index = -1
	add_child(housing)


func _arrow_rects() -> Array[Rect2]:
	var time := _active_time()
	if time < 0.0 or time >= durations.z:
		return []
	# Two arrows leave the central housing together. Keep their contact
	# regions separate so the empty space behind them cannot deal damage.
	var tail := width / 2.0 * (1.0 - time / durations.z)
	var left := Rect2(maxf(0.0, tail - 22.0), -arrow_height - 2.0, minf(22.0, tail), 4.0)
	return [left, Rect2(width - left.end.x, left.position.y, left.size.x, left.size.y)]


func _draw_arrow(bounds: Rect2, direction: int, tint := Color.WHITE) -> void:
	# The atlas arrow points left; mirror the rightward shot and its cue.
	var offset := Vector2(bounds.size.x if direction > 0 else 0.0, 0)
	draw_set_transform(bounds.position + offset, 0, Vector2(-1 if direction > 0 else 1, 1))
	_art(Sprite.ARROW, Rect2(Vector2.ZERO, bounds.size), tint)
	draw_set_transform(Vector2.ZERO)


func _draw_volley(warning: bool) -> void:
	if warning:
		for direction in [-1, 1]:
			var slit := Vector2(width / 2.0 + direction * 9.0, -arrow_height)
			draw_arc(slit, 3, 0, TAU, 12, GOLD, 0.8, true)
			_draw_arrow(Rect2(slit - Vector2(4, 1.5), Vector2(8, 3)), direction, GOLD)
	var arrows := _arrow_rects()
	for index in arrows.size():
		_draw_arrow(arrows[index], -1 if index == 0 else 1)


func _draw_rockfall(warning: bool, danger: Rect2) -> void:
	for index in 2:
		var x := _rock_x(index)
		_art(Sprite.DUST, Rect2(x - 12, -3, 24, 4), Color(0.79, 0.68, 0.53, 0.65))
		if warning:
			_draw_dust(x, 0)
	if danger.has_area():
		_art(Sprite.BOULDER, danger)
	for index in 2:
		var impact_time := _active_time() - index * ROCK_INTERVAL - ROCK_FALL_SECONDS
		if impact_time >= 0.0 and impact_time < ROCK_DUST_SECONDS:
			var progress := impact_time / ROCK_DUST_SECONDS
			var spread := lerpf(13.0, 24.0, progress)
			var height := lerpf(12.0, 21.0, progress)
			_art(Sprite.DUST, Rect2(_rock_x(index) - spread, -height, spread * 2.0, height),
				Color(1, 0.89, 0.74, 1.0 - progress))


func _draw_mirror(warning: bool, danger: Rect2) -> void:
	_art(Sprite.LINTEL, Rect2(-22, -23, 21, 6), Color("dbbb87"))
	_art(Sprite.ARROW_SLITS, Rect2(-20, -18, 17, 18), Color("c6a374"))
	_art(Sprite.MIRROR, Rect2(width - 8, -28, 16, 28), GOLD if warning else Color.WHITE)
	if warning:
		draw_arc(Vector2(width, -20), 9 + sin(elapsed * 35) * 2, 0, TAU, 24, GOLD, 0.85, true)
	if danger.has_area():
		_art(Sprite.FLAME, danger, GOLD)
		var core := danger.get_center().x
		draw_line(Vector2(core, -10), Vector2(core, -2), GOLD, 1.5, true)


func _draw_bridge(warning: bool) -> void:
	var extent := width * (1.0 - clampf(_active_time() / 0.18, 0.0, 1.0))
	var shake := sin(elapsed * 45) if warning else 0.0
	_art(Sprite.PIVOT, Rect2(-5, 0, 7, 9))
	_art(Sprite.PIVOT, Rect2(width - 2, 0, 7, 9))
	for x in range(0, ceili(extent), 28):
		var span := minf(28.0, extent - x)
		var source := _sprite_region(Sprite.DECK)
		source.size.x *= span / 28.0
		var tint := GOLD if warning else Color.WHITE
		draw_texture_rect_region(ART, Rect2(x, shake, span, 5), source, tint)


func _draw_gate() -> void:
	var bottom := _gate_bottom()
	var stone := Color("ada596")
	for side in [-5, width]:
		_art(Sprite.SLAB, Rect2(side, -GATE_HEIGHT, 5, GATE_HEIGHT), stone.darkened(0.35))
	if bottom > -GATE_HEIGHT:
		var panel := _sprite_region(Sprite.SLAB)
		var visible_height := bottom + GATE_HEIGHT
		# Reveal the bottom of the slab first as it slides out of the lintel.
		var hidden_height := panel.size.y * (1.0 - visible_height / GATE_HEIGHT)
		panel.position.y += hidden_height
		panel.size.y -= hidden_height
		draw_texture_rect_region(ART, Rect2(0, -GATE_HEIGHT, width, visible_height), panel, stone)
	_art(Sprite.LINTEL, Rect2(-12, -GATE_HEIGHT - 8, width + 24, 13), stone)
	var open_time := _gate_open_time()
	if open_time >= durations.z - 0.75 and open_time < durations.z:
		_draw_dust(width / 2, -GATE_HEIGHT + 12)


func _draw_dust(x: float, y: float) -> void:
	for speck in 4:
		var phase := fposmod(elapsed * 1.7 + speck * 0.25, 1.0)
		var tint := Color(1, 0.91, 0.76, sin(phase * PI) * 0.9)
		_art(Sprite.DUST, Rect2(x + sin(speck * 5.0) * 7 - 4, y + phase * 18 - 18, 8, 5), tint)
