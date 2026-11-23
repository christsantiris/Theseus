extends Control

signal back_pressed

const ThemeHelpers := preload("res://scenes/ui/theme_helpers.gd")

var _rows: VBoxContainer
var _hint: Label
var _listening_action := ""
var _listening_index := -1


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var slab := PanelContainer.new()
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(slab)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_child(_rows)
	refresh()


func refresh() -> void:
	while _rows.get_child_count() > 0:
		var child := _rows.get_child(0)
		_rows.remove_child(child)
		child.free()

	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"CarvedHeading"
	_rows.add_child(title)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.theme_type_variation = &"CarvedLabel"
	_hint.text = "Landscape touch controls" if MobileControls.enabled else "Click a key, then press a new one"
	_rows.add_child(_hint)

	if MobileControls.enabled:
		for text in ["Left / Right: move", "Jump: tap for a full jump", "Duck: hold to crouch", "Sword: tap, or slide from Jump", "In air: Duck + Sword = downward thrust", "Pause: top-right button"]:
			var label := Label.new()
			label.text = text
			label.theme_type_variation = &"CarvedLabel"
			_rows.add_child(label)
	else:
		for action in InputBindings.ACTIONS:
			_rows.add_child(_make_row(action))

	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(64, 22 if MobileControls.enabled else 16)
	ThemeHelpers.style_button(back, 8)
	back.pressed.connect(_on_back_pressed)
	_rows.add_child(back)


func _make_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = InputBindings.label_for(action)
	name_label.custom_minimum_size = Vector2(72, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.theme_type_variation = &"CarvedLabel"
	row.add_child(name_label)

	var codes := InputBindings.keycodes_for(action)
	for index in codes.size():
		var slot := Button.new()
		var listening := _listening_action == action and _listening_index == index
		slot.text = "..." if listening else InputBindings.key_label(codes[index])
		slot.custom_minimum_size = Vector2(52, 14)
		ThemeHelpers.style_button(slot, 8)
		var action_name := action
		var slot_index := index
		slot.pressed.connect(func() -> void: _listen(action_name, slot_index))
		row.add_child(slot)
	return row


func _listen(action: String, index: int) -> void:
	_listening_action = action
	_listening_index = index
	refresh()
	_hint.text = "Press a key"


func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.physical_keycode == KEY_ESCAPE and _listening_action != "pause":
		_listening_action = ""
		_listening_index = -1
		refresh()
		get_viewport().set_input_as_handled()
		return
	var reason := InputBindings.set_binding(_listening_action, _listening_index, int(key.physical_keycode))
	_listening_action = ""
	_listening_index = -1
	refresh()
	if reason != "":
		_hint.text = reason
	get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	_listening_action = ""
	_listening_index = -1
	back_pressed.emit()
