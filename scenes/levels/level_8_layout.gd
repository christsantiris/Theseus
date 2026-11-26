extends RefCounted

const TIME_LIMIT := 180.0

const WIDTH := 5760
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Drowned Harbor"},
	{"x": 960, "name": "Ring Canals"},
	{"x": 1920, "name": "Sunken Agora"},
	{"x": 2880, "name": "Palace Ascent"},
	{"x": 3840, "name": "Outer Ring Causeway"},
	{"x": 4800, "name": "Poseidon's Sanctuary"},
]
const PLATFORMS := [
	Rect2(640, 264, 112, 16),
	Rect2(752, 248, 208, 32),
	Rect2(960, 232, 256, 48),
	Rect2(1216, 248, 112, 32),
	Rect2(1328, 264, 112, 16),
	Rect2(1552, 264, 112, 16),
	Rect2(1664, 248, 256, 32),
	Rect2(1920, 264, 112, 16),
	Rect2(2160, 264, 112, 16),
	Rect2(2272, 248, 112, 32),
	Rect2(2384, 232, 256, 48),
	Rect2(2640, 216, 112, 64),
	Rect2(2752, 200, 128, 80),
	Rect2(2880, 184, 112, 96),
	Rect2(2992, 168, 112, 112),
	Rect2(3104, 152, 320, 128),
	Rect2(3424, 184, 128, 96),
	Rect2(3552, 216, 128, 64),
	Rect2(3680, 248, 160, 32),
	Rect2(3840, 264, 128, 16),
	Rect2(4160, 264, 112, 16),
	Rect2(4272, 248, 224, 32),
	Rect2(4496, 264, 112, 16),
	Rect2(4800, 264, 128, 16),
	Rect2(5280, 264, 112, 16),
	Rect2(5392, 248, 144, 32),
	Rect2(5536, 264, 48, 16),
	]
const CANALS := [
	{"name": "RingCanal", "position": Vector2(1472, 280), "width": 32.0, "depth": 24.0},
	{"name": "SanctuaryCanal", "position": Vector2(4976, 280), "width": 40.0, "depth": 24.0},
]
const ENEMIES := [
	{"name": "MerfolkHarbor", "kind": "merfolk", "position": Vector2(384, 280), "patrol": Vector2(320, 448)},
	{"name": "MerfolkUpperQuay", "kind": "merfolk", "position": Vector2(848, 248), "patrol": Vector2(784, 928)},
	{"name": "ReefbladeCanals", "kind": "reefblade", "position": Vector2(1088, 232), "patrol": Vector2(1008, 1168)},
	{"name": "MerfolkCanalSteps", "kind": "merfolk", "position": Vector2(1368, 264), "patrol": Vector2(1352, 1408)},
	{"name": "MerfolkRingQuay", "kind": "merfolk", "position": Vector2(1760, 248), "patrol": Vector2(1696, 1840)},
	{"name": "MerfolkAgora", "kind": "merfolk", "position": Vector2(2328, 248), "patrol": Vector2(2296, 2352)},
	{"name": "ReefbladeAgora", "kind": "reefblade", "position": Vector2(2512, 232), "patrol": Vector2(2432, 2592)},
	{"name": "ReefbladePalace", "kind": "reefblade", "position": Vector2(3264, 152), "patrol": Vector2(3160, 3368)},
	{"name": "MerfolkPalaceDescent", "kind": "merfolk", "position": Vector2(3600, 216), "patrol": Vector2(3576, 3648)},
	{"name": "MerfolkLowerPalace", "kind": "merfolk", "position": Vector2(3744, 248), "patrol": Vector2(3712, 3808)},
	{"name": "MerfolkOuterRing", "kind": "merfolk", "position": Vector2(3896, 264), "patrol": Vector2(3864, 3936)},
	{"name": "ReefbladeOuterRing", "kind": "reefblade", "position": Vector2(4368, 248), "patrol": Vector2(4304, 4464)},
	{"name": "MerfolkOuterQuay", "kind": "merfolk", "position": Vector2(4712, 280), "patrol": Vector2(4656, 4768)},
	{"name": "ReefbladeSanctuary", "kind": "reefblade", "position": Vector2(5216, 280), "patrol": Vector2(5200, 5264)},
	{"name": "MerfolkSanctuary", "kind": "merfolk", "position": Vector2(5456, 248), "patrol": Vector2(5416, 5504)},
	{"name": "MerfolkGateCaptain", "kind": "merfolk", "position": Vector2(5632, 280), "patrol": Vector2(5600, 5664)},
	]
const FLASKS := [
	{"name": "HealthFlaskHarbor", "position": Vector2(888, 248)},
	{"name": "HealthFlaskAgora", "position": Vector2(2800, 200)},
]
const EXIT := Vector2(5712, FLOOR_Y)
const GATE_GUARD := "MerfolkGateCaptain"
const TimingObstacle := preload("res://scenes/objects/timing_obstacle.gd")
const TIMING_OBSTACLE := {
	"name": "OuterRingJets", "kind": TimingObstacle.Kind.JETS,
	"position": Vector2(4020, 280), "width": 80.0, "durations": Vector3(4, 1, 1),
}

const TIPS := [
	{"x": 240, "end": 480, "text": "Duck high tridents. Stand and counter after."},
	{"x": 976, "end": 1184, "text": "Low blades: jump or retreat, then counter."},
	{"x": 1424, "end": 1552, "text": "Tides slow Theseus. Climb higher or wait for low tide."},
	{"x": 5520, "end": 5680, "text": "Defeat the captain to open Poseidon's sanctuary."},
	{"x": 3965, "end": 4020, "text": "Bubbles warn of water jets. Cross between bursts."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	for canal: Dictionary in CANALS:
		if x >= canal.position.x and x < canal.position.x + canal.width:
			surface = canal.position.y + canal.depth
	return surface


static func terrain_pieces(rectangle: Rect2) -> Array[Rect2]:
	var pieces: Array[Rect2] = []
	var cursor := rectangle.position.x
	for canal: Dictionary in CANALS:
		var bottom: float = canal.position.y + canal.depth
		var left: float = maxf(cursor, canal.position.x)
		var right: float = minf(rectangle.end.x, canal.position.x + canal.width)
		if right <= left or canal.position.y > rectangle.position.y or bottom <= rectangle.position.y:
			continue
		if left > cursor:
			pieces.append(Rect2(cursor, rectangle.position.y, left - cursor, rectangle.size.y))
		if bottom < rectangle.end.y:
			pieces.append(Rect2(left, bottom, right - left, rectangle.end.y - bottom))
		cursor = right
	if cursor < rectangle.end.x:
		pieces.append(Rect2(cursor, rectangle.position.y, rectangle.end.x - cursor, rectangle.size.y))
	return pieces
