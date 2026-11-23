# Mobile setup and testing

The same Godot project targets Android and iOS. All five levels use the existing movement, collision shapes, jump heights, sword timing, enemy behavior, and checkpoint rules. The mobile interface activates automatically on phones and tablets. Desktop play keeps its keyboard interface.

## Controls and display

Hold Left or Right to walk, or slide between the arrows to change direction. Hold Duck to crouch. Hold Jump for a full jump; release it early for a short jump. Tap Sword to attack. Jump + Sword performs an airborne slash; while airborne, Duck + Sword performs the downward thrust. These actions accept separate fingers at the same time.

The top-right button pauses and resumes. Gameplay controls hide in menus, during death, and when entering the exit temple. Returning from another app leaves gameplay paused and releases held touches. Android Back toggles pause in a level and closes the title's Controls screen.

The game uses either landscape orientation and retains its 320×180 gameplay view. Fractional scaling fits the display; wider phones and tablets can have black bars. Touch targets stay inside the reported safe display area. The title, pause, and Hades menus use larger buttons, and Controls displays touch instructions. Checkpoint loading retains the existing **current-session** behavior; closing the process does not save progress to disk.

Character sheets keep their full-resolution artwork and transparency, with frames arranged into rows so every texture fits within 4096×4096. Frame sizes, animation timing, and collision shapes are unchanged. Display safe areas are converted from physical screen pixels to game coordinates, including letterboxing, so movement and action buttons remain separated on phones and tablets.

