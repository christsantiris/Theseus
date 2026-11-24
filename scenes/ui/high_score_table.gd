extends VBoxContainer

var _result := {}
var _current: Label
var rows: Array[PanelContainer] = []
var highlighted_rank := -1


func _ready() -> void:
	custom_minimum_size.x = 112
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label("High Scores", HORIZONTAL_ALIGNMENT_CENTER)
	_current = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	for index in HighScores.LIMIT:
		var row := PanelContainer.new()
		row.name = "Rank%d" % (index + 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cells := HBoxContainer.new()
		cells.add_theme_constant_override("separation", 2)
		row.add_child(cells)
		for column in 2:
			var cell := Label.new()
			cell.theme_type_variation = &"CarvedLabel"
			cell.add_theme_font_size_override("font_size", 8)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if column == 1:
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cells.add_child(cell)
		rows.append(row)
		add_child(row)
	_refresh()


func _label(caption: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"CarvedLabel"
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", 8)
	add_child(label)
	return label


func show_result(result: Dictionary) -> void:
	_result = result.duplicate()
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	_current.text = "Your score %d" % _result.get("score", 0)
	highlighted_rank = -1
	for index in rows.size():
		var entry: Dictionary = HighScores.entries[index] if index < HighScores.entries.size() else {}
		var current: bool = not entry.is_empty() and entry.id == _result.get("id", "")
		var cells: HBoxContainer = rows[index].get_child(0)
		cells.get_child(0).text = str(index + 1) + "."
		cells.get_child(1).text = str(entry.score) if not entry.is_empty() else "-"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.72, 0.48, 0.13, 0.24) if current else Color.TRANSPARENT
		style.content_margin_left = 2
		style.content_margin_right = 2
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		if current:
			style.set_border_width_all(1)
			style.border_color = Color("b88424")
			highlighted_rank = index + 1
		rows[index].add_theme_stylebox_override("panel", style)
