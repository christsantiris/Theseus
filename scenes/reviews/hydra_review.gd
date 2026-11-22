extends "res://scenes/levels/level_geometry.gd"

const Head := preload("res://scenes/enemies/hydra_head.gd")
const BODY_ART := preload("res://assets/art/characters/hydra_body.png")
const TheseusArt := preload("res://scenes/player/theseus_art.gd")

@onready var player = $Player
@onready var hydra = $Hydra
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
	hud.set_area("Hydra Review")
	hud.set_health(player.health, player.MAX_HEALTH)
	player.health_changed.connect(hud.set_health)
	player.speed_boost_changed.connect(hud.set_speed_boost)
	hydra.defeated.connect(_on_defeated)
	hud.show_message("Each head has 2 HP. Cut all three; jump for high heads.", 10.0)
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
	_label(gallery, "HYDRA / THREE HEADS, THREE HEALTH BARS", Vector2(8, 0), 8)
	_button(gallery, "Back", Vector2(270, 0), _toggle_gallery)
	for index in 6:
		var at := Vector2(32 + (index % 3) * 106, 86 + (index / 3) * 84)
		var captions := ["Three heads", "Two heads", "Last + Theseus", "Windup", "Bite", "Recover"]
		_label(gallery, captions[index], at + Vector2(-26, -74), 7)
		_gallery_hydra(at, [0, 1, 2] if index != 1 and index != 2 else [1, 2] if index == 1 else [2], [0, 0, 0, 2, 3, 5][index])
	var hero := Sprite2D.new()
	TheseusArt.configure_reference(hero)
	hero.position = Vector2(292, 86)
	gallery.add_child(hero)
	gallery.hide()


func _gallery_hydra(at: Vector2, remaining: Array, active_pose: int) -> void:
	var picture := Node2D.new()
	picture.position = at
	gallery.add_child(picture)
	for index in remaining:
		var height: float = [20.0, 6.0, -8.0][index]
		var pose := active_pose if index == 2 else 0
		if pose == 3:
			height = Head.BASE.y - Head.MOUTHS[3].y - 22
		var atlas := AtlasTexture.new()
		atlas.atlas = Head.ART
		atlas.region = Rect2(pose * 96 * Head.ART_SCALE, 0, 96 * Head.ART_SCALE, minf(72, 68 - height) * Head.ART_SCALE)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = atlas
		sprite.scale = Vector2.ONE / Head.ART_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2([8.0, 0.0, -8.0][index] - 24, height - 68)
		picture.add_child(sprite)
	var body := Sprite2D.new()
	body.texture = BODY_ART
	body.scale = Vector2.ONE / Head.ART_SCALE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	body.position.y = -25
	picture.add_child(body)


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
	if is_instance_valid(hydra):
		var count: int = hydra.living_heads()
		phase_label.text = "%d %s / %s" % [count, "head" if count == 1 else "heads", hydra._state.capitalize()]
	else:
		phase_label.text = "Defeated / Reset"


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
	hud.show_message("All heads defeated. Reset to review again.", 10.0, 3)
