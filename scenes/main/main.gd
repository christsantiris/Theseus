extends Node2D

const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")
const TheseusArt := preload("res://scenes/player/theseus_art.gd")

@onready var title_screen: Control = $UI/TitleScreen
@onready var controls_screen: Control = $UI/ControlsScreen
@onready var menu: PanelContainer = $UI/TitleScreen/Menu
@onready var new_game_button: Button = $UI/TitleScreen/Menu/Content/NewGame
@onready var load_button: Button = $UI/TitleScreen/Menu/Content/Load
@onready var controls_button: Button = $UI/TitleScreen/Menu/Content/Controls
@onready var hint: Label = $UI/TitleScreen/Menu/Content/Hint
var privacy_button: Button


func _ready() -> void:
	get_tree().paused = false
	var hero := AnimatedSprite2D.new()
	hero.name = "Theseus"
	TheseusArt.configure(hero)
	hero.position = Vector2(80, 151)
	# Stay in front of the painted coast and behind both menus.
	hero.z_index = 1
	title_screen.z_index = 2
	controls_screen.z_index = 3
	$UI.add_child(hero)
	$UI.move_child(hero, 1)
	hero.play("idle")
	# Google requires a way to reopen the ad consent choices where consent applies.
	privacy_button = Button.new()
	privacy_button.name = "PrivacyChoices"
	privacy_button.text = "Privacy Choices"
	privacy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	privacy_button.pressed.connect(LevelAds.show_privacy_options)
	controls_button.add_sibling(privacy_button)
	for button in [new_game_button, load_button, controls_button, privacy_button]:
		ThemeHelpers.style_button(button, 8)
		button.custom_minimum_size = Vector2(96, 16)
	LevelAds.consent_changed.connect(_update_privacy_button)
	_update_privacy_button()
	controls_screen.back_pressed.connect(_on_controls_back)
	_show_title()


func _update_privacy_button() -> void:
	privacy_button.visible = LevelAds.privacy_options_required()


func _on_new_game_pressed() -> void:
	LevelRun.begin_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")


func _on_load_pressed() -> void:
	if not LevelRun.can_load():
		hint.text = "Reach Level 2 to continue"
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
