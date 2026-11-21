extends "res://scenes/levels/level_geometry.gd"

const PUP_ART := preload("res://assets/art/characters/cerberus_pup.png")
const TheseusArt := preload("res://scenes/player/theseus_art.gd")
const POSE_NAMES := ["Ready", "Run 1", "Run 2", "Run 3", "Run 4", "Windup", "Pounce", "Land"]

@onready var player = $Player
@onready var pack = $CerberusPack
var _score := 0
var _remaining := 2
@onready var hud = $HUD
var gallery: Control
var phase_label: Label


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_solid("Floor", Rect2(0, 152, 640, 32))
	_make_solid("EscapePlatform", Rect2(360, 128, 96, 24))
	_make_solid("LeftWall", Rect2(-16, -64, 16, 256))
	_make_solid("RightWall", Rect2(640, -64, 16, 256))
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	$ReviewUI.process_mode = Node.PROCESS_MODE_ALWAYS
	var camera: Camera2D = $Player/Camera2D
	camera.limit_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 640
	camera.limit_bottom = 180
	camera.reset_smoothing()
	hud.set_area("Cerberus Pup Review")
	hud.set_health(player.health, player.MAX_HEALTH)
	player.health_changed.connect(hud.set_health)
	player.speed_boost_changed.connect(hud.set_speed_boost)
	for pup in pack.get_children():
		pup.defeated.connect(_on_defeated)
	hud.show_message("Two pups. Jump the leap, or strike during windup.", 10.0)
	_build_review_ui()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 180), Color("73919c"))
	draw_rect(Rect2(0, 108, 640, 44), Color("8e9b81"))
	_column(92, 60, false)
	_column(284, 72, false)
	_stone(Rect2(0, 152, 640, 28))
	_stone(Rect2(360, 128, 96, 24))


func _build_review_ui() -> void:
	var ui := $ReviewUI
	_button(ui, "Reset", Vector2(8, 21), _on_reset)
	_button(ui, "Pose gallery", Vector2(62, 21), _toggle_gallery)
	phase_label = _label(ui, "", Vector2(204, 24), 8)
	gallery = Control.new()
	gallery.name = "PoseGallery"
	gallery.size = Vector2(320, 180)
	ui.add_child(gallery)
	var background := ColorRect.new()
	background.size = Vector2(320, 180)
	background.color = Color("111a26")
	gallery.add_child(background)
	_label(gallery, "CERBERUS PUP / THESEUS SCALE", Vector2(8, 0), 9)
	_button(gallery, "Back", Vector2(270, 0), _toggle_gallery)
	for index in 9:
		var at := Vector2(16 + (index % 3) * 96, 14 + (index / 3) * 54)
		_label(gallery, "Theseus" if index == 0 else POSE_NAMES[index - 1], at + Vector2(2, -2), 7)
		var atlas := AtlasTexture.new()
		atlas.atlas = PUP_ART
		atlas.region = Rect2(maxi(0, index - 1) * 72, 0, 72, 56)
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.position = at + Vector2(44, 52)
		sprite.offset = Vector2(0, -25)
		if index == 0:
			TheseusArt.configure_reference(sprite)
		gallery.add_child(sprite)
	gallery.hide()


func _label(parent: Node, text: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f2dbab"))
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, at: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = at
	button.custom_minimum_size = Vector2(48, 14)
	preload("res://scenes/ui/theme_helpers.gd").style_button(button, 8)
	button.pressed.connect(callback)
	parent.add_child(button)


func _process(_delta: float) -> void:
	var states: Array[String] = []
	for pup in pack.get_children():
		if pup.alive:
			states.append(pup._state.capitalize())
	phase_label.text = " / ".join(states) if not states.is_empty() else "Defeated / Reset"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_gallery()
		get_viewport().set_input_as_handled()


func _toggle_gallery() -> void:
	gallery.visible = not gallery.visible
	get_tree().paused = gallery.visible


func _on_reset() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_defeated(points: int) -> void:
	_score += points
	_remaining -= 1
	hud.set_score(_score)
	hud.show_message("Pack defeated. Reset to review again." if _remaining == 0 else "One pup remains.", 10.0, 3)
