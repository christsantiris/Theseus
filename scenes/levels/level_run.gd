extends Node

const START := Vector2(48, 152)

var checkpoint_index := -1
var spawn_position := START
var checkpoint_score := 0
var checkpoint_defeated: Array[String] = []
var checkpoint_collected: Array[String] = []
var elapsed_seconds := 0.0


func begin_run() -> void:
	checkpoint_index = -1
	spawn_position = START
	checkpoint_score = 0
	checkpoint_defeated.clear()
	checkpoint_collected.clear()
	elapsed_seconds = 0.0


func save_checkpoint(index: int, spawn: Vector2, score: int, defeated: Array[String], collected: Array[String]) -> void:
	checkpoint_index = index
	spawn_position = spawn
	checkpoint_score = score
	checkpoint_defeated = defeated.duplicate()
	checkpoint_collected = collected.duplicate()
