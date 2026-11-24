extends Node

const STREAM := preload("res://assets/audio/music/moonpub-ancient-greek-inspired-folk-621132.mp3")
# Level tracks load only when needed. "start" skips an intro: playback begins
# there and every loop returns there, leaving the source file untouched.
const LEVEL_TRACKS := {
	2: {"path": "res://assets/audio/music/u_98673jp944-santorini-breeze-470783.mp3", "start": 0.0},
	# The intro fades out by 20.5 s; the first drum hit lands at about 20.6 s.
	3: {"path": "res://assets/audio/music/alex-morgan-ancient-temple-mysterious-ethnic-music-587426.mp3", "start": 20.5},
}
var _music: AudioStreamPlayer
var _active_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_music)
	get_tree().scene_changed.connect(_on_scene_changed)
	_play_track(STREAM.resource_path)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	var level = scene.get("level_number") if scene != null else null
	if LEVEL_TRACKS.has(level):
		_play_track(LEVEL_TRACKS[level].path, LEVEL_TRACKS[level].start)
	else:
		_play_track(STREAM.resource_path)


func _play_track(path: String, start := 0.0) -> void:
	if path == _active_path:
		return
	# Keep a level's track playing through replays of that level.
	var source := load(path) as AudioStreamMP3
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = true
	stream.loop_offset = start
	_music.stream = stream
	_active_path = path
	_music.play(start)
