# Level 2 — The Rocky Coast

A 4,800×320-pixel ancient Greek coastline: blue sea, distant dry islands,
limestone outcrops, cypress trees, broken columns, and a sanctuary temple.
Thirty broad stone ledges form two climbs and a long descent. Contiguous
landings prevent narrow gaps from trapping Theseus below the high terraces.
Uphill steps rise 16 pixels, within the existing jump; descending terraces
drop 16–48 pixels. The camera follows both axes within the taller world.

![Five areas of the rocky coast](level_2_preview.png)

## Cinematic scenery

Level 2 uses **one continuous Aegean coastline**: connected blue sea, a single
horizon, dry offshore islands, limestone coves, and a distant sanctuary. Its
2,172×724 painting renders at 864×288 world units. It scrolls at 12% of horizontal
camera travel and 25% of vertical travel, with overscan covering the full
320-pixel-tall world through low shore, summit jumps, and descent. It never
switches paintings, wraps, blends architecture, or repeats road aprons.

Fourteen complete transparent landmarks establish the five areas: seven rocky
outcrops with coastal vegetation, four ruined quay fragments, and three
Cyclopean gateways. They stay fixed at their authored landings so their feet
cannot drift off narrow ledges as the camera moves. Cutout footing offsets
account for the transparent margins around each painting. The distant sea's
slower movement provides depth against these objects and the walkable terraces.

`scenes/levels/level_2_geometry.gd` renders `aegean_landscape.png`,
`coastal_outcrop.png`, `ruined_quay.png`, and `cyclopean_gate.png` from
`assets/art/backgrounds/level_2/`. The sea uses S3TC/ETC2 GPU compression; cutouts
remain lossless and import at a 1,024-pixel maximum dimension. All textures stay
below the project's 4,096-pixel mobile limit. Scenery has no mipmaps; the
separate repeating limestone terrain retains its existing mip chain.

Textured limestone covers all thirty original ledges. Stone caps, carved
waystones, checkpoint shrines, and the temple facade retain their existing art.
`level_1_temple.gd` keeps its bronze bars synchronized with unlocking, including
paused temple entry. Collision rectangles, birds and their flight lanes,
encounters, movement, checkpoint behavior, and camera framing are unchanged.
Level 1 retains its continuous countryside; Levels 3–5 keep their previous
panorama renderers pending subsequent milestones.

