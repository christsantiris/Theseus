extends RefCounted

const GOLD := Color(0.96, 0.77, 0.36)
const CREAM := Color(0.93, 0.9, 0.82)


static func style_button(button: Button, font_size: int = 8) -> void:
	button.add_theme_stylebox_override("normal", _box(Color(0.1, 0.13, 0.2), GOLD))
	button.add_theme_stylebox_override("hover", _box(Color(0.18, 0.22, 0.32), Color(1, 0.92, 0.55)))
	button.add_theme_stylebox_override("pressed", _box(Color(0.28, 0.22, 0.1), Color(1, 0.92, 0.55)))
	button.add_theme_stylebox_override("focus", _box(Color(0.16, 0.18, 0.28), Color(1, 0.95, 0.7)))
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.75))
	button.add_theme_color_override("font_focus_color", Color(1, 0.95, 0.75))
	button.add_theme_font_size_override("font_size", font_size)


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	return style
