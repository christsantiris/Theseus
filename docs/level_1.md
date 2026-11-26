# Level 1 — The Temple Road

A complete, left-to-right opening level built from the original 960-pixel test
course. The route is now **5,760 pixels long**, or eighteen 320-pixel screens,
leading from a cypress-lined road to the guarded temple entrance.

![Views from the route](level_1_preview.png)

## Cinematic scenery

Level 1 uses **one continuous Attic landscape**, with connected mountains,
terraced olive groves, a consistent sky, and a distant sanctuary. It never
switches paintings or blends unrelated edges. A 2,172×724 source image renders
at 768×256 world units; the camera moves across it at 8% of horizontal travel
and 30% of vertical travel. The existing camera still follows Theseus' climbs
and descents within the 5,760×256 visual bounds.

Fifteen complete transparent scenery objects establish the route's six areas:
eight olive-and-cypress groves, six ruined colonnades, and one three-arch
aqueduct. These scroll at 82% of horizontal camera travel and stay rooted at
the road's ground height. Trees, columns and arches remain whole as the camera
passes them. There are no panorama seams, fading architecture, repeated road
aprons or runtime background-image processing in this level.

The distant landscape uses desktop/mobile GPU compression. Cutouts remain
lossless with their transparency intact. Grove and colonnade imports are capped
at 1,024 pixels on their longest side, sufficient for their displayed sizes;
the wider aqueduct retains its 2,172-pixel source width. All textures fit the
project's 4,096-pixel mobile limit. No scenery texture generates mipmaps; the
separate repeating stone terrain keeps its existing mipmaps.

Detailed masonry, waystones, and the temple facade complete the scenery. Ground and platform collision,
movement, pickups and temple entry retain their existing rules. The new grove adds three enemies and three terraces.
All eight levels now use continuous landscapes with independent landmarks.

