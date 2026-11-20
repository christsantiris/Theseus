extends CanvasLayer

const GOLD := Color(0.96, 0.77, 0.36)
const FILLED := Color(0.78, 0.2, 0.16)
const EMPTY := Color(0.16, 0.1, 0.12)

var _pips: Array[ColorRect] = []
var _root: Control
var _score: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var root := _root

	var label := Label.new()
	label.text = "HP"
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", GOLD)
	root.add_child(label)

	_score = Label.new()
	_score.anchor_left = 1.0
	_score.anchor_right = 1.0
	_score.offset_left = -88.0
	_score.offset_right = -8.0
	_score.offset_top = 4.0
	_score.offset_bottom = 16.0
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score.add_theme_font_size_override("font_size", 8)
	_score.add_theme_color_override("font_color", GOLD)
	_score.text = "Score 0"
	root.add_child(_score)


func set_health(current: int, maximum: int) -> void:
	while _pips.size() < maximum:
		var pip := ColorRect.new()
		pip.position = Vector2(26 + _pips.size() * 14, 6)
		pip.size = Vector2(12, 6)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(pip)
		_pips.append(pip)
	for i in _pips.size():
		_pips[i].visible = i < maximum
		_pips[i].color = FILLED if i < current else EMPTY


func set_score(value: int) -> void:
	_score.text = "Score %d" % value