Opaque panoramas, baked color overlaps, and terrain tiles use S3TC on supported desktop GPUs and ETC2 on supported mobile GPUs. Web exports include both variants. Character sheets, transparent props, fonts, UI, and seam-data masks stay lossless. Only the five separate terrain tiles generate mipmaps; character and panorama atlases do not. Unsupported GPUs may decode textures to uncompressed memory, so emulator results need separate interpretation. See the [texture measurements and tradeoffs](performance.md#texture-memory-budget).

Level 1 uses one non-repeating landscape and thirteen complete transparent scenery objects instead of panorama blends. Its new cutouts stay lossless; the grove and colonnade import at a 1,024-pixel maximum dimension and the aqueduct at its full 2,172-pixel width. Gameplay coordinates, touch placement, and all render profiles are unchanged.

Level 2 now uses one continuous coast and fourteen complete landmarks anchored to its original ledges. Its three cutouts stay lossless with a 1,024-pixel import limit; the wider sea painting uses GPU compression. Both scenery renderers preserve viewport coverage through their full camera ranges.

## Rendering profiles

Physical Android/iOS devices and mobile web browsers default to a **1280×720 world render target**. The world still uses 320×180 coordinates, the same root camera and zoom, physics world, collisions, movement, and attack timing. Scenery, platforms, and characters render into a shared-world `SubViewport`; a presentation layer displays that texture behind the original UI. Scenes stay direct children of the root, preserving scene changes, reloads, checkpoints, and pause behavior.

HUD, menus, and touch controls render at display resolution on phone profiles. HUD content and touch buttons follow the reported safe display area in either landscape direction. A lower world resolution does not shrink or blur those controls. The root viewport still has a native-resolution composition pass; the budget caps world shading rather than every display pixel.

| Profile | World target | UI target | Default |
| --- | --- | --- | --- |
| `720` | 1280×720 | Display resolution | Physical phones/tablets and mobile web |
| `540` | 960×540 | Display resolution | Optional lower-cost mode |
| `preview` | 320×180 | 320×180, then upscaled | Detected iOS/Android simulators |
| `native` | Display resolution | Display resolution | Desktop |

Set **`rendering/mobile/world_profile`** to `"540"` in `project.godot` for a native phone build using the lower budget. **`rendering/mobile/simulator_profile`** defaults to `"preview"`; set it to `"720"` or `"540"` to inspect phone rendering on an emulator. Intel iOS and Android emulator models are detected; Apple Silicon iOS Simulator is identified by its simulator environment. Physical-device speed and image quality still require phone testing.

Compare profiles on desktop without changing its normal defaults:

```sh
tools/play_mobile.sh 1 --mobile-render=720
tools/play_mobile.sh 1 --mobile-render=540
tools/play_mobile.sh 1 --mobile-render=preview
tools/play_mobile.sh 1 --mobile-render=native
```

The wrapper also accepts engine flags, for example `tools/play_mobile.sh 1 --resolution 1600x900 --mobile-render=540`. Direct Godot launches put the profile after `--`: `godot --path . -- --mobile-controls --mobile-render=720`. A web build accepts `?render=720`, `?render=540`, `?render=preview`, or `?render=native` for comparison. None of these choices changes texture compression or source artwork.

## Preview on desktop

```sh
tools/play_mobile.sh
tools/play_mobile.sh 3 2
```

Click and hold the touch buttons with a mouse. A mouse tests one touch at a time; a device is needed for manual multitouch testing. Keyboard controls also work in the preview. Set `GODOT=/path/to/godot` if needed. Extra engine flags follow the level/shrine arguments, for example `tools/play_mobile.sh 2 --resolution 1280x720`.

Without the wrapper:

```sh
godot --path . -- --mobile-controls
```

## Android

The `Android` export preset builds a debug APK with ARM64 for phones and x86_64 for Intel emulators, package `com.theseus.adventure`, version `0.1.0`. It uses a Gradle build so the AdMob library can be packaged. The current template requires Android 7.0/API 24 or later and OpenGL ES 3.0. The preset requests Internet and network-state permission so the between-level ad can load.

Install export templates matching your Godot version through **Editor → Manage Export Templates**. Configure Java SDK Path and Android SDK Path in **Editor Settings → Export → Android**. See [Godot's Android export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) for SDK setup.

From the repository root:

```sh
mkdir -p builds/android
godot --headless --path . --install-android-build-template --export-debug Android builds/android/theseus.apk
```

The install flag writes Godot's Gradle project into `android/` the first time. Later exports can omit it once that directory is present. The export templates package must include `android_source.zip`.

Enable USB debugging on a connected Android phone and install the APK:

```sh
adb install -r builds/android/theseus.apk
adb shell am start -n com.theseus.adventure/com.godot.game.GodotAppLauncher
```

You can also copy the APK to the phone and open it there. The debug APK is for local testing. Store distribution needs a release keystore, an Android App Bundle export using Gradle, and a final package identifier. Keep signing credentials out of Git.

### Android emulator

This Mac has an x86_64 virtual device named `Pixel_8`. Start it in a terminal:

```sh
"$HOME/Library/Android/sdk/emulator/emulator" -avd Pixel_8
```

Once Android's home screen appears, rebuild the APK using the export command above. In another terminal, install and launch it:

```sh
"$HOME/Library/Android/sdk/platform-tools/adb" -e install -r builds/android/theseus.apk
"$HOME/Library/Android/sdk/platform-tools/adb" -e shell am start -n com.theseus.adventure/com.godot.game.GodotAppLauncher
```

`-e` selects the emulator instead of a connected physical phone. If using another computer, list its virtual devices with `emulator -list-avds` and substitute the name. No architecture changes in Godot's UI are needed.

## iOS

The `iOS` preset targets ARM64 iPhones and iPads running iOS 15 or later. It exports an Xcode project, with bundle identifier `com.theseus.adventure` and version `0.1.0`. The existing title backdrop supplies a development app icon; choose final square icon artwork before distribution.

Install matching Godot export templates and Xcode on macOS. Open **Project → Export → iOS** to review the configured 10-character **App Store Team ID**. Godot requires a valid Team ID and bundle identifier even for a project-only export; use a Team ID belonging to your development team. See [Godot's iOS export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

```sh
tools/export_ios.sh
```

The helper requires Python 3 and Xcode's command-line tools, and uses `GODOT` if set. It exports the game, then sets **Architectures** to `$(ARCHS_STANDARD)` in every generated Xcode build configuration. It also inspects the actual simulator library and adds an iOS Simulator architecture override matching its available slices. The installed template contains x86_64 simulator code, so simulator builds use x86_64 while physical iPhone/iPad builds retain ARM64. Use the helper for subsequent exports: exporting directly through Godot's UI or CLI writes the template's ARM64-only settings again. The generated Xcode project remains in the ignored `builds/ios/` directory.

Open the generated Xcode project in the export directory, select your development team under **Signing & Capabilities**, connect an iPhone or iPad, choose it as the run destination, and run. Xcode manages the device's signing and provisioning. App Store or TestFlight publishing is a separate step.

### iOS Simulator

```sh
open builds/ios/Theseus.xcodeproj
```

In Xcode, choose the **Theseus** scheme and an **iPhone Simulator** run destination, then press **Command-R**. If no simulator is available, install an iOS Simulator runtime through **Xcode → Settings → Components**. The game's Compatibility renderer and the exported simulator library support this path; no manual architecture edits are needed after running `tools/export_ios.sh`.

On this Intel Mac, profiling showed the iOS Simulator's OpenGL renderer rasterizing on the CPU. Detected simulators therefore use the separate 320×180 `preview` profile, including the UI, and scale it to the simulated display. This preview is visibly lower resolution and can still run below the game's target frame rate. Phone profiles use a fixed world budget with native-resolution UI. Use the desktop preview commands above for smoother quality comparisons, and test on a physical phone to assess mobile graphics performance.

## Ads

Android and iOS show one interstitial when Continue is pressed on the level-complete screen. The score stays visible until that press. The next level loads after the ad closes. If the network has nothing ready, Continue opens the next level immediately. Replay, Title, death, and Hades do not show an ad. Level 5 has no next level, so it does not request one.

The project uses Google's sample app ids and interstitial units, which fill with test ads on a development device. Replace the app ids in Project Settings under AdMob, and the unit ids in `scenes/ui/level_ads.gd`, with the ids from your AdMob apps before a store build. Sample units left in a published app can get the AdMob account suspended.

The first iOS export adds the Google Mobile Ads package to the Xcode project. Xcode downloads it on the first build, which needs a network connection.

## Verification

The mobile interaction check sends actual Godot touch and drag events through the native touch buttons. It covers movement, simultaneous jump/sword input, crouching, downward thrust, canceled touches, sliding direction changes, pause/resume, focus loss, Android Back, safe-area bounds, scene changes, and menu button bounds.

```sh
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60 -- --mobile-controls
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60
godot --headless --path . --script res://tests/mobile_art.gd
godot --path . --script res://tests/mobile_rendering.gd --fixed-fps 60 -- --mobile-controls
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60 -- --mobile-controls --mobile-render=720
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60 -- --mobile-controls --mobile-render=540
```

The second command checks desktop controls and integer scaling. The existing combat, animation, Hades, and five level smoke tests also run without mobile controls.

The artwork check verifies mobile-safe texture dimensions, complete atlas regions, and visible pixels for Theseus and every enemy type. The touch checks include physical display insets on an iPhone, an Android phone, and a tablet.

The rendering check reads back the actual world targets, verifies screen markers through the world and final composition for all five levels, compares identical movement/jump/sword-frame histories across profiles, checks left/right safe-area layouts and display resizes, and sends a real mouse click through the presentation layer to a title button. [Performance measurements](performance.md#mobile-rendering-budget) separate hardware browser results from software-rendered simulators.

Before accepting a device build, play each level and check simultaneous touches, short and full jumps, sword timing, ducking under birds, spike-pit recovery, temple entry, pause/resume, and checkpoint loading. Check both landscape directions, notched screens, interruption by another app, frame rate, audio, and heat. Desktop simulation and package validation do not establish device performance or battery use.

Generated builds live in the ignored `builds/` directory. Export credentials and Godot's `.godot/` cache remain ignored.
