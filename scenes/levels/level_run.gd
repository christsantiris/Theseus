extends Node

# Score carried in from earlier levels; Replay restarts the level from here.
var level_start_score := 0
var elapsed_seconds := 0.0
var level_number := 1
var current_score := 0
var _result := {}


func begin_attempt(score: int) -> void:
	current_score = score
	elapsed_seconds = 0.0
	_result.clear()


func record_result() -> Dictionary:
	# A result screen can be reopened without filling the table with duplicates.
	if _result.is_empty():
		_result = HighScores.submit(current_score)
	return _result.duplicate()


func begin_run() -> void:
	begin_level(1)


func begin_level(number: int, carried_score := 0) -> void:
	begin_attempt(carried_score)
	level_number = number
	level_start_score = carried_score


func restart_level() -> void:
	begin_level(level_number, level_start_score)


func scene_path() -> String:
	return "res://scenes/levels/level_%d.tscn" % level_number


func can_load() -> bool:
	# Continue is available after reaching a later level in this session.
	return level_number > 1
