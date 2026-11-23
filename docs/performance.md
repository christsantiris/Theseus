# Background builds and performance

## Seam baking

The five levels have ten panoramas each and nine joins per level. `tools/bake_landscapes.sh` reads the source PNGs on the CPU, runs the original content-aware seam search, and writes two lossless atlases plus `joins.tres` to each level's `_seams/` directory. The 1,092×2,178 overlap atlas holds the previous paintings' edge strips; the 9×582 mask atlas holds the nine seam paths and feather widths. Replicated border pixels preserve clamped bilinear sampling. Both fit below the existing 4096×4096 mobile texture limit.

During play, materials load the appropriate level bundle and sample its atlas rectangles. There are no background GPU readbacks, image resizing, pixel searches, or generated `ImageTexture`s on the level-loading path. Missing or mismatched bundles produce a Godot error with the regeneration command; the game does not fall back to a runtime search. Bundles are retained by the level's materials rather than a permanent cache of all visited levels.

Regenerate after editing source artwork, panorama order, overlap width, or either baker script:

```sh
tools/bake_landscapes.sh
godot --headless --path . --editor --import
tools/bake_landscapes.sh --check
```

Commit all five generated `_seams/` directories, including PNG import settings, with the source change. `--check` recomputes the reference output and returns a nonzero status for stale image pixels, source hashes, baker hashes, panel order, overlap width, or atlas coordinates. It does not rewrite the assets. The game uses normal Godot imports; keep mask textures lossless, without mipmaps or resizing. The atlas padding supports the current bilinear filter and is not padding for a future mip chain.

Compare all 45 rendered joins against the original standalone overlap textures and seam search, including downward extensions when present:

```sh
godot --path . --script res://tests/landscape_bake.gd
# Optional paired captures, kept outside the repository:
godot --path . --script res://tests/landscape_bake.gd -- --captures=/tmp/theseus-backgrounds
```

The renderer comparison passed with a maximum per-channel difference of **1/255** over all joins. Source overlap pixels and baked seam-mask pixels match the reference exactly; the small rendered difference comes from sampling the packed atlas. The existing solid-column, foliage, sky-transition, and checkpoint-shrine checks also passed.

## Measurements — November 23, 2026

These are single paired development runs on this Intel Mac, Godot 4.7.2, Level 1. Both builds contain the same scenery and ongoing downward-extension work; only seam preparation differs. After the title and first level draw, the probe warms up for two seconds, then repeats a 20-second walk, jump, and sword exercise near the entrance. It keeps the player alive. Each target runs separately. These measurements are not a full-level stress test, a distribution build, or a physical-phone benchmark. Disk and driver caches were not purged.

“First draw” starts immediately before loading the level resource and includes instantiation, `_ready`, and an explicitly submitted draw. It excludes the title, app launch, and browser download/Wasm compilation. FPS and frame times describe main-loop intervals; they do not measure display scanout. P95 and worst-frame values below cover the 20-second exercise, with the initial loading stall reported separately.

| Target | Level first draw, before → baked | Loop FPS, before → baked | P95 frame, before → baked | Worst frame, before → baked | Frames >50 ms, before → baked |
| --- | ---: | ---: | ---: | ---: | ---: |
| macOS / Radeon Pro 5300, 1600×900 | 1.28 → 0.75 s | 144.9 → 140.3 | 8.2 → 11.6 ms | 12.0 → 18.2 ms | 0 → 0 |
| Chrome 158 / ANGLE Metal Radeon, 1600×813 | 2.27 → 1.15 s | 60.0 → 60.0 | 17.7 → 17.6 ms | 22.9 → 20.6 ms | 0 → 0 |
| Intel iOS Simulator / Apple Software Renderer, 320×180 internal | 3.50 → 2.14 s | 17.3 → 17.5 | 100.2 → 99.6 ms | 149.8 → 117.4 ms | 209 → 235 |
| Android emulator / SwiftShader, 2400×1080 | 4.90 → 2.11 s | 6.7 → 6.6 | 226.0 → 223.4 ms | 272.5 → 290.7 ms | 134 → 132 |

Both emulators reported software rendering. iOS uses the existing x86_64-only 320×180 preview fallback; the Android probe renders at its full emulated resolution. Neither result predicts physical iOS or Android phone performance. Android used temporary emulator userdata and a standard non-Gradle probe APK without the native AdMob plugin; the production Gradle template was unavailable. Its ads integration was not validated by this probe. The iOS probe used the existing native simulator executable and its linked SDKs. No physical phone or iPhone Safari performance was measured.

Steady gameplay did not gain frame rate from this milestone. The loading work fell substantially; rendering cost remains. These runs do not establish a steady-state performance improvement or regression from the small FPS differences. Mobile resolution and compression settings are unchanged.

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
