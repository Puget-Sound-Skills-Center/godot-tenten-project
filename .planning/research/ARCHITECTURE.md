# Architecture: New System Integration

**Project:** Dungeon Explorer RPG (Godot 4.6)
**Dimension:** Dialogue, Quests, Enemy Variants, Dungeon Theming
**Researched:** 2026-05-08
**Overall confidence:** HIGH — derived from direct source reading, not inference

---

## Existing Architecture Constraints (Non-Negotiable)

Before recommendations, the constraints that new systems must respect:

| Constraint | Source | Implication |
|------------|--------|-------------|
| All persistent state in `global.gd` | save_to_slot / load_from_slot hardcoded sections | New persistent state must be added to both save and load functions, and to `reset_for_new_game()` |
| No signals between scenes | ARCHITECTURE.md anti-patterns | New cross-scene coordination uses global flags + `_process()` polling, not signals |
| NPC identity via `has_method()` duck-typing | `enemy.gd`, `npc.gd` | New entity types add their own `func typename(): pass` tag method |
| Runtime NPC spawn (no .tscn) | `world.gd` `load("res://script/npc.gd").new()` | New NPCs follow same pattern; scene files optional |
| Dungeon floor = clean slate | `get_tree().reload_current_scene()` tears everything down | Nothing on the dungeon node survives floor transition; persistence must live in `global` |
| UI built procedurally in `_ready()` | All scenes | New UI panels are GDScript node construction, not .tscn scenes |

---

## System 1: Dialogue

### Where dialogue data lives

**Recommendation: Dictionary literals in a dedicated `script/dialogue_data.gd` autoload.**

Rationale:
- JSON requires FileAccess + JSON.parse() — adds 10-15 lines of boilerplate and a failure path per load. No payoff for a single-developer project.
- Godot Resource files (`.tres`) require custom Resource class definitions — more overhead, harder to author quickly, overkill for static text.
- Dictionary literals are native GDScript, zero parse overhead, collocated with the project, type-checkable at startup.
- Matches the project's existing "everything in code" philosophy (all UI built in GDScript, no .tscn for NPCs).

```gdscript
# script/dialogue_data.gd  (autoload as "dialogue_data")
extends Node

const TREES: Dictionary = {
    "npc_merchant": [
        {"id": "root", "text": "Welcome traveler. Need supplies?",
         "choices": [{"label": "Yes", "next": "shop_yes"}, {"label": "No", "next": "end"}]},
        {"id": "shop_yes", "text": "Then step right up.", "choices": [], "action": "open_shop"},
        {"id": "end",      "text": "Safe travels.", "choices": []},
    ],
    "npc_gatekeeper": [
        {"id": "root", "text": "The dungeon awaits.", "choices": [],
         "action": "enter_dungeon"},
    ],
}
```

**Node id = string key.** Dialogue engine walks the array by matching `"id"` field. `"action"` key triggers game-side callbacks (open_shop, enter_dungeon, give_quest).

### Dialogue UI component

New autoload: `script/dialogue_ui.gd` (autoload as `dialogue_ui`).

Responsibilities:
- Builds a modal panel (ColorRect + Label + buttons) procedurally in `_ready()`, hidden by default
- Exposes `func show_tree(tree_id: String, npc_ref: Node) -> void`
- On choice selected: advance to next node, call action if present, hide panel when `choices` is empty

Data flow:
```
NPC._process() detects E key press
  → dialogue_ui.show_tree("npc_merchant", self)
  → dialogue_ui reads dialogue_data.TREES["npc_merchant"]
  → renders panel over game
  → on action "open_shop": calls npc_ref.get_parent() or player_ref.open_shop()
  → on panel close: resumes normal _process() in NPC script
```

**Input blocking:** `dialogue_ui` sets `global.dialogue_active = true` while open. NPC `_process()` guards: `if global.dialogue_active: return`. Pause menu already blocks on ESC — `dialogue_ui` should also disable ESC during dialogue by checking `global.dialogue_active` in `pause_menu.gd._unhandled_input`.

