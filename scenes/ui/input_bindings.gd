extends Node

const SAVE_PATH := "user://input_bindings.cfg"

const ACTIONS: Array[String] = [
	"move_left",
	"move_right",
	"jump",
	"attack",
	"pause",
]

const LABELS := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"attack": "Attack",
	"pause": "Pause",
}


func _ready() -> void:
	load_bindings()


func label_for(action: String) -> String:
	return String(LABELS.get(action, action))


func keycodes_for(action: String) -> Array[int]:
	var codes: Array[int] = []
	if not InputMap.has_action(action):
		return codes
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			codes.append(int(event.physical_keycode))
	return codes


func key_label(keycode: int) -> String:
	var event := InputEventKey.new()
	event.physical_keycode = keycode as Key
	var text := event.as_text()
	text = text.replace(" (Physical)", "").replace(" - Physical", "")
	return text


func set_binding(action: String, index: int, keycode: int) -> String:
	for other in ACTIONS:
		if other == action:
			continue
		var other_codes := keycodes_for(other)
		if keycode in other_codes and other_codes.size() == 1:
			return "Used by %s" % label_for(other)

	for other in ACTIONS:
		if other == action:
			continue
		var other_codes := keycodes_for(other)
		if keycode in other_codes:
			_apply(other, _without(other_codes, keycode))

	var codes := keycodes_for(action)
	if index < codes.size():
		codes[index] = keycode
	else:
		codes.append(keycode)
		index = codes.size() - 1

	var unique: Array[int] = []
	for code_index in codes.size():
		var code: int = codes[code_index]
		if code == keycode and code_index != index:
			continue
		unique.append(code)
	_apply(action, unique)
	save_bindings()
	return ""


func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for action in ACTIONS:
		if not config.has_section_key("bindings", action):
			continue
		var saved: Array = config.get_value("bindings", action)
		var codes: Array[int] = []
		for value in saved:
			codes.append(int(value))
		if codes.is_empty():
			continue
		_apply(action, codes)


func save_bindings() -> void:
	var config := ConfigFile.new()
	for action in ACTIONS:
		var saved: Array[int] = keycodes_for(action)
		config.set_value("bindings", action, saved)
	config.save(SAVE_PATH)


func _without(codes: Array[int], keycode: int) -> Array[int]:
	var cleaned: Array[int] = []
	for code in codes:
		if code != keycode:
			cleaned.append(code)
	return cleaned


func _apply(action: String, codes: Array[int]) -> void:
	InputMap.action_erase_events(action)
	for code in codes:
		var event := InputEventKey.new()
		event.physical_keycode = code as Key
		InputMap.action_add_event(action, event)
