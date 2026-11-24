# Level 6 — Atlantis

Level 6 is playable. Cross a partially flooded Atlantean city, fight Merfolk,
and defeat their captain to enter Poseidon's sanctuary. The 4,800×352-unit
route uses the existing movement and combat controls on desktop and mobile.

![Atlantis route and Merfolk encounters](level_6_preview.png)

## Setting and play

Theseus enters a partially flooded Atlantean city and fights through its dry
causeways to Poseidon's sanctuary. Turquoise canals, pale marble, oxidized bronze,
wave carvings, submerged colonnades, and a distant ringed palace distinguish
Atlantis from the earlier rocky coast. The art keeps the detailed cinematic
style and side view established by Theseus and the rebuilt scenery.

The setting is flooded ruins with dry walkways. Theseus keeps his
current running, jumping, ducking, sword attacks, gravity, and five health bars.
Deep water remains behind the playable causeways. Two shallow canal recesses
have solid bottoms and can be jumped across or climbed out of; entering them
causes no damage. Their depth does not submerge Theseus's head. Swimming,
oxygen, currents, and rising tides are outside this first implementation.

The movement design uses the existing 320×180 world coordinates, 90-unit run
speed, -260 jump velocity, and 900 gravity. A full jump rises about 37.6 world
units before collision and frame-step effects. Required upward steps are 16
units; the two canal recesses are 24 units deep and 32/40 units wide, matching
sizes already used by the game's escapable pits. Traversal is checked with the real controller, including full-height touch
jumps in the combat regression.

## Route

The world is 4,800×352 units, starting at (48, 280) and ending at
(4752, 280). It has twenty-three connected raised terraces, fifteen upward
steps, two shallow canal jumps, and a summit at y=152. Descending steps drop
16–32 units. The lower causeway catches missed jumps. There are no required
moving platforms or timed jumps.

| Area | World X | Route and first-clear purpose |
| --- | --- | --- |
| Drowned Harbor | 0–959 | A quiet arrival quay, a lone trident guard with room to duck or retreat, then two short climbs and another guard. Teach the new silhouette before combining it with difficult terrain. |
| Ring Canals | 960–1919 | A broad upper landing introduces the blade fighter. Descend past a trident guard, cross the first shallow canal, then climb to another broad combat landing. |
| Sunken Agora | 1920–2879 | A quiet shrine courtyard precedes a stair climb. A trident guard and a later blade fighter occupy separate landings; a flask follows the fight. |
| Palace Ascent | 2880–3839 | Climb to the highest palace terrace for an isolated blade fight. Descend through two trident-guard landings, with recovery space between them. |
| Poseidon's Sanctuary | 3840–4799 | Descend to a flask and the second canal, then a safe shrine. Fight a blade fighter, a trident guard, and finally the elite Merfolk captain guarding the exit. |

The raised terrain is listed below. All dimensions use world units;
each terrace extends down to the main causeway at y=280. The lower route is
solid except for the two explicitly recessed canal beds.

| Terrace X span | Top Y | Width |
| --- | ---: | ---: |
| 640–752 | 264 | 112 |
| 752–960 | 248 | 208 |
| 960–1216 | 232 | 256 |
| 1216–1328 | 248 | 112 |
| 1328–1440 | 264 | 112 |
| 1552–1664 | 264 | 112 |
| 1664–1920 | 248 | 256 |
| 1920–2032 | 264 | 112 |
| 2160–2272 | 264 | 112 |
| 2272–2384 | 248 | 112 |
| 2384–2640 | 232 | 256 |
| 2640–2752 | 216 | 112 |
| 2752–2880 | 200 | 128 |
| 2880–2992 | 184 | 112 |
| 2992–3104 | 168 | 112 |
| 3104–3424 | 152 | 320 |
| 3424–3552 | 184 | 128 |
| 3552–3680 | 216 | 128 |
| 3680–3840 | 248 | 160 |
| 3840–3968 | 264 | 128 |
| 4320–4432 | 264 | 112 |
| 4432–4576 | 248 | 144 |
| 4576–4624 | 264 | 48 |

| Shallow canal | Left X | Rim Y | Width / depth | Bed Y |
| --- | ---: | ---: | --- | ---: |
| Ring Canal | 1472 | 280 | 32 / 24 | 304 |
| Sanctuary Canal | 4016 | 280 | 40 / 24 | 304 |

