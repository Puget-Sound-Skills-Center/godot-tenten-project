# Coding Conventions

**Analysis Date:** 2026-05-08

## Naming Patterns

**Files:**
- `snake_case.gd` for all script files: `player.gd`, `dungeon_npc.gd`, `pause_menu.gd`, `home_screen.gd`
- `snake_case.tscn` for scene files: `player.tscn`, `cliff_side.tscn`, `puzzle_test.tscn`
- Script files are co-located in `script/` directory; scenes in `scenes/` directory
- Script names mirror scene names exactly: `script/player.gd` ↔ `scenes/player.tscn`

**Functions:**
- Public/lifecycle functions: `snake_case` matching Godot built-ins — `_ready()`, `_process()`, `_physics_process()`
- Private helper functions: leading underscore prefix — `_build_ui()`, `_setup_hud()`, `_spawn_player()`, `_make_wall()`
- Signal handler functions: `_on_<node>_<signal>` — `_on_player_hitbox_body_entered()`, `_on_attack_cooldown_timeout()`, `_on_exit_body_entered()`
- "Marker" functions (duck-typing identity): bare name, `pass` body — `func player(): pass`, `func enemy(): pass`

**Variables:**
- `snake_case` for all variables: `player_chase`, `enemy_inattack_range`, `can_take_damage`
- Private node references: leading underscore — `_nav_agent`, `_hud_layer`, `_shop_layer`, `_dmg_btn`
- Boolean flags use descriptive names without `is_` prefix (inconsistent): `player_alive`, `shop_open`, `puzzle_active`
- Some booleans do use `is_`: `is_green` (tile meta), but not in variable declarations
- Local temporary variables: single-letter or short — `t`, `n`, `v`, `a`, `b`, `op`

**Constants:**
- `SCREAMING_SNAKE_CASE`: `MAX_UPGRADE_LEVEL`, `TILE`, `FLOOR_COLOR`, `PLAYER_SCENE`, `DUNGEON_MAX_FLOOR`
- Color constants grouped at file top with descriptive suffix `_COLOR`: `FLOOR_COLOR`, `WALL_COLOR`, `EXIT_COLOR`
- Scene paths as `const` strings: `const PLAYER_SCENE := "res://scenes/player.tscn"`

**Types:**
- No custom class names in project scripts (no `class_name` declarations in game scripts)
- Autoload singleton: `global` (lowercase), defined via `script/global.gd`

## Code Style

**Formatting:**
- Tabs for indentation (GDScript default)
- No explicit formatter config found; follows Godot editor defaults
- Opening braces inline (Godot style)
- Blank lines between function definitions

**Linting:**
- No external linter config (`.editorconfig`, `gdlint` config) detected
- Godot's built-in parser warnings are the only enforcement

**Type Hints:**
- Mixed usage: newer code uses explicit return types and typed params — `func _ready() -> void:`, `func _on_exit_body_entered(body: Node2D) -> void:`
- Older/simpler functions omit type hints — `func _on_player_hitbox_body_entered(body):`
- Variable declarations use `:=` walrus-style inference for locals in newer code: `var cfg := ConfigFile.new()`
- Top-level var declarations rarely typed explicitly

## Node References

**Shorthand `$` operator** used for direct child nodes known to be in the scene tree:
```gdscript
$AnimatedSprite2D.play("front_idle")   # script/player.gd:28
$attack_cooldown.start()               # script/player.gd:128
$healthbar                             # script/player.gd:164
$detection_area/CollisionShape2D.shape # script/enemy.gd:25
```

**Programmatic `get_tree()` queries** used when node is not a direct child:
```gdscript
get_tree().get_nodes_in_group("player")   # script/pause_menu.gd:167
get_tree().change_scene_to_file(...)      # script/world.gd:32
get_tree().reload_current_scene()         # script/dungeon.gd:87
```

**Stored references** used for dynamically spawned nodes:
```gdscript
var _nav_agent: NavigationAgent2D        # script/enemy.gd:13
var player_node: Node2D                  # script/dungeon.gd:31
var player_ref = null                    # script/npc.gd:3
```

**Rule:** Use `$NodeName` only for static scene-tree children. Use stored references or `get_tree()` for dynamically instantiated nodes.

## Export Variables

No `@export` variables used in any project game scripts. All configuration is hardcoded via `const` or set through the `global` autoload. Scene-to-script coupling is handled via group membership and `has_method()` duck-typing, not exported properties.

