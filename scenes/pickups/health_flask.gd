extends Area2D

const HEAL := 2

var _time := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	_time += delta
	sprite.position.y = -8.0 + sin(_time * 3.0)
	for body in get_overlapping_bodies():
		if body.has_method("heal") and body.heal(HEAL):
			queue_free()
			return
