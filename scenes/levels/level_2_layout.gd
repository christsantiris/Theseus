extends RefCounted

const TIME_LIMIT := 180.0

const WIDTH := 5760
const HEIGHT := 320
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Coastal Road"},
	{"x": 960, "name": "Broken Quays"},
	{"x": 1920, "name": "Sea Cliffs"},
	{"x": 2880, "name": "Cyclopean Ruins"},
	{"x": 3840, "name": "Saltwind Causeway"},
	{"x": 4800, "name": "Rocky Sanctuary"},
]

const QUAY_CROSSINGS := [
	{"name": "BrokenQuays", "position": Vector2(1760, 200)},
	{"name": "SeaCliffs", "position": Vector2(2328, 232)},
	{"name": "SaltwindCauseway", "position": Vector2(4704, 232)},
]
const QUAY_SLAB_WIDTH := 24.0
const QUAY_SLAB_COUNT := 3
const QUAY_PIT_WIDTH := QUAY_SLAB_WIDTH * QUAY_SLAB_COUNT
const QUAY_PIT_DEPTH := 24.0

const PLATFORMS := [
	Rect2(560, 264, 112, 16),
	Rect2(672, 248, 112, 32),
	Rect2(784, 232, 112, 48),
	Rect2(896, 216, 112, 64),
	Rect2(1008, 200, 144, 80),
	Rect2(1152, 184, 112, 96),
	Rect2(1264, 168, 144, 112),
	Rect2(1408, 168, 176, 112),
	Rect2(1584, 184, 128, 96),
	Rect2(1712, 200, 48, 80),
	Rect2(1760, 224, 72, 56),
	Rect2(1832, 200, 24, 80),
	Rect2(1856, 248, 96, 32),
	Rect2(2080, 264, 112, 16),
	Rect2(2192, 248, 112, 32),
	Rect2(2304, 232, 24, 48),
	Rect2(2328, 256, 72, 24),
	Rect2(2400, 232, 16, 48),
	Rect2(2416, 216, 128, 64),
	Rect2(2544, 200, 144, 80),
	Rect2(2688, 184, 144, 96),
	Rect2(2832, 168, 128, 112),
	Rect2(2960, 152, 144, 128),
	Rect2(3104, 136, 144, 144),
	Rect2(3248, 120, 144, 160),
	Rect2(3392, 104, 144, 176),
	Rect2(3536, 136, 96, 144),
	Rect2(3632, 168, 96, 112),
	Rect2(3728, 200, 96, 80),
	Rect2(3824, 232, 16, 48),
	Rect2(3840, 248, 112, 32),
	Rect2(3952, 264, 112, 16),
	Rect2(4240, 264, 112, 16),
	Rect2(4352, 248, 112, 32),
	Rect2(4464, 232, 224, 48),
	Rect2(4688, 232, 16, 48),
	Rect2(4704, 256, 72, 24),
	Rect2(4776, 232, 24, 48),
	Rect2(4800, 232, 80, 48),
	Rect2(4880, 264, 80, 16),
	Rect2(5184, 264, 112, 16),
	Rect2(5296, 248, 144, 32),
	Rect2(5440, 264, 80, 16),
]

const ENEMIES := [
	{"name": "BirdHighIntro", "kind": "bird", "position": Vector2(240, 236), "patrol": Vector2(128, 304)},
	{"name": "BirdLowIntro", "kind": "bird", "position": Vector2(448, 272), "patrol": Vector2(336, 496)},
	{"name": "TelchineRoad", "kind": "telchine", "position": Vector2(832, 232), "patrol": Vector2(800, 864)},
	{"name": "TelchineQuay", "kind": "telchine", "position": Vector2(1072, 200), "patrol": Vector2(1024, 1120)},
	{"name": "SpartoiQuay", "kind": "spartoi", "position": Vector2(1328, 168), "patrol": Vector2(1280, 1376)},
	{"name": "BirdHighQuay", "kind": "bird", "position": Vector2(1536, 124), "patrol": Vector2(1424, 1552)},
	{"name": "BirdLowQuay", "kind": "bird", "position": Vector2(1664, 176), "patrol": Vector2(1600, 1680)},
	{"name": "TelchineCliffs", "kind": "telchine", "position": Vector2(2496, 216), "patrol": Vector2(2432, 2512)},
	{"name": "SpartoiCliffs", "kind": "spartoi", "position": Vector2(2608, 200), "patrol": Vector2(2560, 2656)},
	{"name": "BirdHighCliffs", "kind": "bird", "position": Vector2(2768, 140), "patrol": Vector2(2704, 2800)},
	{"name": "BirdLowRuins", "kind": "bird", "position": Vector2(3168, 128), "patrol": Vector2(3120, 3216)},
	{"name": "TelchineRuins", "kind": "telchine", "position": Vector2(3344, 120), "patrol": Vector2(3264, 3360)},
	{"name": "SpartoiSummit", "kind": "spartoi", "position": Vector2(3456, 104), "patrol": Vector2(3408, 3504)},
	{"name": "TelchineSaltwind", "kind": "telchine", "position": Vector2(3896, 248), "patrol": Vector2(3864, 3920)},
	{"name": "BirdHighSaltwind", "kind": "bird", "position": Vector2(4120, 236), "patrol": Vector2(4088, 4208)},
	{"name": "SpartoiSaltwind", "kind": "spartoi", "position": Vector2(4576, 232), "patrol": Vector2(4496, 4656)},
	{"name": "SpartoiCoast", "kind": "spartoi", "position": Vector2(5104, 280), "patrol": Vector2(5040, 5168)},
	{"name": "TelchineSanctuary", "kind": "telchine", "position": Vector2(5360, 248), "patrol": Vector2(5312, 5408)},
	{"name": "SpartoiSanctuaryGuard", "kind": "spartoi", "position": Vector2(5600, 280), "patrol": Vector2(5552, 5648)},
]

const FLASKS := [
	{"name": "HealthFlaskQuay", "position": Vector2(1320, 168)},
	{"name": "HealthFlaskCliff", "position": Vector2(2904, 168)},
	{"name": "HealthFlaskSanctuary", "position": Vector2(4592, 232)},
]
const EXIT := Vector2(5712, FLOOR_Y)
const GATE_GUARD := "SpartoiSanctuaryGuard"
const TIPS := [
	{"x": 80, "end": 304, "text": "Duck under high birds. Let them pass."},
	{"x": 320, "end": 500, "text": "Jump low birds. Time your sword to hit them."},
	{"x": 680, "end": 920, "text": "Dog-headed Telchines jab. Bait, then counter."},
	{"x": 1200, "end": 1392, "text": "Spartoi lunge like Raiders. Two hits defeat them."},
	{"x": 1695, "end": 1760, "text": "Run across the cracked stones before they drop onto the spikes."},
]


static func surface_at(x: float) -> float:
	for crossing: Dictionary in QUAY_CROSSINGS:
		if x >= crossing.position.x and x < crossing.position.x + QUAY_PIT_WIDTH:
			return crossing.position.y
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
