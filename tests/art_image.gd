extends RefCounted

# Asset checks inspect CPU pixels, while gameplay samples the compressed GPU
# textures directly. Decode before cropping an atlas; AtlasTexture.get_image()
# cannot crop a block-compressed image itself.
static func read(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		var image := read(texture.atlas)
		return image.get_region(Rect2i(texture.region)) if image != null else null
	var image := texture.get_image()
	if image != null and image.is_compressed():
		if image.decompress() != OK:
			push_error("Cannot decode artwork for inspection: " + texture.resource_path)
			return null
	return image
