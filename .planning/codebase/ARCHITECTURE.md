<!-- refreshed: 2026-05-08 -->
# Architecture

**Analysis Date:** 2026-05-08

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Autoloads (always-on)                       │
│  global (script/global.gd)  |  pause_menu (script/pause_menu.gd) │
│  _mcp_game_helper (dev tool, addons/godot_ai/runtime/game_helper.gd) │
└──────────────────────────────┬──────────────────────────────────┘
                               │  shared state / save system
         ┌─────────────────────┼────────────────────────┐
         ▼                     ▼                        ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│  home_screen    │  │  world           │  │  cliff_side          │
│  (entry scene)  │  │  (scenes/        │  │  (scenes/            │
│  scenes/        │  │  world.tscn      │  │  cliff_side.tscn     │
│  home_screen    │  │  + script/       │  │  + script/           │
│  .tscn)         │  │  world.gd)       │  │  cliff_side.gd)      │
└────────┬────────┘  └────────┬─────────┘  └────────┬─────────────┘
         │ New Game            │ cliff transition     │ enter_dungeon flag
         │ Load Save           │                      │
         ▼                     ▼                      ▼
  get_tree().change_scene_to_file() calls (not signal-based)
                               │
                               ▼
              ┌────────────────────────────┐
              │  dungeon (procedural)       │
              │  scenes/dungeon.tscn        │
              │  script/dungeon.gd          │
              │  Floors 1-100, regen via    │
              │  reload_current_scene()     │
              └────────────────────────────┘
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

**Overall:** Scene-based state machine with a single global singleton for shared state.

**Key Characteristics:**
- Scene transitions are imperative (`get_tree().change_scene_to_file()`), coordinated by boolean flags on `global`.
- All persistent state (money, stats, floor, scene) lives in `global` singleton — no signals between scenes.
- UI is constructed entirely in GDScript at runtime (no `.tscn` UI nodes); scenes contain physics bodies only.
- Player identity check uses duck-typing: `body.has_method("player")` / `body.has_method("enemy")`.

## Layers

**Autoloads (persistent):**
- Purpose: Global state, cross-scene UI (pause menu)
- Location: `script/global.gd`, `script/pause_menu.gd`
- Contains: Save/load, player stat vars, scene routing flags
- Depends on: nothing
- Used by: all scene scripts

**Scene scripts (transient):**
- Purpose: Scene lifecycle, room building, NPC spawning, transition triggers
- Location: `script/world.gd`, `script/cliff_side.gd`, `script/dungeon.gd`, `script/home_screen.gd`
- Contains: `_ready()` setup, `_process()` transition polling
- Depends on: `global` autoload
- Used by: Godot scene tree

**Entity scripts (instanced nodes):**
- Purpose: Per-entity behavior (movement, combat, interaction)
- Location: `script/player.gd`, `script/enemy.gd`, `script/npc.gd`, `script/dungeon_npc.gd`
- Contains: Physics processing, input, collision callbacks, UI building
- Depends on: `global` autoload
- Used by: scenes (via scene files or `load().new()`)

## Data Flow

### Game Start / New Game

1. Godot loads `scenes/home_screen.tscn` (main scene in `project.godot`)
2. `home_screen.gd` builds UI procedurally in `_ready()`
3. "New Game" → `global.reset_for_new_game()` → `get_tree().change_scene_to_file("res://scenes/world.tscn")`
4. "Load Save" → `global.load_from_slot(slot)` → `get_tree().change_scene_to_file(...)` (world / cliff_side / dungeon based on saved scene)

### World → Cliffside → Dungeon

1. Player walks into trigger area in `world.tscn` → `_on_cliffside_trasition_point_body_entered` sets `global.transition_scene = true`
2. `world.gd._process()` polls `global.transition_scene` → calls `change_scene_to_file("res://scenes/cliff_side.tscn")`
3. Player interacts with `dungeon_npc` in cliff_side → sets `global.enter_dungeon = true`
4. `cliff_side.gd._process()` polls `global.enter_dungeon` → sets `global.current_floor = global.dungeon_resume_floor` → loads dungeon scene
5. Dungeon floor clear: `global.next_floor = true` → `dungeon.gd._process()` increments floor, calls `get_tree().reload_current_scene()`
6. Save/exit or floor 100: `dungeon.gd._exit_to_cliffside()` → sets `global.came_from_dungeon = true`, loads cliff_side scene

### Dungeon Floor Generation

