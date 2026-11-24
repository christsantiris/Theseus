extends SceneTree

## Guards the level difficulty curve: every level must be harder than the one
## before it, by a manageable step, and every tuned attack must stay readable.
## New level_N_layout.gd files are scored automatically.
##
## The score is a heuristic for comparing levels, not a simulation:
##   threat   = sum of enemy weights, x1.5 for an elite gate guard, x1.15 for an
##              enemy that can join a neighbour within GROUP_RANGE
##   pressure = 1/telegraph * sqrt(1/punish) * sqrt(1/rest) * speed (level curve)
##   score    = threat * pressure * survival + PIT_COST per spike pit
##   survival = (BASE_HEALTH + BASE_HEALING) / (BASE_HEALTH + flask healing);
##              bonus flasks on risky ledges count half
## Healing is the main content lever for smoothing steps: a level that adds
## heavier enemies can carry more flasks, and a lighter one fewer.

const Difficulty := preload("res://scenes/levels/difficulty.gd")
const LEVELS_DIR := "res://scenes/levels"
## Relative danger at neutral tuning; a two-health Raider is 1.0.
const WEIGHTS := {
	# Lane obstacles with one health; dangerous mainly when mistimed.
	"bird": 0.7,
	# Pursues and lunges.
	"raider": 1.0, "spartoi": 1.0,
	# Holds ground and jabs at short range.
	"peltast": 0.9, "telchine": 0.9,
	# Duckable high thrust; short low lunge. Both have exposed recoveries.
	"merfolk": 0.9, "reefblade": 1.0,
	# Invulnerable crouch and the quickest authored windup.
	"hoplite": 1.25,
	# Hops and charges; can be bounced on.
	"satyr": 1.2,
	# Long reach, invulnerable guard after each strike.
	"lamia": 1.2,
	# Fast pursuers that come in pairs (the pair bonus applies too).
	"cerberus_pup": 1.1,
	# Ranged boulders and three health.
	"cyclops": 1.4,
	# Committed charges and four health.
	"bronze_bull": 1.6,
	# Three heads with two health each.
	"hydra": 4.0,
}
const GROUP_RANGE := 128.0
const PIT_COST := 0.5
const BASE_HEALTH := 5.0
const BASE_HEALING := 10.0
## Each level must be at least 10% and at most 40% harder than the one before.
const MIN_STEP := 1.1
const MAX_STEP := 1.4

var _failures := 0


func _initialize() -> void:
	_check_curve()
	_check_floors()
	var scores := {}
	for level in _level_numbers():
		scores[level] = _score(level)
	var levels := scores.keys()
	levels.sort()
	for i in levels.size():
		var level: int = levels[i]
		var line := "Level %d: %.1f" % [level, scores[level]]
		if i > 0:
			var ratio: float = scores[level] / scores[levels[i - 1]]
			line += "  (x%.2f)" % ratio
			_expect(ratio >= MIN_STEP, "Level %d is harder than level %d" % [level, levels[i - 1]])
			_expect(ratio <= MAX_STEP, "Level %d is at most %d%% harder than level %d" % [level, roundi((MAX_STEP - 1.0) * 100), levels[i - 1]])
		print(line)
	if _failures == 0:
		print("PASS: difficulty rises every level in bounded steps; tuned attacks keep readable windups and counters.")
	quit(1 if _failures else 0)


func _check_curve() -> void:
	# Each lever moves the same way every level, by a shrinking amount.
	for lever: String in Difficulty.CURVES:
		var harder_when_lower: bool = lever != "speed"
		var previous_step := INF
		for level in range(1, 21):
			var a := Difficulty.multiplier(lever, level)
			var b := Difficulty.multiplier(lever, level + 1)
			var step := absf(b - a)
			_expect((b < a) == harder_when_lower and step > 0.0, "%s gets harder from level %d to %d" % [lever, level, level + 1])
			_expect(step <= previous_step + 1e-6, "%s steps shrink by level %d" % [lever, level + 1])
			previous_step = step
	for lever in ["telegraph", "punish", "rest", "speed"]:
		_expect(absf(Difficulty.multiplier(lever, 3) - 1.0) < 0.005, "%s is neutral on level 3" % lever)


func _check_floors() -> void:
	# The fastest authored windup (Hoplite, 0.22 s) still gets a fair telegraph
	# on the hardest level the curve can reach.
	var late := Difficulty.for_level(50)
	_expect(Difficulty.telegraph(0.22, late) >= Difficulty.MIN_TELEGRAPH, "Late telegraphs stay at least %.2f s" % Difficulty.MIN_TELEGRAPH)
	_expect(Difficulty.punish(0.4, late) >= Difficulty.MIN_PUNISH, "Late counter windows stay open")
	_expect(Difficulty.rest(0.35, late) >= Difficulty.MIN_REST, "Late attack pauses stay above the floor")
	_expect(Difficulty.telegraph(0.45, Difficulty.NEUTRAL) == 0.45, "Untuned enemies keep authored timings")
	_expect(not Difficulty.for_level(2, true).elite and Difficulty.for_level(3, true).elite, "Gate guards become elite from level 3")


func _score(level: int) -> float:
	var layout: Script = load("%s/level_%d_layout.gd" % [LEVELS_DIR, level])
	var tuning := Difficulty.for_level(level)
	var pressure: float = (
		1.0 / tuning.telegraph * sqrt(1.0 / tuning.punish) * sqrt(1.0 / tuning.rest) * tuning.speed
	)
	var threat := 0.0
	for encounter: Dictionary in layout.ENEMIES:
		_expect(WEIGHTS.has(encounter.kind), "Level %d enemy kind %s has a difficulty weight" % [level, encounter.kind])
		var weight: float = WEIGHTS.get(encounter.kind, 1.0)
		if encounter.name == layout.GATE_GUARD and encounter.kind != "hydra" and level >= Difficulty.ELITE_FROM_LEVEL:
			weight *= 1.5
		for other: Dictionary in layout.ENEMIES:
			if other != encounter and absf(other.position.x - encounter.position.x) <= GROUP_RANGE:
				weight *= 1.15
				break
		threat += weight
	var healing := 0.0
	for flask: Dictionary in layout.FLASKS:
		healing += 1.0 if flask.get("bonus", false) else 2.0
	var constants := layout.get_script_constant_map()
	var pits: int = constants.PITS.size() if constants.has("PITS") else 0
	var survival := (BASE_HEALTH + BASE_HEALING) / (BASE_HEALTH + healing)
	return threat * pressure * survival + PIT_COST * pits


func _level_numbers() -> Array[int]:
	var numbers: Array[int] = []
	for file in DirAccess.get_files_at(LEVELS_DIR):
		if file.begins_with("level_") and file.ends_with("_layout.gd"):
			var number := file.trim_prefix("level_").trim_suffix("_layout.gd")
			if number.is_valid_int():
				numbers.append(number.to_int())
	numbers.sort()
	return numbers


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
