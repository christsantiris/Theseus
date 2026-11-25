extends "res://scenes/levels/level_geometry.gd"

const TheseusArt := preload("res://scenes/player/theseus_art.gd")
const Difficulty := preload("res://scenes/levels/difficulty.gd")
const LANDSCAPE := preload("res://assets/art/backgrounds/level_7/atlantis_landscape.png")
@onready var player = $Player
@onready var hud = $HUD
var merfolk: Node
var gallery: Control
var phase: Label
var _menu_buttons: Array[Button] = []
var role := 0
var _complete := false
var _entering_temple := false


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_solid("Floor", Rect2(0, 152, 320, 28))
	_make_solid("LeftWall", Rect2(-16, -64, 16, 256))
	_make_solid("RightWall", Rect2(320, -64, 16, 256))
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 320
	camera.limit_bottom = 180
	camera.reset_smoothing()
	hud.set_area("Merfolk Review")
	player.health_changed.connect(hud.set_health)
	for item in [["Guard", 8, 0], ["Blade", 64, 1], ["Captain", 120, 2]]:
		_button($ReviewUI, item[0], Vector2(item[1], 22), _choose.bind(item[2]))
	_button($ReviewUI, "Gallery", Vector2(176, 22), _toggle_gallery)
	_button($ReviewUI, "Reset", Vector2(248, 22), _reset)
	phase = Label.new()
	phase.position = Vector2(8, 48)
	phase.add_theme_font_size_override("font_size", 7)
	$ReviewUI.add_child(phase)
	_choose(0)


func _choose(selected: int) -> void:
	get_tree().paused = false
	role = selected
	if is_instance_valid(merfolk):
		merfolk.free()
	var scene := "res://scenes/enemies/merfolk_reefblade.tscn" if role == 1 else "res://scenes/enemies/merfolk_trident.tscn"
	merfolk = load(scene).instantiate()
	merfolk.position = Vector2(232, 152)
	merfolk.direction = -1
	merfolk.patrol_left = 176
	merfolk.patrol_right = 288
	merfolk.tuning = Difficulty.for_level(8, role == 2)
	merfolk.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(merfolk)
	merfolk.defeated.connect(_on_defeated)
	player.position = Vector2(48, 152)
	player.velocity = Vector2.ZERO
	player.health = 5
	player._hurt_lock = 0.0
	hud.set_health(5, 5)
	hud.set_score(0)
	hud.show_message("Jump low blades, then counter." if role == 1 else "Duck high tridents. Stand and counter after.", 7.0)
	_build_gallery()


func _reset() -> void:
	_choose(role)


func _build_gallery() -> void:
	if is_instance_valid(gallery):
		gallery.free()
	gallery = Control.new()
	gallery.size = Vector2(320, 180)
	$ReviewUI.add_child(gallery)
	var background := ColorRect.new()
	background.size = gallery.size
	background.color = Color("10272f")
	gallery.add_child(background)
	_button(gallery, "Back", Vector2(264, 0), _toggle_gallery)
	var poses := [["walk", 0], ["walk", 1], ["walk", 2], ["walk", 3], ["windup", 0], ["strike", 0], ["recover", 0], ["hurt", 0]]
	for index in 9:
		var at := Vector2(8 + (index % 3) * 104, 16 + (index / 3) * 54)
		var label := Label.new()
		label.text = "Theseus" if index == 0 else str(poses[index - 1][0])
		label.position = at
		label.add_theme_font_size_override("font_size", 7)
		gallery.add_child(label)
		var sprite := Sprite2D.new()
		sprite.position = at + Vector2(32, 46)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if index == 0:
			TheseusArt.configure_reference(sprite)
		else:
			var pose: Array = poses[index - 1]
			sprite.texture = merfolk.sprite.sprite_frames.get_frame_texture(pose[0], pose[1])
			sprite.scale = merfolk.sprite.scale
			var number: int = index - 1
			var feet: Array = merfolk.BLADE_FEET if role == 1 else merfolk.TRIDENT_FEET
			sprite.offset = Vector2(16 if number == 5 else 0, merfolk._cell_size.y * 0.5 - feet[number])
		gallery.add_child(sprite)
	gallery.hide()


func _button(parent: Node, text: String, at: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(48, 16)
	button.focus_mode = Control.FOCUS_NONE
	preload("res://scenes/ui/theme_helpers.gd").style_button(button, 8)
	button.pressed.connect(callback)
	parent.add_child(button)
	if parent == $ReviewUI:
		_menu_buttons.append(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_gallery()
		get_viewport().set_input_as_handled()


func _toggle_gallery() -> void:
	_set_paused(not get_tree().paused)


func _process(_delta: float) -> void:
	phase.text = merfolk._state if is_instance_valid(merfolk) else "Defeated / Reset to retry"
	var controls := get_node("/root/MobileControls")
	var safe: Rect2 = controls._safe_rect() if controls.enabled else Rect2(0, 0, 320, 180)
	var width := (safe.size.x - 32.0) / 5.0
	for index in _menu_buttons.size():
		_menu_buttons[index].position = safe.position + Vector2(8 + index * (width + 4), 22)
		_menu_buttons[index].size = Vector2(width, 22 if controls.enabled else 16)
	phase.position = safe.position + Vector2(8, 48)


func _draw() -> void:
	draw_texture_rect_region(LANDSCAPE, Rect2(0, 0, 320, 180), Rect2(0, 0, LANDSCAPE.get_height() * 16.0 / 9.0, LANDSCAPE.get_height()))
	_stone(Rect2(0, 152, 320, 28))


func _on_defeated(points: int) -> void:
	hud.set_score(points)


func _set_paused(value: bool) -> void:
	gallery.visible = value
	get_tree().paused = value
