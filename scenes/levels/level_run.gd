extends Node

const START := Vector2(48, 152)

var checkpoint_index := -1
var spawn_position := START
var checkpoint_score := 0
var checkpoint_defeated: Array[String] = []
var checkpoint_collected: Array[String] = []
var elapsed_seconds := 0.0
var level_number := 1


func begin_run() -> void:
	begin_level(1)


func begin_level(number: int) -> void:
	level_number = number
	checkpoint_index = -1
	spawn_position = START if number == 1 else Vector2(48, 280)
	checkpoint_score = 0
	checkpoint_defeated.clear()
	checkpoint_collected.clear()
	elapsed_seconds = 0.0


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
