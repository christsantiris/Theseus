extends CanvasLayer

const GOLD := Color(0.96, 0.77, 0.36)
const FILLED := Color(0.78, 0.2, 0.16)
const EMPTY := Color(0.16, 0.1, 0.12)

var _pips: Array[ColorRect] = []
var _root: Control
var _level_time: Label
var _score: Label
var _area: Label
var _message: Label
var _message_backdrop: Panel
var _message_time := 0.0
var _message_priority := 0
var _speed_status: Label
var _last_safe_rect := Rect2()
# On touch screens, hints sit between the button groups; this is that strip in
# HUD coordinates. Empty when the groups leave too little room.
var _message_gap := Rect2()
const MIN_MESSAGE_GAP := 96.0


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
	_level_time = Label.new()
	_level_time.name = "LevelTime"
	_level_time.anchor_left = 1.0
	_level_time.anchor_right = 1.0
	_level_time.offset_left = -80.0
	_level_time.offset_right = -8.0
	_level_time.offset_top = 20.0
	_level_time.offset_bottom = 32.0
	_level_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_level_time)
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
	if MobileControls.enabled:
		_layout_mobile()


func _process(delta: float) -> void:
	if MobileControls.enabled:
		_layout_mobile()
	if _message_time <= 0.0:
		return
	_message_time = maxf(0.0, _message_time - delta)
	if _message_time <= 0.0:
		_message.hide()
		_message_backdrop.hide()


func _layout_mobile(safe := Rect2()) -> void:
	if not safe.has_area():
		safe = MobileControls._safe_rect()
	if safe.is_equal_approx(_last_safe_rect):
		return
	_last_safe_rect = safe
	_root.offset_left = safe.position.x
	_root.offset_top = safe.position.y
	_root.offset_right = safe.end.x - get_viewport().get_visible_rect().size.x
	_root.offset_bottom = safe.end.y - get_viewport().get_visible_rect().size.y
	_area.size.x = maxf(0.0, safe.size.x - 192.0)
	_area.clip_text = true
	# Clear the pause button and Atlantis tide meter on touch screens.
	_level_time.offset_top = 44.0
	_level_time.offset_bottom = 56.0
	# Above the thumb controls: the speed timer, and hints when the bottom
	# strip is too narrow.
	var above_controls := maxf(0.0, minf(116.0, safe.size.y - 64.0))
	_speed_status.position.y = maxf(0.0, above_controls - 14.0)
	var gap: Rect2 = MobileControls.bottom_gap(safe)
	gap.position -= safe.position
	_message_gap = gap if gap.size.x >= MIN_MESSAGE_GAP else Rect2()
	if not _message_gap.has_area():
		_message.autowrap_mode = TextServer.AUTOWRAP_OFF
		_message_backdrop.position = Vector2(6, above_controls)
		_message_backdrop.size = Vector2(maxf(0.0, safe.size.x - 12.0), 17)
		_message.position = Vector2(10, above_controls + 4.0)
		_message.size = Vector2(maxf(0.0, safe.size.x - 20.0), 11)
	_place_message()


func _place_message() -> void:
	if not _message_gap.has_area():
		return
	# Wrap the hint inside the strip and grow the plaque upward to fit it,
	# keeping its base level with the bottom of the buttons.
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var width := _message_gap.size.x - 4.0
	# Measure through the label itself so its line spacing is included.
	_message.size = Vector2(width - 8.0, 0)
	var text_height := _message.get_minimum_size().y
	var height := text_height + 6.0
	_message_backdrop.position = Vector2(_message_gap.position.x + 2.0, _message_gap.end.y - height)
	_message_backdrop.size = Vector2(width, height)
	_message.position = _message_backdrop.position + Vector2(4, 4)
	_message.size = Vector2(width - 8.0, text_height)


func set_area(title: String) -> void:
	_area.text = title


func show_message(text: String, seconds: float = 3.0, priority: int = 1) -> bool:
	if _message_time > 0.0 and priority < _message_priority:
		return false
	_message.text = text
	_place_message()
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


func set_level_time(seconds_remaining: float) -> void:
	var seconds := ceili(maxf(0.0, seconds_remaining))
	_level_time.text = "Time %d:%02d" % [seconds / 60, seconds % 60]
	_level_time.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if seconds <= 30 else GOLD)
