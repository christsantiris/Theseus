# Theseus

A left-to-right side scroller. Theseus runs the road from Athens to a guarded temple, along a rocky coast, through a sacred city, into cypress-covered mountain terraces, across a rocky gorge lined with ancient temples, and through the flooded causeways of Atlantis. All characters, including Theseus and all fourteen enemy types, and the scenery in all six levels use detailed cinematic 3D-style artwork.

All six levels use continuous landscapes with independent scenery objects and layered parallax. Checkpoint shrines use matching cinematic limestone and bronze, with lit and unlit brazier states.

## Contents

- [Screenshots](#screenshots)
- [The journey](#the-journey)
  - [The Temple Road](#the-temple-road)
  - [The Rocky Coast](#the-rocky-coast)
  - [The Sacred City](#the-sacred-city)
  - [The Mountain Sanctuary](#the-mountain-sanctuary)
  - [The Gorge Sanctuary](#the-gorge-sanctuary)
  - [Atlantis](#atlantis)
- [How to play](#how-to-play)
- [Mobile version](#mobile-version)
- [Credits](#credits)
- [Play-test any level](#play-test-any-level)
- [Background builds and performance](docs/performance.md)

## Screenshots

### Title

<img width="1600" height="900" alt="Title screen, with Theseus beside the sea and the temple" src="docs/screenshots/title.png" />

### Broken Colonnade

<img width="1600" height="900" alt="Theseus facing a raider among the broken columns" src="docs/screenshots/broken-colonnade.png" />

### Hoplite

<img width="1600" height="900" alt="Theseus fighting a hoplite in front of the colonnade" src="docs/screenshots/hoplite.png" />

## The journey

Enemy windups, recovery windows, cooldowns, and pursuit speed scale with each level. Encounter layouts, counters, healing, and environmental mechanics also determine how difficult a level feels. Light a shrine to keep your place. Entering a new level also saves its entrance. Death opens Hades, where Theseus stands as an opaque shade. Load Game there returns to the last entrance or shrine with full health. Load resumes the highest level or shrine reached in the current session. New Game starts the road over.

### The Temple Road

The opening level is a 4,800-pixel road in five stretches: the King's Road, the Broken Colonnade, the Olive Terraces, the Ruined Aqueduct, and the Temple Approach. Sixteen soldiers wait along it — raiders, peltasts, and hoplites — with health flasks and two shrines. The temple gate stays shut until its guard falls.

One continuous Attic landscape covers the full road behind complete olive groves, ruined colonnades, and a three-arch aqueduct. Slower background parallax adds depth, with detailed limestone surfaces, carved waystones, and a matching temple entrance. The platform layout, encounters, and movement are unchanged.

[Level 1 guide](docs/level_1.md)

### The Rocky Coast

Clear the temple and the road continues onto limestone cliffs above the sea. Birds cross the sky, telchines jab from the ledges, and spartoi hold the landings. The coast is taller than the road, so the view follows Theseus up and down. A sanctuary closes the level.

One continuous Aegean coastline shows blue sea, dry islands, rocky coves, and a distant sanctuary. Complete outcrops, ruined quays, and Cyclopean gateways stay anchored to the original ledges, while slower sea parallax adds depth through both climbs.

[Level 2 guide](docs/level_2.md)

### The Sacred City

The third level is a Greek town: houses, tiled roofs, an agora, and the climb to the acropolis. Lamia share the streets with hoplites, peltasts, and spartoi. The temple at the top opens the way into the mountains.

One continuous sacred-city landscape sits behind complete plaster workshops, blue doors, terracotta roofs, shaded stoas, and ruined colonnades. Grounded buildings and amphorae frame the original cut-stone terraces through the temple climb.

[Level 3 guide](docs/level_3.md)

### The Mountain Sanctuary

Cypress trees rise above Greek mountain slopes and terraced stone walls. Cyclops Slingers hurl breakable boulders, Satyrs hop between ledges and charge with their horns, and Raiders and Telchines return. Four spike pits interrupt the road: jump across, or climb out after losing a health bar. Satyrs can be bounced on and sometimes drop stolen wine for a brief speed boost.

One continuous mountain landscape shows rocky ridges, cypress slopes, terraced walls, and a distant sanctuary. Complete groves, low retaining walls, rocky outcrops, and weathered column fragments stand on the original terraces, leaving all four spike pits open.

[Level 4 guide](docs/level_4.md)

### The Gorge Sanctuary

Pale limestone cliffs, dark clefts, ruined temples, and stone causeways frame the fifth level. Bronze Bulls charge along flat corridors, Cerberus Pups pursue in pairs, and a three-headed Hydra guards the exit. Two optional high flask ledges reward riding a staggered bull. The main route uses normal jumps, with two spike pits and two checkpoint shrines.

One continuous dry gorge landscape shows stratified limestone walls and distant cliffside temples. Complete ruined shrines, colonnades, and rocky outcrops stand on the original causeways, while both bull ledges and pit openings keep their original geometry.

[Level 5 guide](docs/level_5.md)

### Atlantis

Atlantis is a partially flooded city with dry marble causeways, ring canals,
a palace climb, and Poseidon's sanctuary. Merfolk trident guards make high
thrusts that can be ducked; Reefblades make low lunges that can be jumped.
Thirteen Merfolk encounters include the elite captain guarding the exit.
A repeating tide floods and drains the causeways. Water slows Theseus by up to
30% while Merfolk keep their full Level 6-scaled speed. Higher platforms reduce
the drag; a tide meter shows the phase and remaining time. The shallow canals
remain safe to fall into and can be climbed out of with Jump.

One continuous landscape and grounded wave-carved walls, bronze Poseidon
statues, and ruined arches frame twenty-three terraces. Two flasks and two
full-healing shrines support the route. Level 5 continues into Atlantis and
saves its entrance as the new load point.

[Level 6 guide](docs/level_6.md)

Play-test with `tools/play_level.sh 6`, or `tools/play_mobile.sh 6` for touch
controls. Review both Merfolk roles and the captain with
`godot --path . res://scenes/reviews/merfolk_review.tscn`.

## How to play

Theseus runs, jumps, ducks, and fights. Grounded sword attacks alternate between a stab and a diagonal slash, with the same timing, reach, and one-health damage. Regular airborne attacks always slash, including when Jump and Sword are pressed together. Taking off during a stab changes it to a slash without restarting the attack. Airborne attacks leave the grounded sequence unchanged; Duck + Sword in the air still performs a downward thrust. With a keyboard, releasing Jump early makes a short jump; touch jumps are always full height, so one thumb can jump and then reach Sword. Sword hits and a jump into an enemy each cost that enemy one health; landing on a Satyr bounces Theseus safely. Theseus has five health. Flasks restore two, and they never fill him past five. Stolen wine grants six seconds of extra speed. Spike pits cost one health bar per damaging contact and have enough room to jump out.

| Action | Keys |
| --- | --- |
| Move left | A / Left arrow |
| Move right | D / Right arrow |
| Jump | W / Up arrow |
| Duck | S / Down arrow |
| Sword | Space |
| Downward thrust | Hold Duck + Sword while airborne |
| Pause | Escape |

On desktop, Controls on the title screen rebinds these keys for the next time you play. On mobile, it explains the touch controls.

The Bronze Bull is available in a separate review arena. Jump its committed charge, or use a downward thrust on its back to stagger it and ride it briefly. Its cool sheen marks the safe platform; amber warns that it is recovering. Run `godot --path . res://scenes/reviews/bronze_bull_review.tscn` to try it, or open that scene and press **F6**. The pose gallery pauses the fight.

## Mobile version

Android and iOS share the six levels, artwork, combat, and checkpoints. Landscape touch controls support movement, ducking, jumping, sword attacks, and pause, including simultaneous presses for airborne attacks. Menus have larger touch targets. Tutorial messages sit at the bottom, between the left and right buttons, and gameplay pauses when the app loses focus. After a level is cleared, Continue plays a short full-screen ad and then opens the next level. Desktop and the web build skip that ad.

Phones render the world at 1280×720 while keeping HUD, menus, and touch controls at display resolution. A 960×540 option reduces world rendering further; simulators use a separate 320×180 preview. All profiles retain the same 320×180 game coordinates. Desktop keeps native rendering. Compare the phone budgets with `tools/play_mobile.sh 1 --mobile-render=720` and `tools/play_mobile.sh 1 --mobile-render=540`; see the [rendering profiles](docs/mobile.md#rendering-profiles).

Start the installed Pixel 8 Android emulator on this Mac:

```bash
"$HOME/Library/Android/sdk/emulator/emulator" -avd Pixel_8
```

Keep that terminal open while the emulator runs. On another Mac, use `"$HOME/Library/Android/sdk/emulator/emulator" -list-avds` to find its virtual device names and replace `Pixel_8` as needed.

Preview the controls with a mouse on desktop:

```sh
tools/play_mobile.sh        # title screen
tools/play_mobile.sh 2      # Level 2
tools/play_mobile.sh 5 1    # Level 5, first shrine
```

Start the installed iPhone 17 Pro simulator on this Mac:

```bash
xcrun simctl bootstatus 7789BA5B-D179-4740-A908-29924052D442 -b
open -a /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app --args -CurrentDeviceUDID 7789BA5B-D179-4740-A908-29924052D442
```

The first command boots the virtual iPhone if needed and waits until it is ready; the second opens its window. The device ID is specific to this Mac. Use `xcrun simctl list devices available` to find an ID on another Mac.

To run Theseus, open `builds/ios/Theseus.xcodeproj` in Xcode, select an iPhone Simulator run destination, and press **Command-R**.

[Mobile setup and device testing](docs/mobile.md) covers the Android APK and iOS Xcode export. iOS requires your Apple Developer Team ID before Godot can export it.

## Credits

Music by <a href="https://pixabay.com/users/moonpub-15209240/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=621132">Johnny Hoeve</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=621132">Pixabay</a>

Level 2 — Santorini Breeze. Music by <a href="https://pixabay.com/users/u_98673jp944-48995615/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=470783">u_98673jp944</a> from <a href="https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=470783">Pixabay</a>

Level 3 — Ancient Temple. Music by <a href="https://pixabay.com/users/alex-morgan-54692529/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=587426">Alex Morgan</a> from <a href="https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=587426">Pixabay</a>

Level 4 — Atlas Egypt. Music by <a href="https://pixabay.com/users/vadim_makes_sound-54823268/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=559404">Vadim</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=559404">Pixabay</a>

Sound effect by <a href="https://pixabay.com/users/daviddumaisaudio-41768500/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=185432">David Dumais</a> from <a href="https://pixabay.com/sound-effects//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=185432">Pixabay</a>

Sound effect by <a href="https://pixabay.com/users/u_qqkrn9bn55-52083300/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=398256">u_qqkrn9bn55</a> from <a href="https://pixabay.com/sound-effects//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=398256">Pixabay</a>

Sound Effect by <a href="https://pixabay.com/users/dragon-studio-38165424/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=515257">DRAGON-STUDIO</a> from <a href="https://pixabay.com/sound-effects//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=515257">Pixabay</a>

## Play-test any level

To review Theseus, run `godot --path . res://scenes/reviews/theseus_review.tscn`, or open that scene and press **F6**. It shows all eleven animations: breathing idle, walk, crouch, jump rise, jump fall, sword thrust, grounded sword swing, airborne sword swing, downward thrust, hurt, and death. Use **Slow**, **Hold**, and **Flip** to inspect the 48 frames, or **Play level 1** to try them in the game. The airborne slash keeps his knees bent through the whole attack. Walking plays at 8 fps, matching raiders and peltasts and close to the hoplites' 6 fps. Movement speed, collision sizes, attack timing, and the wine boost's 35% cadence increase are unchanged. The title screen also uses the animated character.

To review Cerberus Pups, run `godot --path . res://scenes/reviews/cerberus_pup_review.tscn`, or open that scene and press **F6**. The two hounds run together and take turns making a telegraphed leap. Jump over the attack or interrupt it with a sword hit. Each pup has two health bars; the surviving pup continues to pursue Theseus.

To review the Hydra, run `godot --path . res://scenes/reviews/hydra_review.tscn`, or open that scene and press **F6**. Each of its three heads has two health and a separate hit area. Cut down every head to defeat it; hitting the coiled body does no damage. Jump to reach the higher heads, or counter their telegraphed bites as they dip toward Theseus. Severed heads stay gone, and the survivors continue taking turns attacking.

To check all five continuous landscapes, complete scenery objects, and shrine activation, run `godot --path . --script res://tests/scenery_art.gd`. This check uses the renderer.

Start any level at its entrance or at one of its shrines:

```sh
tools/play_level.sh        # choose a level and shrine from a menu
tools/play_level.sh 3      # Level 3 from the entrance
tools/play_level.sh 3 2    # Level 3 from its second shrine
```

To skip the wrapper script, run `godot --path . res://scenes/debug/level_select.tscn -- --level=3 --shrine=2`, or open `scenes/debug/level_select.tscn` in the editor and press **F6**. A shrine start counts that shrine as lit. Enemies before it are still alive, and the score starts at 0.

## Background builds and performance

Each level loads one continuous landscape and complete transparent scenery objects. No panorama joins, seam assets, repeated aprons, or image-processing step are needed. Opaque backgrounds use GPU compression; terrain tiles also use mipmaps. Character art, fonts, UI, and transparent props remain lossless. After changing artwork, import it and check camera coverage and painted ground contacts:

```sh
godot --headless --path . --editor --import
godot --path . --script res://tests/scenery_art.gd
godot --path . --script res://tests/scenery_grounding.gd
godot --path . --script res://tests/texture_budget.gd
```

Run each affected level's `tests/level_N_scenery.gd` for full-route coverage and collision checks. See [performance measurements and benchmark instructions](docs/performance.md).
