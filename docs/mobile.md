# Mobile setup and testing

The same Godot project targets Android and iOS. All five levels use the existing movement, collision shapes, jump heights, sword timing, enemy behavior, and checkpoint rules. The mobile interface activates automatically on phones and tablets. Desktop play keeps its keyboard interface.

## Controls and display

Hold Left or Right to walk, or slide between the arrows to change direction. Hold Duck to crouch. Hold Jump for a full jump; release it early for a short jump. Tap Sword to attack. Jump + Sword performs an airborne slash; while airborne, Duck + Sword performs the downward thrust. These actions accept separate fingers at the same time.

The top-right button pauses and resumes. Gameplay controls hide in menus, during death, and when entering the exit temple. Returning from another app leaves gameplay paused and releases held touches. Android Back toggles pause in a level and closes the title's Controls screen.

The game uses either landscape orientation and retains its 320×180 gameplay view. Fractional scaling fits the display; wider phones and tablets can have black bars. Touch targets stay inside the reported safe display area. The title, pause, and Hades menus use larger buttons, and Controls displays touch instructions. Checkpoint loading retains the existing **current-session** behavior; closing the process does not save progress to disk.

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

The `Android` export preset builds an ARM64 debug APK, package `com.theseus.adventure`, version `0.1.0`. It uses Godot's prebuilt template and does not require a Gradle project. The current template requires Android 7.0/API 24 or later and OpenGL ES 3.0. The preset requests no Internet permission.

Install export templates matching your Godot version through **Editor → Manage Export Templates**. Configure Java SDK Path and Android SDK Path in **Editor Settings → Export → Android**. See [Godot's Android export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) for SDK setup.

From the repository root:

```sh
mkdir -p builds/android
godot --headless --path . --export-debug Android builds/android/theseus.apk
```

Enable USB debugging on a connected Android phone and install the APK:

```sh
adb install -r builds/android/theseus.apk
adb shell am start -n com.theseus.adventure/com.godot.game.GodotApp
```

You can also copy the APK to the phone and open it there. The debug APK is for local testing. Store distribution needs a release keystore, an Android App Bundle export using Gradle, and a final package identifier. Keep signing credentials out of Git.

## iOS

The `iOS` preset targets ARM64 iPhones and iPads running iOS 15 or later. It exports an Xcode project, with bundle identifier `com.theseus.adventure` and version `0.1.0`. The existing title backdrop supplies a development app icon; choose final square icon artwork before distribution.

Install matching Godot export templates and Xcode on macOS. Open **Project → Export → iOS** to review the configured 10-character **App Store Team ID**. Godot requires a valid Team ID and bundle identifier even for a project-only export; use a Team ID belonging to your development team. See [Godot's iOS export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

```sh
mkdir -p builds/ios
godot --headless --path . --export-debug iOS builds/ios/Theseus.zip
```

Open the generated Xcode project in the export directory, select your development team under **Signing & Capabilities**, connect an iPhone or iPad, choose it as the run destination, and run. Xcode manages the device's signing and provisioning. App Store or TestFlight publishing is a separate step.

## Verification

The mobile interaction check sends actual Godot touch and drag events through the native touch buttons. It covers movement, simultaneous jump/sword input, crouching, downward thrust, canceled touches, sliding direction changes, pause/resume, focus loss, Android Back, safe-area bounds, scene changes, and menu button bounds.

```sh
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60 -- --mobile-controls
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60
```

The second command checks desktop controls and integer scaling. The existing combat, animation, Hades, and five level smoke tests also run without mobile controls.

Before accepting a device build, play each level and check simultaneous touches, short and full jumps, sword timing, ducking under birds, spike-pit recovery, temple entry, pause/resume, and checkpoint loading. Check both landscape directions, notched screens, interruption by another app, frame rate, audio, and heat. Desktop simulation and package validation do not establish device performance or battery use.

Generated builds live in the ignored `builds/` directory. Export credentials and Godot's `.godot/` cache remain ignored.
