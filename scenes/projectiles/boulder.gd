extends CharacterBody2D

signal shattered

const SPEED_X := 144.0
const SPEED_Y := -100.0
const GRAVITY := 360.0
const LIFETIME := 3.0

var _age := 0.0
var _broken := false


func _ready() -> void:
	add_to_group("cyclops_boulders")


func launch(facing: int) -> void:
	velocity = Vector2(facing * SPEED_X, SPEED_Y)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	$Sprite2D.rotation += delta * 3.0 * signf(velocity.x)
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return
	var body := collision.get_collider()
	if body.is_in_group("player") and body.has_method("hurt"):
		body.hurt(1)
	shatter()


func sword_hit() -> void:
	shatter()


func shatter() -> void:
	if _broken:
		return
	_broken = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	$CollisionShape2D.set_deferred("disabled", true)
	shattered.emit()
	$Sprite2D.modulate = Color(1.8, 1.8, 1.8)
	var tween := create_tween().set_parallel()
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.12)
	tween.tween_property($Sprite2D, "scale", Vector2(1.3, 1.3), 0.12)
	tween.chain().tween_callback(queue_free)
