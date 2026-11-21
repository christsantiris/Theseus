extends CanvasLayer

const GOLD := Color(0.96, 0.77, 0.36)
const FILLED := Color(0.78, 0.2, 0.16)
const EMPTY := Color(0.16, 0.1, 0.12)

var _pips: Array[ColorRect] = []
var _root: Control
var _score: Label
var _area: Label
var _message: Label
var _message_backdrop: Panel
var _message_time := 0.0
var _message_priority := 0
var _speed_status: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var root := _root

	var label := Label.new()
	label.text = "HP"
	label.position = Vector2(8, 4)
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
	_score.add_theme_color_override("font_color", GOLD)
	_score.text = "Score 0"
	root.add_child(_score)
	_area = Label.new()
	_area.position = Vector2(104, 4)
	_area.size = Vector2(128, 12)
	_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_area)
	_speed_status = Label.new()
	_speed_status.position = Vector2(8, 148)
	_speed_status.add_theme_color_override("font_color", GOLD)
	_speed_status.hide()
	root.add_child(_speed_status)
	# Messages are incised into a marble plaque (the theme's Panel style).
	_message_backdrop = Panel.new()
	_message_backdrop.position = Vector2(6, 161)
	_message_backdrop.size = Vector2(308, 17)
	_message_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message_backdrop)
	_message = Label.new()
	_message.position = Vector2(10, 165)
	_message.size = Vector2(300, 11)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.theme_type_variation = &"CarvedLabel"
	root.add_child(_message)
	_message.hide()
	_message_backdrop.hide()


func _process(delta: float) -> void:
	if _message_time <= 0.0:
		return
	_message_time = maxf(0.0, _message_time - delta)
	if _message_time <= 0.0:
		_message.hide()
		_message_backdrop.hide()


func set_area(title: String) -> void:
	_area.text = title


func show_message(text: String, seconds: float = 3.0, priority: int = 1) -> bool:
	if _message_time > 0.0 and priority < _message_priority:
		return false
	_message.text = text
	_message_time = seconds
	_message_priority = priority
	_message.show()
	_message_backdrop.show()
	return true


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


func set_speed_boost(seconds_remaining: int) -> void:
	_speed_status.text = "Swift %ds" % seconds_remaining
	_speed_status.visible = seconds_remaining > 0