### Component boundary

| What | Where | Communicates with |
|------|-------|-------------------|
| Dialogue tree data | `script/dialogue_data.gd` (autoload) | Read-only by `dialogue_ui` |
| Dialogue panel UI | `script/dialogue_ui.gd` (autoload) | Reads `dialogue_data`; sets `global.dialogue_active`; calls callbacks on NPC/player refs |
| NPC trigger | `script/npc.gd`, `script/dungeon_npc.gd` — add E-key branch | Calls `dialogue_ui.show_tree()` |

---

## System 2: Quest State

### Where quest state lives

**In `global.gd` — no alternative given save system constraints.**

The save/load functions are hardcoded ConfigFile sections. Any state outside `global` cannot be saved without rewriting the save system. Quest state must live in `global`.

```gdscript
# Additions to global.gd

# Quest state — serialized to save file
var active_quests: Dictionary = {}   # quest_id -> { "stage": int, "count": int }
var completed_quests: Array = []     # [quest_id, ...]

# Quest definitions — static, NOT serialized (rebuilt from data at load time)
# Defined in script/quest_data.gd instead (see below)
```

Quest definitions (what a quest requires, its stages, rewards) are static content — they do not need to be saved, only the player's progress does. Keep definitions in a separate `script/quest_data.gd` autoload (same rationale as dialogue_data: dictionary literals, no parse overhead).

```gdscript
# script/quest_data.gd  (autoload as "quest_data")
extends Node

const QUESTS: Dictionary = {
    "kill_slimes": {
        "title": "Slime Cleaner",
        "stages": [
            {"type": "kill", "target": "slime", "count": 5, "desc": "Kill 5 slimes"},
        ],
        "reward_gold": 500,
        "giver_npc": "npc_merchant",
    },
    "reach_floor_10": {
        "title": "Going Deeper",
        "stages": [
            {"type": "floor", "floor": 10, "desc": "Reach dungeon floor 10"},
        ],
        "reward_gold": 1000,
        "giver_npc": "npc_gatekeeper",
    },
}
```

### Quest engine

New autoload: `script/quest_manager.gd` (autoload as `quest_manager`).

Responsibilities:
- `func accept_quest(quest_id: String) -> void` — adds to `global.active_quests`
- `func notify_kill(enemy_type: String) -> void` — increments kill counts, checks completion
- `func notify_floor(floor_no: int) -> void` — checks floor-reach quests
- `func complete_quest(quest_id: String) -> void` — moves to `global.completed_quests`, awards gold
- `func is_active(quest_id: String) -> bool`
- `func is_complete(quest_id: String) -> bool`

Data flow for kill quest:
```
enemy.gd queue_free() path
  → quest_manager.notify_kill("slime")
  → quest_manager checks global.active_quests for kill-type quests targeting "slime"
  → increments global.active_quests["kill_slimes"]["count"]
  → if count >= target: quest_manager.complete_quest("kill_slimes")
    → global.money += reward_gold
    → global.completed_quests.append("kill_slimes")
```

Data flow for floor quest:
```
dungeon.gd._check_next_floor()
  → before reload_current_scene(): quest_manager.notify_floor(global.current_floor)
```

### Save system integration

Add to `global.gd.save_to_slot()`:
```gdscript
cfg.set_value("quests", "active", active_quests)
cfg.set_value("quests", "completed", completed_quests)
```

Add to `global.gd.load_from_slot()`:
```gdscript
active_quests = cfg.get_value("quests", "active", {})
completed_quests = cfg.get_value("quests", "completed", [])
```

Add to `global.gd.reset_for_new_game()`:
```gdscript
active_quests = {}
completed_quests = []
```

ConfigFile handles Dictionary and Array natively — no serialization needed.

### Component boundary

