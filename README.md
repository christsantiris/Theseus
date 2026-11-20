# Theseus

A left-to-right, retro side-scrolling adventure inspired by the readable levels,
expressive movement, and pixel art of early SNES platformers.

## Open the project

1. Install the standard edition of **Godot 4.5 or newer (4.x)**. This project uses GDScript;
   the .NET edition is not required.
2. In Godot's Project Manager, choose **Import** and select `project.godot`.
3. Open the project and press **F6** with `scenes/main/main.tscn` open, or **F5** to run the project.

The current milestone displays a small startup screen. Player movement and levels
will be added in later milestones.

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

| Input action | Keyboard binding | Planned use |
| --- | --- | --- |
| `move_left` | A / Left arrow | Move left |
| `move_right` | D / Right arrow | Move right |
| `jump` | Space | Jump |
| `pause` | Escape | Pause/menu |

These actions are configured for future scripts; the startup screen has no input behavior.
Letter bindings use physical keys, corresponding to A/D positions on a US keyboard.

## Milestones

1. **Project structure (current):** folders, settings, input actions, audio buses,
   startup scene, and development notes.
2. **Player prototype:** horizontal movement, jump feel, collisions, camera, and a
   small test level.
3. **Adventure loop:** level progression, hazards, collectibles, enemies, and HUD.
4. **Presentation:** original pixel art, animation, backgrounds, music, and sound.

Stop after each milestone for review and a manual commit. No commits or GitHub
publishing are performed automatically.
