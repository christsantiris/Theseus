extends CharacterBody2D

const SPEED := 168.0
const LIFE := 1.4

var kind := "spear"
var _age := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	add_to_group("thrown_weapons")
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 3)
	shape_node.shape = shape
	add_child(shape_node)


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


func _draw() -> void:
	var bronze := Color("c4a15a")
	var dark := Color("6c4c21")
	if kind == "trident":
		draw_line(Vector2(-7, 0), Vector2(4, 0), dark, 1.1, true)
		draw_line(Vector2(4, 0), Vector2(8, 0), bronze, 1.1, true)
		draw_line(Vector2(5, -2.2), Vector2(8, 0), bronze, 0.9, true)
		draw_line(Vector2(5, 2.2), Vector2(8, 0), bronze, 0.9, true)
	else:
		draw_line(Vector2(-7, 0), Vector2(5, 0), dark, 1.1, true)
		draw_line(Vector2(3, 0), Vector2(8, 0), bronze, 1.2, true)
