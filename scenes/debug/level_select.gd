extends Control

## Debug launcher: --level=N starts that level at its entrance.
## Without arguments (or with F6) it shows a picker.
## This scene is excluded from the Web export.

const LEVELS_DIR := "res://scenes/levels"
const BACKDROP := preload("res://assets/art/ui/title_backdrop.png")

var _first_button: Button


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	if args.has("level"):
		var error := _validate(args.level)
		if error.is_empty():
			_start.call_deferred(args.level)
			return
		push_error("Level select: " + error)
		_build_picker(error)
		return
	_build_picker("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg in raw:
		for key in ["level"]:
			var prefix: String = "--%s=" % key
			if arg.begins_with(prefix) and arg.trim_prefix(prefix).is_valid_int():
				parsed[key] = arg.trim_prefix(prefix).to_int()
	return parsed


func _level_numbers() -> Array[int]:
	var numbers: Array[int] = []
	for file in DirAccess.get_files_at(LEVELS_DIR):
		# Exported builds list scenes as .tscn.remap.
		var name := file.trim_suffix(".remap")
		if name.begins_with("level_") and name.ends_with(".tscn"):
			var number := name.trim_prefix("level_").trim_suffix(".tscn")
			if number.is_valid_int():
				numbers.append(number.to_int())
	numbers.sort()
	return numbers


func _validate(level: int) -> String:
	if level not in _level_numbers():
		return "no level %d (found %s)" % [level, _level_numbers()]
	return ""


func _start(level: int) -> void:
	LevelRun.begin_level(level)
	print("Level select: starting level %d at the entrance" % level)
	get_tree().paused = false
	get_tree().change_scene_to_file("%s/level_%d.tscn" % [LEVELS_DIR, level])


func _build_picker(error: String) -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var slab := PanelContainer.new()
	center.add_child(slab)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	slab.add_child(rows)

	var heading := Label.new()
	heading.text = "Play Test"
	heading.theme_type_variation = &"CarvedHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(heading)

	# Nine levels fit the short landscape viewport in three columns.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	rows.add_child(grid)
	for level in _level_numbers():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		grid.add_child(row)
		var name_label := Label.new()
		name_label.text = "Level %d" % level
		name_label.custom_minimum_size = Vector2(32, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.theme_type_variation = &"CarvedLabel"
		row.add_child(name_label)
		row.add_child(_button("Start", level))

	var hint := Label.new()
	hint.text = error if not error.is_empty() else "Esc quits"
	hint.theme_type_variation = &"CarvedLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(hint)

	if _first_button:
		_first_button.grab_focus()


func _button(text: String, level: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 16)
	button.pressed.connect(_start.bind(level))
	if _first_button == null:
		_first_button = button
	return button
