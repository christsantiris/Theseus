extends "res://scenes/levels/level_geometry.gd"

const CYCLOPS_ART := preload("res://assets/art/characters/cyclops_slinger.png")
const ART_SCALE := 8.0
const POSE_NAMES := ["Ready", "Breathe", "Lift", "Windup", "Throw", "Reload", "New stone", "Recover"]

@onready var player = $Player
@onready var cyclops = $Cyclops
@onready var hud = $HUD
var gallery: Control
var phase_label: Label


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_solid("Floor", Rect2(0, 152, 320, 32))
	_make_solid("ReviewPlatform", Rect2(160, 136, 144, 16))
	_make_solid("LeftWall", Rect2(-16, -64, 16, 256))
	_make_solid("RightWall", Rect2(320, -64, 16, 256))
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	$ReviewUI.process_mode = Node.PROCESS_MODE_ALWAYS
	var camera: Camera2D = $Player/Camera2D
	camera.limit_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 320
	camera.limit_bottom = 180
	camera.reset_smoothing()
	hud.set_area("Cyclops Review")
	hud.set_health(player.health, player.MAX_HEALTH)
	player.health_changed.connect(hud.set_health)
	cyclops.defeated.connect(_on_defeated)
	hud.show_message("Jump boulders or the close slam. Counter during recovery.", 7.0)
	_build_review_ui()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("73919c"))
	draw_rect(Rect2(0, 108, 320, 44), Color("8e9b81"))
	_column(92, 60, false)
	_column(284, 72, false)
	_stone(Rect2(0, 152, 320, 28))
	_stone(Rect2(160, 136, 144, 16))


func _build_review_ui() -> void:
	var ui := $ReviewUI
	_button(ui, "Reset", Vector2(8, 21), _on_reset)
	_button(ui, "Pose gallery", Vector2(62, 21), _toggle_gallery)
	phase_label = _label(ui, "", Vector2(151, 24), 8)
	gallery = Control.new()
	gallery.name = "PoseGallery"
	gallery.size = Vector2(320, 180)
	ui.add_child(gallery)
	var background := ColorRect.new()
	background.size = Vector2(320, 180)
	background.color = Color("111a26")
	gallery.add_child(background)
	_label(gallery, "CYCLOPS / EIGHT POSES", Vector2(8, 0), 9)
	_button(gallery, "Back", Vector2(270, 0), _toggle_gallery)
	for index in 8:
		var at := Vector2((index % 4) * 80, 16 + (index / 4) * 82)
		_label(gallery, POSE_NAMES[index], at + Vector2(2, -2), 7)
		var atlas := AtlasTexture.new()
		atlas.atlas = CYCLOPS_ART
		atlas.region = Rect2(index * 80 * ART_SCALE, 0, 80 * ART_SCALE, 80 * ART_SCALE)
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.position = at + Vector2(40, 80)
		sprite.scale = Vector2.ONE / ART_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.offset = Vector2(0, -37 * ART_SCALE)
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
	if is_instance_valid(cyclops):
		phase_label.text = "Opening: reload" if cyclops._state == "reload" else cyclops._state.capitalize()
	else:
		phase_label.text = "Defeated / Reset to retry"


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
	hud.set_score(points)
	hud.show_message("Cyclops defeated. Reset to review again.", 10.0, 3)
