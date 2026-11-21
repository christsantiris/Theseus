extends Node2D

const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")

@onready var title_screen: Control = $UI/TitleScreen
@onready var controls_screen: Control = $UI/ControlsScreen
@onready var menu: PanelContainer = $UI/TitleScreen/Menu
@onready var new_game_button: Button = $UI/TitleScreen/Menu/Content/NewGame
@onready var load_button: Button = $UI/TitleScreen/Menu/Content/Load
@onready var controls_button: Button = $UI/TitleScreen/Menu/Content/Controls
@onready var hint: Label = $UI/TitleScreen/Menu/Content/Hint


func _ready() -> void:
	get_tree().paused = false
	for button in [new_game_button, load_button, controls_button]:
		ThemeHelpers.style_button(button, 8)
		button.custom_minimum_size = Vector2(96, 16)
	controls_screen.back_pressed.connect(_on_controls_back)
	_show_title()


func _on_new_game_pressed() -> void:
	LevelRun.begin_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")


func _on_load_pressed() -> void:
	if not LevelRun.can_load():
		hint.text = "No shrine lit yet"
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(LevelRun.scene_path())


func _on_controls_pressed() -> void:
	title_screen.hide()
	controls_screen.show()
	controls_screen.refresh()


func _on_controls_back() -> void:
	_show_title()


func _show_title() -> void:
	hint.text = ""
	controls_screen.hide()
	title_screen.show()
	new_game_button.grab_focus()
