extends Area2D


func attack_target() -> Node:
	# Body and back share one receiver, so a single swing cannot double-hit.
	return get_parent()
