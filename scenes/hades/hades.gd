extends Node2D

const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")
const TheseusArt := preload("res://scenes/player/theseus_art.gd")
const SHADE := preload("res://resources/shaders/shade.gdshader")
const ScoreTable := preload("res://scenes/ui/high_score_table.gd")
var high_score_table: VBoxContainer

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
	$UI/Menu/Content/Meander.hide()
	$UI/Menu/Content/Subtitle.hide()
	$UI/Menu/Content.add_theme_constant_override("separation", 1)
	high_score_table = ScoreTable.new()
	high_score_table.name = "HighScores"
	$UI/Menu/Content.add_child(high_score_table)
	$UI/Menu/Content.move_child(high_score_table, 1)
	high_score_table.show_result(LevelRun.record_result())
	var panel: PanelContainer = $UI/Menu
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -72
	panel.offset_right = 72
	panel.offset_top = -82
	panel.offset_bottom = 82
	new_game_button.grab_focus()


func _process(_delta: float) -> void:
	var safe := MobileControls._safe_rect() if MobileControls.enabled else get_viewport().get_visible_rect()
	var panel: PanelContainer = $UI/Menu
	panel.position = safe.get_center() - panel.size * 0.5


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
