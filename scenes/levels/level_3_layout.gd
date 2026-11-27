extends RefCounted

const TIME_LIMIT := 150.0

const WIDTH := 5760
const HEIGHT := 320
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "City Gate"},
	{"x": 960, "name": "Potters' Quarter"},
	{"x": 1920, "name": "Agora Terraces"},
	{"x": 2880, "name": "Temple District"},
	{"x": 3840, "name": "Processional Courts"},
	{"x": 4800, "name": "Acropolis Approach"},
]

# Connected uphill steps and generous combat landings keep every missed jump
# recoverable. The breaks at street level are shallow courtyards, not pits.
const PLATFORMS := [
	Rect2(480, 264, 256, 16),
	Rect2(736, 248, 112, 32),
	Rect2(848, 232, 320, 48),
	Rect2(1168, 248, 128, 32),
	Rect2(1296, 264, 128, 16),
	Rect2(1488, 264, 112, 16),
	Rect2(1600, 248, 160, 32),
	Rect2(1760, 264, 128, 16),
	Rect2(2208, 264, 112, 16),
	Rect2(2320, 248, 112, 32),
	Rect2(2432, 232, 224, 48),
	Rect2(2656, 216, 256, 64),
	Rect2(2912, 200, 128, 80),
	Rect2(3040, 184, 128, 96),
	Rect2(3168, 168, 192, 112),
	Rect2(3360, 152, 256, 128),
	Rect2(3616, 184, 112, 96),
	Rect2(3728, 216, 112, 64),
	Rect2(3840, 232, 128, 48),
	Rect2(3968, 248, 128, 32),
	Rect2(4096, 264, 96, 16),
	Rect2(4352, 264, 112, 16),
	Rect2(4464, 248, 112, 32),
	Rect2(4576, 232, 112, 48),
	Rect2(4688, 248, 112, 32),
	Rect2(4800, 248, 112, 32),
	Rect2(4912, 264, 112, 16),
	Rect2(5200, 264, 112, 16),
	Rect2(5312, 248, 192, 32),
	Rect2(5504, 264, 80, 16),
]

const ENEMIES := [
	{"name": "HopliteCityGate", "kind": "hoplite", "position": Vector2(304, 280), "patrol": Vector2(240, 368)},
	{"name": "PeltastGate", "kind": "peltast", "position": Vector2(576, 264), "patrol": Vector2(512, 688)},
	{"name": "SpartoiWorkshop", "kind": "spartoi", "position": Vector2(784, 248), "patrol": Vector2(752, 832)},
	{"name": "LamiaWorkshop", "kind": "lamia", "position": Vector2(1040, 232), "patrol": Vector2(944, 1120)},
	{"name": "SpartoiPotters", "kind": "spartoi", "position": Vector2(1344, 264), "patrol": Vector2(1312, 1408)},
	{"name": "PeltastPotters", "kind": "peltast", "position": Vector2(1680, 248), "patrol": Vector2(1616, 1744)},
	{"name": "HopliteAgora", "kind": "hoplite", "position": Vector2(2100, 280), "patrol": Vector2(2040, 2160)},
	{"name": "HopliteColonnade", "kind": "hoplite", "position": Vector2(2528, 232), "patrol": Vector2(2464, 2624)},
	{"name": "LamiaAgora", "kind": "lamia", "position": Vector2(2800, 216), "patrol": Vector2(2720, 2864)},
	{"name": "PeltastTempleLanding", "kind": "peltast", "position": Vector2(3088, 184), "patrol": Vector2(3056, 3152)},
	{"name": "SpartoiTempleRoof", "kind": "spartoi", "position": Vector2(3264, 168), "patrol": Vector2(3184, 3344)},
	{"name": "LamiaTemple", "kind": "lamia", "position": Vector2(3504, 152), "patrol": Vector2(3424, 3584)},
	{"name": "PeltastProcession", "kind": "peltast", "position": Vector2(4032, 248), "patrol": Vector2(3992, 4072)},
	{"name": "SpartoiProcession", "kind": "spartoi", "position": Vector2(4272, 280), "patrol": Vector2(4224, 4320)},
	{"name": "LamiaProcession", "kind": "lamia", "position": Vector2(4744, 248), "patrol": Vector2(4712, 4776)},
	{"name": "PeltastDescent", "kind": "peltast", "position": Vector2(4848, 248), "patrol": Vector2(4816, 4896)},
	{"name": "SpartoiSanctuary", "kind": "spartoi", "position": Vector2(5168, 280), "patrol": Vector2(5104, 5192)},
	{"name": "LamiaSanctuary", "kind": "lamia", "position": Vector2(5408, 248), "patrol": Vector2(5344, 5472)},
	{"name": "HopliteAcropolisGuard", "kind": "hoplite", "position": Vector2(5632, 280), "patrol": Vector2(5600, 5664)},
]

const FLASKS := [
	{"name": "HealthFlaskGate", "position": Vector2(928, 232)},
	{"name": "HealthFlaskAgora", "position": Vector2(2112, 280)},
	{"name": "HealthFlaskTemple", "position": Vector2(3664, 184)},
	{"name": "HealthFlaskAcropolis", "position": Vector2(5056, 280)},
]
const EXIT := Vector2(5712, FLOOR_Y)
const GATE_GUARD := "HopliteAcropolisGuard"
const TimingObstacle := preload("res://scenes/objects/timing_obstacle.gd")
const TIMING_OBSTACLE := {
	"name": "PottersKiln", "kind": TimingObstacle.Kind.KILN,
	"position": Vector2(1784, 264), "width": 80.0, "durations": Vector3(2.7, 0.8, 1),
}

const TIPS := [
	{"x": 80, "end": 320, "text": "The town road leads to the acropolis."},
	{"x": 864, "end": 1120, "text": "Lamia reaches far. Bait her strike, then wait."},
	{"x": 1120, "end": 1456, "text": "Closed coils are protected. Counter when open."},
	{"x": 2656, "end": 2880, "text": "Jump the long strike or retreat out of reach."},
	{"x": 1729, "end": 1784, "text": "Glowing kiln vents are about to flare."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