| What | Where | Communicates with |
|------|-------|-------------------|
| Quest definitions | `script/quest_data.gd` (autoload) | Read-only by `quest_manager` and `dialogue_ui` (to show accept prompts) |
| Quest progress state | `global.gd` — `active_quests`, `completed_quests` | Written by `quest_manager`; read by UI, NPC dialogue |
| Quest engine logic | `script/quest_manager.gd` (autoload) | Reads `quest_data`; mutates `global`; called by `enemy.gd`, `dungeon.gd` |
| Quest accept trigger | NPC dialogue `"action": "give_quest:kill_slimes"` | `dialogue_ui` parses action string, calls `quest_manager.accept_quest()` |

---

## System 3: Enemy Type Variants

### How variants fit the existing enemy pattern

The existing `enemy.gd` is a concrete script (not a base class) that hardcodes `speed = 40`, `health = 100`, `money_drop = 1000`. The scene `scenes/enemy.tscn` is the single enemy scene loaded by `dungeon.gd`.

**Recommendation: Base script + variant scripts extending it.**

```gdscript
# script/enemy_base.gd  — rename/refactor current enemy.gd to this
extends CharacterBody2D

var speed: float = 40.0
var health: float = 100.0
var max_health: float = 100.0
var money_drop: int = 100
var enemy_type: String = "melee"   # identity tag for quest_manager.notify_kill()

func enemy(): pass   # keep duck-type tag

# All shared logic: NavigationAgent2D, detection, damage, health bar
# Subclass-overrideable hooks:
func _on_player_spotted(_player: Node2D) -> void: pass   # override for special behavior
func _get_attack_damage() -> int: return global.get_attack_damage()
```

```gdscript
# script/enemy_fast.gd
extends "res://script/enemy_base.gd"

func _ready() -> void:
    speed = 90.0
    health = 50.0
    max_health = 50.0
    money_drop = 80
    enemy_type = "fast"
    super._ready()
```

```gdscript
# script/enemy_tank.gd
extends "res://script/enemy_base.gd"

func _ready() -> void:
    speed = 20.0
    health = 300.0
    max_health = 300.0
    money_drop = 300
    enemy_type = "tank"
    super._ready()
```

```gdscript
# script/enemy_ranged.gd
extends "res://script/enemy_base.gd"

var _projectile_timer: Timer
var attack_range: float = 150.0

func _ready() -> void:
    speed = 35.0
    health = 60.0
    max_health = 60.0
    money_drop = 120
    enemy_type = "ranged"
    super._ready()
    # add projectile timer as child
```

**Each variant reuses the existing `scenes/enemy.tscn` node structure** (CharacterBody2D + AnimatedSprite2D + detection_area + healthbar). The script is swapped — `dungeon.gd` loads the scene then calls `set_script()` before adding to tree, or loads variant scenes (`scenes/enemy_fast.tscn`, etc.) that share the same node layout but reference the variant script.

Simpler approach (no extra .tscn files): dungeon.gd instantiates `enemy.tscn` then sets the script:

```gdscript
# dungeon.gd _spawn_enemies() — revised
func _pick_enemy_script(floor_no: int) -> Script:
    var pool := ["res://script/enemy_base.gd"]
    if floor_no >= 5:  pool.append("res://script/enemy_fast.gd")
    if floor_no >= 10: pool.append("res://script/enemy_tank.gd")
    if floor_no >= 15: pool.append("res://script/enemy_ranged.gd")
    return load(pool[rng.randi() % pool.size()])

func _spawn_one_enemy(pos: Vector2, floor_no: int) -> void:
    var e = load(ENEMY_SCENE).instantiate()
    e.set_script(_pick_enemy_script(floor_no))
    e.global_position = pos
    add_child(e)
```

**Health bar fix is required** before multiple types work: `healthbar.max_value = max_health` must be set in `_ready()`, and `update_health()` must compare against `max_health` not hardcoded `100`.

**quest_manager.notify_kill()** receives `enemy_type` string from `enemy_base.gd` on queue_free:

```gdscript
# in enemy_base.gd deal_with_damage():
if health <= 0:
    global.money += money_drop
    quest_manager.notify_kill(enemy_type)
    self.queue_free()
```

### Pack/alert behavior

