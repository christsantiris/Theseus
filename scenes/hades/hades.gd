extends Node2D

const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")
const TheseusArt := preload("res://scenes/player/theseus_art.gd")
const SHADE := preload("res://resources/shaders/shade.gdshader")

@onready var new_game_button: Button = $UI/Menu/Content/NewGame
@onready var load_button: Button = $UI/Menu/Content/LoadGame


func _ready() -> void:
	get_tree().paused = false
	var shade := AnimatedSprite2D.new()
	shade.name = "Theseus"
	TheseusArt.configure(shade)
	shade.position = Vector2(56, 151)
	var wash := ShaderMaterial.new()
	wash.shader = SHADE
	shade.material = wash
	shade.modulate = Color.WHITE
	shade.z_index = 1
	$UI.add_child(shade)
	$UI.move_child(shade, 1)
	shade.play("idle")
	for button in [new_game_button, load_button]:
		ThemeHelpers.style_button(button, 8)
		button.custom_minimum_size = Vector2(96, 16)
	new_game_button.grab_focus()


func new_game() -> void:
	LevelRun.begin_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")


func load_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LevelRun.scene_path())


func _on_new_game_pressed() -> void:
	new_game()


func _on_load_game_pressed() -> void:
	load_game()
