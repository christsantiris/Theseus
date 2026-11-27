# Level 7 — The Pyramid Road

Theseus crosses an Egyptian desert between the Gorge Sanctuary and Atlantis.
Pyramids, dunes, carved obelisks and sandstone pylon gateways frame the route.
The level reuses Hoplites, Peltasts, Raiders and Spartoi, including their existing
artwork, attacks, counters and score rewards. No new enemy type is introduced.

![Theseus on the Egyptian pyramid road](level_7_preview.png)

## Sunbeam sweep

At x=3544–3624 on Obelisk Rise, a bronze mirror flashes for 0.9 seconds before a low beam sweeps left for 1.4 seconds. Jump over it or wait in the stone recess outside the beam’s path. The mirror resets for three seconds.

## Route

The 5,760×352-unit route begins at (48, 280) and ends at the sun temple at
(5600, 280). Twenty-five sandstone terraces use sixteen-unit rises, with a
continuous lower floor beneath them. Normal jumps reach every required landing;
there are no pits, water, riding requirements or changes to player movement.
The highest landing is at Y=200, eighty units above the desert road.

| Section | World X | Encounters and route |
| --- | --- | --- |
| Desert Road | 0–959 | Raider, Peltast and the first sandstone climb. |
| Pyramid Causeway | 960–1919 | Hoplite and Spartoi, a lower Raider court, then a Peltast climb. |
| Buried Courts | 1920–2879 | Spartoi and Hoplite landings precede a Raider on the ascent. |
| Obelisk Rise | 2880–3839 | A recovery flask precedes the high court pair. Cross the sunbeam, then face Spartoi on the next landing. |
| Sandstone Causeway | 3840–4799 | Low sandstone steps separate a Raider, a raised Peltast and a Spartoi approach. |
| Temple of the Sun | 4800–5759 | Raider, Peltast and Spartoi lead to a second Raider stationed on the elite Hoplite captain’s approach. |

## Encounters and healing

Four Hoplites, five Peltasts, six Raiders and five Spartoi make twenty encounters. All receive the
existing Level 7 difficulty curve once. The sun captain alone receives the
standard elite health bonus: three hits during vulnerable states defeat him.
His existing crouch and rise still block sword hits. Bait the attack and counter
during recovery. Defeating him unlocks the temple gate.

Three flasks restore two health each, at (1216, 248), (2896, 216), and
(4496, 280). Full health leaves a flask available for later.

## Campaign, controls and results

The gorge offers **Continue to Level 7**. Finishing Egypt shows a ready ad before
results on mobile, then **Continue to Level 8** enters [Atlantis](level_8.md).
The [Minotaur finale](level_9.md) is Level 9.

Each attempt starts with full health and a 3:00 countdown. Pause, app
interruptions, temple entry, the ad and results freeze the clock. Death or time
expiry opens Hades; Retry Level restores the Egyptian entrance, enemies,
flasks and score carried from earlier levels. Replay and the title's Load also restart the attempt. There are no checkpoints.

Desktop keyboard/mouse controls and simultaneous mobile touch controls use the
shared player and UI. The camera follows the climbs within the existing bounds.

## Artwork and rendering

One continuous 2,172×724 desert painting supplies the dunes and pyramids.
Seven complete obelisks and five pylon gateways stay anchored to the terrain;
only the distant painting uses parallax. The exit's Egyptian pylon replaces the
Greek facade while retaining the shared gate collision and doorway animation.

The opaque landscape uses desktop and mobile GPU compression. Transparent props
remain lossless, with measured painted-base anchors and textures below the
4,096-pixel mobile limit. Existing native, 720p, 540p and preview rendering
profiles are shared with the rest of the campaign. Ancient Persia Epic
Soundtrack 03 by Alejandro Piñero Amerio starts and loops from 1:02; music
credits are in the README.

## Play testing

```sh
tools/play_level.sh 7
tools/play_mobile.sh 7
tools/play_mobile.sh 7 --mobile-render=540
godot --headless --path . --script res://tests/level_7_smoke.gd --fixed-fps 60
godot --headless --path . --script res://tests/level_7_smoke.gd --fixed-fps 60 -- --mobile-controls
godot --path . --script res://tests/level_7_scenery.gd --fixed-fps 60
godot --headless --path . --script res://tests/difficulty_curve.gd
```

The gameplay check covers gorge→Egypt→Atlantis progression, recycled enemy
placement and scaling, healing, Hades retry, title restart, replay, the complete
route using normal jumps, countdown and the captain's gate. The scenery check
covers camera overscan, texture limits, terrace collisions and the Egyptian exit.
Campaign-wide rendering, painted-base grounding, countdown and ad tests include
all nine levels where applicable. Native iOS/Android delivery and physical
device performance still require device checks.

## Extended approach

The route is 20% longer: 5,760 world units with a new Sandstone Causeway section
at X=3840–4799 before the final area. Three additional enemies occupy that
space. The countdown remains 3:00, and existing music keeps looping at its
configured offset. Background camera coverage includes the full extended route.