Add to `enemy_base.gd`:
```gdscript
signal player_spotted(player_pos: Vector2)

func _on_detection_area_body_entered(body) -> void:
    if body.has_method("player"):
        player = body
        player_chase = true
        player_spotted.emit(body.global_position)
```

In `dungeon.gd._spawn_enemies()`, after spawning all enemies, connect each enemy's `player_spotted` signal to a `_on_player_spotted` function that calls `set_alert()` on all live enemies. This is the one place signals are acceptable — it's intra-scene (all enemies are children of dungeon node), not cross-scene.

### Component boundary

| What | Where | Communicates with |
|------|-------|-------------------|
| Shared enemy behavior | `script/enemy_base.gd` | Reads `global`; calls `quest_manager.notify_kill()` on death |
| Variant stats/behavior | `script/enemy_fast.gd`, `enemy_tank.gd`, `enemy_ranged.gd` | Extend `enemy_base` |
| Spawn selection | `dungeon.gd._spawn_enemies()` | Reads `global.current_floor`; sets script on scene instance |
| Pack alert | `player_spotted` signal, connected in `dungeon.gd` | Intra-scene signal (same dungeon node), not cross-scene |

---

## System 4: Dungeon Floor Theming

### How theming hooks into dungeon.gd generation

The dungeon floor generation sequence in `dungeon.gd._ready()` is:

1. `_build_floor_background()` — sets `FLOOR_COLOR` (single constant)
2. `_build_outer_walls()` → `_make_wall()` — uses `WALL_COLOR`
3. `_build_random_obstacles()` — uses same `WALL_COLOR`
4. Exit uses `EXIT_COLOR` / `EXIT_UNLOCKED_COLOR`

All colors are module-level constants in `dungeon.gd`. Theming requires them to become variables that change per floor range.

**Recommendation: Theme dictionary in `script/dungeon_themes.gd` (autoload or static inner class).**

```gdscript
# script/dungeon_themes.gd  (autoload as "dungeon_themes")
extends Node

const THEMES: Dictionary = {
    "cave": {
        "floor_range": [1, 25],
        "floor_color":   Color(0.07, 0.06, 0.09),
        "wall_color":    Color(0.18, 0.16, 0.22),
        "accent_color":  Color(0.55, 0.25, 0.85),  # puzzle tiles
        "tileset_path":  "",   # future: swap TileMap tileset
        "label":         "Cave",
    },
    "ruins": {
        "floor_range": [26, 50],
        "floor_color":  Color(0.10, 0.09, 0.07),
        "wall_color":   Color(0.30, 0.25, 0.18),
        "accent_color": Color(0.85, 0.65, 0.20),
        "label":        "Ancient Ruins",
    },
    "depths": {
        "floor_range": [51, 75],
        "floor_color":  Color(0.05, 0.05, 0.12),
        "wall_color":   Color(0.15, 0.12, 0.28),
        "accent_color": Color(0.20, 0.80, 0.80),
        "label":        "The Depths",
    },
    "inferno": {
        "floor_range": [76, 100],
        "floor_color":  Color(0.12, 0.04, 0.02),
        "wall_color":   Color(0.35, 0.10, 0.05),
        "accent_color": Color(0.95, 0.40, 0.10),
        "label":        "Inferno",
    },
}

func get_theme(floor_no: int) -> Dictionary:
    for key in THEMES:
        var t = THEMES[key]
        if floor_no >= t["floor_range"][0] and floor_no <= t["floor_range"][1]:
            return t
    return THEMES["cave"]  # fallback
```

In `dungeon.gd._ready()`, replace the constant color references:

```gdscript
var _theme: Dictionary

func _ready() -> void:
    # ... existing floor_no clamping ...
    _theme = dungeon_themes.get_theme(floor_no)
    _build_floor_background()   # uses _theme.floor_color
    _build_outer_walls()        # uses _theme.wall_color
    # etc.
```

Then `_build_floor_background()` uses `_theme["floor_color"]` instead of `FLOOR_COLOR`. `_make_wall()` uses `_theme["wall_color"]`. Puzzle tile colors use `_theme["accent_color"]`.

