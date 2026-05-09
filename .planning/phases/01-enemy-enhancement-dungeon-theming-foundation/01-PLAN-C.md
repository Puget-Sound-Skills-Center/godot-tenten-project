---
phase: "01-enemy-enhancement-dungeon-theming-foundation"
plan: "01-PLAN-C"
type: execute
wave: 3
depends_on:
  - "01-PLAN-B"
files_modified:
  - script/dungeon.gd
autonomous: true
requirements:
  - ENM-01
  - ENM-02
  - ENM-03
  - ENM-04
  - DNG-01

must_haves:
  truths:
    - "Dungeon floor 1-33 uses cave colors (dark floor, muted purple-gray walls, green exit)"
    - "Dungeon floor 34-66 uses ruins colors (warm brown walls, golden exit)"
    - "Dungeon floor 67+ uses abyss colors (near-black blue floor, dark purple walls, violet exit)"
    - "Floor 1 enemies have base stats; floor 50 enemies have ~2x base stats; floor 100 enemies have ~3x"
    - "Floors 1-9 spawn melee only; floors 10-33 add fast; floors 34-66 add ranged; floors 67+ add tank"
    - "NavMesh agent_radius updated to 10.0 to accommodate tank avoidance"
  artifacts:
    - path: "script/dungeon.gd"
      provides: "Theme constants, _get_dungeon_theme(), _pick_enemy_script(), _get_floor_multiplier(), updated _spawn_enemies(), updated NavMesh radius, _theme var used in all builders"
      contains: "THEME_CAVE"
  key_links:
    - from: "script/dungeon.gd _ready()"
      to: "_theme dict"
      via: "_theme = _get_dungeon_theme(floor_no) as first statement in _ready()"
      pattern: "_theme = _get_dungeon_theme"
    - from: "script/dungeon.gd _spawn_enemies()"
      to: "enemy_base/ranged/fast/tank scripts"
      via: "set_script(load(_pick_enemy_script(floor_no))) before add_child"
      pattern: "set_script"
    - from: "script/dungeon.gd _spawn_enemies()"
      to: "floor multiplier"
      via: "_get_floor_multiplier(floor_no) applied to max_health, speed, money_drop after set_script"
      pattern: "_get_floor_multiplier"
---

<objective>
Wire the three enemy variant scripts into dungeon.gd spawning with floor-range selection and stat scaling. Add three dungeon visual themes (cave/ruins/abyss) driven by floor number. Update NavMesh agent_radius to 10.0 for tank compatibility.

Purpose: Delivers ENM-01/02/03 in-game (variants now spawn), ENM-04 (stats scale), and DNG-01 (visual themes). This plan is a single-file surgery on dungeon.gd.
Output: dungeon.gd with theme system, variant spawning, stat scaling, and updated NavMesh.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-RESEARCH.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-PATTERNS.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-A-SUMMARY.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-B-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add dungeon theme system to dungeon.gd (DNG-01)</name>

  <read_first>
    - script/dungeon.gd (read full file — confirm: existing color consts at lines 9-21, _build_floor_background() location, _make_wall() location, EXIT_COLOR usage, _ready() structure, floor_no assignment timing)
  </read_first>

  <action>
Four changes to dungeon.gd for the theme system:

**1. Add theme constants and `_theme` var** — insert after the existing `EXIT_COLOR` constant block (after the last existing color const, before the first non-const line):
```gdscript
const THEME_CAVE := {
    "floor": Color(0.07, 0.06, 0.09),
    "wall":  Color(0.18, 0.16, 0.22),
    "exit":  Color(0.20, 0.85, 0.30),
    "accent": Color(0.35, 0.30, 0.55),
}
const THEME_RUINS := {
    "floor": Color(0.10, 0.08, 0.05),
    "wall":  Color(0.30, 0.22, 0.14),
    "exit":  Color(0.85, 0.75, 0.20),
    "accent": Color(0.55, 0.40, 0.20),
}
const THEME_ABYSS := {
    "floor": Color(0.02, 0.02, 0.08),
    "wall":  Color(0.08, 0.06, 0.20),
    "exit":  Color(0.60, 0.20, 0.90),
    "accent": Color(0.30, 0.10, 0.60),
}

var _theme: Dictionary
```

**2. Add `_get_dungeon_theme()` helper** — add as a new function (placement: near bottom of file, before any signal handlers):
```gdscript
func _get_dungeon_theme(floor_no: int) -> Dictionary:
    if floor_no >= 67:
        return THEME_ABYSS
    elif floor_no >= 34:
        return THEME_RUINS
    else:
        return THEME_CAVE
```

