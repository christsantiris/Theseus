extends Node

const LIMIT := 5
const SAVE_PATH := "user://high_scores.cfg"
var storage_path := SAVE_PATH
var entries: Array[Dictionary] = []


func _ready() -> void:
	load_scores()


func load_scores() -> void:
	entries.clear()
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	var saved: Variant = config.get_value("scores", "entries", [])
	if not saved is Array:
		return
	var ids := {}
	for value: Variant in saved:
		if not value is Dictionary:
			continue
		var id: Variant = value.get("id")
		var score: Variant = value.get("score")
		if not id is String or id.is_empty() or ids.has(id) or not score is int or score < 0:
			continue
		ids[id] = true
		_insert({"id": id, "score": score})


func submit(score: int) -> Dictionary:
	var result := {"id": Crypto.new().generate_random_bytes(16).hex_encode(), "score": maxi(0, score)}
	_insert(result)
	_save_scores()
	return result.duplicate()


func _insert(result: Dictionary) -> void:
	var rank := entries.size()
	for index in entries.size():
		# Earlier entries win ties, including a tie for fifth place.
		if result.score > entries[index].score:
			rank = index
			break
	entries.insert(rank, result.duplicate())
	if entries.size() > LIMIT:
		entries.resize(LIMIT)


func _save_scores() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "entries", entries)
	var temporary := storage_path + ".tmp"
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
	if error != OK:
		push_warning("High scores could not be saved: %s" % error_string(error))