The recesses have real terrain cuts and visible bright rims. Water is a shallow
visual layer over their beds, with neither a damage trigger nor an invisible
bridge. Both allow jumping out in either direction. Scenery bases leave the openings
clear. Pause freezes any water animation.

## Merfolk

Merfolk have scaled humanoid torsos, finned ears, webbed hands, bronze Greek
armor, and a single fish tail ending in two flukes. They brace and propel their
tails along wet stone; they do not walk on human legs or hover over the floor.
Their measured tail bases remain planted across all eight animation poses. Weapons
and crests distinguish their roles without relying on color alone.

There are two regular combat roles and one elite of the trident role. Both
regular roles start with two health; the captain receives the existing gate
elite bonus once, for three. Every attack deals one health. Ordinary body
collisions, including landing on a Merfolk, retain the existing one-health
trade for both characters. These are not safe-bounce enemies.

| Role | Count | Score each | Read and counter |
| --- | ---: | ---: | --- |
| Merfolk Trident Guard | 8 | 125 | Raises a held trident, then makes one stationary high thrust. Duck underneath or back away; stand and counter during recovery. |
| Merfolk Reefblade | 4 | 150 | Lowers a short bronze blade and coils its tail before a short, committed ground lunge. Jump over the weapon or retreat, then counter. Ducking does not avoid this low attack. |
| Merfolk Gate Captain | 1 | 250 | Reuses the trident guard's readable attack, with an additional bronze fin crest and three health. Defeating it opens the sanctuary. |

The maximum combat score is **1,850**. The captain must be defeated to finish the level. No Merfolk throws
its weapon, fires a projectile, or requires a new block/dodge input.

### Attack timing and pursuit

These are play-test tuning values, subject to combat review. The
existing difficulty curve applies once. At Level 6 it currently scales windup
by approximately 0.821, recovery by 0.839, cooldown by 0.793, and movement speed
by 1.060. The existing minimum timing floors remain in effect.

| Behavior | Authored value | Approximate Level 6 value |
| --- | --- | --- |
| Trident windup / active / recovery / cooldown | 0.70 / 0.18 / 1.10 / 1.25 seconds | 0.57 / 0.18 / 0.92 / 0.99 seconds |
| Trident pursuit speed | 26 units/second | 27.6 units/second |
| Reefblade windup / active / recovery / cooldown | 0.65 / 0.18 / 1.05 / 1.25 seconds | 0.53 / 0.18 / 0.88 / 0.99 seconds |
| Reefblade pursuit speed | 30 units/second | 31.8 units/second |
| Reefblade attack travel | 18 units over 0.18 seconds | Same committed travel |

A trident thrust must actually clear the duck pose. Theseus's current standing
and crouching bodies are 44 and 36 units high. The high strike band is
38–44 units above a shared flat landing, with at least two units above the
ducked body. Guards engage only when the fighters' feet are effectively level and never
retarget downward onto a crouching player. The visible trident and Theseus's
painted ducked head must also clear at preview, 540p, 720p, and desktop sizes.
Theseus's body shapes are unchanged. A straight jump cannot reliably clear
this high band; duck or retreat from a trident. Crouching currently prevents sword attacks, so the counter
comes after releasing Duck during the long recovery.

Reefblades are smaller than trident guards and use a 36-unit body. Their attacks occupy a low band that overlaps both standing and crouched
Theseus. Their ground travel stays fixed after windup. Jumping must clear the
weapon and body; landing on the fighter still counts as a collision. Windup
and attack direction lock together, and each committed attack can damage the
player at most once. Recovery is vulnerable, with no hidden invulnerability.

Both roles keep focus through attacks, recovery, and nearby jumps. They resume
safe pursuit or face Theseus while waiting at an edge; they do not turn back
into their patrol after a hit. Reuse the existing focus range, line-of-sight,
wall, and floor checks. Neither attack can pass through terrain, cross a canal,
or carry its owner off a landing. Nearby encounters use separate landings to keep the first play-test version
from depending on simultaneous attack juggling.

### Encounter positions

These are play-test placements, with feet on the authored route. Patrol extents
must remain inside the same safe landing, clear of canal beds and shrine spawns.
The 256/320-unit upper landings provide room for the first three blade fights;
the fourth uses the broad lower causeway after the final shrine.

