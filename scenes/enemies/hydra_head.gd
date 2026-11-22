extends Area2D

signal damaged(head: Node)
signal severed(head: Node)

const ART := preload("res://assets/art/characters/hydra_heads.png")
const ART_SCALE := 8.0
const CELL_SIZE := Vector2(96, 72)
const BASE := Vector2(24, 68)
# Mouth centres stay in world units, independent of the atlas resolution.
const MOUTHS := [Vector2(39, 24), Vector2(39, 24), Vector2(32, 26), Vector2(81, 26), Vector2(54, 24), Vector2(41, 26)]

@export var base_x := 0.0
@export var base_y := 0.0
@onready var sprite: Sprite2D = $Sprite2D
var alive := true
var hp := 2
var _atlas := AtlasTexture.new()
var _flash := 0.0
var _pose := 0


func _ready() -> void:
	add_to_group("enemies")
	_atlas.atlas = ART
	sprite.texture = _atlas
	sprite.scale = Vector2.ONE / ART_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_pose(0, base_y)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_flash = maxf(0, _flash - delta)
	sprite.modulate = Color(1.7, 1.7, 1.7) if _flash > 0 else Color(1.15, 0.95, 0.75) if _pose == 2 else Color.WHITE


func set_pose(index: int, height: float) -> void:
	if not alive:
		return
	_pose = index
	var mouth: Vector2 = MOUTHS[index]
	position = Vector2(base_x, height) + mouth - BASE
	sprite.position = -mouth
	# Shorter necks sink into the common coils, never below the floor. The body
	# is drawn in front of their bases; head size remains the same at every height.
	_atlas.region = Rect2(index * CELL_SIZE.x * ART_SCALE, 0, CELL_SIZE.x * ART_SCALE, minf(CELL_SIZE.y, BASE.y - height) * ART_SCALE)
	queue_redraw()


func _draw() -> void:
	if alive:
		# Put the small health bar beside the mouth, clear of the head above it.
		draw_rect(Rect2(12, -12, 10, 2), Color(0.12, 0.08, 0.08))
		draw_rect(Rect2(12, -12, 5.0 * hp, 2), Color(0.78, 0.2, 0.16))


func sword_hit() -> void:
	take_damage(1)


func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	_flash = 0.1
	if hp == 0:
		alive = false
		collision_layer = 0
		$CollisionShape2D.set_deferred("disabled", true)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
		# Keep the node until the whole Hydra dies so attack turns never refer
		# to freed heads and a defeated head can never return to the rotation.
	queue_redraw()
	damaged.emit(self)
	if not alive:
		severed.emit(self)
