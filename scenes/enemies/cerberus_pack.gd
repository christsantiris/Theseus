extends Node2D

# Place this scene to get exactly two pups with a shared patrol and attack turn.
@export var direction := -1
@export var patrol_half_width := 96.0
var _attacker: Node
var _preferred: Node
var _gap := 0.0


func _ready() -> void:
	for pup in get_children():
		pup.pack = self
		pup.direction = direction
		pup.patrol_left = global_position.x - patrol_half_width
		pup.patrol_right = global_position.x + patrol_half_width


func _physics_process(delta: float) -> void:
	_gap = maxf(0, _gap - delta)
	for pup in get_children():
		if pup.alive and pup._has_focus:
			return
	# Turn the pair together; independent patrol turns leave them nose-to-nose
	# and unable to pass their partner's spacing boundary.
	var turn := false
	for pup in get_children():
		if not pup.alive or pup._state != "run":
			continue
		pup.direction = direction
		if not pup.is_on_floor():
			continue
		var at_end: bool = pup.global_position.x <= pup.patrol_left + 16 if direction < 0 else pup.global_position.x >= pup.patrol_right - 16
		turn = turn or at_end or not pup._floor_ahead() or pup._wall_ahead()
	if turn:
		direction *= -1
		for pup in get_children():
			if pup.alive and pup._state == "run":
				pup.direction = direction


func share_focus(source: Node) -> void:
	for pup in get_children():
		if pup != source and pup.alive and pup._player_close(pup.FOCUS_RANGE, pup.FOCUS_HEIGHT):
			pup._has_focus = true


func request_attack(pup: Node) -> bool:
	if _gap > 0 or (is_instance_valid(_attacker) and _attacker.alive):
		return false
	if is_instance_valid(_preferred) and _preferred != pup and _preferred.ready_to_pounce():
		return false
	_attacker = pup
	return true


func release_attack(pup: Node) -> void:
	if _attacker != pup:
		return
	_attacker = null
	_gap = 0.3
	_preferred = null
	for other in get_children():
		if other != pup and other.alive:
			_preferred = other
