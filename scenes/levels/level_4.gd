extends "res://scenes/levels/level_1.gd"


func _ready() -> void:
	layout = preload("res://scenes/levels/level_4_layout.gd")
	level_number = 4
	next_level = "res://scenes/levels/level_5.tscn"
	objective = "Cross Troy's fortifications. Defeat the citadel captain."
	completion_text = "Troy's gates are open. The mountain road awaits.\n\"Ibn Al-Noor\" Kevin MacLeod (incompetech.com)\nLicensed under Creative Commons: By Attribution 4.0 License\nhttp://creativecommons.org/licenses/by/4.0/"
	$Player/Camera2D.position.y = -24
	super()
	_gate.has_entry_stairs = false
	# Keep the supplied music credit inside the existing results panel.
	var credit_font := details.get_theme_font("font").duplicate() as FontFile
	credit_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	details.add_theme_font_override("font", credit_font)
	details.add_theme_font_size_override("font_size", 6)
	details.add_theme_constant_override("line_spacing", 0)
