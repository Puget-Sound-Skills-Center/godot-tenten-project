<!-- GSD:project-start source:PROJECT.md -->
## Project

**Dungeon Explorer RPG**

A 2D pixel art dungeon exploration RPG built in Godot 4.6, inspired by Stardew Valley's aesthetic and warmth but focused on deep dungeon crawling. Players explore procedurally generated dungeon floors, interact with a cast of NPCs who give quests and tell stories, and fight varied enemies that challenge them to adapt their approach. The game lives in the tension between the safety of the overworld town and the danger of going deeper.

**Core Value:** Every dungeon run feels different and purposeful — varied enemies, hidden secrets, and NPC quests that make players *want* to go back in.

### Constraints

- **Tech stack**: Godot 4.6 / GDScript — no external dependencies
- **Art style**: Pixel art, consistent with existing `art/` assets
- **Architecture**: Follow existing patterns (global flag polling, duck-typed identity, runtime NPC spawn)
- **Save system**: Any new persistent state must be added to `global.gd` save/load slots
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- GDScript 4.x - All game logic and editor tooling (`script/*.gd`, `addons/godot_ai/**/*.gd`)
- Python (server-side) - MCP server backend launched by `addons/godot_ai` via `uv` (see plugin README)
## Runtime
- Godot Engine 4.6 (declared in `project.godot` `config/features`)
- None (Godot project — no npm/pip manifests in project root)
- Python MCP server managed by `uv` (installed separately, not committed)
- Lockfile: Not applicable
## Frameworks
- Godot 4.6 - Game engine, scene system, physics, rendering
- Godot AI addon v2.4.2 - MCP server + AI-editor bridge (`addons/godot_ai/plugin.cfg`)
- None detected (no test runner config; `addons/godot_ai` contains `test_handler.gd` for editor-side test execution via MCP)
- Godot Editor (standalone) - Scene editing, export
- Godot AI MCP server - WebSocket server connecting AI clients to the live editor
## Key Dependencies
- Godot Engine 4.6 - Required runtime; targets `Forward Plus` renderer
- Jolt Physics (3D engine) - Configured in `project.godot` `[physics]` section
- `uv` (Python package runner) - Required to launch the MCP server; installed separately
- `addons/godot_ai` v2.4.2 - Provides MCP protocol bridge; auto-starts WebSocket server on editor open
## Configuration
- No `.env` files detected
- Game state persisted to `user://save_slot_N.cfg` (Godot `ConfigFile` format, 4 slots) — see `script/global.gd`
- No external environment variables required for game runtime
- `project.godot` - Main project config (engine version, main scene, autoloads, input map, renderer)
- `addons/godot_ai/plugin.cfg` - Plugin metadata
- `.import/` files - Auto-generated Godot asset import metadata (committed per standard Godot practice)
## Platform Requirements
- Godot 4.6+ editor (Windows; rendering backend: Direct3D 12 `d3d12`)
- `uv` installed for AI/MCP features
- An MCP client (Claude Code, Codex, Antigravity, Cursor, etc.)
- Godot export templates for target platform
- Viewport: 1920x1080 logical, scale 4.0 (pixel-art scaling)
- Renderer: Forward Plus (GPU required)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- `snake_case.gd` for all script files: `player.gd`, `dungeon_npc.gd`, `pause_menu.gd`, `home_screen.gd`
- `snake_case.tscn` for scene files: `player.tscn`, `cliff_side.tscn`, `puzzle_test.tscn`
- Script files are co-located in `script/` directory; scenes in `scenes/` directory
- Script names mirror scene names exactly: `script/player.gd` ↔ `scenes/player.tscn`
- Public/lifecycle functions: `snake_case` matching Godot built-ins — `_ready()`, `_process()`, `_physics_process()`
- Private helper functions: leading underscore prefix — `_build_ui()`, `_setup_hud()`, `_spawn_player()`, `_make_wall()`
- Signal handler functions: `_on_<node>_<signal>` — `_on_player_hitbox_body_entered()`, `_on_attack_cooldown_timeout()`, `_on_exit_body_entered()`
- "Marker" functions (duck-typing identity): bare name, `pass` body — `func player(): pass`, `func enemy(): pass`
- `snake_case` for all variables: `player_chase`, `enemy_inattack_range`, `can_take_damage`
- Private node references: leading underscore — `_nav_agent`, `_hud_layer`, `_shop_layer`, `_dmg_btn`
- Boolean flags use descriptive names without `is_` prefix (inconsistent): `player_alive`, `shop_open`, `puzzle_active`
- Some booleans do use `is_`: `is_green` (tile meta), but not in variable declarations
- Local temporary variables: single-letter or short — `t`, `n`, `v`, `a`, `b`, `op`
- `SCREAMING_SNAKE_CASE`: `MAX_UPGRADE_LEVEL`, `TILE`, `FLOOR_COLOR`, `PLAYER_SCENE`, `DUNGEON_MAX_FLOOR`
- Color constants grouped at file top with descriptive suffix `_COLOR`: `FLOOR_COLOR`, `WALL_COLOR`, `EXIT_COLOR`
- Scene paths as `const` strings: `const PLAYER_SCENE := "res://scenes/player.tscn"`
- No custom class names in project scripts (no `class_name` declarations in game scripts)
- Autoload singleton: `global` (lowercase), defined via `script/global.gd`
## Code Style
- Tabs for indentation (GDScript default)
- No explicit formatter config found; follows Godot editor defaults
- Opening braces inline (Godot style)
- Blank lines between function definitions
- No external linter config (`.editorconfig`, `gdlint` config) detected
- Godot's built-in parser warnings are the only enforcement
- Mixed usage: newer code uses explicit return types and typed params — `func _ready() -> void:`, `func _on_exit_body_entered(body: Node2D) -> void:`
- Older/simpler functions omit type hints — `func _on_player_hitbox_body_entered(body):`
- Variable declarations use `:=` walrus-style inference for locals in newer code: `var cfg := ConfigFile.new()`
- Top-level var declarations rarely typed explicitly
## Node References
## Export Variables
## Signal Patterns
## Duck-Typing Identity Pattern
## Scene Connection Patterns
## Error Handling
## Logging
## Comments
## Function Design
## Module Design
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```
```
## Component Responsibilities
| Component | Responsibility | File |
|-----------|----------------|------|
| `global` (autoload) | Global game state, save/load, player stats, scene routing flags | `script/global.gd` |
| `pause_menu` (autoload) | ESC pause overlay, in-game save panel, return to home | `script/pause_menu.gd` |
| `home_screen` | Title screen, new game, load save slot selection | `scenes/home_screen.tscn` + `script/home_screen.gd` |
| `world` | Overworld hub, player spawn, shop NPC, cliffside transition | `scenes/world.tscn` + `script/world.gd` |
| `cliff_side` | Intermediate zone, dungeon NPC, back-to-world transition | `scenes/cliff_side.tscn` + `script/cliff_side.gd` |
| `dungeon` | Procedural floor generator, enemy spawner, puzzle system, exit logic | `scenes/dungeon.tscn` + `script/dungeon.gd` |
| `player` | CharacterBody2D, movement, combat, HUD, upgrade shop UI | `scenes/player.tscn` + `script/player.gd` |
| `enemy` | CharacterBody2D, NavigationAgent2D pathfinding, damage dealing | `scenes/enemy.tscn` + `script/enemy.gd` |
| `npc` (shop) | Area2D, proximity interact, calls `player.open_shop()` | `script/npc.gd` (spawned at runtime) |
| `dungeon_npc` | Area2D, proximity interact, sets `global.enter_dungeon = true` | `script/dungeon_npc.gd` (spawned at runtime) |
| `puzzle_test` | Standalone test scene: all 5 puzzle types in one room | `scenes/puzzle_test.tscn` + `script/puzzle_test.gd` |
## Pattern Overview
- Scene transitions are imperative (`get_tree().change_scene_to_file()`), coordinated by boolean flags on `global`.
- All persistent state (money, stats, floor, scene) lives in `global` singleton — no signals between scenes.
- UI is constructed entirely in GDScript at runtime (no `.tscn` UI nodes); scenes contain physics bodies only.
- Player identity check uses duck-typing: `body.has_method("player")` / `body.has_method("enemy")`.
## Layers
- Purpose: Global state, cross-scene UI (pause menu)
- Location: `script/global.gd`, `script/pause_menu.gd`
- Contains: Save/load, player stat vars, scene routing flags
- Depends on: nothing
- Used by: all scene scripts
- Purpose: Scene lifecycle, room building, NPC spawning, transition triggers
- Location: `script/world.gd`, `script/cliff_side.gd`, `script/dungeon.gd`, `script/home_screen.gd`
- Contains: `_ready()` setup, `_process()` transition polling
- Depends on: `global` autoload
- Used by: Godot scene tree
- Purpose: Per-entity behavior (movement, combat, interaction)
- Location: `script/player.gd`, `script/enemy.gd`, `script/npc.gd`, `script/dungeon_npc.gd`
- Contains: Physics processing, input, collision callbacks, UI building
- Depends on: `global` autoload
- Used by: scenes (via scene files or `load().new()`)
## Data Flow
### Game Start / New Game
### World → Cliffside → Dungeon
### Dungeon Floor Generation
### Save System
- All game state in `global` singleton (Node autoload at path `global`)
- No signals between scenes — flag polling in `_process()` is the coordination mechanism
- Player current health persisted to `global.player_current_health` via `player.gd._exit_tree()`
## Key Abstractions
- Purpose: Identify player vs. enemy on collision without node group lookup overhead
- Examples: `body.has_method("player")` in `enemy.gd`, `npc.gd`, `dungeon.gd`; `body.has_method("enemy")` in `player.gd`
- Pattern: Each entity script declares a no-op method (`func player(): pass` / `func enemy(): pass`) as a type tag
- Purpose: Floor tile that triggers puzzle logic on player step
- Examples: Created by `_make_tile_base()` in `dungeon.gd`, `_make_tile()` in `puzzle_test.gd`
- Pattern: Area2D with CollisionShape2D + ColorRect visual + Label, metadata stored via `set_meta()` / `get_meta()`
- Purpose: Interaction point; no scene file, built entirely in `_ready()`
- Examples: `script/npc.gd` (shop), `script/dungeon_npc.gd` (dungeon entry)
- Pattern: `load("res://script/npc.gd").new()` then `add_child()` from scene `_ready()`
## Entry Points
- Location: `scenes/home_screen.tscn` (set as `run/main_scene` in `project.godot`)
- Triggers: Godot engine boot
- Responsibilities: Menu display, new game init, save slot loading
- Location: `scenes/dungeon.tscn` (reloaded per floor)
- Triggers: `cliff_side.gd` polling `global.enter_dungeon`; `dungeon.gd` polling `global.next_floor`
- Responsibilities: Procedural room generation, enemy + puzzle spawn
## Architectural Constraints
- **Threading:** Single-threaded Godot main loop. No threads or workers used.
- **Global state:** `global` singleton (`script/global.gd`) holds all cross-scene mutable state. Accessed everywhere as bare `global.` prefix.
- **Circular imports:** None detected. Scene scripts only depend on autoloads.
- **Scene reload for floor advance:** `get_tree().reload_current_scene()` is used to advance dungeon floors — this tears down and rebuilds the entire dungeon scene every floor, which is intentional but means no persistent dungeon objects survive floor transitions.
- **UI in code only:** No Control nodes in `.tscn` files — all UI (HUD, shop, pause, home screen) is built procedurally in `_ready()` / `_build_*()` methods. This makes UI hard to inspect in the Godot editor.
## Anti-Patterns
### Flag polling in `_process()`
### Duck-typed method tag for entity identity
### Duplicate puzzle logic
## Error Handling
- `global.load_from_slot()` returns `bool` (false if file missing) — caller checks return value
- No error recovery for missing scenes or assets
- `_is_position_clear()` fallback: returns center of room if no clear position found after 80 attempts
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
