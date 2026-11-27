extends RefCounted

const TIME_LIMIT := 180.0

const WIDTH := 5760
const HEIGHT := 256
const FLOOR_Y := 152
const START := Vector2(48, FLOOR_Y)

const SECTIONS := [
	{"x": 0, "name": "The King's Road"},
	{"x": 960, "name": "Broken Colonnade"},
	{"x": 1920, "name": "Olive Terraces"},
	{"x": 2880, "name": "Ruined Aqueduct"},
	{"x": 3840, "name": "Sacred Grove"},
	{"x": 4800, "name": "Temple Approach"},
]

# Each platform is a solid stone terrace extending down to the ground.
# Required upward steps are 16 or 32 pixels; the floor catches missed jumps.
const PLATFORMS := [
	Rect2(248, 120, 112, 32),
	Rect2(376, 104, 96, 48),
	Rect2(1056, 136, 96, 16),
	Rect2(1168, 120, 128, 32),
	Rect2(1312, 104, 96, 48),
	Rect2(2240, 136, 96, 16),
	Rect2(2352, 120, 128, 32),
	Rect2(2496, 104, 80, 48),
	Rect2(2960, 136, 96, 16),
	Rect2(3072, 120, 128, 32),
	Rect2(3216, 104, 96, 48),
	Rect2(3344, 120, 128, 32),
	Rect2(3504, 136, 80, 16),
	Rect2(4000, 136, 112, 16),
	Rect2(4112, 120, 224, 32),
	Rect2(4336, 136, 112, 16),
	Rect2(5136, 136, 96, 16),
	Rect2(5248, 120, 128, 32),
]

const ENEMIES := [
	{"name": "Raider", "kind": "raider", "position": Vector2(168, 152), "patrol": Vector2(96, 208)},
	{"name": "Peltast", "kind": "peltast", "position": Vector2(304, 120), "patrol": Vector2(268, 340)},
	{"name": "Hoplite", "kind": "hoplite", "position": Vector2(800, 152), "patrol": Vector2(704, 864)},
	{"name": "PeltastColonnade", "kind": "peltast", "position": Vector2(1360, 104), "patrol": Vector2(1328, 1392)},
	{"name": "RaiderColonnade", "kind": "raider", "position": Vector2(1536, 152), "patrol": Vector2(1456, 1616)},
	{"name": "HopliteColonnade", "kind": "hoplite", "position": Vector2(1760, 152), "patrol": Vector2(1696, 1808)},
	{"name": "RaiderOlives", "kind": "raider", "position": Vector2(2128, 152), "patrol": Vector2(2064, 2192)},
	{"name": "PeltastOlives", "kind": "peltast", "position": Vector2(2400, 120), "patrol": Vector2(2368, 2464)},
	{"name": "RaiderTerraces", "kind": "raider", "position": Vector2(2704, 152), "patrol": Vector2(2624, 2800)},
	{"name": "PeltastAqueductWest", "kind": "peltast", "position": Vector2(3136, 120), "patrol": Vector2(3088, 3184)},
	{"name": "PeltastAqueductEast", "kind": "peltast", "position": Vector2(3408, 120), "patrol": Vector2(3360, 3456)},
	{"name": "HopliteAqueduct", "kind": "hoplite", "position": Vector2(3648, 152), "patrol": Vector2(3616, 3696)},
	{"name": "RaiderGrove", "kind": "raider", "position": Vector2(3896, 152), "patrol": Vector2(3856, 3952)},
	{"name": "PeltastGrove", "kind": "peltast", "position": Vector2(4224, 120), "patrol": Vector2(4144, 4304)},
	{"name": "HopliteGrove", "kind": "hoplite", "position": Vector2(4624, 152), "patrol": Vector2(4528, 4704)},
	{"name": "RaiderTemple", "kind": "raider", "position": Vector2(5008, 152), "patrol": Vector2(4944, 5088)},
	{"name": "PeltastTemple", "kind": "peltast", "position": Vector2(5312, 120), "patrol": Vector2(5264, 5360)},
	{"name": "HopliteTempleOuter", "kind": "hoplite", "position": Vector2(5456, 152), "patrol": Vector2(5424, 5488)},
	{"name": "HopliteTempleGuard", "kind": "hoplite", "position": Vector2(5600, 152), "patrol": Vector2(5568, 5648)},
]

const FLASKS := [
	{"name": "HealthFlaskRoad", "position": Vector2(920, 152)},
	{"name": "HealthFlaskColonnade", "position": Vector2(1968, 152)},
	{"name": "HealthFlaskTerrace", "position": Vector2(3080, 120)},
	{"name": "HealthFlaskTemple", "position": Vector2(4560, 152)},
]


const EXIT := Vector2(5712, 152)
const GATE_GUARD := "HopliteTempleGuard"

const TimingObstacle := preload("res://scenes/objects/timing_obstacle.gd")
const TIMING_OBSTACLE := {
	"name": "BronzeWeight", "kind": TimingObstacle.Kind.WEIGHT,
	"position": Vector2(1180, 120), "width": 104.0, "durations": Vector3(0, 0, 4),
}

const TIPS := [
	{"x": 96, "end": 224, "text": "Sword hits deal damage. Two hits fell a raider."},
	{"x": 224, "end": 288, "text": "Hold Jump to climb these terraces."},
	{"x": 288, "end": 480, "text": "Land on an enemy: both lose one health."},
	{"x": 640, "end": 832, "text": "Spear guards take two sword hits."},
	{"x": 1125, "end": 1180, "text": "Run under the bronze weight as it swings away."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
