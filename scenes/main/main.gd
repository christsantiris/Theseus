extends Node2D

const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")

@onready var title_screen: Control = $UI/TitleScreen
@onready var controls_screen: Control = $UI/ControlsScreen
@onready var new_game_button: Button = $UI/TitleScreen/CenterContainer/Content/NewGame
@onready var controls_button: Button = $UI/TitleScreen/CenterContainer/Content/Controls


func _ready() -> void:
	get_tree().paused = false
	ThemeHelpers.style_button(new_game_button, 10)
	ThemeHelpers.style_button(controls_button, 10)
	new_game_button.custom_minimum_size = Vector2(96, 18)
	controls_button.custom_minimum_size = Vector2(96, 18)
	controls_screen.back_pressed.connect(_on_controls_back)
	_show_title()


func _on_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")


func _on_controls_pressed() -> void:
	title_screen.hide()
	controls_screen.show()
	controls_screen.refresh()


func _on_controls_back() -> void:
	_show_title()


func _show_title() -> void:
	controls_screen.hide()
	title_screen.show()
	new_game_button.grab_focus()
