extends Node2D

const Layout := preload("res://scenes/levels/level_1_layout.gd")
const LEVEL_WIDTH := Layout.WIDTH
const LEVEL_HEIGHT := Layout.HEIGHT
const ENEMY_SCENES := {
	"raider": preload("res://scenes/enemies/raider.tscn"),
	"peltast": preload("res://scenes/enemies/peltast.tscn"),
	"hoplite": preload("res://scenes/enemies/hoplite.tscn"),
	"telchine": preload("res://scenes/enemies/telchine.tscn"),
	"spartoi": preload("res://scenes/enemies/spartoi.tscn"),
	"bird": preload("res://scenes/enemies/stymphalian_bird.tscn"),
	"lamia": preload("res://scenes/enemies/lamia.tscn"),
	"cyclops": preload("res://scenes/enemies/cyclops_slinger.tscn"),
	"satyr": preload("res://scenes/enemies/satyr.tscn"),
	"bronze_bull": preload("res://scenes/enemies/bronze_bull.tscn"),
	"cerberus_pup": preload("res://scenes/enemies/cerberus_pup.tscn"),
	"hydra": preload("res://scenes/enemies/hydra.tscn"),
}
const Difficulty := preload("res://scenes/levels/difficulty.gd")
const FLASK := preload("res://scenes/pickups/health_flask.tscn")
const CHECKPOINT := preload("res://scenes/objects/checkpoint.tscn")
const GATE := preload("res://scenes/objects/temple_gate.tscn")

var layout: Script = Layout
var level_number := 1
var next_level := "res://scenes/levels/level_2.tscn"
var objective := "Reach the temple. Light shrines to save progress."
var completion_text := "The temple road is clear."

@onready var pause_screen: Control = $PauseLayer/PauseScreen
@onready var pause_panel: PanelContainer = $PauseLayer/PauseScreen/Center/Panel
@onready var pause_heading: Label = $PauseLayer/PauseScreen/Center/Panel/Stack/Label
@onready var details: Label = $PauseLayer/PauseScreen/Center/Panel/Stack/Details
@onready var resume_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Resume
@onready var replay_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Replay
@onready var next_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Next
@onready var title_button: Button = $PauseLayer/PauseScreen/Center/Panel/Stack/Buttons/Title
@onready var player = $Player
@onready var hud = $HUD

var _score := 0
var _defeated: Array[String] = []
var _collected: Array[String] = []
var _section := -1
var _complete := false
var _entering_temple := false
var _gate_hint_shown := false
var _death_notice_shown := false
var _shown_tips: Array[int] = []
var _gate: Node2D


func _ready() -> void:
	if LevelRun.level_number != level_number:
		LevelRun.begin_level(level_number)
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
	camera.limit_right = layout.WIDTH
	camera.limit_bottom = layout.HEIGHT
	if level_number == 1:
		camera.position.y = -24
	camera.reset_smoothing()
	camera.force_update_scroll()
	_style_pause_screen()
	player.health_changed.connect(_on_health_changed)
	player.speed_boost_changed.connect(hud.set_speed_boost)
	_on_health_changed(player.health, player.MAX_HEALTH)
	hud.set_score(_score)
	_update_section()
	hud.show_message(objective, 4.5)
	if LevelRun.checkpoint_index >= 0:
		hud.show_message("Restored at shrine — progress recovered.", 3.5)


func _build_encounters() -> void:
	_build_enemies()
	for pickup: Dictionary in layout.FLASKS:
		var pickup_id := String(pickup.name)
		if pickup_id in _collected:
			continue
		var flask = FLASK.instantiate()
		flask.name = pickup_id
		flask.position = pickup.position
		flask.collected.connect(_on_flask_collected.bind(pickup_id))
		add_child(flask)
	for index in layout.CHECKPOINTS.size():
		var definition: Dictionary = layout.CHECKPOINTS[index]
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
	_gate.position = layout.EXIT
	_gate.entry_started.connect(_on_gate_entry_started)
	_gate.entered.connect(_on_gate_entered)
	add_child(_gate)
	if layout.GATE_GUARD in _defeated:
		_gate.unlock()


func _build_enemies() -> void:
	for encounter: Dictionary in layout.ENEMIES:
		if encounter.name not in _defeated:
			add_child(_create_enemy(encounter))


