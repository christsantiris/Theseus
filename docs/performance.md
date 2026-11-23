# Background builds and performance

## Seam baking

Levels 2–5 have ten panoramas each and nine joins per level. Level 1 now uses one continuous landscape and independent scenery objects; it has no seam bundle. `tools/bake_landscapes.sh` reads the source PNGs on the CPU, runs the original content-aware seam search, and writes two lossless atlases plus `joins.tres` to each level's `_seams/` directory. The 1,116×2,196 overlap atlas holds the previous paintings' edge strips; the 9×582 mask atlas holds the nine seam paths and feather widths. Block-aligned strips and at least four replicated border pixels isolate each overlap under GPU compression. The shader clamps lookup to the strip’s own texel centers. Both fit below the existing 4096×4096 mobile texture limit.

During play, materials load the appropriate level bundle and sample its atlas rectangles. There are no background GPU readbacks, image resizing, pixel searches, or generated `ImageTexture`s on the level-loading path. Missing or mismatched bundles produce a Godot error with the regeneration command; the game does not fall back to a runtime search. Bundles are retained by the level's materials rather than a permanent cache of all visited levels.

Regenerate after editing source artwork, panorama order, overlap width, or either baker script:

```sh
tools/bake_landscapes.sh
godot --headless --path . --editor --import
tools/bake_landscapes.sh --check
```

Commit the four generated `_seams/` directories for Levels 2–5, including PNG import settings, with the source change. `--check` recomputes the reference output and returns a nonzero status for stale image pixels, source hashes, baker hashes, panel order, overlap width, or atlas coordinates. It does not rewrite the assets. The game uses normal Godot imports; keep mask textures lossless, without mipmaps or resizing. The atlas padding supports the current bilinear filter and is not padding for a future mip chain.

Compare all 36 remaining rendered joins against standalone decoded strips, including downward extensions when present. This isolates atlas sampling from codec error; the baker’s `--check` separately verifies the lossless source pixels and original seam search:

```sh
godot --path . --script res://tests/landscape_bake.gd
# Optional paired captures, kept outside the repository:
godot --path . --script res://tests/landscape_bake.gd -- --captures=/tmp/theseus-backgrounds
```

The compressed renderer comparison passed with a maximum per-channel difference of **3/255** over all joins. Source overlap PNG pixels and baked seam-mask pixels match the reference exactly; the comparison includes small GPU/CPU codec rounding and atlas-sampling differences. The existing solid-column, foliage, sky-transition, and checkpoint-shrine checks also passed.

## Historical measurements — November 23, 2026

These seam-baking measurements predate the continuous Level 1 scenery rebuild.

These are single paired development runs on this Intel Mac, Godot 4.7.2, Level 1. Both builds contain the same scenery and ongoing downward-extension work; only seam preparation differs. After the title and first level draw, the probe warms up for two seconds, then repeats a 20-second walk, jump, and sword exercise near the entrance. It keeps the player alive. Each target runs separately. These measurements are not a full-level stress test, a distribution build, or a physical-phone benchmark. Disk and driver caches were not purged.

“First draw” starts immediately before loading the level resource and includes instantiation, `_ready`, and an explicitly submitted draw. It excludes the title, app launch, and browser download/Wasm compilation. FPS and frame times describe main-loop intervals; they do not measure display scanout. P95 and worst-frame values below cover the 20-second exercise, with the initial loading stall reported separately.

| Target | Level first draw, before → baked | Loop FPS, before → baked | P95 frame, before → baked | Worst frame, before → baked | Frames >50 ms, before → baked |
| --- | ---: | ---: | ---: | ---: | ---: |
| macOS / Radeon Pro 5300, 1600×900 | 1.28 → 0.75 s | 144.9 → 140.3 | 8.2 → 11.6 ms | 12.0 → 18.2 ms | 0 → 0 |
| Chrome 158 / ANGLE Metal Radeon, 1600×813 | 2.27 → 1.15 s | 60.0 → 60.0 | 17.7 → 17.6 ms | 22.9 → 20.6 ms | 0 → 0 |
| Intel iOS Simulator / Apple Software Renderer, 320×180 internal | 3.50 → 2.14 s | 17.3 → 17.5 | 100.2 → 99.6 ms | 149.8 → 117.4 ms | 209 → 235 |
| Android emulator / SwiftShader, 2400×1080 | 4.90 → 2.11 s | 6.7 → 6.6 | 226.0 → 223.4 ms | 272.5 → 290.7 ms | 134 → 132 |

