extends Node

const STREAM := preload("res://assets/audio/music/moonpub-ancient-greek-inspired-folk-621132.mp3")
const LEVEL_2_PATH := "res://assets/audio/music/u_98673jp944-santorini-breeze-470783.mp3"
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
	var level_two: bool = scene != null and scene.get("level_number") == 2
	_play_track(LEVEL_2_PATH if level_two else STREAM.resource_path)


func _play_track(path: String) -> void:
	if path == _active_path:
		return
	# Load the coastal track only when needed, and keep it playing on replay.
	var source := load(path) as AudioStreamMP3
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = true
	_music.stream = stream
	_active_path = path
	_music.play()
