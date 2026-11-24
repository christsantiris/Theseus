extends RefCounted


static func isolate(store: Node) -> Callable:
	# Test deaths and victories must never modify a player's real local records.
	var original_path: String = store.storage_path
	var original_entries: Array[Dictionary] = store.entries.duplicate(true)
	store.storage_path = "user://high_scores_test_%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path))
	store.load_scores()
	return func() -> void:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path + ".tmp"))
		store.storage_path = original_path
		store.entries = original_entries
