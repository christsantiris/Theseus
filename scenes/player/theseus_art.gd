extends RefCounted

# Artwork is eight times the logical game size. Keep physics in world units;
# only the sprite and its texture-space foot anchor use this scale.
const SCALE := 8.0
const FRAME_SIZE := Vector2i(576, 448)
const DOWN_FRAME_SIZE := Vector2i(576, 640)
const FOOT_ROW := 432.0
const COLUMNS := 8
const ART := preload("res://assets/art/characters/theseus.png")
const DOWN_ART := preload("res://assets/art/characters/theseus_down_thrust.png")
const ANIMATIONS := {
	"idle": {"indices": [0, 1, 2, 3], "fps": 4.0, "loop": true},
	"walk": {"indices": [4, 5, 6, 7, 8, 9, 10, 11], "fps": 16.0, "loop": true},
	"duck": {"indices": [12, 13], "fps": 3.0, "loop": true},
	"jump_rise": {"indices": [14, 15], "fps": 8.0, "loop": false},
	"jump_fall": {"indices": [16, 17], "fps": 8.0, "loop": false},
	"hurt": {"indices": [18, 19], "fps": 12.0, "loop": false},
	# Six visual frames retain the original 0.25-second thrust: two windup,
	# two extended-blade frames, two recovery. The hit window is unchanged.
	"attack": {"indices": [20, 21, 22, 23, 24, 25], "fps": 24.0, "loop": false},
	"death": {"indices": [26, 27, 28, 29], "fps": 8.0, "loop": false},
	"down_thrust": {"indices": [0, 1, 2, 3, 4, 5], "fps": 24.0, "loop": false},
}


static func texture(index: int, downward: bool = false) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	var size := DOWN_FRAME_SIZE if downward else FRAME_SIZE
	atlas.atlas = DOWN_ART if downward else ART
	atlas.region = Rect2(Vector2i(index % COLUMNS, index / COLUMNS) * size, size)
	return atlas


static func frames() -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation("default")
	for animation: String in ANIMATIONS:
		var definition: Dictionary = ANIMATIONS[animation]
		result.add_animation(animation)
		result.set_animation_speed(animation, definition.fps)
		result.set_animation_loop(animation, definition.loop)
		for index: int in definition.indices:
			result.add_frame(animation, texture(index, animation == "down_thrust"))
	return result


static func anchor(sprite: AnimatedSprite2D, animation: String) -> void:
	var height := DOWN_FRAME_SIZE.y if animation == "down_thrust" else FRAME_SIZE.y
	sprite.offset = Vector2(0, height * 0.5 - FOOT_ROW)


static func configure(sprite: AnimatedSprite2D) -> void:
	sprite.sprite_frames = frames()
	sprite.scale = Vector2.ONE / SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anchor(sprite, "idle")


static func configure_reference(sprite: Sprite2D) -> void:
	sprite.texture = texture(0)
	sprite.scale = Vector2.ONE / SCALE
	sprite.offset = Vector2(0, FRAME_SIZE.y * 0.5 - FOOT_ROW)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
