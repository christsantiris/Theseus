extends RefCounted

## Level difficulty curve shared by every enemy.
##
## Each lever eases from a forgiving Level 1 value toward a limit that stays
## winnable, so every level is harder than the one before it by a shrinking step:
##     multiplier(level) = limit + (start - limit) * rate ^ (level - 1)
## Level 3 is the neutral baseline (all multipliers 1.0). Levels past 5 continue
## the same curve; the floors below keep every attack readable and punishable.
##
##   level   telegraph  punish  rest   speed
##     1       1.25      1.20   1.25   0.95
##     2       1.11      1.09   1.11   0.98
##     3       1.00      1.00   1.00   1.00
##     4       0.92      0.93   0.91   1.02
##     5       0.86      0.88   0.85   1.04
##     8       0.77      0.78   0.72   1.09
##
## Damage stays at one health per hit on every level: with five health, larger
## hits would be the sudden spike this curve is meant to avoid.

## Shortest windup a tuned attack may have, in seconds. Human reaction time is
## roughly 0.25 seconds, so a tuned telegraph is never shorter than this.
const MIN_TELEGRAPH := 0.3
## Shortest window to counter after a missed attack.
const MIN_PUNISH := 0.35
## Shortest pause between attacks.
const MIN_REST := 0.35
## Level from which a level's gate guard gains one extra health as a mini-boss.
const ELITE_FROM_LEVEL := 3

## start: Level 1 multiplier; limit: value approached on late levels; rate:
## how quickly each level closes the remaining gap.
const CURVES := {
	# Windup before an attack lands. Lower is harder.
	"telegraph": {"start": 1.25, "limit": 0.70, "rate": 0.7385},
	# Recovery after an attack, while the enemy is open to a counter.
	"punish": {"start": 1.20, "limit": 0.70, "rate": 0.7746},
	# Cooldown between attacks. Lower means more frequent attacks.
	"rest": {"start": 1.25, "limit": 0.60, "rate": 0.7845},
	# Patrol and pursuit speed. Higher is harder.
	"speed": {"start": 0.95, "limit": 1.25, "rate": 0.9129},
}

## Tuning for enemies placed outside a level, such as review scenes and
## behaviour tests: authored timings exactly, without floors.
const NEUTRAL := {"level": 0, "telegraph": 1.0, "punish": 1.0, "rest": 1.0, "speed": 1.0, "elite": false}


static func multiplier(lever: String, level: int) -> float:
	var curve: Dictionary = CURVES[lever]
	var steps := maxi(level, 1) - 1
	return curve.limit + (curve.start - curve.limit) * pow(curve.rate, steps)


static func for_level(level: int, elite := false) -> Dictionary:
	return {
		"level": level,
		"telegraph": multiplier("telegraph", level),
		"punish": multiplier("punish", level),
		"rest": multiplier("rest", level),
		"speed": multiplier("speed", level),
		"elite": elite and level >= ELITE_FROM_LEVEL,
	}


static func telegraph(seconds: float, tuning: Dictionary) -> float:
	return _scaled(seconds, tuning, "telegraph", MIN_TELEGRAPH)


static func punish(seconds: float, tuning: Dictionary) -> float:
	return _scaled(seconds, tuning, "punish", MIN_PUNISH)


static func rest(seconds: float, tuning: Dictionary) -> float:
	return _scaled(seconds, tuning, "rest", MIN_REST)


static func _scaled(seconds: float, tuning: Dictionary, lever: String, floor_seconds: float) -> float:
	if tuning.level <= 0:
		return seconds
	return maxf(seconds * tuning[lever], floor_seconds)