| Area | Encounters (X, Y) |
| --- | --- |
| Drowned Harbor | Trident (384, 280), Trident (848, 248) |
| Ring Canals | Reefblade (1088, 232), Trident (1368, 264), Trident (1760, 248) |
| Sunken Agora | Trident (2328, 248), Reefblade (2512, 232) |
| Palace Ascent | Reefblade (3264, 152), Trident (3600, 216), Trident (3744, 248) |
| Poseidon's Sanctuary | Reefblade (4256, 280), Trident (4496, 248), Captain (4672, 280) |

## Recovery and progression

Entering from Level 5 saves the Level 6 entrance immediately, replacing
any gorge shrine as the latest load point. The Agora Shrine at (2064, 280)
saves a spawn at (2088, 280); the Sanctuary Shrine at (4096, 280) saves
(4120, 280). Each sits outside enemy patrols and gives a safe interval before
the next engagement. The final blade fighter's patrol stays at x>=4240,
at least 120 units from the second saved spawn.

Two health flasks sit at (888, 248) and (2800, 200), between the entrance and
full-healing shrines. Each restores two health, up to five. Both shrines heal
and snapshot score, defeated enemies, and collected flasks. Backtracking cannot
replace a later checkpoint; death, Title Load, and manual Save retain the
campaign's existing snapshot behavior. The two-flask balance keeps the existing
difficulty heuristic's increase from Level 5 within its 10–40% bounds; combat
pacing still needs human play testing.

The captain at (4672, 280) guards the exit at (4752, 280). Three sword hits
defeat the captain. Theseus enters the doorway using the existing steps and
fade sequence. Level 5 offers **Continue to Level 6**. Atlantis is the current
campaign endpoint; its completion offers Replay and Return to Title.

## Scenery and platform budgets

One continuous 2,172×724 painting shows the ringed city, sea, palace, and
submerged ruins. It fills 912×304 world units with 13% horizontal and 25%
vertical camera travel. Overscan covers the full route, summit jumps, and canal
bottoms without panel joins, wrapping, or reflected strips.

Thirteen complete transparent landmarks include five wave-carved walls, four
bronze Poseidon statues, two reused coastal arches, and two ruined colonnades.
Their measured painted bases use `scenery_grounding.gd` and sit on wide, flat
landings clear of canals. Warm stone caps mark walkable terrain against cooler
turquoise water and distant ruins. The exit retains a distinct, functional
temple doorway.

Water is a local animated 2D surface seven units deep over each canal bed.
Pause freezes it. There is no full-screen refraction or real-time reflection.
Opaque scenery uses supported S3TC/ETC2 imports; the two 1,881×836 Merfolk
atlases, transparent props, fonts, and UI stay lossless. New scenery cutouts
have a 1,024-pixel import cap. Terrain reuses the existing city masonry and its
mipmaps. The 720p/540p phone profiles and simulator preview are unchanged.

## Play testing and validation

```sh
tools/play_level.sh 6
tools/play_level.sh 6 2                  # second shrine
tools/play_mobile.sh 6                  # desktop touch preview
tools/play_mobile.sh 6 --mobile-render=540
godot --path . res://scenes/reviews/merfolk_review.tscn
godot --headless --path . --script res://tests/merfolk_behavior.gd --fixed-fps 60 -- --mobile-controls
godot --headless --path . --script res://tests/level_6_smoke.gd --fixed-fps 60
godot --headless --path . --script res://tests/level_6_scenery.gd --fixed-fps 60
```

The review arena switches between Guard, Blade, and Captain. Gallery pauses
combat and displays all eight poses beside Theseus; Reset restores the fight.
The combat check exercises real weapon collision queries, standing/duck/jump/
retreat counters, actual sword attacks, full touch jumps, one damage per attack,
locked facing, focus, wall and edge safety, scores, captain health, and review
controls. It independently inspects the imported painted tail contacts.

The integration check covers Level 5→6, the saved entrance, Title Load,
death/reload, supported enemy and flask placements, both shrines, checkpoint
rollback, the captain-locked gate, entry, completion, replay, and New Game.
With combat isolated, the full course takes 51.8 simulated seconds and 17
jumps. Both canals are harmless and escapable in either direction; pause
freezes their water animation. The scenery check sweeps the camera route and
extremes, checks every terrace and canal cut, and leaves openings unobscured.
Shared scenery, texture, and mobile checks include all six levels.

Human play testing should assess whether the first trident clearly teaches
Duck, the blade telegraph gives enough time to jump, and the two-flask pacing
feels fair. Keep Intel Simulator software-rendering results separate from
physical-phone performance.