1. `dungeon.gd._ready()` runs: reads `global.current_floor`, scales `room_w`/`room_h`
2. Sequence: `_build_floor_background()` → `_build_outer_walls()` → `_build_random_obstacles()` → `_setup_navigation()` → `_spawn_player()` → `_spawn_enemies()` → `_build_floor_exit()` → optional `_build_save_point()` (every 10 floors) → optional `_setup_puzzle()` (20% chance)
3. NavigationPolygon baked from walkable area minus obstacle rects for enemy pathfinding

### Save System

1. `pause_menu` (autoload, always active) handles ESC key via `_unhandled_input`
2. Save: `global.save_to_slot(slot, player_pos)` writes `user://save_slot_N.cfg` (ConfigFile)
3. Load: `global.load_from_slot(slot)` reads config, sets `global.loaded_from_save = true`
4. Scene scripts check `global.loaded_from_save` in `_ready()` to reposition player

**State Management:**
- All game state in `global` singleton (Node autoload at path `global`)
- No signals between scenes — flag polling in `_process()` is the coordination mechanism
- Player current health persisted to `global.player_current_health` via `player.gd._exit_tree()`

## Key Abstractions

**Duck-typed identity check:**
- Purpose: Identify player vs. enemy on collision without node group lookup overhead
- Examples: `body.has_method("player")` in `enemy.gd`, `npc.gd`, `dungeon.gd`; `body.has_method("enemy")` in `player.gd`
- Pattern: Each entity script declares a no-op method (`func player(): pass` / `func enemy(): pass`) as a type tag

**Puzzle tile (Area2D):**
- Purpose: Floor tile that triggers puzzle logic on player step
- Examples: Created by `_make_tile_base()` in `dungeon.gd`, `_make_tile()` in `puzzle_test.gd`
- Pattern: Area2D with CollisionShape2D + ColorRect visual + Label, metadata stored via `set_meta()` / `get_meta()`

**NPC (runtime-spawned Node2D):**
- Purpose: Interaction point; no scene file, built entirely in `_ready()`
- Examples: `script/npc.gd` (shop), `script/dungeon_npc.gd` (dungeon entry)
- Pattern: `load("res://script/npc.gd").new()` then `add_child()` from scene `_ready()`

## Entry Points

**Application Entry:**
- Location: `scenes/home_screen.tscn` (set as `run/main_scene` in `project.godot`)
- Triggers: Godot engine boot
- Responsibilities: Menu display, new game init, save slot loading

**Dungeon Floor Entry:**
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

**What happens:** Scene scripts poll `global.transition_scene`, `global.enter_dungeon`, `global.next_floor` every frame in `_process()` to trigger scene changes.
**Why it's wrong:** Burning CPU every frame for rare state transitions; race condition if flag is set and cleared in the same frame; hard to trace scene change triggers.
**Do this instead:** Use Godot signals. Emit `global.scene_transition_requested` from the trigger site; connect in the scene's `_ready()`.

### Duck-typed method tag for entity identity

**What happens:** `func player(): pass` / `func enemy(): pass` in entity scripts; collision callbacks call `body.has_method("player")`.
**Why it's wrong:** Fragile — any node with a `player()` method matches; refactoring method names silently breaks all collision logic.
**Do this instead:** Use Godot groups. Query with `body.is_in_group("player")` instead of `has_method`.

### Duplicate puzzle logic

**What happens:** All 5 puzzle types are implemented separately in both `script/dungeon.gd` and `script/puzzle_test.gd` with near-identical code.
**Why it's wrong:** Bug fixes must be applied in two places. Files are already 500+ and 700+ lines respectively.
**Do this instead:** Extract puzzle logic to a shared `script/puzzle_system.gd` resource or autoload.

## Error Handling

**Strategy:** No explicit error handling. Operations assume success.

**Patterns:**
- `global.load_from_slot()` returns `bool` (false if file missing) — caller checks return value
- No error recovery for missing scenes or assets
- `_is_position_clear()` fallback: returns center of room if no clear position found after 80 attempts

## Cross-Cutting Concerns

**Logging:** None (no logging calls in game scripts; `addons/godot_ai/` provides dev-time logging via `game_logger.gd` but is not used by game code)
**Validation:** None. Input actions checked via `Input.is_action_pressed/just_pressed` directly.
**Authentication:** Not applicable (single-player local game).

---

*Architecture analysis: 2026-05-08*
