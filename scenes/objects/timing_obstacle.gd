extends Node2D
## The physics clock drives both the visible cue and the contact region.

enum Kind { WEIGHT, WAVE, KILN, ARROWS, ROCKFALL, BRIDGE, SUNBEAM, JETS, STONE_GATE }

const BRONZE := Color("b8884b")
const GOLD := Color("ffe1a0")
const STONE := Color("766b68")
const SHADOW := Color("3e3433")
const FOAM := Color("d4fcf7")
const WATER := Color("47b7cf")
const WEIGHT_PIVOT_Y := -94.0
const GATE_HEIGHT := 72.0
const GATE_TRAVEL := 0.45
const ROCK_INTERVAL := 0.40

var kind: Kind
var width: float
# Seconds spent in rest, warning, and active phases.
var durations: Vector3
var player: CharacterBody2D
var elapsed := 0.0
var _solid: StaticBody2D
var _player_shape: CollisionShape2D
var _hit_this_cycle := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 9
	_player_shape = player.get_node("CollisionShape2D")
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
	var cycle := durations.x + durations.y + durations.z
	elapsed += delta
	if elapsed >= cycle:
		elapsed = fposmod(elapsed, cycle)
		_hit_this_cycle = false
	if kind == Kind.STONE_GATE and player.health > 0:
		_resolve_gate_contact()
	_update_solid()
	if kind != Kind.STONE_GATE and player.health > 0 and not _hit_this_cycle:
		var danger := _danger_rect()
		if danger.has_area() and danger.intersects(_player_rect()):
			_hurt_player()
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


func _gate_bottom() -> float:
	# The first part of the open phase is the raising animation.
	if elapsed < GATE_TRAVEL:
		return lerpf(0.0, -GATE_HEIGHT, elapsed / GATE_TRAVEL)
	return lerpf(-GATE_HEIGHT, 0.0, clampf(_active_time() / GATE_TRAVEL, 0.0, 1.0))


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
	if _active_time() >= 0.0 and _active_time() <= GATE_TRAVEL and not _hit_this_cycle:
		_hurt_player()


func _weight_center() -> Vector2:
	var angle := cos(TAU * elapsed / durations.z) * 0.92
	return Vector2(width / 2, WEIGHT_PIVOT_Y) + Vector2(sin(angle), cos(angle)) * 55.0


func _rock_center(index: int) -> Vector2:
	var fall := clampf((_active_time() - index * ROCK_INTERVAL) / 0.30, 0.0, 1.0)
	return Vector2(width * (0.25 + index * 0.5), lerpf(-72, -8, fall * fall))


func _danger_rect() -> Rect2:
	if kind == Kind.WEIGHT:
		return Rect2(_weight_center() - Vector2(7, 7), Vector2(14, 14))
	var time := _active_time()
	if time < 0.0:
		return Rect2()
	var progress := time / durations.z
	match kind:
		Kind.WAVE:
			return Rect2(0, -22, width * minf(progress * 2.0, 1.0), 22)
		Kind.KILN, Kind.JETS:
			return Rect2(0, -28, width, 28)
		Kind.ARROWS:
			var front := (width + 22.0) * (1.0 - progress)
			var left := maxf(0, front - 22.0)
			return Rect2(left, -42, maxf(0, minf(front, width) - left), 4)
		Kind.ROCKFALL:
			var index := int(time >= ROCK_INTERVAL)
			return Rect2(_rock_center(index) - Vector2(8, 8), Vector2(16, 16))
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
		Kind.WAVE:
			draw_rect(Rect2(0, -4, width, 4), WATER.darkened(0.45))
			if warning:
				for x in range(3, int(width), 7):
					draw_circle(Vector2(x, -3 + sin(x + elapsed * 16) * 2), 1.3, FOAM)
			if danger.has_area():
				_draw_wave(danger)
		Kind.KILN, Kind.JETS:
			_draw_vents(warning, danger.has_area())
		Kind.ARROWS:
			_draw_volley(warning, danger)
		Kind.ROCKFALL:
			for index in 2:
				var x := width * (0.25 + index * 0.5)
				draw_line(Vector2(x - 8, -1), Vector2(x + 8, -1), BRONZE, 2)
				if warning:
					_draw_dust(x, 0)
			if danger.has_area():
				_draw_rock(danger.get_center(), 8, STONE)
		Kind.SUNBEAM:
			_draw_mirror(warning, danger)
		Kind.BRIDGE:
			_draw_bridge(warning)
		Kind.STONE_GATE:
			_draw_gate(warning)


func _draw_weight() -> void:
	var anchor := Vector2(width / 2, WEIGHT_PIVOT_Y)
	var weight := _weight_center()
	draw_rect(Rect2(anchor - Vector2(11, 4), Vector2(22, 6)), STONE)
	draw_circle(anchor, 4, BRONZE)
	for link in range(1, 12):
		draw_circle(anchor.lerp(weight, link / 12.0), 2, BRONZE if link % 2 else SHADOW)
	_draw_rock(weight, 8, BRONZE)


