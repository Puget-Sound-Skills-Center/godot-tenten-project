# Codebase Structure

**Analysis Date:** 2026-05-08

## Directory Layout

```
godot-tenten-project/
├── project.godot          # Engine config, autoloads, input map, main scene
├── scenes/                # Packed scene files (.tscn)
│   ├── home_screen.tscn   # Title/menu screen (entry point)
│   ├── world.tscn         # Overworld hub
│   ├── cliff_side.tscn    # Transition zone to dungeon
│   ├── dungeon.tscn       # Procedural dungeon floor (reloaded per floor)
│   ├── player.tscn        # Player CharacterBody2D
│   ├── enemy.tscn         # Enemy CharacterBody2D
│   └── puzzle_test.tscn   # Dev test scene for all puzzle types
├── script/                # All GDScript logic
│   ├── global.gd          # Autoload: global state, save/load system
│   ├── pause_menu.gd      # Autoload: ESC pause overlay + in-game save
│   ├── home_screen.gd     # Home screen UI and scene routing
│   ├── world.gd           # World scene setup and transition trigger
│   ├── cliff_side.gd      # Cliff side setup and dungeon entry trigger
│   ├── dungeon.gd         # Procedural floor generation + puzzle system
│   ├── puzzle_test.gd     # Standalone test of all 5 puzzle types
│   ├── player.gd          # Player movement, combat, HUD, shop UI
│   ├── enemy.gd           # Enemy AI (NavigationAgent2D pathfinding)
│   ├── npc.gd             # World shop NPC (runtime-spawned, no .tscn)
│   └── dungeon_npc.gd     # Cliffside dungeon-entry NPC (runtime-spawned)
├── art/                   # Visual assets
│   ├── characters/        # Player and enemy sprite sheets
│   ├── objects/           # NPC sprites (chest_01.png, chest_02.png)
│   ├── particles/         # Particle textures
│   └── tilesets/          # Tilemap tiles
└── addons/
    └── godot_ai/          # Godot AI MCP plugin (dev tool, not game logic)
        ├── plugin.gd      # Editor plugin entry
        ├── runtime/       # game_helper.gd autoload (dev only)
        ├── handlers/      # MCP tool handlers
        ├── clients/       # AI client integrations
        └── utils/         # Plugin utilities
```

## Directory Purposes

**`scenes/`:**
- Purpose: Godot PackedScene files — the structural shell of each game area/entity
- Contains: `.tscn` files with node hierarchies for scenes and entities
- Key files: `home_screen.tscn` (entry), `dungeon.tscn` (gameplay loop), `player.tscn` + `enemy.tscn` (entities)
- Note: Scene files hold node structure and physics; all logic is in the paired `script/` file

**`script/`:**
- Purpose: All GDScript game logic
- Contains: Scene controller scripts, autoloads, NPC scripts
- Key files: `global.gd` (state), `dungeon.gd` (core gameplay, ~707 lines), `player.gd` (player + shop UI)
- Note: NPC scripts (`npc.gd`, `dungeon_npc.gd`) have no paired `.tscn` — they are spawned via `load().new()`

**`art/`:**
- Purpose: All game textures and sprites
- Contains: PNG sprite sheets organized by category
- Key files: `art/objects/chest_01.png` (shop NPC sprite), `art/objects/chest_02.png` (dungeon NPC sprite)

**`addons/godot_ai/`:**
- Purpose: Godot AI MCP editor plugin (developer tooling only)
- Contains: Editor plugin, MCP server, AI client configs
- Note: `_mcp_game_helper` is registered as an autoload but is a dev tool — do not add game logic here

## Key File Locations

**Entry Points:**
- `scenes/home_screen.tscn`: Application entry — set as `run/main_scene` in `project.godot`
- `project.godot`: Autoload declarations, input map, viewport config (1920x1080, scale 4.0)

**Autoloads (always in tree):**
- `script/global.gd`: Accessed as `global` everywhere — game state and save system
- `script/pause_menu.gd`: Accessed as `pause_menu` — ESC menu, always active

**Core Gameplay:**
- `script/dungeon.gd`: Procedural floor generation, enemy spawning, all 5 puzzle types
- `script/player.gd`: Player controller, combat, shop UI, HUD

**Navigation:**
- `script/enemy.gd`: NavigationAgent2D usage — pathfinding setup pattern lives here

**Save Data:**
- Stored at runtime in `user://save_slot_1.cfg` through `user://save_slot_4.cfg` (ConfigFile format)

## Naming Conventions

**Files:**
- Scene files: `snake_case.tscn` matching the scene's purpose (e.g., `home_screen.tscn`, `cliff_side.tscn`)
- Script files: `snake_case.gd` matching the scene or role (e.g., `dungeon_npc.gd`, `puzzle_test.gd`)
- Scene and script pairs share the same base name (e.g., `dungeon.tscn` ↔ `dungeon.gd`)

**Functions:**
- Private/internal helpers prefixed with `_` (e.g., `_build_floor_background()`, `_spawn_player()`)
- Signal callbacks prefixed with `_on_` (e.g., `_on_exit_body_entered()`, `_on_attack_cooldown_timeout()`)
- Public API uses no prefix (e.g., `open_shop()`, `player()`, `enemy()`)

**Variables:**
- `snake_case` throughout; private UI node refs prefixed with `_` (e.g., `_hud_layer`, `_shop_money_label`)
- Constants in `UPPER_SNAKE_CASE` (e.g., `TILE`, `DUNGEON_MAX_FLOOR`, `PUZZLE_TYPES`)

## Where to Add New Code

**New playable scene (e.g., a second dungeon type):**
- Scene file: `scenes/new_scene.tscn`
- Script: `script/new_scene.gd` extending `Node2D`
- Register routing in `global.gd` (`current_scene` string value)
- Add transition logic to the scene that should link to it

**New enemy type:**
- Duplicate `scenes/enemy.tscn` → `scenes/enemy_new.tscn`
- New script: `script/enemy_new.gd` extending `CharacterBody2D`; must include `func enemy(): pass` identity tag
- Reference new scene path as a const in `dungeon.gd`

**New puzzle type:**
- Add type string to `PUZZLE_TYPES` array in `script/dungeon.gd`
- Add `_build_puzzle_<type>()` and `_handle_<type>_tile()` methods in `script/dungeon.gd`
- Add matching zone and handlers in `script/puzzle_test.gd` for isolated testing

**New NPC:**
- Create `script/new_npc.gd` extending `Node2D`; build visual + Area2D interaction zone in `_ready()`
- Spawn from a scene's `_ready()` via `load("res://script/new_npc.gd").new()`
- No `.tscn` file needed (matches existing pattern)

**New upgrade stat:**
- Add level variable to `global.gd` (`var player_X_level = 0`)
- Include in `reset_for_new_game()`, `save_to_slot()`, `load_from_slot()`, `slot_preview()` in `global.gd`
- Add shop row in `player.gd._setup_shop()` and update logic in `_update_hud()` / `_upgrade_X()`

**Utilities / shared helpers:**
- No shared utility file exists yet. Add `script/utils.gd` as a new autoload entry in `project.godot` if needed.

## Special Directories

**`addons/godot_ai/`:**
- Purpose: Godot AI MCP development plugin — not game code
- Warning: Do not place game scripts here. The `_mcp_game_helper` autoload from this addon is a dev tool.

---

*Structure analysis: 2026-05-08*