## Signal Patterns

**Godot built-in signals** connected in `_ready()` or `_build_*()` helper functions:
```gdscript
area.body_entered.connect(_on_body_entered)          # script/npc.gd:34
_dmg_btn.pressed.connect(_upgrade_damage)            # script/player.gd:247
area.body_entered.connect(_on_puzzle_tile_entered.bind(area))  # script/dungeon.gd:443
```

**No custom `signal` declarations** found in any game script. All inter-object communication uses:
1. Direct method calls via stored reference: `player_ref.open_shop()`
2. Global autoload state: `global.player_current_attack`, `global.next_floor`
3. Group-based discovery: `get_tree().get_nodes_in_group("player")`

**Bind pattern** for passing context to callbacks:
```gdscript
area.body_entered.connect(_on_puzzle_tile_entered.bind(area))
tween.tween_callback(_set_tile_color.bind(tile, ECHO_FLASH_COLOR))
btn.pressed.connect(_on_load_slot.bind(i + 1))
```

## Duck-Typing Identity Pattern

Player and enemy identification uses empty marker functions instead of `is` type checks or groups:
```gdscript
# script/player.gd
func player():
    pass

# script/enemy.gd
func enemy():
    pass

# Detection at call sites:
if body.has_method("player"):   # script/npc.gd:44
if body.has_method("enemy"):    # script/player.gd:115
```

This is the primary polymorphism mechanism throughout the codebase. Use `has_method("player")` or `has_method("enemy")` to identify node types — do NOT use `body is Player` or `body.get_class()`.

## Scene Connection Patterns

**Scenes load other scenes procedurally** — no `@export PackedScene` variables:
```gdscript
const PLAYER_SCENE := "res://scenes/player.tscn"
var packed: PackedScene = load(PLAYER_SCENE)
player_node = packed.instantiate()
add_child(player_node)
```

**Scene transitions** via `get_tree()`:
```gdscript
get_tree().change_scene_to_file("res://scenes/world.tscn")
get_tree().reload_current_scene()   # dungeon floor reload
```

**State passed between scenes** via the `global` autoload singleton — no direct scene references held across transitions.

## Error Handling

**No `try/catch` equivalent (no `push_error`/`assert` guards) in game logic.**

**Config file load uses return-value checks:**
```gdscript
if cfg.load(_slot_path(slot)) != OK:
    return false          # script/global.gd:92
```

**Guard clauses** used at function tops:
```gdscript
if not body.has_method("player"):
    return                             # script/dungeon.gd:305
if not global.next_floor:
    return                             # script/dungeon.gd:81
if dir == "none":
    return                             # script/player.gd:137
```

**Validity checks** before using node references:
```gdscript
if is_instance_valid(player):         # script/enemy.gd:31
if save_prompt_label:                 # script/dungeon.gd:352
if player_ref and player_ref.has_method("open_shop"):  # script/npc.gd:40
```

No `push_error()`, `push_warning()`, or `assert()` calls used anywhere in game scripts.

## Logging

No logging framework. No `print()` statements in any game script. Silent failures are the norm.

## Comments

Sparse inline comments. Section headers use `# --- Section Name ---` format:
```gdscript
# --- Shop (opened by NPC) ---
# --- HUD & Shop UI ---
# --- Build helpers ---
# --- Type: Order ---
```

No docstrings or function-level comments.

## Function Design

**Lifecycle split:** Large `_ready()` functions delegate to `_build_*()` and `_setup_*()` helpers:
```gdscript
func _ready() -> void:
    _build_floor_background()
    _build_outer_walls()
    _spawn_player()
    _spawn_enemies(floor_no, obstacles)
```

**UI construction in code:** All UI built procedurally in `_build_*()` / `_setup_*()` functions — no `.tscn` scene files for UI layouts (except home_screen and pause_menu which also build UI in code).

**`_process()` usage:** Kept thin — delegates immediately to named functions:
```gdscript
func _physics_process(delta):
    player_movement(delta)
    enemy_attack()
    attack()
    update_health()
    _update_hud()
```

## Module Design

**No barrel files / no `class_name`** in game scripts.

**Autoload as global state:** `global` (autoload name, maps to `script/global.gd`) acts as the single shared state store. All scripts access it by unqualified name `global.*`.

**One script per scene:** Each `.tscn` has exactly one `.gd` attached. Scripts live in `script/`, scenes in `scenes/`.

---

*Convention analysis: 2026-05-08*
