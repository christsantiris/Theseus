extends StaticBody2D

const LIMESTONE := preload("res://assets/art/backgrounds/level_2/coastal_limestone.png")
const CAP := preload("res://assets/art/backgrounds/level_1/limestone_wall.png")
const EFFECTS := preload("res://assets/art/objects/timing_obstacles.png")
const DUST_REGION := Rect2(386, 386, 124, 124)
const DEPTH := 9.0
const CRUMBLE_DELAY := 0.5
const FALL_DURATION := 0.4
const RESET_DELAY := 2.4

var player: CharacterBody2D
var width: float
# A negative time means this slab is ready for footsteps.
var elapsed := -1.0


func _ready() -> void:
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width, DEPTH)
	var collider := CollisionShape2D.new()
	collider.shape = rectangle
	collider.position = Vector2(width / 2.0, DEPTH / 2.0)
	collider.one_way_collision = true
	add_child(collider)


func _physics_process(delta: float) -> void:
	if elapsed < 0.0:
		var feet := to_local(player.global_position)
		if player.is_on_floor() and absf(feet.y) < 1.0 and feet.x >= 0.0 and feet.x < width:
			elapsed = 0.0
		return

	elapsed += delta
	if elapsed >= CRUMBLE_DELAY + RESET_DELAY:
		elapsed = -1.0
	collision_layer = int(elapsed < CRUMBLE_DELAY)
	queue_redraw()


func _draw() -> void:
	var fall_time := elapsed - CRUMBLE_DELAY
	if fall_time >= FALL_DURATION:
		return
	var fall := maxf(0.0, fall_time) / FALL_DURATION
	var warning := elapsed >= 0.0 and fall_time < 0.0
	var shift := sin(elapsed * 95.0) * 0.45 if warning else 0.0
	draw_set_transform(Vector2(shift, 37.0 * fall * fall), fall * 0.18)
	var tint := Color(0.92, 0.88, 0.79, 1.0 - fall)
	draw_texture_rect_region(LIMESTONE, Rect2(0, 0, width - 0.5, DEPTH),
		Rect2(0, 0, width * 16, DEPTH * 16), tint)
	draw_texture_rect_region(CAP, Rect2(0, 0, width - 0.5, 3),
		Rect2(0, 96, width * 16, 48), tint)
	var crack := PackedVector2Array([
		Vector2(width * 0.53, 0), Vector2(width * 0.45, 3),
		Vector2(width * 0.56, 5), Vector2(width * 0.41, DEPTH),
	])
	draw_polyline(crack, Color(0.20, 0.16, 0.12, tint.a), 1.3 if warning else 0.8, true)
	draw_set_transform(Vector2.ZERO)
	if elapsed >= 0.0:
		var grit := fposmod(elapsed * 3.0, 1.0)
		var dust := Color(1.0, 0.91, 0.77, (1.0 - fall) * (1.0 - grit) * 0.85)
		draw_texture_rect_region(EFFECTS, Rect2(-3, 3 + grit * 9, width + 6, 8), DUST_REGION, dust)
