extends Node2D

const Layout := preload("res://scenes/levels/level_8_layout.gd")
const LOW_Y := 304.0
const HIGH_Y := 128.0
const LOW_SECONDS := 4.0
const FILL_SECONDS := 8.0
const HIGH_SECONDS := 6.0
const DRAIN_SECONDS := 8.0
const CYCLE_SECONDS := LOW_SECONDS + FILL_SECONDS + HIGH_SECONDS + DRAIN_SECONDS
const WADING_SPEED := 0.70
const DRAG_START_DEPTH := 8.0
const FULL_DRAG_DEPTH := 32.0
var player: CharacterBody2D
var hud: CanvasLayer
var elapsed := 0.0
var water_y := LOW_Y
var phase_name := "LOW TIDE"
var _surface_runs: Array[Rect2] = []
var _puddles: Array[Node2D] = []
var _display: Control
var _label: Label
var _fill: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Apply drag before Theseus's input and movement step, on the physics clock.
	process_priority = -2
	z_index = 8
	_build_surface_runs()
	for canal: Dictionary in Layout.CANALS:
		_puddles.append(get_parent().get_node("World/" + String(canal.name)))
	_build_display()
	_sync_tide()


static func height_at(seconds: float) -> float:
	var time := fposmod(seconds, CYCLE_SECONDS)
	if time < LOW_SECONDS:
		return LOW_Y
	if time < LOW_SECONDS + FILL_SECONDS:
		return lerpf(LOW_Y, HIGH_Y, smoothstep(0.0, FILL_SECONDS, time - LOW_SECONDS))
	if time < LOW_SECONDS + FILL_SECONDS + HIGH_SECONDS:
		return HIGH_Y
	return lerpf(HIGH_Y, LOW_Y, smoothstep(0.0, DRAIN_SECONDS, time - LOW_SECONDS - FILL_SECONDS - HIGH_SECONDS))


static func speed_at(feet_y: float, surface_y: float) -> float:
	var immersion := clampf((feet_y - surface_y - DRAG_START_DEPTH) / (FULL_DRAG_DEPTH - DRAG_START_DEPTH), 0.0, 1.0)
	return lerpf(1.0, WADING_SPEED, immersion)


func _physics_process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, CYCLE_SECONDS)
	_sync_tide()


func _process(_delta: float) -> void:
	# Camera movement needs a redraw even when it crosses a dry section.
	queue_redraw()


func _sync_tide() -> void:
	water_y = height_at(elapsed)
	if is_instance_valid(player):
		player.set_environment_speed_multiplier(speed_at(player.global_position.y, water_y))
	for puddle in _puddles:
		puddle.visible = water_y > puddle.global_position.y + puddle.canal_depth - 7.0
	var time := fposmod(elapsed, CYCLE_SECONDS)
	var end := LOW_SECONDS
	phase_name = "LOW TIDE"
	if time >= LOW_SECONDS + FILL_SECONDS + HIGH_SECONDS:
		phase_name = "DRAINING"
		end = CYCLE_SECONDS
	elif time >= LOW_SECONDS + FILL_SECONDS:
		phase_name = "HIGH TIDE"
		end = LOW_SECONDS + FILL_SECONDS + HIGH_SECONDS
	elif time >= LOW_SECONDS:
		phase_name = "RISING"
		end = LOW_SECONDS + FILL_SECONDS
	if is_instance_valid(_label):
		_label.text = "%s  %ds" % [phase_name, ceili(end - time)]
		_label.add_theme_color_override("font_color", Color("efca76") if phase_name == "RISING" else Color("e2f2ee"))
		_fill.size.x = 86.0 * (LOW_Y - water_y) / (LOW_Y - HIGH_Y)
	queue_redraw()


func _build_surface_runs() -> void:
	# Clip water to the open space above the real terrain. It cannot shine
	# through retaining walls, and the untouched stone lips stay readable.
	var edges: Array[float] = [0.0, float(Layout.WIDTH)]
	for platform: Rect2 in Layout.PLATFORMS:
		edges.append(platform.position.x)
		edges.append(platform.end.x)
	for canal: Dictionary in Layout.CANALS:
		edges.append(canal.position.x)
		edges.append(canal.position.x + canal.width)
	edges.sort()
	for index in edges.size() - 1:
		var left := edges[index]
		var right := edges[index + 1]
		if right <= left:
			continue
		var ground := Layout.surface_at((left + right) * 0.5)
		if not _surface_runs.is_empty() and is_equal_approx(_surface_runs[-1].position.y, ground) and is_equal_approx(_surface_runs[-1].end.x, left):
			_surface_runs[-1].size.x += right - left
		else:
			_surface_runs.append(Rect2(left, ground, right - left, 0))


func _draw() -> void:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	view = view.grow(2.0)
	for run: Rect2 in _surface_runs:
		var left := maxf(view.position.x, run.position.x)
		var right := minf(view.end.x, run.end.x)
		var top := maxf(view.position.y, water_y)
		var bottom := minf(view.end.y, run.position.y)
		if right <= left or bottom <= top:
			continue
		draw_rect(Rect2(left, top, right - left, bottom - top), Color(0.04, 0.48, 0.64, 0.22))
		if water_y >= view.position.y and water_y < bottom:
			var foam := PackedVector2Array()
			var x := left
			while x < right:
				foam.append(Vector2(x, water_y + sin(x * 0.10 + elapsed * 2.0) * 0.65))
				x += 4.0
			foam.append(Vector2(right, water_y + sin(right * 0.10 + elapsed * 2.0) * 0.65))
			draw_polyline(foam, Color(0.76, 0.96, 0.96, 0.9), 0.6, true)
			for ripple in 2:
				draw_line(Vector2(left, water_y + 2.0 + ripple * 2.0), Vector2(right, water_y + 2.0 + ripple * 2.0), Color(0.50, 0.86, 0.92, 0.16), 0.45, true)
	# Sparse bubbles stay in water above the landing, never inside stone.
	for cell in range(floori(view.position.x / 32.0), ceili(view.end.x / 32.0)):
		var x := cell * 32.0 + 16.0 + sin(elapsed + cell) * 2.0
		if x < 0.0 or x >= Layout.WIDTH:
			continue
		var depth := Layout.surface_at(x) - water_y - 4.0
		if depth <= 8.0:
			continue
		var y := water_y + 2.0 + fposmod(cell * 13.0 - elapsed * 8.0, depth)
		if view.has_point(Vector2(x, y)):
			draw_arc(Vector2(x, y), 0.6 + (cell % 3) * 0.2, 0.0, TAU, 8, Color(0.78, 0.96, 0.98, 0.42), 0.3, true)


func _build_display() -> void:
	if not is_instance_valid(hud):
		return
	_display = Control.new()
	_display.name = "TideStatus"
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.anchor_left = 0.5
	_display.anchor_right = 0.5
	_display.offset_left = -55
	_display.offset_right = 55
	_display.offset_top = 20
	_display.offset_bottom = 39
	hud._root.add_child(_display)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(110, 18)
	backdrop.color = Color(0.03, 0.12, 0.16, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(backdrop)
	_label = Label.new()
	_label.position = Vector2(2, 1)
	_label.size = Vector2(106, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(_label)
	var track := ColorRect.new()
	track.position = Vector2(12, 13)
	track.size = Vector2(86, 2)
	track.color = Color("263f49")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(track)
	_fill = ColorRect.new()
	_fill.position = track.position
	_fill.size.y = 2
	_fill.color = Color("8bd7d8")
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(_fill)


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.set_environment_speed_multiplier(1.0)
	if is_instance_valid(_display):
		_display.queue_free()