Standing scenery uses measured painted bases from `scenery_grounding.gd`, with
one world pixel of overlap at the ground. This closes transparent-padding gaps
under trees, ruins, pots, columns, and waystones while preserving their artwork
and collision layout. See the [ground-contact regression](performance.md#scenery-ground-contacts).

## Route

| Area | X range | Route and encounters |
| --- | --- | --- |
| Coastal Road | 0–959 | Flat approach teaches a high bird, then a low bird; short ledge climbs introduce a Telchine. |
| Broken Quays | 960–1919 | Terraces climb to y=168. Telchine jabs and Spartoi lunges share broad landings; high and low birds occupy separate lanes. |
| Sea Cliffs | 1920–2879 | First shrine, then a second climb with melee fights and a high bird. |
| Cyclopean Ruins | 2880–3839 | Low bird, Telchine, and Spartoi summit guard. Highest landing is y=104, followed by descending ledges. |
| Rocky Sanctuary | 3840–4799 | Second shrine, final low terraces and melee fights, then the Spartoi temple guard. |

## Enemies

| Enemy | Count | Health / score | Behavior and defense |
| --- | --- | --- | --- |
| Stymphalian Bird | 6 | 1 / 75 | Flies horizontally at 48 pixels/second, roughly half Theseus's running speed. High lanes are 44 pixels above a landing: duck in place and let the bird pass, or jump and time a sword strike. Low lanes are 8 pixels above a landing: jump forward over the approaching bird, or time a standing sword strike. |
| Telchine | 5 | 2 / 100 | Dog-headed sea daemon in Greek soldier armor, carrying a held bronze trident. Uses Peltast's stationary melee jab, tuned for this level: a 0.55-second windup, 0.18-second strike, and 0.87-second recovery. Retreat, jump, or pass the committed windup, then counter. |
| Spartoi | 5 | 2 / 100 | Exposed skull, ribs, and bone limbs under Greek helmet and armor. Uses Raider's committed sword lunge, tuned for this level: a 0.5-second windup, 0.22-second lunge, and 0.92-second recovery. Bait the lunge and counter. |

Birds stay at their assigned height and reverse at their patrol endpoints.
Every high-bird wing frame clears the visible ducking helmet by four pixels.
Theseus's standing and ducking collision heights are 44 and 36 pixels,
respectively, matching the visible poses so a standing player still takes a hit.
They wake within 256 horizontal and 128 vertical pixels of the player.
They deal one bar of contact damage per pass; remaining in one overlap cannot
repeat the hit. There are no projectiles or added blocking controls. Sword
damage still requires the extended-blade attack frame. Landing onto a bird
uses the existing mutual collision rule: each actor loses one health.

The humanoids reuse the tested melee controllers and hitboxes. Art uses
four walking frames and three attack poses, matching the existing soldiers.
The birds use four wing frames. All three coastal enemies use cinematic
3D-style artwork matching Theseus: exposed skeletal Spartoi, dog-headed
Telchines with held tridents, and bronze-feathered Stymphalian Birds. Their
transparent 576×448 cells render at one-eighth scale with linear filtering,
retaining the original logical size, flight lanes, hitboxes, and animation speeds.

## Checkpoints and completion

Clearing Level 1 offers **Continue to Level 2**. On entering Level 2, its entrance
at (48, 280) becomes the saved checkpoint immediately, replacing the Level 1
shrine. Returning to the title and choosing Load resumes that entrance until
a Level 2 shrine is lit. Death opens Hades, and Load Game restarts from this
entrance or the latest Level 2 shrine. Progress remains in memory for the current game session.

The Coastal Shrine at x=2000 saves a safe spawn at (2024, 280). The Sanctuary
Shrine at x=4048 saves (4072, 280). Each snapshots
the running score, defeated enemies, and collected flasks. Backtracking
cannot replace a later shrine. Four health flasks restore two bars each.

Defeat SpartoiSanctuaryGuard to open the temple at (4752, 280). Theseus climbs
the temple steps and disappears into the doorway before the completion menu.
Replay Level restarts Level 2; New Game on the title starts Level 1 and clears
the run. Level 2 completion also offers **Continue to Level 3**, leading to
[The Sacred City](level_3.md). Entering town replaces the coastal checkpoint
with a new load point at the Level 3 entrance.

## Run and validation

```sh
godot --path . --scene res://scenes/levels/level_2.tscn
godot --headless --path . --script res://tests/coastal_enemies.gd --fixed-fps 60
godot --headless --path . --script res://tests/level_2_smoke.gd --fixed-fps 60
godot --headless --path . --script res://tests/level_2_scenery.gd --fixed-fps 60
```

The enemy test uses Theseus's actual input, ducking shape, jump arc, attack
animation, and sword query to verify both bird lanes and their defenses. It
checks opaque sprite bounds for every high-bird wing frame at all three high
lanes, ensuring the art clears the helmet as well as the collision shape. It
also checks Telchine jabs, Spartoi lunges, recovery, and damage.

The level test covers Level 1→2 progression, entrance checkpoint, title Load,
actual death/reload, both shrines, defeated-enemy rollback, camera limits,
completion, replay, and New Game. A route traversal with combat disabled
reaches the doorway using normal movement and 20 jumps, in about 52 simulated
seconds. Combat pacing still benefits from a human playthrough.

The scenery check sweeps the full camera route and checks viewport coverage at
the low shore, both climbs, summit jumps, and descent. It verifies one unblended,
non-repeating painting, monotonic texture sampling, fourteen complete landmarks
anchored to the world, original ledge collisions, paused gate updates, and
isolation from the other levels.
