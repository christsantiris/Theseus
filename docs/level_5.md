# Level 5 — The Gorge Sanctuary

A 4,800×352-pixel rocky gorge with pale limestone faces, deep dry clefts,
weathered Greek temples, broken columns, and bright stone causeways. Eighteen
main terraces climb from y=280 to the high colonnade at y=168, then descend
to the Hydra's sanctuary. Background ruins use muted stone; bright caps mark
the playable path.

![Five areas of the rocky gorge](level_5.png)

## Cinematic scenery

Each area has west and east cinematic 3D-style panoramas matching the detailed
stone and warm Mediterranean lighting in Levels 1–4. Pale stratified cliff
walls, dark dry clefts, ruined Doric temples, and elevated colonnades fill ten
overlapping panels. The cliff shelves follow the route height smoothly so the
ruins stay visible above the causeways. Weathered masonry covers the original
terrain; column fragments and the cinematic temple facade reuse the earlier
levels' art.

All eighteen main terraces, both one-way bull ledges, both recessed spike pits,
and their collision settings are unchanged. The temple remains closed until
the Hydra's final head falls, and the facade updates during paused entry.

## Route

| Area | World X | Route and encounters |
| --- | --- | --- |
| Gorge Mouth | 0–959 | A broad, flat lane introduces the first Bronze Bull. Staggering it opens an optional route to a high flask ledge. Three low steps lead to the temple terraces. |
| Temple Ledges | 960–1919 | The first pair of Cerberus Pups holds a broad landing. Descend into a second flat bull corridor before the first shrine. |
| Broken Causeway | 1920–2879 | Light the shrine, cross a spike pit, and climb 16-pixel steps. A second pup pair guards a wide terrace halfway up. |
| High Colonnade | 2880–3839 | A third bull charges along a 512-pixel causeway. A second high flask ledge rewards riding it. Descending terraces lead toward the sanctuary. |
| Hydra Sanctuary | 3840–4799 | The final pup pair guards the descent. Jump the last spike pit and light the second shrine, then defeat every Hydra head to open the exit temple. |

## Encounters

| Enemy | Count | Health / score | Counter |
| --- | --- | --- | --- |
| Bronze Bull | 3 | 4 / 250 | Jump the committed charge. While airborne, hold Duck and press Sword to thrust onto its back, deal one damage, and stagger it into a temporary moving platform. |
| Cerberus Pup | 6, in three pairs | 2 / 100 each | The pair shares pursuit and takes turns making a telegraphed leap. Jump over the attack or interrupt it with a sword hit. Killing one pup leaves its partner active. |
| Hydra | 1, with three heads | 2 per head / 450 total | Each mouth has independent health. Use jumping sword attacks to reach higher heads, or counter a head as it dips into a bite. Body hits do no damage. All three heads must be defeated; severed heads stay gone. |

The maximum combat score is **1,800** across ten encounters. Each pup counts
separately; the Hydra counts once after its final head falls. Ordinary airborne
collisions with enemies or Hydra mouths still cost both Theseus and the target
one health. There is no automatic stomp kill.

## Optional bull ledges and spike pits

The main route needs ten terrace climbs and two pit jumps, all possible at the
normal movement speed. It does not require riding a bull. Two extra ledges
stand 56 pixels above the bull lanes, beyond a normal jump from the ground:

| Ledge | Span | Top Y | Flask X |
| --- | --- | --- | --- |
| Gorge Mouth | 544–656 | 224 | 616 |
| High Colonnade | 3328–3440 | 112 | 3384 |

A downward thrust on a bull's back opens a brief ride. Its cool sheen marks
the safe platform; amber warns that it is recovering. Ride toward the ledge,
then jump onto its bright stone cap. The ledges allow approach from below,
leaving the charging corridor clear. Both reward a health flask; three more
flasks sit on the main route. Each restores two health without exceeding five.

Two spike recesses reuse Level 4's damage-and-escape mechanic:

| Pit | Left edge | Rim Y | Width / depth |
| --- | --- | --- | --- |
| CausewayPit | 2080 | 280 | 32 / 24 |
| SanctuaryPit | 4160 | 264 | 32 / 24 |

Falling onto a pit bed costs one health bar. Hold Jump and move toward either
rim to climb out; there is no automatic ejection. The 1.25-second interval
between damaging contacts leaves time to escape. A fatal hit restores the
latest level entrance or shrine.

## Progress and the exit

Continuing from Level 4 saves the gorge entrance at (48, 280). The Causeway
Shrine at x=2016 saves (2040, 280); the Hydra Shrine at x=4256 saves
(4280, 280). Both snapshot score, defeated enemies, and
collected flasks. Load resumes the highest level or shrine reached in the
current session, and backtracking cannot replace a later shrine.

Pup defeats are saved individually. Saving after killing one pup restores
only its surviving partner; the survivor can still pursue and attack. Damage
to surviving enemies is reset on reload, as in earlier levels. Hydra heads
must all be defeated to record the Hydra's kill and unlock the gate.

HydraTempleGuard at (4608, 280) guards the temple at (4752, 280). Cutting
one or two heads leaves the gate locked. The last head awards 450 points
once and opens the gate. Theseus climbs the temple steps and disappears
inside before the Level 5 completion menu. Replay restarts Level 5, and
New Game resets the campaign to Level 1. Level 5 is the current final level.

## Play and validation

```sh
tools/play_level.sh 5
tools/play_level.sh 5 2
godot --path . res://scenes/levels/level_5.tscn
godot --headless --path . --script res://tests/level_5_smoke.gd --fixed-fps 60
godot --headless --path . --script res://tests/level_5_scenery.gd --fixed-fps 60
```

The integration suite checks Level 4→5, entrance and shrine loading, actual
death/reload, individual pup snapshots, survivor attacks, pickup and enemy
placement, fatal spike recovery, real sword-and-jump combat against the Hydra
guard, the bull ride and high flask reward, camera scrolling, temple entry,
replay, and New Game. With combat isolated, the complete main route takes
about 52 simulated seconds and twelve jumps without damage or a speed boost.

`scenes/levels/level_5_geometry.gd` keeps the original terrain cuts, spike-floor
metadata, and one-way ledge construction while rendering the gorge in the game
and editor. Each section PNG in `assets/art/backgrounds/level_5/` stores west
and east panoramas stacked vertically; the directory also contains the causeway
masonry. Column fragments reuse Level 4's cutout; stone caps and the temple
facade reuse Level 1's art.

The scenery check verifies all ten panoramas, coverage at street level, both
bonus ledges and pit bottoms, original terrain collisions, one-way settings,
spike metadata, the Hydra's three-head gate requirement, paused facade updates,
and isolation from the other levels.
