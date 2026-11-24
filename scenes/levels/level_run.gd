extends Node

const START := Vector2(48, 152)

var checkpoint_index := -1
var spawn_position := START
var checkpoint_score := 0
# Score carried in from earlier levels; Replay restarts the level from here.
var level_start_score := 0
var checkpoint_defeated: Array[String] = []
var checkpoint_collected: Array[String] = []
var elapsed_seconds := 0.0
var level_number := 1
var current_score := 0
var _result := {}


func begin_attempt(score: int) -> void:
	current_score = score
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
	checkpoint_index = -1
	spawn_position = START if number == 1 else Vector2(48, 280)
	level_start_score = carried_score
	checkpoint_score = carried_score
	checkpoint_defeated.clear()
	checkpoint_collected.clear()
	elapsed_seconds = 0.0


func restart_level() -> void:
	begin_level(level_number, level_start_score)


func scene_path() -> String:
	return "res://scenes/levels/level_%d.tscn" % level_number


func can_load() -> bool:
	# Reaching a later level saves its entrance before any shrine is lit.
	return level_number > 1 or checkpoint_index >= 0


func save_checkpoint(index: int, spawn: Vector2, score: int, defeated: Array[String], collected: Array[String]) -> void:
	checkpoint_index = index
	spawn_position = spawn
	checkpoint_score = score
	checkpoint_defeated = defeated.duplicate()
	checkpoint_collected = collected.duplicate()
