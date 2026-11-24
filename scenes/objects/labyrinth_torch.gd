@tool
extends Node2D

const ART := preload("res://assets/art/backgrounds/labyrinth/torch.png")
var _time := 0.0
var _light: PointLight2D
static var _glow: GradientTexture2D


func _ready() -> void:
	# Cull using this frame's wall transform, applied by the geometry at priority 10.
	process_priority = 11
	if _glow == null:
		_glow = GradientTexture2D.new()
		_glow.width = 128
		_glow.height = 128
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1, 0.5)
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_glow.gradient = gradient
	_light = PointLight2D.new()
	_light.texture = _glow
	_light.texture_scale = 1.65
	_light.color = Color(1.0, 0.66, 0.32)
	_light.energy = 0.75
	_light.shadow_enabled = false
	add_child(_light)
	var flame := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 7)
	var cell := ART.get_size() / Vector2(4, 1)
	for index in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = ART
		atlas.region = Rect2(Vector2(index * cell.x, 0), cell)
		atlas.filter_clip = true
		frames.add_frame("default", atlas)
	flame.sprite_frames = frames
	flame.scale = Vector2.ONE * 32.0 / cell.y
	flame.position.y = 7
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flame.material = unlit
	add_child(flame)
	flame.play()
	flame.frame = int(position.x) % 4
	_time = position.x * 0.13


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	# Only the nearby torches draw lights; no shadows or full-screen effects.
	visible = camera == null or absf(camera.get_screen_center_position().x - global_position.x) < 256
	if not visible:
		return
	_time += delta
	_light.energy = 0.72 + sin(_time * 8) * 0.045 + sin(_time * 13) * 0.025
