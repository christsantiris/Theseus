extends RefCounted

const TIME_LIMIT := 300.0

const WIDTH := 4800
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Cypress Foothills"},
	{"x": 960, "name": "Stone Switchbacks"},
	{"x": 1920, "name": "Mountain Gardens"},
	{"x": 2880, "name": "High Pass"},
	{"x": 3840, "name": "Summit Sanctuary"},
]

const PLATFORMS := [
	Rect2(480, 264, 256, 16), Rect2(736, 248, 112, 32),
	Rect2(848, 232, 256, 48), Rect2(1104, 248, 96, 32),
	Rect2(1200, 264, 96, 16),
	Rect2(1472, 264, 112, 16), Rect2(1584, 248, 112, 32),
	Rect2(1696, 232, 192, 48), Rect2(1888, 248, 64, 32),
	Rect2(1952, 264, 48, 16),
	Rect2(2208, 264, 112, 16), Rect2(2320, 248, 112, 32),
	Rect2(2432, 232, 160, 48), Rect2(2592, 216, 112, 64),
	Rect2(2704, 200, 112, 80), Rect2(2816, 184, 112, 96),
	Rect2(2928, 168, 288, 112), Rect2(3216, 152, 112, 128),
	Rect2(3328, 136, 224, 144), Rect2(3552, 168, 112, 112),
	Rect2(3664, 200, 112, 80), Rect2(3776, 232, 112, 48),
	Rect2(3888, 248, 112, 32), Rect2(4000, 264, 64, 16),
	Rect2(4320, 264, 112, 16), Rect2(4432, 248, 144, 32),
	Rect2(4576, 264, 48, 16),
]

const PITS := [
	{"name": "FoothillPit", "position": Vector2(304, 280), "width": 32.0, "depth": 24.0},
	{"name": "SwitchbackPit", "position": Vector2(1344, 280), "width": 40.0, "depth": 24.0},
	{"name": "HighPassPit", "position": Vector2(3088, 168), "width": 40.0, "depth": 24.0},
	{"name": "SummitPit", "position": Vector2(4224, 280), "width": 40.0, "depth": 24.0},
]

const ENEMIES := [
	{"name": "SatyrFoothills", "kind": "satyr", "position": Vector2(560, 264), "patrol": Vector2(496, 704)},
	{"name": "CyclopsFoothills", "kind": "cyclops", "position": Vector2(896, 232), "patrol": Vector2(880, 1088)},
	{"name": "RaiderScree", "kind": "raider", "position": Vector2(1136, 248), "patrol": Vector2(1120, 1184)},
	{"name": "SatyrPitApproach", "kind": "satyr", "position": Vector2(1248, 264), "patrol": Vector2(1216, 1280)},
	{"name": "TelchineSwitchback", "kind": "telchine", "position": Vector2(1528, 264), "patrol": Vector2(1488, 1568)},
	{"name": "CyclopsSwitchback", "kind": "cyclops", "position": Vector2(1736, 232), "patrol": Vector2(1712, 1872)},
	{"name": "RaiderCypress", "kind": "raider", "position": Vector2(2256, 264), "patrol": Vector2(2224, 2304)},
	{"name": "SatyrGarden", "kind": "satyr", "position": Vector2(2512, 232), "patrol": Vector2(2448, 2576)},
	{"name": "TelchineClimb", "kind": "telchine", "position": Vector2(2760, 200), "patrol": Vector2(2720, 2800)},
	{"name": "CyclopsHighWall", "kind": "cyclops", "position": Vector2(2960, 168), "patrol": Vector2(2944, 3056)},
	{"name": "RaiderHighPass", "kind": "raider", "position": Vector2(3400, 136), "patrol": Vector2(3360, 3504)},
	{"name": "TelchineDescent", "kind": "telchine", "position": Vector2(3720, 200), "patrol": Vector2(3680, 3760)},
	{"name": "SatyrDescent", "kind": "satyr", "position": Vector2(3840, 232), "patrol": Vector2(3792, 3872)},
	{"name": "TelchineSummit", "kind": "telchine", "position": Vector2(4360, 264), "patrol": Vector2(4336, 4416)},
	{"name": "CyclopsSummit", "kind": "cyclops", "position": Vector2(4464, 248), "patrol": Vector2(4448, 4560)},
	{"name": "RaiderSummitGuard", "kind": "raider", "position": Vector2(4672, 280), "patrol": Vector2(4640, 4704)},
]

const FLASKS := [
	{"name": "HealthFlaskFoothill", "position": Vector2(376, 280)},
	{"name": "HealthFlaskSwitchback", "position": Vector2(1408, 280)},
	{"name": "HealthFlaskGarden", "position": Vector2(2464, 232)},
	{"name": "HealthFlaskHighPass", "position": Vector2(3168, 168)},
	{"name": "HealthFlaskDescent", "position": Vector2(3928, 248)},
	{"name": "HealthFlaskSummit", "position": Vector2(4296, 280)},
]
const EXIT := Vector2(4752, FLOOR_Y)
const GATE_GUARD := "RaiderSummitGuard"
const TIPS := [
	{"x": 80, "end": 288, "text": "Jump spike pits. Hold jump to climb out."},
	{"x": 480, "end": 704, "text": "Bounce on Satyrs. Wine briefly boosts speed."},
	{"x": 736, "end": 960, "text": "Jump or sword boulders; counter during reload."},
	{"x": 1280, "end": 1472, "text": "Spikes cost health. Keep moving and jump out."},
	{"x": 2864, "end": 3072, "text": "A high pit ahead. Jump from the bright stone lip."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	for pit: Dictionary in PITS:
		if x >= pit.position.x and x < pit.position.x + pit.width:
			surface = pit.position.y + pit.depth
	return surface


static func terrain_pieces(rectangle: Rect2) -> Array[Rect2]:
	var pieces: Array[Rect2] = []
	var cursor := rectangle.position.x
	for pit: Dictionary in PITS:
		var bottom: float = pit.position.y + pit.depth
		var left: float = maxf(cursor, pit.position.x)
		var right: float = minf(rectangle.end.x, pit.position.x + pit.width)
		if right <= left or pit.position.y > rectangle.position.y or bottom <= rectangle.position.y:
			continue
		if left > cursor:
			pieces.append(Rect2(cursor, rectangle.position.y, left - cursor, rectangle.size.y))
		if bottom < rectangle.end.y:
			pieces.append(Rect2(left, bottom, right - left, rectangle.end.y - bottom))
		cursor = right
	if cursor < rectangle.end.x:
		pieces.append(Rect2(cursor, rectangle.position.y, rectangle.end.x - cursor, rectangle.size.y))
	return pieces


static func is_spike_floor(rectangle: Rect2) -> bool:
	for pit: Dictionary in PITS:
		if rectangle.position.x == pit.position.x and rectangle.position.y == pit.position.y + pit.depth:
			return true
	return false