Both emulators reported software rendering. iOS uses the existing x86_64-only 320×180 preview fallback; the Android probe renders at its full emulated resolution. Neither result predicts physical iOS or Android phone performance. Android used temporary emulator userdata and a standard non-Gradle probe APK without the native AdMob plugin; the production Gradle template was unavailable. Its ads integration was not validated by this probe. The iOS probe used the existing native simulator executable and its linked SDKs. No physical phone or iPhone Safari performance was measured.

Steady gameplay did not gain frame rate from this milestone. The loading work fell substantially; rendering cost remains. These runs do not establish a steady-state performance improvement or regression from the small FPS differences. Mobile resolution and compression settings were unchanged in this first milestone.

### Memory and package cost

These are Godot's allocator and texture counters, in MiB. Allocator peak covers the whole process run, including the title; it is not total process RSS. Texture memory is the engine's accounting, not measured device VRAM residency. Browser/Wasm, driver, emulator, and native SDK overhead can exceed these counters.

| Target | Allocator peak, before → baked | Texture counter at end, before → baked |
| --- | ---: | ---: |
| macOS / Radeon Pro 5300 | 73.04 → 73.04 | 213.56 → 213.66 |
| Chrome 158 / ANGLE Metal Radeon | 87.71 → 87.73 | 209.24 → 209.33 |
| Intel iOS Simulator / Apple Software Renderer | 74.30 → 69.85 | 202.65 → 202.74 |
| Android emulator / SwiftShader | 74.89 → 70.46 | 218.03 → 218.12 |

The packed borders add about 0.09 MiB to the texture counter for this level. Baking ships overlap pixels that previously existed only after loading: the probe PCK grew from 130.5 to 145.3 MiB across all five levels. This trades download/storage size for faster loading; it does not compress the original artwork.

## Repeat the probe

Run the opt-in scene on desktop:

```sh
godot --path . res://scenes/debug/performance_probe.tscn -- --level=1 --seconds=20 --output=/tmp/theseus-performance.json
```

The JSON records the adapter, window and logical sizes, title/startup timing, level-ready and first-draw timing, average loop FPS, median/P95/P99/worst intervals, count of frames above 50 ms, and one-second memory/process/physics samples. The output directory must exist. Do not run other game builds or benchmarks concurrently.

For a mobile or web export, use a temporary project copy: set its main scene to `res://scenes/debug/performance_probe.tscn` and remove `scenes/debug/*` from that copy's export exclusions. Normal exports deliberately exclude this scene. Export and install using the [mobile guide](mobile.md). The default exercise takes 20 seconds and writes `user://performance.json`; web also exposes the result as `window.theseusBenchmark` for browser developer tools. On iOS Simulator, retrieve the JSON from the app data container's `Documents` directory. On a debug Android APK, read it with `adb shell run-as com.theseus.adventure cat files/performance.json`. Restore the ordinary playable build after testing. Do not publish the benchmark scene as the game.

Keep raw JSON, logs, captures, and temporary export copies outside the repository. Compare the same input exercise, renderer, dimensions, build mode, and artwork revision. Measure physical phones separately from software-rendered emulators.

## Mobile rendering budget

