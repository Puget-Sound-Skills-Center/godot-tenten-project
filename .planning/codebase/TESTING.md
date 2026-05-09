# Testing Patterns

**Analysis Date:** 2026-05-08

## Test Framework

**Runner:** None detected.

No test framework (GUT, WAT, gdUnit4, or similar) is installed or configured. No `addons/gut/`, `addons/gdunit4/`, or equivalent directories exist. The `addons/` directory contains only `godot_ai` (an MCP/AI editor integration tool).

**Assertion Library:** None.

**Run Commands:** N/A — no automated test runner configured.

## Test File Organization

**Dedicated test scene exists:** `script/puzzle_test.gd` + `scenes/puzzle_test.tscn`

This is a **manual playtest scene**, not an automated test. It is a full Godot scene (`extends Node2D`) that spawns the player and all five puzzle types in a divided arena, allowing a developer to walk through each puzzle type manually and verify behavior.

```
script/
├── puzzle_test.gd    # Manual playtest scene for all puzzle types
scenes/
├── puzzle_test.tscn  # Scene file for above
```

No `*_test.gd` or `*_spec.gd` files with automated assertions exist.

## Test Structure

No automated test suite structure. The `puzzle_test.gd` scene is the only testing artifact.

**What `puzzle_test.gd` does:**
- Divides a large room (1280×800) into 6 zones (Order, Math, Trap, Echo, Switches, Reset)
- Spawns one instance of each puzzle type in its zone at a fixed floor level (`const TEST_FLOOR := 30`)
- Provides a Reset pad (press E) to tear down and rebuild all puzzles
- Player can walk through each puzzle manually to verify correct behavior
- Visual feedback via `Label` nodes updated in real time

**Location:** `D:/Unity/godot-tenten-project/script/puzzle_test.gd`
**Scene:** `D:/Unity/godot-tenten-project/scenes/puzzle_test.tscn`

## Mocking

Not applicable — no automated tests exist.

## Fixtures and Factories

Not applicable. The `puzzle_test.gd` scene uses the live `global` autoload and the real `player.tscn` scene instantiated at runtime.

## Coverage

**Requirements:** None enforced.

**Automated coverage:** None.

**Manual coverage:** Only puzzle mechanics (`dungeon.gd`) have a dedicated playtest scene. The following areas have no test coverage (manual or automated):

- Player movement and combat (`script/player.gd`)
- Enemy AI and navigation (`script/enemy.gd`)
- Save/load system (`script/global.gd` — `save_to_slot`, `load_from_slot`)
- Scene transitions (`script/world.gd`, `script/cliff_side.gd`)
- Shop upgrade system (`script/player.gd` — `_upgrade_damage`, etc.)
- NPC interaction (`script/npc.gd`)
- Pause menu (`script/pause_menu.gd`)
- Home screen (`script/home_screen.gd`)
- Dungeon floor generation (`script/dungeon.gd`)

## Test Types

**Unit Tests:** None.

**Integration Tests:** None.

**E2E Tests:** None automated. The `puzzle_test.tscn` scene serves as a manual E2E playtest for puzzle mechanics only.

## Testing Approach

The project uses **manual playtesting** as the sole verification strategy. The only formalized testing artifact is a dedicated playtest scene for the dungeon puzzle subsystem.

**To add automated tests:** GUT (Godot Unit Testing) is the standard framework for this engine version. Install via `addons/gut/`. Test files would conventionally be placed in `test/` at project root with naming pattern `test_*.gd`.

---

*Testing analysis: 2026-05-08*
