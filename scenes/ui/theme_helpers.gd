extends RefCounted

## Shared UI colours. Fonts, carved-marble panels and button styles come from the project
## theme (res://resources/themes/theseus.tres), set as gui/theme/custom in project.godot.
## Label type variations in that theme:
##   CarvedHeading - large gilded, chiselled capitals for titles on marble.
##   CarvedLabel   - dark text incised into marble, with a 1 px lit lower edge.
## A plain Label draws light relief lettering with a dark shadow, for text over the scene.

const GOLD := Color(0.96, 0.77, 0.36)
const CREAM := Color(0.93, 0.9, 0.82)
const STONE_INK := Color(0.31, 0.282, 0.235)

## Pixel font size. Body text is 8; the bitmap font only scales in whole multiples.
const BODY_SIZE := 8


static func style_button(button: Button, font_size: int = BODY_SIZE) -> void:
	# The marble button styles come from the project theme; only the size is per-button.
	button.add_theme_font_size_override("font_size", font_size)
