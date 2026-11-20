extends Node2D

const LEVEL_WIDTH := 960
const LEVEL_HEIGHT := 180

@onready var pause_screen: Control = $PauseLayer/PauseScreen
@onready var pause_panel: PanelContainer = $PauseLayer/PauseScreen/Center/Panel
@onready var resume_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Resume
@onready var title_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Title


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		if child == $PauseLayer:
			continue
		child.process_mode = Node.PROCESS_MODE_PAUSABLE

	var camera := $Player/Camera2D as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = LEVEL_WIDTH
	camera.limit_bottom = LEVEL_HEIGHT

	var theme := preload("res://scenes/ui/theme_helpers.gd")
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 1)
	panel_style.border_color = theme.GOLD
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(8)
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	theme.style_button(resume_button, 8)
	theme.style_button(title_button, 8)
	resume_button.custom_minimum_size = Vector2(72, 16)
	title_button.custom_minimum_size = Vector2(72, 16)
	pause_screen.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_screen.visible = paused
	if paused:
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