**3. Set `_theme` at the start of `_ready()`** — insert as the FIRST line of `_ready()`, before any other statement (floor_no must already be set from global at this point; confirm how floor_no is assigned in _ready() — if it's read from `global.current_floor`, add `_theme = _get_dungeon_theme(global.current_floor)` after that line):
```gdscript
_theme = _get_dungeon_theme(floor_no)
```
If `floor_no` is a local var assigned inside `_ready()`, place this line immediately after that assignment.

**4. Replace color constants with `_theme` dict access in all builder functions:**

In `_build_floor_background()`:
- Replace `FLOOR_COLOR` with `_theme.floor`

In `_make_wall()` (all call sites where `WALL_COLOR` is the argument or used directly):
- Replace `WALL_COLOR` with `_theme.wall`

In the exit Area2D construction (wherever `EXIT_COLOR` is used):
- Replace `EXIT_COLOR` with `_theme.exit`

For puzzle echo tiles (wherever `ECHO_TILE_COLOR` or any secondary accent color is used):
- Replace with `_theme.accent`
- If no echo tile color exists, leave unchanged — do not invent references

Do NOT remove the old `FLOOR_COLOR`, `WALL_COLOR`, `EXIT_COLOR` constants — leave them in place as they may be referenced elsewhere. The replacements only apply inside the builder functions.
  </action>

  <verify>
    <automated>grep -n "THEME_CAVE" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "_theme = _get_dungeon_theme" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "_theme.floor" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "_theme.wall" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "_theme.exit" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "func _get_dungeon_theme" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/dungeon.gd contains `const THEME_CAVE := {`
    - script/dungeon.gd contains `const THEME_RUINS := {`
    - script/dungeon.gd contains `const THEME_ABYSS := {`
    - script/dungeon.gd contains `var _theme: Dictionary`
    - script/dungeon.gd contains `func _get_dungeon_theme(floor_no: int) -> Dictionary:`
    - script/dungeon.gd contains `_theme = _get_dungeon_theme(` in `_ready()`
    - script/dungeon.gd contains `_theme.floor` (used in floor background builder)
    - script/dungeon.gd contains `_theme.wall` (used in wall builder)
    - script/dungeon.gd contains `_theme.exit` (used in exit area builder)
  </acceptance_criteria>

  <done>Theme constants, _theme var, _get_dungeon_theme() helper, and all color substitutions in builders complete.</done>
</task>

<task type="auto">
  <name>Task 2: Add variant spawning, stat scaling, and NavMesh update to dungeon.gd (ENM-01/02/03/04)</name>

  <read_first>
    - script/dungeon.gd lines 100-130 (confirm NavigationPolygon agent_radius line — expect ~line 123)
    - script/dungeon.gd lines 215-250 (confirm full _spawn_enemies() body — existing instantiate/add_child pattern)
  </read_first>

  <action>
Four changes to dungeon.gd:

**1. Add script path constants** — insert near the top of the file after existing `const` declarations (after PLAYER_SCENE or similar):
```gdscript
const ENEMY_SCRIPT_BASE   := "res://script/enemy_base.gd"
const ENEMY_SCRIPT_RANGED := "res://script/enemy_ranged.gd"
const ENEMY_SCRIPT_FAST   := "res://script/enemy_fast.gd"
const ENEMY_SCRIPT_TANK   := "res://script/enemy_tank.gd"
```

**2. Add helper functions** — add these two functions near `_get_dungeon_theme()`:
```gdscript
func _pick_enemy_script(floor_no: int) -> String:
    if floor_no < 10:
        return ENEMY_SCRIPT_BASE
    elif floor_no < 34:
        return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_FAST].pick_random()
    elif floor_no < 67:
        return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST].pick_random()
    else:
        return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST, ENEMY_SCRIPT_TANK].pick_random()

func _get_floor_multiplier(floor_no: int) -> float:
    return 1.0 + (floor_no - 1) / 99.0 * 2.0
```

**3. Update `_spawn_enemies()`** — find the enemy instantiation block (the `load(ENEMY_SCENE)` / `packed.instantiate()` / `add_child(enemy)` sequence). Replace the instantiate-and-add block with:
```gdscript
var packed: PackedScene = load(ENEMY_SCENE)
var enemy: Node2D = packed.instantiate()
enemy.set_script(load(_pick_enemy_script(floor_no)))
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.health = enemy.max_health
enemy.speed = enemy.speed * mult
enemy.money_drop = int(enemy.money_drop * mult)
enemy.position = pos
add_child(enemy)
```
The `set_script()` call MUST come before `add_child()` — this is critical. `_ready()` fires on `add_child`, so the variant's `_ready()` (which calls `super._ready()`) must be the active script when the node enters the tree.

The stat scaling lines (`enemy.max_health = ...`, etc.) MUST come between `set_script()` and `add_child()`. At this point the script is replaced but `_ready()` has not yet run — so setting `max_health` here means the variant's `_ready()` will see this value when it runs `health = max_health` in `super._ready()`.

Wait — this is a conflict: the variant's `_ready()` sets `max_health = 60` (for ranged) then calls `super._ready()` which sets `health = max_health`. If we set `enemy.max_health` BEFORE `add_child`, the variant's `_ready()` will overwrite it. 

**Correct order:** Apply scaling AFTER `add_child()`, then re-sync health:
```gdscript
var enemy: Node2D = packed.instantiate()
enemy.set_script(load(_pick_enemy_script(floor_no)))
enemy.position = pos
add_child(enemy)  # _ready() fires HERE — variant sets base stats, super sets health = max_health
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.health = enemy.max_health   # re-sync health to scaled max
enemy.speed = enemy.speed * mult
enemy.money_drop = int(enemy.money_drop * mult)
```
This way: variant `_ready()` sets type-specific base stats → `super._ready()` sets `health = max_health` → then we scale up. The re-sync `enemy.health = enemy.max_health` is mandatory after scaling.

**4. Update NavMesh agent_radius** — find the line `nav_poly.agent_radius = 5.0` (approximately line 123 in `_setup_navigation()`) and change to:
```gdscript
nav_poly.agent_radius = 10.0
```
This accommodates the tank enemy's avoidance radius of 10.0.
  </action>

  <verify>
    <automated>grep -n "ENEMY_SCRIPT_BASE" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "set_script" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "_get_floor_multiplier" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "_pick_enemy_script" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "nav_poly.agent_radius = 10.0" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
    <automated>grep -n "enemy.health = enemy.max_health" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/dungeon.gd contains `const ENEMY_SCRIPT_BASE   := "res://script/enemy_base.gd"`
    - script/dungeon.gd contains `const ENEMY_SCRIPT_RANGED := "res://script/enemy_ranged.gd"`
    - script/dungeon.gd contains `const ENEMY_SCRIPT_FAST   := "res://script/enemy_fast.gd"`
    - script/dungeon.gd contains `const ENEMY_SCRIPT_TANK   := "res://script/enemy_tank.gd"`
    - script/dungeon.gd contains `func _pick_enemy_script(floor_no: int) -> String:`
    - script/dungeon.gd contains `func _get_floor_multiplier(floor_no: int) -> float:`
    - script/dungeon.gd contains `enemy.set_script(load(_pick_enemy_script(floor_no)))`
    - script/dungeon.gd contains `enemy.health = enemy.max_health` after scaling (post-add_child re-sync)
    - script/dungeon.gd contains `nav_poly.agent_radius = 10.0` (not 5.0)
    - script/dungeon.gd contains `.pick_random()` in `_pick_enemy_script` for floors 10+ (random variant selection)
  </acceptance_criteria>

  <done>dungeon.gd updated: variant script selection by floor range, stat scaling with post-add_child re-sync, NavMesh agent_radius 10.0.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| dungeon.gd → variant scripts | load() by path string — path must exist at runtime |
| floor_no → multiplier | floor_no sourced from global.current_floor — assumed valid int ≥ 1 |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01C-01 | Denial of Service | _pick_enemy_script returns path to non-existent file | mitigate | All four ENEMY_SCRIPT_* const paths use files created in Plan A/B; Godot load() will log error and return null if missing — add_child with null script falls back to base behavior, not crash |
| T-01C-02 | Denial of Service | _theme not initialized before first _make_wall call | mitigate | `_theme = _get_dungeon_theme(floor_no)` is first line of _ready() after floor_no set; _make_wall is called later in _ready() — ordering guaranteed |
| T-01C-03 | Denial of Service | Nav agent_radius 10.0 blocks single-tile passages | accept | Dungeon rooms use 2+ tile widths for all traversable areas; 10px radius leaves ≥6px clearance in narrowest valid passage (2×16px = 32px - 2×10px = 12px clearance) |
| T-01C-04 | Elevation of Privilege | Stat scaling applied incorrectly if _ready() not yet fired | mitigate | Scaling applied AFTER add_child (so _ready() has run); re-sync health = max_health after scaling prevents health/max_health mismatch |
</threat_model>

<verification>
After all tasks complete:
1. Enter dungeon at floor_no = 1 (set global.current_floor = 1) — floor and walls use cave palette (dark purple-gray)
2. Set global.current_floor = 34 — floor and walls use ruins palette (warm brown)
3. Set global.current_floor = 67 — floor and walls use abyss palette (near-black blue)
4. At floor 67+, observe tank enemies (red-tinted, larger sprite) among spawned enemies
5. At floor 35, observe ranged enemies backing away from player and firing orange projectiles
6. `grep -c "set_script" script/dungeon.gd` returns ≥ 1
7. `grep "nav_poly.agent_radius" script/dungeon.gd` returns `= 10.0`
</verification>

<success_criteria>
- DNG-01: Three distinct color palettes active at floor 1, 34, and 67 — all ColorRect builders use _theme dict
- ENM-01/02/03: Variant scripts selected by _pick_enemy_script() and applied via set_script() before _ready()
- ENM-04: _get_floor_multiplier() scales max_health, speed, money_drop at spawn; health re-synced after scaling
- NavMesh: agent_radius = 10.0 to support tank avoidance
</success_criteria>

<output>
After completion, create `.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-C-SUMMARY.md`
</output>
