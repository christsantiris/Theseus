extends CharacterBody2D

signal collected

const BOOST_SECONDS := 6.0
const LIFETIME := 18.0
var _age := 0.0
var _collected := false


func _ready() -> void:
	velocity.y = -90.0
	add_to_group("stolen_wine")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if not is_on_floor():
		velocity.y += 600.0 * delta
	move_and_slide()
	$Sprite2D.position.y = -8.0 + sin(_age * 3.0)
	$Sprite2D.modulate.a = 0.45 if _age > LIFETIME - 3.0 and int(_age * 8) % 2 == 0 else 1.0
	for body in $Collect.get_overlapping_bodies():
		if _collected or not body.is_in_group("player") or not body.has_method("grant_speed_boost"):
			continue
		if body.grant_speed_boost(BOOST_SECONDS):
			_collected = true
			collected.emit()
			queue_free()
			return
