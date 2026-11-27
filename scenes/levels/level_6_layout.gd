extends RefCounted

const TIME_LIMIT := 180.0

const WIDTH := 5760
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, FLOOR_Y)
const SECTIONS := [
	{"x": 0, "name": "Gorge Mouth"},
	{"x": 960, "name": "Temple Ledges"},
	{"x": 1920, "name": "Broken Causeway"},
	{"x": 2880, "name": "High Colonnade"},
	{"x": 3840, "name": "Western Temple Court"},
	{"x": 4800, "name": "Hydra Sanctuary"},
]

const PLATFORMS := [
	Rect2(736, 264, 96, 16),
	Rect2(832, 248, 96, 32),
	Rect2(928, 232, 256, 48),
	Rect2(1184, 248, 80, 32),
	Rect2(1264, 264, 80, 16),
	Rect2(2144, 264, 112, 16),
	Rect2(2256, 248, 112, 32),
	Rect2(2368, 232, 256, 48),
	Rect2(2624, 216, 112, 64),
	Rect2(2736, 200, 112, 80),
	Rect2(2848, 184, 112, 96),
	Rect2(2960, 168, 512, 112),
	Rect2(3472, 184, 112, 96),
	Rect2(3584, 200, 112, 80),
	Rect2(3696, 216, 112, 64),
	Rect2(3808, 232, 32, 48),
	Rect2(3840, 248, 96, 32),
	Rect2(3936, 264, 96, 16),
	Rect2(4448, 264, 64, 16),
	Rect2(4512, 248, 64, 32),
	Rect2(4576, 232, 224, 48),
	Rect2(4800, 232, 224, 48),
	Rect2(5024, 248, 64, 32),
	Rect2(5088, 264, 32, 16),
]

# These ledges can be reached from a staggered bull. The main route never
# requires a ride, and their one-way tops leave the charging lane clear.
const BONUS_LEDGES := [Rect2(544, 224, 112, 8), Rect2(3328, 112, 112, 8)]
const BRIDGE_TIMING := Vector3(3.0, 0.8, 2.0)
const BRIDGE_WIDTH := 112.0
const BRIDGE_PIT_DEPTH := 48.0
const PITS := [
	{"name": "GorgeMouthPit", "bridge": "GorgeMouthBridge", "position": Vector2(80, 280), "width": BRIDGE_WIDTH, "depth": BRIDGE_PIT_DEPTH},
	{"name": "CausewayPit", "bridge": "CausewayBridge", "position": Vector2(2016, 280), "width": BRIDGE_WIDTH, "depth": BRIDGE_PIT_DEPTH},
	{"name": "SanctuaryPit", "bridge": "SanctuaryBridge", "position": Vector2(5136, 280), "width": BRIDGE_WIDTH, "depth": BRIDGE_PIT_DEPTH},
]

const ENEMIES := [
	{"name": "BullGorgeMouth", "kind": "bronze_bull", "position": Vector2(432, 280), "patrol": Vector2(224, 704)},
	{"name": "TemplePupA", "kind": "cerberus_pup", "position": Vector2(1024, 232), "patrol": Vector2(960, 1152), "pack": "TemplePack", "delay": 0.3},
	{"name": "TemplePupB", "kind": "cerberus_pup", "position": Vector2(1072, 232), "patrol": Vector2(960, 1152), "pack": "TemplePack", "delay": 0.9},
	{"name": "BullDryRiver", "kind": "bronze_bull", "position": Vector2(1696, 280), "patrol": Vector2(1376, 1888)},
	{"name": "CausewayPupA", "kind": "cerberus_pup", "position": Vector2(2448, 232), "patrol": Vector2(2400, 2592), "pack": "CausewayPack", "delay": 0.3},
	{"name": "CausewayPupB", "kind": "cerberus_pup", "position": Vector2(2496, 232), "patrol": Vector2(2400, 2592), "pack": "CausewayPack", "delay": 0.9},
	{"name": "BullColonnade", "kind": "bronze_bull", "position": Vector2(3264, 168), "patrol": Vector2(3008, 3440)},
	{"name": "BullWesternCourt", "kind": "bronze_bull", "position": Vector2(4264, 280), "patrol": Vector2(4080, 4384)},
	{"name": "WesternPupA", "kind": "cerberus_pup", "position": Vector2(4632, 232), "patrol": Vector2(4608, 4752), "pack": "WesternPack", "delay": 0.3},
	{"name": "WesternPupB", "kind": "cerberus_pup", "position": Vector2(4680, 232), "patrol": Vector2(4608, 4752), "pack": "WesternPack", "delay": 0.9},
	{"name": "SanctuaryPupA", "kind": "cerberus_pup", "position": Vector2(4864, 232), "patrol": Vector2(4800, 4992), "pack": "SanctuaryPack", "delay": 0.3},
	{"name": "SanctuaryPupB", "kind": "cerberus_pup", "position": Vector2(4912, 232), "patrol": Vector2(4800, 4992), "pack": "SanctuaryPack", "delay": 0.9},
	{"name": "HydraTempleGuard", "kind": "hydra", "position": Vector2(5568, 280), "patrol": Vector2(5440, 5648)},
]

const FLASKS := [
	{"name": "HealthFlaskBullLedge", "position": Vector2(616, 224), "bonus": true},
	{"name": "HealthFlaskCauseway", "position": Vector2(2136, 280)},
	{"name": "HealthFlaskHighLedge", "position": Vector2(3384, 112), "bonus": true},
	{"name": "HealthFlaskSanctuary", "position": Vector2(5328, 280)},
]
const EXIT := Vector2(5712, FLOOR_Y)
const GATE_GUARD := "HydraTempleGuard"
const TIPS := [
	{"x": 48, "end": 80, "text": "Wait for the bridge, then run across."},
	{"x": 160, "end": 352, "text": "Jump the bull's charge; it cannot turn mid-charge."},
	{"x": 480, "end": 704, "text": "Airborne Duck + Sword staggers a bull's back."},
	{"x": 800, "end": 1056, "text": "Pups run in pairs. Sword hits interrupt their leaps."},
	{"x": 1920, "end": 2016, "text": "Cross the bridge before it retracts."},
	{"x": 3104, "end": 3376, "text": "Ride the bull, then jump to the high flask ledge."},
	{"x": 5280, "end": 5472, "text": "Cut all three Hydra heads. Jump for the high heads."},
	{"x": 5056, "end": 5136, "text": "Wait for the sanctuary bridge."},
]


static func surface_at(x: float, include_bonus: bool = false) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	if include_bonus:
		for ledge: Rect2 in BONUS_LEDGES:
			if x >= ledge.position.x and x < ledge.end.x:
				surface = minf(surface, ledge.position.y)
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
