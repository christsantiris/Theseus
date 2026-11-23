extends Resource

# One bundle per level. Materials retain it so the importer cache shares its
# atlases during play and releases them with the level.
@export var panel_keys: PackedStringArray
@export var previous_keys: PackedStringArray
@export var overlap_width := 1.0 / 6.0
@export var overlaps: Texture2D
@export var masks: Texture2D
@export var overlap_rects: Array[Rect2] = []
@export var mask_rects: Array[Rect2] = []
@export var source_hashes: Dictionary = {}
@export var baker_hash := ""


static func panel_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		return "%s:%s" % [texture.atlas.resource_path, texture.region]
	return texture.resource_path
