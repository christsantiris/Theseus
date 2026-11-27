extends Node2D

const Layout := preload("res://scenes/levels/level_1_layout.gd")
const LEVEL_WIDTH := Layout.WIDTH
const LEVEL_HEIGHT := Layout.HEIGHT
const ENEMY_SCENES := {
	"minotaur": "res://scenes/enemies/minotaur.tscn",
	"merfolk": "res://scenes/enemies/merfolk_trident.tscn",
	"reefblade": "res://scenes/enemies/merfolk_reefblade.tscn",
	"raider": "res://scenes/enemies/raider.tscn",
	"peltast": "res://scenes/enemies/peltast.tscn",
	"hoplite": "res://scenes/enemies/hoplite.tscn",
	"telchine": "res://scenes/enemies/telchine.tscn",
	"spartoi": "res://scenes/enemies/spartoi.tscn",
	"bird": "res://scenes/enemies/stymphalian_bird.tscn",
	"lamia": "res://scenes/enemies/lamia.tscn",
	"cyclops": "res://scenes/enemies/cyclops_slinger.tscn",
	"satyr": "res://scenes/enemies/satyr.tscn",
	"bronze_bull": "res://scenes/enemies/bronze_bull.tscn",
	"cerberus_pup": "res://scenes/enemies/cerberus_pup.tscn",
	"hydra": "res://scenes/enemies/hydra.tscn",
}
const TimingObstacle := preload("res://scenes/objects/timing_obstacle.gd")
const Difficulty := preload("res://scenes/levels/difficulty.gd")
const FLASK := preload("res://scenes/pickups/health_flask.tscn")
const GATE := preload("res://scenes/objects/temple_gate.tscn")
const ScoreTable := preload("res://scenes/ui/high_score_table.gd")

var layout: Script = Layout
var level_number := 1
var next_level := "res://scenes/levels/level_2.tscn"
var objective := "Reach the temple before time runs out."
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
var _results_ready := false
var _entering_temple := false
var _gate_hint_shown := false
var _death_notice_shown := false
var _shown_tips: Array[int] = []
var _gate: Node2D
var high_score_table: VBoxContainer


func _ready() -> void:
	if LevelRun.level_number != level_number:
		LevelRun.begin_level(level_number)
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_score = LevelRun.level_start_score
	LevelRun.begin_attempt(_score)
	_build_encounters()
	_build_timing_obstacle()
	for child in get_children():
		if child != $PauseLayer:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = layout.START
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
	hud.set_level_time(layout.TIME_LIMIT)
	_update_section()
	hud.show_message(objective, 4.5)
	if not next_level.is_empty():
		LevelAds.prepare()


func _build_encounters() -> void:
	_build_enemies()
	for pickup: Dictionary in layout.FLASKS:
		var pickup_id := String(pickup.name)
		var flask = FLASK.instantiate()
		flask.name = pickup_id
		flask.position = pickup.position
		flask.collected.connect(_on_flask_collected.bind(pickup_id))
		add_child(flask)
	_gate = GATE.instantiate()
	_gate.name = "TempleGate"
	_gate.position = layout.EXIT
	_gate.entry_started.connect(_on_gate_entry_started)
	_gate.entered.connect(_on_gate_entered)
	add_child(_gate)


func _build_timing_obstacle() -> void:
	_add_timing_obstacle(layout.TIMING_OBSTACLE)


func _add_timing_obstacle(definition: Dictionary) -> void:
	var obstacle := TimingObstacle.new()
	obstacle.name = definition.name
	obstacle.kind = definition.kind
	obstacle.variant = String(definition.get("variant", ""))
	obstacle.position = definition.position
	obstacle.width = definition.width
	obstacle.durations = definition.durations
	obstacle.player = player
	add_child(obstacle)


func _build_enemies() -> void:
	for encounter: Dictionary in layout.ENEMIES:
		add_child(_create_enemy(encounter))


func _create_enemy(encounter: Dictionary) -> Node2D:
	# Load only the enemy types used by this level, keeping later levels' large
	# sprite sheets out of memory until their encounters are needed.
	var enemy = load(ENEMY_SCENES[encounter.kind]).instantiate()
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
	if _complete and high_score_table != null:
		var center := pause_panel.get_parent() as Control
		var safe := MobileControls._safe_rect() if MobileControls.enabled else get_viewport().get_visible_rect()
		center.position = safe.position
		center.size = safe.size
	if get_tree().paused or _complete:
		return
	if player.health <= 0:
		if not _death_notice_shown:
			_death_notice_shown = true
			hud.show_message("Fallen.", 1.0, 4)
		return
	LevelRun.elapsed_seconds = minf(layout.TIME_LIMIT, LevelRun.elapsed_seconds + delta)
	var remaining: float = layout.TIME_LIMIT - LevelRun.elapsed_seconds
	hud.set_level_time(remaining)
	if remaining <= 0.0:
		_death_notice_shown = true
		hud.show_message("Time up!", 1.0, 4)
		player._die()
		hud.set_health(0, player.MAX_HEALTH)
		return
	_update_section()
	for index in layout.TIPS.size():
		var tip: Dictionary = layout.TIPS[index]
		if index not in _shown_tips and player.position.x >= tip.x and player.position.x < tip.end:
			if hud.show_message(tip.text, 4.0):
				_shown_tips.append(index)
	if player.position.x > layout.WIDTH - 288 and not _gate_hint_shown and not _gate.unlocked:
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
	LevelRun.restart_level()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_next_pressed() -> void:
	if not _results_ready or next_level.is_empty():
		return
	_results_ready = false
	LevelRun.begin_level(level_number + 1, _score)
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
	LevelRun.current_score = _score
	hud.set_score(_score)
	if enemy_id == layout.GATE_GUARD:
		_gate.unlock()
		hud.show_message("The temple gate is open. Head inside!", 4.0, 3)


func _on_flask_collected(pickup_id: String) -> void:
	if pickup_id not in _collected:
		_collected.append(pickup_id)


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
	pause_screen.hide()
	if next_level.is_empty():
		_show_completion_results()
	else:
		LevelAds.show_then(_show_completion_results)


func _show_completion_results() -> void:
	_results_ready = true
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
		_show_final_scores()
		replay_button.grab_focus()


func _show_final_scores() -> void:
	var stack := pause_heading.get_parent() as VBoxContainer
	var columns := HBoxContainer.new()
	columns.name = "ResultsColumns"
	columns.add_theme_constant_override("separation", 8)
	pause_panel.remove_child(stack)
	pause_panel.add_child(columns)
	columns.add_child(stack)
	stack.custom_minimum_size.x = 144
	stack.add_theme_constant_override("separation", 3)
	# Wrap the victory description so both columns fit the 320x180 view.
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	high_score_table = ScoreTable.new()
	high_score_table.name = "HighScores"
	columns.add_child(high_score_table)
	high_score_table.show_result(LevelRun.record_result())