**Hidden rooms:** Add `_build_hidden_room()` call in `_ready()` with low probability (10-15%). A hidden room is a sealed wall section that opens when a trigger condition is met (pressure plate, kill all enemies). Uses the same `_make_wall()` / Area2D pattern already in use. Add `hidden_rooms_found` counter to `global` for quest integration.

**Lore objects:** Spawned as runtime Node2D with Area2D (same pattern as NPC). On player interaction: show a dialogue_ui panel with lore text keyed from `dialogue_data.TREES["lore_floor_25"]` etc. No new pattern needed — reuses dialogue system.

**Boss floors:** `floor_no % 25 == 0` triggers `_build_boss_floor()`. Spawns a single enemy with boss stats (separate `script/enemy_boss.gd` extending `enemy_base`). Blocks exit until boss is dead — reuses the existing `puzzle_active` exit barrier pattern but driven by an `enemies_alive` counter.

### Component boundary

| What | Where | Communicates with |
|------|-------|-------------------|
| Theme definitions | `script/dungeon_themes.gd` (autoload) | Read-only by `dungeon.gd` |
| Theme application | `dungeon.gd._ready()` — replace color constants | Reads `dungeon_themes.get_theme(floor_no)` |
| Hidden room logic | `dungeon.gd._build_hidden_room()` | Uses existing wall/Area2D patterns |
| Lore objects | Runtime Node2D spawned in `dungeon.gd` | Calls `dialogue_ui.show_tree()` |
| Boss floor | `dungeon.gd._build_boss_floor()` | Spawns `enemy_boss.gd`; gates exit on `enemies_alive == 0` |

---

## Full Component Map (Post-Integration)

```
Autoloads (persistent, always-on)
├── global.gd          — game state, save/load, quest progress vars
├── pause_menu.gd      — ESC overlay (add: check global.dialogue_active)
├── dialogue_ui.gd     — NEW: modal dialogue panel, tree walker
├── dialogue_data.gd   — NEW: static dialogue tree dictionaries
├── quest_data.gd      — NEW: static quest definition dictionaries
├── quest_manager.gd   — NEW: quest accept/progress/complete logic
└── dungeon_themes.gd  — NEW: floor theme color dictionaries

Scene scripts (transient, per scene)
├── world.gd           — spawn NPC with dialogue trigger
├── cliff_side.gd      — spawn NPC with dialogue + quest trigger
├── dungeon.gd         — read theme, spawn typed enemies, lore objects
└── home_screen.gd     — unchanged

Entity scripts (instanced)
├── player.gd          — unchanged (dialogue_active flag already gates input)
├── enemy_base.gd      — NEW: refactored from enemy.gd; notifies quest_manager on death
├── enemy_fast.gd      — NEW: extends enemy_base
├── enemy_tank.gd      — NEW: extends enemy_base
├── enemy_ranged.gd    — NEW: extends enemy_base
├── enemy_boss.gd      — NEW: extends enemy_base, boss stats
├── npc.gd             — ADD: call dialogue_ui instead of directly calling open_shop
└── dungeon_npc.gd     — ADD: call dialogue_ui instead of setting enter_dungeon directly
```

---

## Data Flow Summary

### Dialogue trigger
```
Player presses E near NPC
  → npc.gd sets global.dialogue_active = true, calls dialogue_ui.show_tree(tree_id, self)
  → dialogue_ui renders panel, walks tree
  → on action "open_shop": calls player_ref.open_shop()
  → on action "give_quest:X": calls quest_manager.accept_quest("X")
  → on action "enter_dungeon": sets global.enter_dungeon = true
  → on close: sets global.dialogue_active = false
```

### Quest progress
```
Enemy dies → enemy_base notifies quest_manager.notify_kill(enemy_type)
Floor advances → dungeon.gd notifies quest_manager.notify_floor(floor_no)
Quest completes → quest_manager awards gold via global.money += reward
Quest state in global.active_quests / completed_quests → saved/loaded in ConfigFile
```

