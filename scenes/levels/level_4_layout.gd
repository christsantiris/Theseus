extends RefCounted

const TIME_LIMIT := 180.0
const WIDTH := 5760
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Trojan Plain"},
	{"x": 960, "name": "Outer Rampart"},
	{"x": 1920, "name": "Gate Court"},
	{"x": 2880, "name": "High Battlements"},
	{"x": 3840, "name": "Inner Wall"},
	{"x": 4800, "name": "Citadel Gate"},
]
# Broad fighting landings separated by ordinary 16-pixel climbs. The high
# rampart and its descent give Troy a different silhouette from the city.
const PLATFORMS := [
	Rect2(512, 264, 128, 16),
	Rect2(640, 248, 128, 32),
	Rect2(768, 232, 384, 48),
	Rect2(1152, 248, 128, 32),
	Rect2(1280, 264, 128, 16),
	Rect2(1536, 264, 128, 16),
	Rect2(1664, 248, 128, 32),
	Rect2(1792, 232, 128, 48),
	Rect2(1920, 216, 384, 64),
	Rect2(2304, 232, 128, 48),
	Rect2(2432, 248, 128, 32),
	Rect2(2560, 232, 128, 48),
	Rect2(2688, 216, 128, 64),
	Rect2(2816, 200, 128, 80),
	Rect2(2944, 184, 128, 96),
	Rect2(3072, 168, 128, 112),
	Rect2(3200, 152, 384, 128),
	Rect2(3584, 168, 128, 112),
	Rect2(3712, 184, 128, 96),
	Rect2(3840, 200, 128, 80),
	Rect2(3968, 216, 384, 64),
	Rect2(4352, 232, 128, 48),
	Rect2(4480, 248, 128, 32),
	Rect2(4608, 264, 128, 16),
	Rect2(4864, 264, 128, 16),
	Rect2(4992, 248, 128, 32),
	Rect2(5120, 232, 256, 48),
	Rect2(5376, 248, 128, 32),
	Rect2(5504, 264, 64, 16),
]
const ENEMIES := [
	{"name": "RaiderPlain", "kind": "raider", "position": Vector2(336, 280), "patrol": Vector2(256, 416)},
	{"name": "PeltastOuterSteps", "kind": "peltast", "position": Vector2(704, 248), "patrol": Vector2(664, 736)},
	{"name": "HopliteOuterWall", "kind": "hoplite", "position": Vector2(960, 232), "patrol": Vector2(880, 1040)},
	{"name": "RaiderWallDescent", "kind": "raider", "position": Vector2(1344, 264), "patrol": Vector2(1304, 1376)},
	{"name": "PeltastGateSteps", "kind": "peltast", "position": Vector2(1728, 248), "patrol": Vector2(1688, 1760)},
	{"name": "HopliteGateCourt", "kind": "hoplite", "position": Vector2(2032, 216), "patrol": Vector2(1960, 2080)},
	{"name": "RaiderGateCourt", "kind": "raider", "position": Vector2(2224, 216), "patrol": Vector2(2152, 2272)},
	{"name": "PeltastRampartFoot", "kind": "peltast", "position": Vector2(2496, 248), "patrol": Vector2(2456, 2528)},
	{"name": "HopliteRampartSteps", "kind": "hoplite", "position": Vector2(2880, 200), "patrol": Vector2(2840, 2912)},
	{"name": "PeltastHighWall", "kind": "peltast", "position": Vector2(3264, 152), "patrol": Vector2(3232, 3320)},
	{"name": "HopliteHighWall", "kind": "hoplite", "position": Vector2(3472, 152), "patrol": Vector2(3408, 3544)},
	{"name": "RaiderRampartDescent", "kind": "raider", "position": Vector2(3776, 184), "patrol": Vector2(3736, 3808)},
	{"name": "PeltastInnerWall", "kind": "peltast", "position": Vector2(4064, 216), "patrol": Vector2(4008, 4128)},
	{"name": "RaiderInnerWall", "kind": "raider", "position": Vector2(4272, 216), "patrol": Vector2(4192, 4320)},
	{"name": "PeltastInnerSteps", "kind": "peltast", "position": Vector2(4544, 248), "patrol": Vector2(4504, 4576)},
	{"name": "RaiderCitadelRoad", "kind": "raider", "position": Vector2(4792, 280), "patrol": Vector2(4752, 4832)},
	{"name": "HopliteCitadelWall", "kind": "hoplite", "position": Vector2(5248, 232), "patrol": Vector2(5160, 5336)},
	{"name": "PeltastCitadelSteps", "kind": "peltast", "position": Vector2(5440, 248), "patrol": Vector2(5400, 5472)},
	{"name": "HopliteTrojanCaptain", "kind": "hoplite", "position": Vector2(5680, 280), "patrol": Vector2(5640, 5704)},
]
const FLASKS := [
	{"name": "HealthFlaskOuterWall", "position": Vector2(1184, 248)},
	{"name": "HealthFlaskGateCourt", "position": Vector2(1888, 232)},
	{"name": "HealthFlaskRampart", "position": Vector2(3104, 168)},
	{"name": "HealthFlaskInnerWall", "position": Vector2(4416, 232)},
	{"name": "HealthFlaskCitadel", "position": Vector2(5056, 248)},
]
const EXIT := Vector2(5728, FLOOR_Y)
const GATE_GUARD := "HopliteTrojanCaptain"
const TIPS := [
	{"x": 496, "end": 704, "text": "Climb Troy's ramparts with normal jumps."},
	{"x": 880, "end": 1056, "text": "Bait the hoplite's spear, then counter in recovery."},
	{"x": 2816, "end": 3008, "text": "The high wall leads to the inner defenses."},
	{"x": 5536, "end": 5680, "text": "Defeat the Trojan captain to open the citadel gate."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
