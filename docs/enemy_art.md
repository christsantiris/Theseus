# Greek soldier enemies

Theseus is the visual reference for all three enemies: warm skin, shaded bronze,
readable helmets, adult human proportions, layered cloth, and articulated limbs.
The replacement sheets use the same 72×56 animation cells, right-facing artwork,
and nearest-neighbor rendering as the player. Enemy feet share pixel row 53.

| Enemy | Visual identity | Combat role | Atlas |
| --- | --- | --- | --- |
| Hoplite | Bronze cuirass, round shield, red-crested helmet, spear | Crouches on guard, stands when approached, marches and thrusts; takes two sword hits | `hoplite.png`, 9 frames |
| Peltast | Teal tunic and crest, bronze helmet, short javelin held in both hands | Patrols, plants his feet, telegraphs a short melee jab, then recovers; never throws the weapon | `peltast.png`, 7 frames |
| Raider | Crimson tunic and cape, bronze helmet, curved iron sword | Engages nearby visible targets, telegraphs a short sword lunge, then recovers without contact damage | `raider.png`, 7 frames |

Artwork lives in `assets/art/characters/`; corresponding scripts and scenes live
in `scenes/enemies/`. Level instances use the same names. Patrol placement,
damage, and scoring are retained. Collision heights, the
hoplite's spear strike, and the peltast's held-javelin hitbox fit the artwork.
The hoplite's crouch/rise collision box follows its stance.

The Raider has a 0.45-second windup, a 0.22-second lunge at 120 pixels/second,
and a 0.85-second recovery. He commits to his windup direction and hits each
target at most once per lunge, using a sword hitbox rather than body contact.
He attacks only within 64 horizontal pixels and 24 vertical pixels, with a clear
line of sight and safe space to lunge. Sword hits still deal damage in every
state. His fire effect has been removed. Hoplite behavior is unchanged.

Test the Raider's engagement, damage, telegraph, recovery, and terrain safety:

```sh
godot --headless --path . --script res://tests/raider_behavior.gd --fixed-fps 60
```

## Peltast melee javelin

The Peltast retains his placement, two health points, and 100-point score. His
weapon is always held: four walk frames, windup, short two-handed jab, and recovery.
No projectile is created, and the unused projectile scene, script, and texture
have been removed.

He waits when farther than 192 horizontal pixels from Theseus and starts an
attack only within 38 horizontal and 12 vertical pixels, with clear line of
sight. His 0.5-second windup locks his facing direction, followed by a stationary
0.18-second jab and 0.8-second recovery. Only the attached weapon hitbox damages
Theseus, once per jab; body overlap during patrol, windup, and recovery is safe.

Back away, jump over the jab, or move past the committed windup to make it miss.
Sword hits work in every state. A stomp during the jab or recovery finishes him;
stomping during patrol or windup only bounces Theseus, matching the existing
stomp interaction. Raider and Hoplite behavior have not changed with this update.

```sh
godot --headless --path . --script res://tests/peltast_behavior.gd --fixed-fps 60
```

## Review

![Theseus beside the three soldiers in standing and attacking poses](enemy_roster.png)

The comparison uses actual game textures at native pixel size. Test the enemies
in Level 1 with:

```sh
godot --path . --scene res://scenes/levels/level_1.tscn
```

Artwork was created with the built-in imagegen tool using the player sprite sheet
as the style reference, then packed into the game's fixed-size atlas cells with
Godot's Image API. Production art briefs adapted from the generation prompts are
recorded in [enemy_sprite_prompts.json](enemy_sprite_prompts.json), using neutral
source-atlas descriptions and the current soldier names throughout.

## Validation

- Godot 4.7.2 imported all renamed scenes and textures successfully.
- All 23 frames have transparent margins, fit their atlas cells, and end on foot row 53.
- A focused engine smoke test passed for all animation regions, crouch/rise
  collision heights, spear strike height, javelin strike height, lunge/recovery,
  damage vulnerabilities, and the combined 350-point defeat score.
- Level 1 completed a 300-frame run without runtime errors.
- Godot reports an MP3 stream/playback leak at shutdown from the existing music
  autoload; the same warning occurs in the art-only packing and preview runs,
  which do not instantiate any enemies.
