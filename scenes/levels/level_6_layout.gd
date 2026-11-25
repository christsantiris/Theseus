extends RefCounted

const TIME_LIMIT := 180.0
const WIDTH := 5760
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Desert Road"},
	{"x": 960, "name": "Pyramid Causeway"},
	{"x": 1920, "name": "Buried Courts"},
	{"x": 2880, "name": "Obelisk Rise"},
	{"x": 3840, "name": "Sandstone Causeway"},
	{"x": 4800, "name": "Temple of the Sun"},
]
const PLATFORMS := [
	Rect2(640, 264, 128, 16),
	Rect2(768, 248, 128, 32),
	Rect2(896, 232, 256, 48),
	Rect2(1152, 248, 128, 32),
	Rect2(1280, 264, 128, 16),
	Rect2(1600, 264, 128, 16),
	Rect2(1728, 248, 128, 32),
	Rect2(1856, 232, 256, 48),
	Rect2(2112, 248, 128, 32),
	Rect2(2240, 264, 128, 16),
	Rect2(2496, 264, 128, 16),
	Rect2(2624, 248, 128, 32),
	Rect2(2752, 232, 128, 48),
	Rect2(2880, 216, 128, 64),
	Rect2(3008, 200, 256, 80),
	Rect2(3264, 216, 128, 64),
	Rect2(3392, 232, 128, 48),
	Rect2(3520, 248, 128, 32),
	Rect2(3648, 264, 128, 16),
	Rect2(3968, 264, 128, 16),
	Rect2(4096, 248, 256, 32),
	Rect2(4352, 264, 128, 16),
	Rect2(4992, 264, 128, 16),
	Rect2(5120, 248, 256, 32),
	Rect2(5376, 264, 128, 16),
]
const ENEMIES := [
	{"name": "RaiderDunes", "kind": "raider", "position": Vector2(352, 280), "patrol": Vector2(288, 448)},
	{"name": "PeltastPyramidRoad", "kind": "peltast", "position": Vector2(800, 248), "patrol": Vector2(784, 864)},
	{"name": "HoplitePyramidGuard", "kind": "hoplite", "position": Vector2(1008, 232), "patrol": Vector2(928, 1120)},
	{"name": "SpartoiCauseway", "kind": "spartoi", "position": Vector2(1344, 264), "patrol": Vector2(1304, 1384)},
	{"name": "RaiderBuriedCourt", "kind": "raider", "position": Vector2(1520, 280), "patrol": Vector2(1456, 1568)},
	{"name": "PeltastCourt", "kind": "peltast", "position": Vector2(1792, 248), "patrol": Vector2(1752, 1824)},
	{"name": "SpartoiCourt", "kind": "spartoi", "position": Vector2(1984, 232), "patrol": Vector2(1888, 2064)},
	{"name": "HopliteCourt", "kind": "hoplite", "position": Vector2(2304, 264), "patrol": Vector2(2264, 2336)},
	{"name": "RaiderObeliskSteps", "kind": "raider", "position": Vector2(2688, 248), "patrol": Vector2(2648, 2720)},
	{"name": "PeltastHighCourt", "kind": "peltast", "position": Vector2(3072, 200), "patrol": Vector2(3032, 3120)},
	{"name": "HopliteHighCourt", "kind": "hoplite", "position": Vector2(3200, 200), "patrol": Vector2(3160, 3232)},
	{"name": "SpartoiDescent", "kind": "spartoi", "position": Vector2(3456, 232), "patrol": Vector2(3416, 3488)},
	{"name": "RaiderSands", "kind": "raider", "position": Vector2(3896, 280), "patrol": Vector2(3856, 3936)},
	{"name": "PeltastSands", "kind": "peltast", "position": Vector2(4224, 248), "patrol": Vector2(4144, 4304)},
	{"name": "SpartoiSands", "kind": "spartoi", "position": Vector2(4624, 280), "patrol": Vector2(4528, 4704)},
	{"name": "RaiderTempleRoad", "kind": "raider", "position": Vector2(4848, 280), "patrol": Vector2(3824, 4912)},
	{"name": "PeltastTemple", "kind": "peltast", "position": Vector2(5184, 248), "patrol": Vector2(5152, 5296)},
	{"name": "SpartoiTemple", "kind": "spartoi", "position": Vector2(5440, 264), "patrol": Vector2(5408, 5472)},
	{"name": "HopliteSunCaptain", "kind": "hoplite", "position": Vector2(5536, 280), "patrol": Vector2(5512, 5560)},
]
const FLASKS := [
	{"name": "HealthFlaskPyramids", "position": Vector2(1216, 248)},
	{"name": "HealthFlaskCourts", "position": Vector2(2400, 280)},
	{"name": "HealthFlaskObelisk", "position": Vector2(2944, 216)},
	{"name": "HealthFlaskSunTemple", "position": Vector2(4960, 280)},
]
const EXIT := Vector2(5600, FLOOR_Y)
const GATE_GUARD := "HopliteSunCaptain"
const TIPS := [
	{"x": 560, "end": 752, "text": "Climb the sandstone steps with normal jumps."},
	{"x": 960, "end": 1152, "text": "Bait the hoplite's spear, then counter in recovery."},
	{"x": 1856, "end": 2064, "text": "Spartoi guard the courts. Make space before striking."},
	{"x": 5376, "end": 5536, "text": "Defeat the sun captain to open the temple."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
