extends RefCounted

const TIME_LIMIT := 300.0

const WIDTH := 4800
const HEIGHT := 320
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Coastal Road"},
	{"x": 960, "name": "Broken Quays"},
	{"x": 1920, "name": "Sea Cliffs"},
	{"x": 2880, "name": "Cyclopean Ruins"},
	{"x": 3840, "name": "Rocky Sanctuary"},
]

const PLATFORMS := [
	# Adjacent ledges meet: uphill steps require jumps without deep, narrow traps.
	Rect2(560, 264, 112, 16), Rect2(672, 248, 112, 32),
	Rect2(784, 232, 112, 48), Rect2(896, 216, 112, 64),
	Rect2(1008, 200, 144, 80), Rect2(1152, 184, 112, 96),
	Rect2(1264, 168, 144, 112), Rect2(1408, 168, 176, 112),
	Rect2(1584, 184, 128, 96), Rect2(1712, 200, 144, 80),
	Rect2(1856, 248, 96, 32),
	Rect2(2080, 264, 112, 16), Rect2(2192, 248, 112, 32),
	Rect2(2304, 232, 112, 48), Rect2(2416, 216, 128, 64),
	Rect2(2544, 200, 144, 80), Rect2(2688, 184, 144, 96),
	Rect2(2832, 168, 128, 112), Rect2(2960, 152, 144, 128),
	Rect2(3104, 136, 144, 144), Rect2(3248, 120, 144, 160),
	Rect2(3392, 104, 144, 176),
	Rect2(3536, 136, 96, 144), Rect2(3632, 168, 96, 112),
	Rect2(3728, 200, 96, 80), Rect2(3824, 232, 96, 48),
	Rect2(3920, 264, 80, 16),
	Rect2(4224, 264, 112, 16), Rect2(4336, 248, 144, 32),
	Rect2(4480, 264, 80, 16),
]

const ENEMIES := [
	# High cores sit 44 px above each landing: their lowest sprite pixel clears
	# Theseus's visible ducking helmet by 4 px throughout the wing cycle.
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
	{"name": "SpartoiCoast", "kind": "spartoi", "position": Vector2(4144, 280), "patrol": Vector2(4080, 4208)},
	{"name": "TelchineSanctuary", "kind": "telchine", "position": Vector2(4400, 248), "patrol": Vector2(4352, 4448)},
	{"name": "SpartoiSanctuaryGuard", "kind": "spartoi", "position": Vector2(4640, 280), "patrol": Vector2(4592, 4688)},
]

const FLASKS := [
	{"name": "HealthFlaskQuay", "position": Vector2(1200, 184)},
	{"name": "HealthFlaskCliff", "position": Vector2(2880, 168)},
	{"name": "HealthFlaskDescent", "position": Vector2(3760, 200)},
	{"name": "HealthFlaskSanctuary", "position": Vector2(4512, 264)},
]
const EXIT := Vector2(4752, FLOOR_Y)
const GATE_GUARD := "SpartoiSanctuaryGuard"
const TIPS := [
	{"x": 80, "end": 304, "text": "Duck under high birds. Let them pass."},
	{"x": 320, "end": 500, "text": "Jump low birds. Time your sword to hit them."},
	{"x": 680, "end": 920, "text": "Dog-headed Telchines jab. Bait, then counter."},
	{"x": 1200, "end": 1392, "text": "Spartoi lunge like Raiders. Two hits defeat them."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
