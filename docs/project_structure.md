# Project conventions

## Scene ownership

`scenes/main/main.tscn` is the project entry point. Its `World` node will host the
active level; its `UI` CanvasLayer will host screen-space controls. The temporary
`ScaffoldScreen` can be removed when the first playable level is connected.

Create reusable scenes for the player, each enemy, and interactive objects. A
level owns its terrain and instances those scenes. Keep each scene's GDScript
files beside it, for example `scenes/player/player.tscn` and `scenes/player/player.gd`.
Introduce shared systems or autoloads when gameplay establishes a concrete need.

Use `snake_case` for files, folders, functions, and variables; `PascalCase` for
node and class names; and `UPPER_SNAKE_CASE` for constants. Use typed GDScript
where practical, and input actions rather than hard-coded keys in gameplay code.

## Art and world space

The initial viewport is 320×180 with integer scaling, a preserved aspect ratio,
and nearest-neighbor texture filtering. Use 16×16 pixels as the initial terrain
tile grid; sprites can span multiple tiles. These are starting conventions that
can be adjusted when the art direction is established.

Godot's positive X points right and positive Y points down. Build levels to
progress along positive X. Keep collision geometry and level coordinates aligned
with the terrain grid where appropriate.

Store shared source art in `assets/art`, audio in `assets/audio`, and fonts in
`assets/fonts`. Store reusable TileSet and Theme resources in `resources`.
Use original or appropriately licensed assets and record attribution when assets
are introduced.

## Physics and audio

| Layer number | Bit value | Purpose |
| --- | --- | --- |
| 1 | 1 | World terrain and solid platforms |
| 2 | 2 | Player body |
| 3 | 4 | Enemy bodies |
| 4 | 8 | Collectible detection areas |
| 5 | 16 | Hazard detection areas |

Collision layers describe what an object is; masks describe what it detects.
Set both explicitly when adding physics scenes. The scaffold only names the
layers and does not yet establish collision behavior.

Route background music to `Music` and sound effects to `SFX`; both feed `Master`.
Godot loads `default_bus_layout.tres` as the default bus layout.

## Version control and review

Track source scenes, scripts, assets, resource files, project settings, and
Godot-generated `.uid` files. Ignore `.godot/`, local overrides, export credentials,
and exported builds. `docs/.gdignore` keeps documentation out of the engine's
resource browser. Remove `.gitkeep` when a content folder gains real files.

Review and commit each milestone manually before beginning the next one.

## Godot references

- [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
- [Multiple resolutions and pixel-art scaling](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [Project settings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)