func _create_enemy(encounter: Dictionary) -> Node2D:
	var enemy = ENEMY_SCENES[encounter.kind].instantiate()
	enemy.name = encounter.name
	enemy.position = encounter.position
	enemy.direction = -1
	enemy.patrol_left = encounter.patrol.x
	enemy.patrol_right = encounter.patrol.y
	# The Hydra is already a multi-head boss, so only ordinary gate guards gain
	# the elite health bonus.
	var elite: bool = encounter.name == layout.GATE_GUARD and encounter.kind != "hydra"
	enemy.tuning = Difficulty.for_level(level_number, elite)
	enemy.defeated.connect(_on_enemy_defeated.bind(String(encounter.name)))
	return enemy


func _style_pause_screen() -> void:
	var theme := preload("res://scenes/ui/theme_helpers.gd")
	for button in [resume_button, next_button, replay_button, title_button]:
		theme.style_button(button, 8)
		button.custom_minimum_size = Vector2(96, 16)
	replay_button.hide()
	next_button.hide()
	details.hide()
	pause_screen.hide()


func _process(delta: float) -> void:
	if get_tree().paused or _complete:
		return
	if player.health <= 0:
		if not _death_notice_shown:
			_death_notice_shown = true
			hud.show_message("Fallen.", 1.0, 4)
		return
	LevelRun.elapsed_seconds += delta
	_update_section()
	for index in layout.TIPS.size():
		var tip: Dictionary = layout.TIPS[index]
		if index not in _shown_tips and player.position.x >= tip.x and player.position.x < tip.end:
			if hud.show_message(tip.text, 4.0):
				_shown_tips.append(index)
	if player.position.x > 4512 and not _gate_hint_shown and not _gate.unlocked:
		_gate_hint_shown = true
		hud.show_message("Defeat the temple guard to open the gate.", 4.0, 2)


func _update_section() -> void:
	var current := mini(layout.SECTIONS.size() - 1, maxi(0, int(player.position.x) / 960))
	if current == _section:
		return
	_section = current
	var title := String(layout.SECTIONS[_section].name)
	hud.set_area(title)
	hud.show_message(title, 2.5, 0)


func _input(event: InputEvent) -> void:
	if _complete or _entering_temple or player.health <= 0:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	if _complete or _entering_temple:
		return
	get_tree().paused = paused
	pause_screen.visible = paused
	if paused:
		details.hide()
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_replay_pressed() -> void:
	LevelRun.begin_level(level_number)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_next_pressed() -> void:
	if not _complete or next_level.is_empty():
		return
	LevelRun.begin_level(level_number + 1)
	get_tree().paused = false
	get_tree().change_scene_to_file(next_level)


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
	if enemy_id == layout.GATE_GUARD:
		_gate.unlock()
		hud.show_message("The temple gate is open. Head inside!", 4.0, 3)


func _on_flask_collected(pickup_id: String) -> void:
	if pickup_id not in _collected:
		_collected.append(pickup_id)


func _on_checkpoint_activated(shrine: Area2D) -> void:
	if shrine.checkpoint_index <= LevelRun.checkpoint_index:
		return
	LevelRun.save_checkpoint(shrine.checkpoint_index, shrine.spawn_position, _score, _defeated, _collected)
	hud.show_message("Shrine lit — progress saved.", 4.0, 3)


func _on_gate_entry_started(body: Node2D) -> void:
	_entering_temple = true
	body.set_physics_process(false)
	body.velocity = Vector2.ZERO
	get_tree().paused = true


func _on_gate_entered() -> void:
	if _complete:
		return
	_complete = true
	_entering_temple = false
	get_tree().paused = true
	pause_heading.text = "Level %d Complete" % level_number
	var seconds := int(LevelRun.elapsed_seconds)
	details.text = "%s\nScore %d  |  Defeated %d/%d\nTime %d:%02d" % [completion_text, _score, _defeated.size(), layout.ENEMIES.size(), seconds / 60, seconds % 60]
	details.show()
	resume_button.hide()
	replay_button.show()
	next_button.visible = not next_level.is_empty()
	next_button.text = "Continue to Level %d" % (level_number + 1)
	pause_screen.show()
	if next_button.visible:
		next_button.grab_focus()
	else:
		replay_button.grab_focus()
