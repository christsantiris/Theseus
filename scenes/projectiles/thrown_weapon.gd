extends CharacterBody2D

const SPEED := 168.0
const LIFE := 1.4
const ART := preload("res://assets/art/projectiles/javelin.png")
# Ignore faint alpha specks outside the painted weapon; keep the source intact.
const ART_REGION := Rect2(66, 327, 2029, 77)
const ART_BOUNDS := Rect2(-26, -1.5, 44, 3)

var kind := "javelin"
var _age := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	add_to_group("thrown_weapons")
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 3)
	shape_node.position = Vector2(12, 0)
	shape_node.shape = shape
	add_child(shape_node)
	var sprite := Sprite2D.new()
	sprite.name = "JavelinArt"
	sprite.texture = ART
	sprite.region_enabled = true
	sprite.region_rect = ART_REGION
	sprite.region_filter_clip_enabled = true
	sprite.centered = false
	sprite.position = ART_BOUNDS.position
	sprite.scale = ART_BOUNDS.size / ART_REGION.size
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)


func launch(facing: int, weapon: String) -> void:
	kind = weapon
	velocity = Vector2(facing * SPEED, 0.0)
	rotation = 0.0 if facing > 0 else PI


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return
	var body := collision.get_collider()
	if body != null and body.is_in_group("player") and body.has_method("hurt"):
		body.hurt(1)
	queue_free()
