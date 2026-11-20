extends Node2D

const Layout := preload("res://scenes/levels/level_1_layout.gd")
const LEVEL_WIDTH := Layout.WIDTH
const LEVEL_HEIGHT := Layout.HEIGHT
const ENEMY_SCENES := {
	"raider": preload("res://scenes/enemies/raider.tscn"),
	"peltast": preload("res://scenes/enemies/peltast.tscn"),
	"hoplite": preload("res://scenes/enemies/hoplite.tscn"),
}
const FLASK := preload("res://scenes/pickups/health_flask.tscn")
const CHECKPOINT := preload("res://scenes/objects/checkpoint.tscn")
const GATE := preload("res://scenes/objects/temple_gate.tscn")

@onready var pause_screen: Control = $PauseLayer/PauseScreen
@onready var pause_panel: PanelContainer = $PauseLayer/PauseScreen/Center/Panel
@onready var pause_heading: Label = $PauseLayer/PauseScreen/Center/Panel/Stack/Label
@onready var details: Label = $PauseLayer/PauseScreen/Center/Panel/Stack/Details
@onready var resume_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Resume
@onready var save_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Save
@onready var replay_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Replay
@onready var title_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Title
@onready var player = $Player
@onready var hud = $HUD

var _score := 0
var _defeated: Array[String] = []
var _collected: Array[String] = []
var _section := -1
var _complete := false
var _gate_hint_shown := false
var _death_notice_shown := false
var _shown_tips: Array[int] = []
var _gate: Node2D


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_score = LevelRun.checkpoint_score
	_defeated = LevelRun.checkpoint_defeated.duplicate()
	_collected = LevelRun.checkpoint_collected.duplicate()
	_build_encounters()
	for child in get_children():
		if child != $PauseLayer:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = LevelRun.spawn_position
	var camera := $Player/Camera2D as Camera2D
	camera.limit_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = LEVEL_WIDTH
	camera.limit_bottom = LEVEL_HEIGHT
	camera.reset_smoothing()
	camera.force_update_scroll()
	_style_pause_screen()
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.MAX_HEALTH)
	hud.set_score(_score)
	_update_section()
	hud.show_message("Reach the temple. Light shrines to save progress.", 4.5)
	if LevelRun.checkpoint_index >= 0:
		hud.show_message("Restored at shrine — health and progress recovered.", 3.5)


func _build_encounters() -> void:
	for encounter: Dictionary in Layout.ENEMIES:
		var enemy_id := String(encounter.name)
		if enemy_id in _defeated:
			continue
		var enemy = ENEMY_SCENES[encounter.kind].instantiate()
		enemy.name = enemy_id
		enemy.position = encounter.position
		enemy.direction = -1
		enemy.patrol_left = encounter.patrol.x
		enemy.patrol_right = encounter.patrol.y
		enemy.defeated.connect(_on_enemy_defeated.bind(enemy_id))
		add_child(enemy)
	for pickup: Dictionary in Layout.FLASKS:
		var pickup_id := String(pickup.name)
		if pickup_id in _collected:
			continue
		var flask = FLASK.instantiate()
		flask.name = pickup_id
		flask.position = pickup.position
		flask.collected.connect(_on_flask_collected.bind(pickup_id))
		add_child(flask)
	for index in Layout.CHECKPOINTS.size():
		var definition: Dictionary = Layout.CHECKPOINTS[index]
		var shrine = CHECKPOINT.instantiate()
		shrine.name = definition.name
		shrine.position = definition.position
		shrine.checkpoint_index = index
		shrine.spawn_position = definition.spawn
		shrine.set_lit(index <= LevelRun.checkpoint_index)
		shrine.activated.connect(_on_checkpoint_activated)
		add_child(shrine)
	_gate = GATE.instantiate()
	_gate.name = "TempleGate"
	_gate.position = Layout.EXIT
	_gate.entered.connect(_on_gate_entered)
	add_child(_gate)
	if Layout.GATE_GUARD in _defeated:
		_gate.unlock()


func _style_pause_screen() -> void:
	var theme := preload("res://scenes/ui/theme_helpers.gd")
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 1)
	panel_style.border_color = theme.GOLD
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(8)
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	for button in [resume_button, save_button, replay_button, title_button]:
		theme.style_button(button, 8)
		button.custom_minimum_size = Vector2(96, 16)
	replay_button.hide()
	details.hide()
	pause_screen.hide()


func _process(delta: float) -> void:
	if get_tree().paused or _complete:
		return
	if player.health <= 0:
		if not _death_notice_shown:
			_death_notice_shown = true
			hud.show_message("Fallen — returning to the last shrine.", 1.0, 4)
		return
	LevelRun.elapsed_seconds += delta
	_update_section()
	for index in Layout.TIPS.size():
		var tip: Dictionary = Layout.TIPS[index]
		if index not in _shown_tips and player.position.x >= tip.x and player.position.x < tip.end:
			if hud.show_message(tip.text, 4.0):
				_shown_tips.append(index)
	if player.position.x > 4512 and not _gate_hint_shown and not _gate.unlocked:
		_gate_hint_shown = true
		hud.show_message("Defeat the temple guard to open the gate.", 4.0, 2)


func _update_section() -> void:
	var current := mini(Layout.SECTIONS.size() - 1, maxi(0, int(player.position.x) / 960))
	if current == _section:
		return
	_section = current
	var title := String(Layout.SECTIONS[_section].name)
	hud.set_area(title)
	hud.show_message(title, 2.5, 0)


func _input(event: InputEvent) -> void:
	if _complete or player.health <= 0:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	if _complete:
		return
	get_tree().paused = paused
	pause_screen.visible = paused
	if paused:
		details.hide()
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_save_pressed() -> void:
	if _complete or not get_tree().paused:
		return
	details.text = "Save comes later"
	details.show()


func _on_replay_pressed() -> void:
	LevelRun.begin_run()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_health_changed(current: int, maximum: int) -> void:
	hud.set_health(current, maximum)


func _on_enemy_defeated(points: int, enemy_id: String) -> void:
	if enemy_id in _defeated:
		return
	_defeated.append(enemy_id)
	_score += points
	hud.set_score(_score)
	if enemy_id == Layout.GATE_GUARD:
		_gate.unlock()
		hud.show_message("The temple gate is open. Head inside!", 4.0, 3)


func _on_flask_collected(pickup_id: String) -> void:
	if pickup_id not in _collected:
		_collected.append(pickup_id)


func _on_checkpoint_activated(shrine: Area2D) -> void:
	if shrine.checkpoint_index <= LevelRun.checkpoint_index:
		return
	player.heal(player.MAX_HEALTH)
	LevelRun.save_checkpoint(shrine.checkpoint_index, shrine.spawn_position, _score, _defeated, _collected)
	hud.show_message("Shrine lit — progress saved and health restored.", 4.0, 3)


func _on_gate_entered() -> void:
	if _complete:
		return
	_complete = true
	get_tree().paused = true
	pause_heading.text = "Level 1 Complete"
	var seconds := int(LevelRun.elapsed_seconds)
	details.text = "The temple road is clear.\nScore %d  |  Defeated %d/%d\nTime %d:%02d" % [_score, _defeated.size(), Layout.ENEMIES.size(), seconds / 60, seconds % 60]
	details.show()
	resume_button.hide()
	save_button.hide()
	replay_button.show()
	pause_screen.show()
	replay_button.grab_focus()