func _draw_wave(danger: Rect2) -> void:
	var crest := PackedVector2Array([Vector2(0, 0)])
	for x in range(0, int(danger.size.x), 3):
		crest.append(Vector2(x, -17 + sin(x * 0.3 - elapsed * 24) * 4))
	crest.append(Vector2(danger.end.x, -14))
	draw_colored_polygon(crest + PackedVector2Array([Vector2(danger.end.x, 0)]), WATER)
	if crest.size() > 2:
		draw_polyline(crest.slice(1), FOAM, 2)


func _draw_vents(warning: bool, active: bool) -> void:
	var water := kind == Kind.JETS
	var light := FOAM if water else GOLD
	var plume := WATER if water else Color("e96f38")
	for x in range(5, int(width), 10):
		draw_rect(Rect2(x - 5, -4, 10, 4), STONE)
		draw_line(Vector2(x - 3, -2), Vector2(x + 3, -2), light if warning or active else SHADOW, 2)
		if warning and water:
			var bubble := Vector2(x, -6 - fposmod(elapsed * 23 + x, 16))
			draw_arc(bubble, 1.6, 0, TAU, 8, light, 1)
		if active:
			var tip := Vector2(x + sin(x + elapsed * 30) * 2, -24 - 4 * sin(x + elapsed * 22))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -2), tip, Vector2(x + 5, -2)]), plume)
			draw_line(Vector2(x, -3), tip * Vector2(1, 0.75), light, 1.5)


func _draw_volley(warning: bool, danger: Rect2) -> void:
	for offset in [0, -8, -16]:
		var slit := Vector2(width + offset, -40)
		draw_rect(Rect2(slit - Vector2(3, 7), Vector2(6, 14)), SHADOW)
		if warning:
			draw_arc(slit, 4, -PI / 2, PI / 2, 8, BRONZE, 1)
			draw_line(slit + Vector2(2, 0), slit - Vector2(5, 0), GOLD, 1)
	if danger.has_area():
		draw_line(Vector2(danger.position.x, -40), Vector2(danger.end.x, -40), GOLD, 2)
		draw_colored_polygon(PackedVector2Array([
			Vector2(danger.position.x, -40), Vector2(danger.position.x + 5, -42),
			Vector2(danger.position.x + 5, -38),
		]), BRONZE)


func _draw_mirror(warning: bool, danger: Rect2) -> void:
	draw_rect(Rect2(-18, -19, 15, 19), STONE)
	draw_rect(Rect2(-21, -25, 21, 6), STONE.lightened(0.18))
	draw_line(Vector2(width, 0), Vector2(width, -19), BRONZE, 3)
	draw_circle(Vector2(width, -19), 7, BRONZE)
	draw_circle(Vector2(width, -19), 5, GOLD if warning else Color("d9bb77"))
	if warning:
		draw_arc(Vector2(width, -19), 10 + sin(elapsed * 35) * 2, 0, TAU, 16, GOLD, 1)
	if danger.has_area():
		draw_rect(danger, Color("d98833"))
		draw_line(danger.position + Vector2(danger.size.x / 2, 1), danger.get_center() + Vector2(0, 6), GOLD, 3)


func _draw_bridge(warning: bool) -> void:
	var extent := width * (1.0 - clampf(_active_time() / 0.18, 0.0, 1.0))
	var shake := sin(elapsed * 45) if warning else 0.0
	draw_rect(Rect2(-4, 0, 5, 9), SHADOW)
	draw_rect(Rect2(width - 1, 0, 5, 9), SHADOW)
	draw_rect(Rect2(0, shake, extent, 4), GOLD if warning else BRONZE)
	for x in range(2, int(extent), 5):
		draw_line(Vector2(x, shake), Vector2(x, shake + 4), SHADOW, 1)


func _draw_gate(warning: bool) -> void:
	draw_rect(Rect2(-17, -GATE_HEIGHT - 7, width + 34, 11), STONE)
	var bottom := _gate_bottom()
	if bottom > -GATE_HEIGHT:
		draw_rect(Rect2(0, -GATE_HEIGHT, width, bottom + GATE_HEIGHT), SHADOW)
		draw_rect(Rect2(2, -GATE_HEIGHT, width - 4, bottom + GATE_HEIGHT), STONE)
		for y in range(int(bottom) - 5, -int(GATE_HEIGHT), -10):
			draw_line(Vector2(0, y), Vector2(width, y), SHADOW, 1)
	if warning:
		_draw_dust(width / 2, -GATE_HEIGHT)


func _draw_dust(x: float, y: float) -> void:
	for speck in 7:
		var drift := fposmod(elapsed * 23 + speck * 3, 21)
		draw_circle(Vector2(x + sin(speck * 5.0) * 8, y + drift - 18), 1.3, GOLD)


func _draw_rock(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for corner in 8:
		var length := radius if corner % 3 else radius * 0.78
		points.append(center + Vector2.from_angle(corner * TAU / 8) * length)
	draw_colored_polygon(points, color)
	draw_line(center + Vector2(-4, -2), center + Vector2(0, -5), color.lightened(0.5), 2)
