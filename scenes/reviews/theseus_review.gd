extends Node2D

const Art := preload("res://scenes/player/theseus_art.gd")
const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")
const NAMES := ["idle", "walk", "duck", "jump_rise", "jump_fall", "attack", "swing", "down_thrust", "hurt", "death"]
const TITLES := ["Idle / breathe", "Walk", "Crouch", "Jump / rise", "Jump / fall", "Sword thrust", "Sword swing", "Downward thrust", "Hurt", "Death"]

var preview: AnimatedSprite2D
var _selected := 0
var _restart_left := 0.0
var _slow := false
var _held := false
var _status: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	get_tree().paused = false
	preview = AnimatedSprite2D.new()
	Art.configure(preview)
	preview.scale *= 2.0
	add_child(preview)
	preview.animation_finished.connect(func() -> void: _restart_left = 0.35)
	_label("THESEUS / CINEMATIC", Vector2(10, 4), 11)
	_label("Animation review", Vector2(10, 19), 7)
	for index in NAMES.size():
		var button := _button(TITLES[index], Vector2(10, 32 + index * 12), func() -> void: _select(index))
		button.custom_minimum_size.x = 106
		_buttons.append(button)
	_button("Flip", Vector2(144, 23), func() -> void: preview.flip_h = not preview.flip_h)
	_button("Slow", Vector2(187, 23), _toggle_slow)
	_button("Hold", Vector2(234, 23), _toggle_hold)
	_button("Play level 1", Vector2(10, 158), _play_level)
	_status = _label("", Vector2(143, 164), 7)
	_select(0)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("101923"))
	draw_rect(Rect2(133, 42, 179, 117), Color("1e2933"))
	draw_line(Vector2(138, 148), Vector2(307, 148), Color("665846"), 0.5)


func _process(delta: float) -> void:
	if _restart_left > 0.0 and not _held:
		_restart_left -= delta * (0.25 if _slow else 1.0)
		if _restart_left <= 0.0:
			preview.stop()
			preview.play(NAMES[_selected])
	_status.text = "Frame %d / %d   %s" % [preview.frame + 1, preview.sprite_frames.get_frame_count(preview.animation), "Held" if _held else "1/4 speed" if _slow else "2x view"]


func _select(index: int) -> void:
	_selected = index
	_restart_left = 0.0
	preview.stop()
	preview.position = Vector2(224, 132 if NAMES[index] == "down_thrust" else 148)
	Art.anchor(preview, NAMES[index])
	preview.play(NAMES[index])
	for at in _buttons.size():
		_buttons[at].modulate = Color("e8bd76") if at == index else Color.WHITE


func _toggle_slow() -> void:
	_slow = not _slow
	_update_speed()


func _toggle_hold() -> void:
	_held = not _held
	_update_speed()


func _update_speed() -> void:
	preview.speed_scale = 0.0 if _held else 0.25 if _slow else 1.0


func _play_level() -> void:
	get_node("/root/LevelRun").begin_level(1)
	get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")


func _label(text: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e6d2ad"))
	add_child(label)
	return label


func _button(text: String, at: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(40, 12)
	button.focus_mode = Control.FOCUS_NONE
	ThemeHelpers.style_button(button, 7)
	button.pressed.connect(callback)
	add_child(button)
	return button
