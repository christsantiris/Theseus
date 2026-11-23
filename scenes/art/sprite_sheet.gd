extends RefCounted

# Keep complete, full-resolution animation cells in sheets that fit mobile GPU
# limits. Rows are a storage detail; frame order and world-space size stay fixed.
static func region(texture: Texture2D, index: int, cell: Vector2) -> Rect2:
	var columns := maxi(1, floori(texture.get_width() / cell.x))
	return Rect2(Vector2(index % columns, index / columns) * cell, cell)