### Enemy type selection
```
dungeon.gd._ready() → floor_no determines eligible enemy script pool
_spawn_enemies() → instantiates enemy.tscn, sets variant script, positions in room
Enemy detects player → optionally emits player_spotted signal → other enemies alert
Enemy dies → global.money += drop, quest_manager.notify_kill(), queue_free()
```

### Floor theming
```
dungeon.gd._ready() → dungeon_themes.get_theme(floor_no) → _theme dict
_build_floor_background() → _theme["floor_color"]
_make_wall() → _theme["wall_color"]
floor_no % 25 == 0 → _build_boss_floor()
rng check → _build_hidden_room(), lore objects spawned as Node2D
```

---

## Build Order

Dependencies determine sequencing. Each step's output is required by the next.

| Order | System | Depends on | Enables |
|-------|--------|-----------|---------|
| 1 | `enemy_base.gd` refactor | nothing (replaces enemy.gd) | enemy variants, quest kill tracking |
| 2 | `dungeon_themes.gd` + apply in `dungeon.gd` | enemy_base done (floor generation stable) | themed floors, visual variety |
| 3 | Enemy variants (fast, tank, ranged) | enemy_base exists | enemy variety per floor |
| 4 | `dialogue_data.gd` + `dialogue_ui.gd` | nothing | NPC conversations, quest accept UI |
| 5 | `quest_data.gd` + `quest_manager.gd` | dialogue_ui (accept via action), enemy_base (notify kill) | quest accept, progress, complete |
| 6 | NPC dialogue wiring | dialogue_ui exists | replace direct global flag sets with dialogue flow |
| 7 | Quest save/load in `global.gd` | quest_manager exists, vars defined | persistence |
| 8 | Boss floors, hidden rooms, lore objects | theming + dialogue_ui + quest_manager all exist | late-game content |

**Critical path:** enemy_base → (themes || dialogue_ui) → enemy variants || quest_manager → boss/hidden rooms

---

## Decisions Locked by Architecture

| Decision | Rationale |
|----------|-----------|
| Dialogue data as GDScript Dictionary, not JSON/Resource | Zero parse overhead, matches project "everything in code" pattern, no authoring toolchain needed |
| Quest state in `global.gd`, definitions in `quest_data.gd` | Save system cannot serialize state outside global; definitions are static content, no persistence needed |
| Enemy variants via `set_script()` on shared scene, not separate .tscn per type | One scene to maintain; visual/collision config unchanged; script swap is clean GDScript |
| Theming via Dictionary lookup in `dungeon_themes.gd` autoload | Decouples content from generation logic; dungeon.gd stays as procedural engine |
| `dialogue_active` flag on `global` for input blocking | Follows existing flag-polling pattern; `pause_menu` can check it without architectural change |
| Intra-scene signals for pack/alert behavior | Enemy→Enemy communication is same-scene; this is the one appropriate signal use — no cross-scene state |

---

## Pitfalls to Avoid During Integration

| Integration Point | Risk | Guard |
|-------------------|------|-------|
| Adding quest vars to `global` | Forgetting to add to `reset_for_new_game()` causes quest state bleed between new games | Add reset immediately when adding the vars |
| `set_script()` on instantiated scene | Must call before `add_child()` — script `_ready()` fires on add_child, not on instantiate | Sequence: instantiate → set_script → set position → add_child |
| health bar fix | Variants with health != 100 break `update_health()` comparison | Fix `max_health` tracking in enemy_base before implementing any variant |
| `global.dialogue_active` blocking | If dialogue_ui crashes without clearing the flag, game input locks permanently | Always clear flag in a `finally`-equivalent (signal on panel `visibility_changed`) |
| Floor theming colors | Puzzle tile colors are also constants in dungeon.gd — must be migrated to theme dict too, or puzzle tiles will clash with new palette | Include `accent_color` in theme dict, used for puzzle tiles |

---

*Architecture analysis: 2026-05-08*
