extends Area2D

const GRAVITY := 720.0

var velocity := Vector2.ZERO
var _life := 2.4


func _physics_process(delta: float) -> void:
	_life -= delta
	velocity.y += GRAVITY * delta
	var motion := velocity * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, 1)
	if not space.intersect_ray(query).is_empty() or _life <= 0.0:
		queue_free()
		return
	global_position += motion
	rotation += delta * 7.0
	if _hits_player() or global_position.y > 220.0:
		queue_free()


func cut() -> void:
	queue_free()


func _hits_player() -> bool:
	var node := get_tree().get_first_node_in_group("player")
	var player := node as Node2D
	if player == null or not player.has_method("hurt"):
		return false
	var dx := absf(player.global_position.x - global_position.x)
	var dy := player.global_position.y - global_position.y
	if dx < 12.0 and dy > -4.0 and dy < 36.0:
		player.hurt(1)
		return true
	return false
