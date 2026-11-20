extends Node

const STREAM := preload("res://assets/audio/music/moonpub-ancient-greek-inspired-folk-621132.mp3")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var music := AudioStreamPlayer.new()
	music.bus = "Music"
	music.process_mode = Node.PROCESS_MODE_PAUSABLE
	var stream := STREAM.duplicate() as AudioStreamMP3
	stream.loop = true
	music.stream = stream
	add_child(music)
	music.play()
