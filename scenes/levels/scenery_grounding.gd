extends RefCounted

# Painted base rows measured from the source artwork at 50% alpha. Transparent
# canvas padding is not a physical foot. Keep these anchors with their artwork;
# tests inspect imported pixels independently when an image changes.
const FOOTINGS := {
	"res://assets/art/backgrounds/level_1/olive_grove.png": Vector2(990, 1024),
	"res://assets/art/backgrounds/level_1/colonnade.png": Vector2(862, 887),
	"res://assets/art/backgrounds/level_1/aqueduct.png": Vector2(691, 724),
	"res://assets/art/backgrounds/level_1/waystone.png": Vector2(844, 847),
	"res://assets/art/backgrounds/level_2/coastal_outcrop.png": Vector2(845, 887),
	"res://assets/art/backgrounds/level_2/ruined_quay.png": Vector2(585, 724),
	"res://assets/art/backgrounds/level_2/cyclopean_gate.png": Vector2(980, 1024),
	"res://assets/art/backgrounds/level_3/amphora.png": Vector2(1444, 1449),
	"res://assets/art/backgrounds/level_4/broken_column.png": Vector2(2023, 2038),
}
# One world pixel closes the contact after bilinear filtering, including the
# 320x180 preview. No image readback or pixel search occurs during gameplay.
const OVERLAP := 1.0


static func rect(texture: Texture2D, center_x: float, ground_y: float, height: float, width := 0.0) -> Rect2:
	if not FOOTINGS.has(texture.resource_path):
		push_error("Missing painted scenery footing: " + texture.resource_path)
	var footing: Vector2 = FOOTINGS.get(texture.resource_path, Vector2.ONE)
	if width <= 0.0:
		width = height * texture.get_width() / float(texture.get_height())
	return Rect2(center_x - width * 0.5, ground_y + OVERLAP - height * footing.x / footing.y, width, height)


static func place(sprite: Sprite2D, center_x: float, ground_y: float, height: float) -> void:
	var target := rect(sprite.texture, center_x, ground_y, height)
	sprite.centered = false
	sprite.position = target.position
	sprite.scale = target.size / sprite.texture.get_size()
