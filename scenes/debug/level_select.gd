extends Control

## Debug launcher for play-testing any level, from its start or from a lit shrine.
##
## With arguments it jumps straight in:
##   godot --path . res://scenes/debug/level_select.tscn -- --level=3 --shrine=2
## Without arguments (or opened with F6 in the editor) it shows a picker.
##
## --level=N   level number, matching res://scenes/levels/level_N.tscn
## --shrine=K  optional, 1-based shrine to start from; 0 or omitted starts at the entrance.
##
## Starting at a shrine marks it lit, so earlier enemies are still alive and score starts at 0.
## This scene is excluded from the Web export.

const LEVELS_DIR := "res://scenes/levels"
const BACKDROP := preload("res://assets/art/ui/title_backdrop.png")

var _first_button: Button


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	if args.has("level"):
		var error := _validate(args.level, args.get("shrine", 0))
		if error.is_empty():
			_start.call_deferred(args.level, args.get("shrine", 0))
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
		for key in ["level", "shrine"]:
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


func _layout(level: int) -> Script:
	return load("%s/level_%d_layout.gd" % [LEVELS_DIR, level])


func _validate(level: int, shrine: int) -> String:
	if level not in _level_numbers():
		return "no level %d (found %s)" % [level, _level_numbers()]
	var shrines: int = _layout(level).CHECKPOINTS.size()
	if shrine < 0 or shrine > shrines:
		return "level %d has shrines 1-%d, not %d" % [level, shrines, shrine]
	return ""


func _start(level: int, shrine: int) -> void:
	var layout := _layout(level)
	LevelRun.begin_level(level)
	LevelRun.spawn_position = layout.START
	if shrine > 0:
		var checkpoint: Dictionary = layout.CHECKPOINTS[shrine - 1]
		var none: Array[String] = []
		LevelRun.save_checkpoint(shrine - 1, checkpoint.spawn, 0, none, none)
	print("Level select: starting level %d %s" % [level, "at shrine %d" % shrine if shrine > 0 else "at the entrance"])
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

	for level in _level_numbers():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		rows.add_child(row)
		var name_label := Label.new()
		name_label.text = "Level %d" % level
		name_label.custom_minimum_size = Vector2(44, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.theme_type_variation = &"CarvedLabel"
		row.add_child(name_label)
		row.add_child(_button("Start", level, 0))
		for shrine in range(1, _layout(level).CHECKPOINTS.size() + 1):
			row.add_child(_button("Shrine %d" % shrine, level, shrine))

	var hint := Label.new()
	hint.text = error if not error.is_empty() else "Esc quits"
	hint.theme_type_variation = &"CarvedLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(hint)

	if _first_button:
		_first_button.grab_focus()


func _button(text: String, level: int, shrine: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 16)
	button.pressed.connect(_start.bind(level, shrine))
	if _first_button == null:
		_first_button = button
	return button
