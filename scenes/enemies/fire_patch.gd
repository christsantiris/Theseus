extends Area2D

var _life := 1.05


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	modulate = Color(1.0, 0.75 + 0.2 * sin(_life * 28.0), 0.55)
	for body in get_overlapping_bodies():
		if body.has_method("hurt"):
			body.hurt(1)
