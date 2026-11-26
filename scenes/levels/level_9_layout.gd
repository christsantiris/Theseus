extends RefCounted

const TIME_LIMIT := 180.0

const WIDTH := 5760
const HEIGHT := 352
const FLOOR_Y := 280
const START := Vector2(48, 280)
const SECTIONS := [
	{"x": 0, "name": "Gates of Knossos"},
	{"x": 960, "name": "Twisting Galleries"},
	{"x": 1920, "name": "Hall of the Bull"},
	{"x": 2880, "name": "Ariadne's Passage"},
	{"x": 3840, "name": "The Silent Gallery"},
	{"x": 4800, "name": "The Minotaur's Lair"},
]
const PLATFORMS := [
	Rect2(448, 264, 112, 16),
	Rect2(560, 248, 224, 32),
	Rect2(784, 264, 112, 16),
	Rect2(1088, 264, 112, 16),
	Rect2(1200, 248, 112, 32),
	Rect2(1312, 232, 224, 48),
	Rect2(1536, 248, 112, 32),
	Rect2(1648, 264, 112, 16),
	Rect2(2176, 264, 112, 16),
	Rect2(2288, 248, 112, 32),
	Rect2(2400, 232, 112, 48),
	Rect2(2512, 216, 224, 64),
	Rect2(2736, 248, 112, 32),
	Rect2(2848, 264, 112, 16),
	Rect2(3264, 264, 112, 16),
	Rect2(3376, 248, 224, 32),
	Rect2(3600, 264, 112, 16),
	Rect2(3968, 264, 112, 16),
	Rect2(4080, 248, 224, 32),
	Rect2(4304, 264, 112, 16),
]
# Low-roofed corridors remain walkable with the existing planted duck controls.
const CEILINGS := [Rect2(1824, 0, 144, 224), Rect2(3040, 0, 144, 224)]
const ENEMIES := [
	{"name": "RaiderEntrance", "kind": "raider", "position": Vector2(304, 280), "patrol": Vector2(248, 376)},
	{"name": "HopliteFirstGallery", "kind": "hoplite", "position": Vector2(672, 248), "patrol": Vector2(600, 752)},
	{"name": "PeltastLowerGallery", "kind": "peltast", "position": Vector2(976, 280), "patrol": Vector2(944, 1040)},
	{"name": "RaiderUpperTurn", "kind": "raider", "position": Vector2(1424, 232), "patrol": Vector2(1352, 1496)},
	{"name": "PeltastDescent", "kind": "peltast", "position": Vector2(1712, 264), "patrol": Vector2(1680, 1736)},
	{"name": "HopliteBullHall", "kind": "hoplite", "position": Vector2(2112, 280), "patrol": Vector2(2088, 2152)},
	{"name": "RaiderHighHall", "kind": "raider", "position": Vector2(2600, 216), "patrol": Vector2(2544, 2696)},
	{"name": "PeltastHighHall", "kind": "peltast", "position": Vector2(2704, 216), "patrol": Vector2(2664, 2712)},
	{"name": "HoplitePassage", "kind": "hoplite", "position": Vector2(2968, 280), "patrol": Vector2(2968, 3008)},
	{"name": "RaiderPassage", "kind": "raider", "position": Vector2(3464, 248), "patrol": Vector2(3408, 3544)},
	{"name": "PeltastLastTurn", "kind": "peltast", "position": Vector2(3568, 248), "patrol": Vector2(3528, 3576)},
	{"name": "HopliteLairGuard", "kind": "hoplite", "position": Vector2(3784, 280), "patrol": Vector2(3752, 3816)},
	{"name": "RaiderSilentGallery", "kind": "raider", "position": Vector2(3896, 280), "patrol": Vector2(3856, 3936)},
	{"name": "PeltastSilentGallery", "kind": "peltast", "position": Vector2(4176, 248), "patrol": Vector2(4112, 4256)},
	{"name": "HopliteSilentGallery", "kind": "hoplite", "position": Vector2(4592, 280), "patrol": Vector2(4512, 4688)},
	{"name": "Minotaur", "kind": "minotaur", "position": Vector2(5440, 280), "patrol": Vector2(5040, 5624)},
]
const FLASKS := [
	{"name": "GalleryFlask", "position": Vector2(1600, 248)},
	{"name": "BullHallFlask", "position": Vector2(2800, 248)},
	{"name": "PassageFlask", "position": Vector2(3648, 264)},
]
const EXIT := Vector2(5712, 280)
const GATE_GUARD := "Minotaur"
const TimingObstacle := preload("res://scenes/objects/timing_obstacle.gd")
const TIMING_OBSTACLE := {
	"name": "SilentGalleryGate", "kind": TimingObstacle.Kind.STONE_GATE,
	"position": Vector2(4454, 280), "width": 20.0, "durations": Vector3(3.45, 1, 2.45),
}

const TIPS := [
	{"x": 168, "end": 320, "text": "Follow the bronze thread through the labyrinth."},
	{"x": 1776, "end": 1896, "text": "Low stone lintel ahead. Keep to the ground."},
	{"x": 4856, "end": 5040, "text": "Prepare to jump the Minotaur’s charge."},
	{"x": 5080, "end": 5280, "text": "Jump his low charge. Counter after the headbutt."},
	{"x": 4399, "end": 4454, "text": "Dust warns that the stone gate is about to descend."},
]


static func surface_at(x: float) -> float:
	var surface := float(FLOOR_Y)
	for platform: Rect2 in PLATFORMS:
		if x >= platform.position.x and x < platform.end.x:
			surface = minf(surface, platform.position.y)
	return surface
