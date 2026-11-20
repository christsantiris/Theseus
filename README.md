# Theseus

A left-to-right, retro side-scrolling adventure inspired by the readable levels,
expressive movement, and pixel art of early SNES platformers.

## Open the project

1. Install the standard edition of **Godot 4.5 or newer (4.x)**. This project uses GDScript;
   the .NET edition is not required.
2. In Godot's Project Manager, choose **Import** and select `project.godot`.
3. Open the project and press **F6** with `scenes/main/main.tscn` open, or **F5** to run the project.

New Game starts the complete Level 1, The Temple Road: five connected areas,
sixteen Greek soldiers, two checkpoint shrines, and a guarded temple exit.
See the [level guide and map](docs/level_1.md). Theseus can run, jump, duck, and thrust. Controls can be
rebound from the title screen, and those bindings are saved for the next launch.

If Godot is available as `godot` on your PATH:

```sh
godot --editor --path .
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 2
```

The last two commands import and check the project, then briefly run its startup scene.

## Project layout

```text
theseus/
├── project.godot              # Project settings and input actions
├── default_bus_layout.tres    # Master, Music, and SFX audio buses
├── scenes/
│   ├── main/main.tscn         # Entry point; World and UI roots
│   ├── player/                # Player scene and its scripts
│   ├── enemies/               # Enemy scenes and their scripts
│   ├── levels/                # Level scenes and level-specific scripts
│   ├── objects/               # Platforms, collectibles, and hazards
│   └── ui/                    # HUD, menus, and reusable controls
├── assets/
│   ├── art/
│   │   ├── characters/
│   │   ├── environments/
│   │   └── ui/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/
├── resources/
│   ├── tilesets/              # Shared TileSet resources
│   └── themes/                # Shared UI Theme resources
└── docs/                     # Development notes; excluded from Godot imports
```

Empty content folders contain `.gitkeep` so they survive a Git checkout.
Place scripts beside the scenes they control. See [project conventions](docs/project_structure.md)
for rendering, naming, and scene ownership decisions.

## Foundation settings

- Compatibility renderer for a lightweight 2D project.
- 320×180 base viewport, initially displayed at 960×540; integer scaling and a
  fixed aspect ratio keep the pixel grid consistent. This is a widescreen starting
  point rather than an exact SNES display resolution.
- Nearest-neighbor texture filtering for pixel art.
- Named 2D physics layers: World, Player, Enemies, Collectibles, and Hazards.
- Audio buses: Master, Music, and SFX.

| Input action | Default keys | Use |
| --- | --- | --- |
| `move_left` | A / Left arrow | Move left |
| `move_right` | D / Right arrow | Move right |
| `jump` | Up arrow / W | Jump. Release early for a shorter hop |
| `duck` | Down arrow / S | Duck in place |
| `attack` | Space | Sword thrust |
| `pause` | Escape | Pause, then resume or return to the title |

The title screen's Controls button rebinds these keys. Bindings are stored in
`user://input_bindings.cfg`. Letter keys use physical positions, so A/D/W stay
on those keys for a US keyboard layout.

## Milestones

1. **Project structure:** folders, settings, input actions, audio buses, startup
   scene, and development notes.
2. **Player prototype:** Theseus can run, jump, duck, and thrust in Level 1.
   The title screen has New Game and remappable controls. The Greek folk track
   starts on the title screen and keeps looping through Level 1. The backdrop is a flat
   Greek color study, not a finished tileset.
3. **Level 1 (current):** a 4,800-pixel route with five areas, sixteen enemies,
   health pickups, checkpoint recovery, score, and a temple-gate ending.
4. **Presentation:** finished level art, animation polish, music, and sound.

Stop after each milestone for review and a manual commit. No commits or GitHub
publishing are performed automatically.

## Credits

Music by <a href="https://pixabay.com/users/moonpub-15209240/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=621132">Johnny Hoeve</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=621132">Pixabay</a>

Sound Effect by <a href="https://pixabay.com/users/daviddumaisaudio-41768500/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=185432">David Dumais</a> from <a href="https://pixabay.com/sound-effects//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=185432">Pixabay</a>

Sound Effect by <a href="https://pixabay.com/users/u_qqkrn9bn55-52083300/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=398256">u_qqkrn9bn55</a> from <a href="https://pixabay.com/sound-effects//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=398256">Pixabay</a>

## Play test the game

1. **Run the command** ` godot --path .`