The second milestone adds `720`, `540`, and `preview` profiles. Physical Android/iOS devices and mobile web use a 1280×720 world target by default; 960×540 is the lower-cost option. Desktop retains its original native rendering. Detected simulators default to a separate 320×180 preview, including its UI. See [profile selection and preview commands](mobile.md#rendering-profiles).

The phone profiles draw the existing shared `World2D` through a fixed-size `SubViewport` with a 320×180 2D override. The original root camera remains active, and its completed transform is copied before drawing. A presentation layer displays the result; HUD, menus, and touch controls stay on the native-resolution UI viewport. There is still a native-size composition pass. Source artwork, texture imports, world coordinates, scene ownership, physics, collisions, and attack timing are unchanged.

### Available-target comparison

These are separate 20-second Level 1 development runs using the existing scripted exercise and two-second warmup. Chrome used a Radeon Pro 5300 with a phone-sized 2622×1206 physical display at DPR 3; its results are Mac GPU measurements, not iPhone Safari measurements. Native iOS used Apple Software Renderer; native Android used the emulator's SwiftShader. The Android probes used the standard non-Gradle template without the native AdMob plugin, so this does not validate the production Android Gradle/ads integration.

| Target and profile | Loop FPS | P95 frame | Worst frame | Texture counter, MiB |
| --- | ---: | ---: | ---: | ---: |
| Chrome / Radeon, `native` | 60.0 | 17.7 ms | 23.3 ms | 222.03 |
| Chrome / Radeon, `720` | 60.0 | 17.8 ms | 22.5 ms | 229.06 |
| Chrome / Radeon, `540` | 60.0 | 17.6 ms | 20.6 ms | 225.99 |
| iOS Simulator / software, `720` | 3.9 | 283.4 ms | 300.2 ms | 229.06 |
| iOS Simulator / software, `540` | 5.2 | 217.0 ms | 232.9 ms | 225.99 |
| iOS Simulator / software, `preview` | 18.2 | 90.0 ms | 129.2 ms | 203.18 |
| Android emulator / software, `native` | 7.1 | 199.9 ms | 230.8 ms | 218.12 |
| Android emulator / software, `720` | 7.5 | 190.8 ms | 234.8 ms | 225.15 |
| Android emulator / software, `540` | 9.2 | 144.2 ms | 203.7 ms | 222.08 |
| Android emulator / software, `preview` | 14.8 | 92.4 ms | 138.8 ms | 203.18 |

Chrome remained at its approximately 60 FPS cap across all profiles. Software-rendered simulators benefited from the cheaper preview; their low phone-profile frame rates do not establish physical-phone performance. The extra world framebuffer increases the texture counter by about 7.03 MiB at 720p or 3.96 MiB at 540p. This is a shading budget, not a texture-memory optimization. Compression was unchanged in that second-milestone comparison.

The benchmark now records `render_profile`, `world_target_pixels`, and `ui_target_pixels`. Native framebuffer dimensions exclude letterbox margins; physical window dimensions are recorded separately. The renderer regression compares the derived UI dimensions against an actual framebuffer readback. A separate five-second metadata check measured a 2144×1206 native gameplay framebuffer within the 2622×1206 window. The 720p and 540p targets reduce world pixel count by about 64% and 80% respectively; UI stays at 2144×1206. That check also confirmed automatic 720p selection for a touch-enabled Mac user agent, the iPadOS desktop-page case. The earlier comparison probe reported physical window dimensions for `native`; its FPS measurements remain valid, but that field should not be used to calculate the native world's pixel count.

### Verification and remaining device checks

The renderer check passed for all five levels at 720p, 540p, and preview resolution. It verifies actual texture sizes and screen-space markers in both the world target and final composition, unchanged root camera/zoom and scene ownership, identical movement/jump/sword animation histories against native rendering, resize/portrait-transition bounds, landscape safe-area fixtures, and title-button clicks through the presentation layer. Desktop and simultaneous-touch checks passed, including jump/sword and downward thrust, and the existing combat checks passed with the budget enabled. A small render-test capture and raw probe data stay outside the repository.

HUD score, health, titles, messages, and controls were inspected at native UI resolution in the iOS Simulator. Messages and speed status move above the touch targets when the home-indicator inset reduces usable height. Android's input service reported both landscape rotations (1 and 3) with a 2400×1080 display; reverse-rotation screenshot capture was incomplete. Physical-device visual rotation, readability, sustained frame rate, and thermal behavior still require testing. The iOS Simulator must remain foregrounded during profiling; a backgrounded attempt was discarded.

```sh
# Renderer-backed framing and gameplay regression:
godot --path . --script res://tests/mobile_rendering.gd --fixed-fps 60 -- --mobile-controls
# Profile-specific interaction checks:
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60 -- --mobile-controls --mobile-render=720
godot --headless --path . --script res://tests/mobile_controls.gd --fixed-fps 60 -- --mobile-controls --mobile-render=540
# Reproduce a desktop rendering comparison:
godot --path . res://scenes/debug/performance_probe.tscn -- --mobile-controls --mobile-render=720 --output=/tmp/theseus-720.json
godot --path . res://scenes/debug/performance_probe.tscn -- --mobile-controls --mobile-render=540 --output=/tmp/theseus-540.json
```

## Texture memory budget

Before the continuous Level 1 rebuild, the third milestone compressed **35 opaque background textures**: 25 panorama sheets, five baked overlap atlases, and five terrain tiles. Godot's Compatibility renderer imports standard-quality S3TC for desktop and ETC2 for mobile. Both variants are enabled in the Web export; the runtime selects a supported variant. High-quality BPTC/ASTC is not enabled because this renderer does not support that import mode. See Godot's [texture import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html) and [Web export requirements](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

For that compression milestone, original panorama and terrain PNGs retained their dimensions and pixels. Overlap PNGs were regenerated with compression-block-aligned padding; the lossless seam-data masks are unchanged. Transparent props, every character sheet, fonts, UI, and other gameplay artwork remain lossless. The character trial covered all 17 sheets at preview, 540p, and 720p scales. S3TC introduced small detail changes. The ETC2 RGBA desktop fallback/readback comparison produced severe artifacts, although independent headless decoding preserved the source artwork. That readback comparison is inconclusive for normal GPU sampling. Character compression remains deferred pending direct-render transparency and detail review on physical mobile devices. The trial assets and captures are outside the repository.

Only the five separate repeating stone tiles generate mipmaps, and all five geometry scripts explicitly select a mip-aware filter. At three/four output pixels per 16 source texels, the mip trial reduced RMS error against a lossless mip-filtered reference from 12.3–24.5 to 6.3–13.2 channel values out of 255 across all tiles. The reviewed captures preserve mortar lines while reducing undersampling noise. The ten render checks require at least a 20% error reduction. Mip levels add **1.26 MiB across all five compressed tiles**, about one third over their compressed base levels. Their standalone textures contain no neighboring atlas frames.

Panoramas, overlap atlases, seam masks, and character atlases have no mip chains. This avoids frame mixing and atlas-edge bleeding, and avoids adding a third to the much larger panorama allocation. The atlas regression now checks the 36 remaining joins and extended aprons against decoded standalone strips with a maximum difference of 3/255; the baker verifies exact source overlap and mask pixels separately. UI and fonts remain lossless without mipmaps.

### Historical memory and download comparison

The following figures predate the continuous Level 1 rebuild. These are five-second Level 1 development probes after a two-second warmup, with the same 1280×720 world target in both builds. They measure texture accounting and format selection; they are too short to establish sustained performance or thermal effects. The desktop probe confirmed RGB8 → DXT1, with its first panorama payload falling from 9,435,168 to 1,572,528 bytes. The 35 background payloads across the whole project total **282.50 → 48.36 MiB** per platform variant, including terrain mips; this is imported pixel payload, not total application memory.

| Target | Texture counter, lossless → compressed |
| --- | ---: |
| macOS / Radeon Pro 5300, 720p | 220.69 → 158.21 MiB |
| Chrome / ANGLE Metal Radeon, 720p, phone-sized display | 229.06 → 166.58 MiB |
| Intel iOS Simulator / Apple Software Renderer, 720p | 229.06 → 166.58 MiB |
| Android emulator / SwiftShader, 720p | 225.15 → 162.68 MiB |

Chrome used a 2622×1206 physical window at DPR 3 on the Mac GPU, not iPhone Safari. WebGL upload inspection confirmed DXT1 for its compressed scenery and accepted every terrain mip level without upload errors. The iOS probe reused the existing simulator executable with its linked native SDKs; its exported pack contains ETC2 backgrounds. The software simulator remained around 3.5 FPS at 720p, so the normal app retains its separate low-resolution preview default. The Android probes used the standard non-Gradle APK template without the native AdMob plugin because its Gradle template was unavailable; production Gradle/ads integration was not validated. Both emulator probes used software rendering. These measurements do not establish physical-phone performance. No physical iOS/Android device or iPhone Safari test was available.

Godot's texture counters are estimates, not device VRAM residency or total process RSS. Render targets, lossless characters, UI, SDKs, and browser/Wasm overhead remain. A GPU without the selected compression support can fall back to an uncompressed texture and lose the expected memory saving.

The following probe exports use the same official non-threaded debug Web template and include all five levels. Numbers cover the HTML, JavaScript, Wasm, PCK and accompanying images. Gzip is an offline level-6 estimate for a server configured to compress those files, not a measured transfer or the default behavior of every host.

| Web package | PCK | Whole package | Estimated gzip transfer |
| --- | ---: | ---: | ---: |
| Lossless baseline, desktop export flag | 145.30 MiB | 181.80 MiB | 154.26 MiB |
| Compressed, desktop variant only (comparison) | 73.14 MiB | 109.64 MiB | 67.84 MiB |
| Compressed, desktop + mobile variants (shipping preset) | 121.50 MiB | 158.00 MiB | 100.41 MiB |

Shipping both variants adds **48.36 MiB** to the desktop-only PCK. The dual package is still about 13% smaller uncompressed and 35% smaller with estimated gzip than the lossless baseline. Both variants travel in the download; only the selected variant is needed as the GPU texture. Importing both variants does not mean loading both into GPU memory during play.

Repeat validation after changing artwork or import settings:

```sh
godot --headless --path . --editor --import
tools/bake_landscapes.sh --check
godot --path . --script res://tests/texture_budget.gd
godot --path . --script res://tests/landscape_bake.gd
godot --path . --script res://tests/scenery_art.gd
```

`tests/texture_budget.gd` checks both imported format payloads, dimensions, protected lossless textures, the selective mip policy, Web variants, overlap block alignment, and minified terrain. It explicitly loads the mobile variant for inspection on desktop; a warning about converting ETC2 to RGBA8 there reflects desktop hardware support, not the format selected by normal desktop gameplay. Add `-- --captures=/tmp/theseus-terrain` to keep the three-column terrain comparisons (lossless mip reference, compressed without mips, compressed with mips) outside the repository. The performance probe records `panorama_readback` after timing. Desktop tools can return compressed image data; [Web/mobile return a decoded RGBA image](https://github.com/godotengine/godot/blob/master/drivers/gles3/storage/texture_storage.cpp) even for compressed GPU textures. Use import payloads and GPU upload inspection to verify the runtime format on those targets.


## Continuous Level 1 scenery

Level 1 replaces its ten blended panoramas with one 2,172×724 painting, displayed at 768×256 world units with horizontal/vertical parallax. Thirteen complete transparent midground objects establish its route landmarks. Its five old sheets and seam bundle have been removed. The remaining four seam bundles only change their baker hash because the offline tool now skips continuous landscapes. Levels 2–5 retain their artwork.

The new distant painting uses S3TC/ETC2, while the three cutout textures stay lossless. Grove and colonnade imports have a 1,024-pixel maximum dimension; the aqueduct retains its full width. The five stone terrain mip policies and mobile render budgets are unchanged. A five-second desktop Level 1 probe at the 720p budget reports **161.83 MiB** in the texture counter, versus 158.21 MiB before the rebuild: **3.62 MiB more** for the reusable transparent objects. These counters do not measure total process RSS or physical device VRAM residency. Older tables above refer to the previous artwork and package revision.

The Level 1 scenery regression sweeps the entire camera route, checks all viewport corners through climbs and jumps, and verifies one unblended texture without UV resets or wraps. Full-route physics traversal, all five levels' render-profile framing, terrain import checks, and the 36 remaining legacy-join comparisons also pass. The updated [Level 1 guide](level_1.md) shows in-game captures of all five areas and the temple.

The native iOS artwork preview also rendered the aqueduct at the 720p world budget, with a 2,144×1,206 UI framebuffer, one landscape, and thirteen landmarks. It used the Intel Simulator’s Apple Software Renderer, so this validates the native rendering path rather than physical-phone performance. The ordinary playable iOS app was restored afterward. A stock-template Android artwork probe APK exported successfully without the native AdMob plugin; the production Gradle/ads integration and physical Android display quality remain untested.
