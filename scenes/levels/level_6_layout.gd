extends RefCounted

const WIDTH := 4800
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Drowned Harbor"},
	{"x": 960, "name": "Ring Canals"},
	{"x": 1920, "name": "Sunken Agora"},
	{"x": 2880, "name": "Palace Ascent"},
	{"x": 3840, "name": "Poseidon's Sanctuary"},
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
	Rect2(4320, 264, 112, 16),
	Rect2(4432, 248, 144, 32),
	Rect2(4576, 264, 48, 16),
	]
const CANALS := [
	{"name": "RingCanal", "position": Vector2(1472, 280), "width": 32.0, "depth": 24.0},
	{"name": "SanctuaryCanal", "position": Vector2(4016, 280), "width": 40.0, "depth": 24.0},
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
	{"name": "ReefbladeSanctuary", "kind": "reefblade", "position": Vector2(4256, 280), "patrol": Vector2(4240, 4304)},
	{"name": "MerfolkSanctuary", "kind": "merfolk", "position": Vector2(4496, 248), "patrol": Vector2(4456, 4544)},
	{"name": "MerfolkGateCaptain", "kind": "merfolk", "position": Vector2(4672, 280), "patrol": Vector2(4640, 4704)},
	]
const FLASKS := [
	{"name": "HealthFlaskHarbor", "position": Vector2(888, 248)},
	{"name": "HealthFlaskAgora", "position": Vector2(2800, 200)},
]
const CHECKPOINTS := [
	{"name": "AtlantisAgoraShrine", "position": Vector2(2064, 280), "spawn": Vector2(2088, 280)},
	{"name": "PoseidonShrine", "position": Vector2(4096, 280), "spawn": Vector2(4120, 280)},
]
const EXIT := Vector2(4752, FLOOR_Y)
const GATE_GUARD := "MerfolkGateCaptain"
const TIPS := [
	{"x": 240, "end": 480, "text": "Duck high tridents. Stand and counter after."},
	{"x": 976, "end": 1184, "text": "Low blades: jump or retreat, then counter."},
	{"x": 1424, "end": 1552, "text": "Tides slow Theseus. Climb higher or wait for low tide."},
	{"x": 4560, "end": 4720, "text": "Defeat the captain to open Poseidon's sanctuary."},
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
