extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var music: Node = root.get_node("GameMusic")
	for number in range(1, 9):
		var definition: Dictionary = music.LEVEL_TRACKS.get(number, {"path": music.STREAM.resource_path, "start": 0.0})
		music._play_track(definition.path, definition.start)
		var stream: AudioStreamMP3 = music._music.stream
		var offset: float = {3: 20.5, 5: 21.0, 6: 62.0}.get(number, 0.0)
		_expect(stream.loop and is_equal_approx(stream.loop_offset, offset), "Level %d keeps its configured music loop start" % number)
		_expect(stream.get_length() > offset, "Level %d has playable music after its start offset" % number)
		# Decode across the real MP3 ending instead of only checking its loop flag.
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start(stream.get_length() - 0.02)
		var samples := playback.mix_audio(1.0, 8192)
		_expect(samples.size() == 8192 and playback.is_playing() and playback.get_loop_count() > 0, "Level %d soundtrack continues through the end of the file" % number)
		_expect(playback.get_playback_position() >= offset and playback.get_playback_position() < offset + 1.0, "Level %d loops back to the selected music start" % number)
		playback.stop()
	music._music.stop()
	music._music.stream = null
	print("PASS: all eight level soundtracks decode across file endings and continue looping at their selected offsets." if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