Standing scenery uses measured painted bases from `scenery_grounding.gd`, with
one world pixel of overlap at the ground. This closes transparent-padding gaps
under trees, ruins, pots, columns, and waystones while preserving their artwork
and collision layout. See the [ground-contact regression](performance.md#scenery-ground-contacts).

## Route and encounter progression

| Area | World X | Purpose | Encounters |
| --- | --- | --- | --- |
| The King's Road | 0–959 | Establish run, full-height jump, and attack timing using the original raider, two raised platforms, peltast, and hoplite sequence. Short prompts introduce the enemy openings. | 1 Raider, 1 Peltast, 1 Hoplite |
| Broken Colonnade | 960–1919 | Climb a staircase of 16-pixel rises, then handle separate close-combat encounters after the drop. | 1 Peltast, 1 Raider, 1 Hoplite |
| Olive Terraces | 1920–2879 | Apply the learned timings around an elevated javelin fighter. A health flask on the upper terrace rewards climbing; the ground catches missed jumps. | 2 Raiders, 1 Peltast |
| Ruined Aqueduct | 2880–3839 | Cross ascending and descending stone terraces, with two separated javelin fighters and a final spear guard. | 2 Peltasts, 1 Hoplite |
| Sacred Grove | 3840–4799 | Cross a low grove terrace, with a Raider on the approach, a raised Peltast and a Hoplite on open ground. | 1 Raider, 1 Peltast, 1 Hoplite |
| Temple Approach | 4800–5759 | Remix the three soldier types in sequence. Defeat the named temple guard to raise the gate, then enter to complete Level 1. | 1 Raider, 1 Peltast, 2 Hoplites |

[Open the route map](level_1_map.svg) for exact enemy, pickup, and terrace positions.

There are **19 soldiers** and **5 health flasks**. The
maximum combat score is **2,200**: six Hoplites at 150 points, seven Peltasts at
100, and six Raiders at 100. Earlier enemies can be bypassed; only the temple
guard must be defeated to finish.

## Movement and fairness

The player's existing movement remains unchanged: speed 90 px/s, jump velocity
−260 px/s, and gravity 900 px/s². A held jump reaches about 38 pixels vertically
and 52 pixels horizontally on level ground. Required upward steps stay at 16–32
pixels, with broad stone landing surfaces. Most uphill gaps are 16 pixels; the
32-pixel gaps occur while descending. Continuous ground makes a missed terrace
jump recoverable. There are no blind lethal pits.

The first two raised platforms retain the test course's positions and heights.
Later terrain repeats and extends that pattern. Raiders occupy open ground;
Peltasts occupy readable raised positions; Hoplites guard ground approaches.
Raiders start their sword windup only against visible targets within 64 horizontal
and 24 vertical pixels, and their lunges respect terrain and patrol bounds.
Peltasts wait outside 192 horizontal pixels and engage only within 38 horizontal
and 12 vertical pixels. They use a held javelin for a stationary, telegraphed jab,
followed by a safe recovery window. There are no ranged enemy attacks.

Duck remains available, but the route does not require crouch-walking. First-clear
pacing is intended to be under the **3-minute limit** with combat and exploration;
this is a design target for human playtesting. The automated combat-free route
takes approximately **63 simulated seconds** and uses 17 jumps.

Landing on an enemy's head costs **one health for both Theseus and the enemy**.
It does not instantly defeat an enemy at full health. Side grazes do not count,
and the existing invulnerability window prevents repeated collision damage.
Sword damage occurs only while the blade is visibly extended during an attack.

## Recovery and completion

Health flasks restore two health and remain available when Theseus is already full.

Every attempt starts at the level entrance with full health and a **3:00 countdown**.
The timer turns red for the final 30 seconds. It freezes during pause, app
interruptions, temple entry, and completion. Running out of time opens Hades,
just like a fatal hit. **Retry Level** there restarts the entire level, including
all enemies and flasks, and restores the score carried in from earlier levels.
There are no checkpoint shrines or mid-level saves.

The title's **Load** button restarts the current level from its entrance
once Level 2 or later has been reached in this session. Replay also resets the
level and countdown. New Game resets the campaign and score to Level 1.
Session progress is held in memory; high scores are saved separately on disk.

- The temple gate remains physically closed until its guard is defeated. Reaching
  the open temple pauses combat while Theseus walks up the steps and fades into
  the doorway. The level-clear screen appears after he has entered, showing
  score, defeated count, and time, with Continue to Level 2, Replay Level, and
  Return to Title buttons. Entering [Level 2](level_2.md) starts a fresh countdown.
- The score carries into each next level. Replay Level restarts from the score
  Theseus entered the level with; only New Game resets it to 0.

![Theseus entering the temple before the level-clear screen](temple_entry_preview.gif)

## Editing and validation

`scenes/levels/level_1_layout.gd` contains the route, terraces, enemy patrols,
pickup positions, time limit, and tutorial prompts. `level_1_geometry.gd`
inherits the original collision construction from `level_geometry.gd`, then
renders the continuous landscape, independent scenery cutouts, and stone surfaces.
`assets/art/backgrounds/level_1/attic_landscape.png` is the single opaque painting;
`olive_grove.png`, `colonnade.png`, and `aqueduct.png` are transparent landmarks. `level_1_temple.gd` renders the cinematic facade used by the Greek sanctuary exits,
leaving gate collision, unlocking, and entry logic on the existing temple.
Each level owns its scenery renderer. Scenery is also visible in the editor.
`level_1.gd` builds the encounters and manages
the countdown, camera limits, pause, and completion. Enemy and pickup instances are
created from their existing reusable scenes at runtime.

Play the level directly:

```sh
godot --path . --scene res://scenes/levels/level_1.tscn
```

Run the integration checks:

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/level_1_smoke.gd --fixed-fps 60
godot --headless --path . --script res://tests/level_1_scenery.gd --fixed-fps 60
godot --headless --path . --script res://tests/player_combat.gd --fixed-fps 60
```

The suite checks placement against terrain, full-health pickup retention,
healing, enemy activation distance, actual death/reload,
entrance retry, gate collision and unlocking, completion, replay, and a
physics-driven traversal of the full route. Enemies are held still for that
traversal so it tests geometry independently of combat skill. Combat difficulty
and first-clear pacing still need human playtesting.

The scenery check verifies vertical camera and skyline movement, background
coverage through climbs and jumps and across the entire route, monotonic sampling
without wraps, natural proportions, extended ground and authored
terrace collisions, the open facade during paused temple entry, and camera and
renderer isolation from Levels 2–5. The route test also checks vertical camera
travel during actual movement and jumping.

## Extended approach

The route is 20% longer: 5,760 world units with a new Sacred Grove section
at X=3840–4799 before the final area. Three additional enemies occupy that
space. The countdown remains 3:00, and existing music keeps looping at its
configured offset. Background camera coverage includes the full extended route.
