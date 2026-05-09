# Technology Stack — Research

**Project:** Dungeon Explorer RPG (Godot 4.6)
**Researched:** 2026-05-08
**Scope:** New systems: dialogue, quests, enemy AI variants, dungeon visual theming
**Constraint:** GDScript only, no external dependencies, match existing patterns

---

## Dialogue System

### Recommendation: Custom JSON-driven DialogueManager (no addon)

**Do NOT use Dialogic 2.**

Dialogic is a full-featured visual novel/dialogue editor addon. It introduces:
- A separate timeline editor, its own scene nodes (`DialogicNode_DialogText`, etc.), its own autoload (`Dialogic`)
- Non-trivial upgrade path when addon versions change
- Requires `.dtl` timeline assets or JSON with Dialogic-specific schema
- Overkill for a dungeon RPG with 2–3 NPCs

This project has zero external deps. Adding Dialogic means owning the addon's bugs and API surface forever.

**Do NOT use Godot's built-in DialogueLabel** alone — it handles text animation (BBCode, typewriter effect) but has no branching logic. It is a component, not a system.

**Use instead: Custom `dialogue_manager.gd` autoload + JSON data files.**

Pattern (verified Godot 4.x built-ins):
- Dialogue data as `.json` files under `res://data/dialogue/` — one file per NPC
- `dialogue_manager.gd` added as autoload; loads JSON via `FileAccess.open()` + `JSON.parse_string()`
- UI panel built in GDScript (matches existing pattern — all UI built in code, no `.tscn` Control nodes)
- Uses `RichTextLabel` with BBCode enabled for typewriter effect via `visible_characters` tween
- Branching: array of choice dicts, rendered as `Button` nodes added dynamically
- Quest trigger hooks: dialogue nodes carry `"action": "start_quest"` / `"action": "complete_quest"` fields; `dialogue_manager` fires signal `dialogue_action(action_name, args)` for quest system to receive

**JSON schema (minimal, opinionated):**
```json
{
  "npc_id": "elder_mira",
  "nodes": {
    "start": {
      "speaker": "Elder Mira",
      "text": "The dungeon grows darker below floor 20.",
      "next": "quest_offer"
    },
    "quest_offer": {
      "speaker": "Elder Mira",
      "text": "Will you investigate?",
      "choices": [
        { "label": "I'll do it.", "next": "accept", "action": "start_quest", "quest_id": "mira_floor20" },
        { "label": "Not now.", "next": "end" }
      ]
    }
  }
}
```

**Why JSON over Godot Resources (.tres):**
- `.tres` resource files require the class to be registered (`class_name DialogueNode extends Resource`) — works, but then saves binary or text resource that is harder to hand-edit and diff
- JSON is plain text, easily authored/edited by non-programmer, no Godot editor required, better for content iteration
- `FileAccess` + `JSON.parse_string()` is stable Godot 4.x API (HIGH confidence)

**Godot 4.x built-ins used:**
| Built-in | Purpose |
|----------|---------|
| `FileAccess.open(path, FileAccess.READ)` | Load JSON files |
| `JSON.parse_string(text)` | Parse dialogue data |
| `RichTextLabel` | Rendered dialogue text with BBCode |
| `Tween` + `visible_characters` | Typewriter effect |
| `Button` nodes (added/removed dynamically) | Choice rendering |
| Autoload singleton | `dialogue_manager` accessible everywhere |

**Confidence: HIGH** — all built-ins verified against Godot 4.x documentation.

---

## Quest System

### Recommendation: `quest_manager.gd` autoload + dictionary-based state in `global.gd`

**Do NOT use a quest addon.** None in the Godot asset library are Godot 4-native, actively maintained, and dependency-free simultaneously. Building custom is 150–200 lines and fits existing patterns exactly.

**Pattern:**

Quest definitions as `.json` or inline GDScript `const` dictionaries in `quest_manager.gd`. Quest runtime state (active, completed, objectives progress) stored as a `Dictionary` in `global.gd` so it persists through `save_to_slot()` / `load_from_slot()`.

```gdscript
# global.gd additions
var quest_state: Dictionary = {}
# Shape: { "mira_floor20": { "status": "active", "objectives": { "reach_floor_20": false } } }
```

```gdscript
# quest_manager.gd (autoload)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal objective_updated(quest_id: String, objective_id: String)

func start_quest(quest_id: String) -> void:
    global.quest_state[quest_id] = { "status": "active", "objectives": _get_initial_objectives(quest_id) }
    quest_started.emit(quest_id)

func complete_objective(quest_id: String, objective_id: String) -> void:
    if global.quest_state.get(quest_id, {}).get("status") != "active":
        return
    global.quest_state[quest_id]["objectives"][objective_id] = true
    objective_updated.emit(quest_id, objective_id)
    _check_completion(quest_id)
```

**Quest types to implement:**
| Type | How triggered |
|------|--------------|
| Kill N enemies | `enemy.gd` emits signal on death → `quest_manager.complete_objective()` |
| Reach floor N | `dungeon.gd._ready()` checks floor → `quest_manager.complete_objective()` |
| Fetch item | Item pickup node calls `quest_manager.complete_objective()` |
| Story chain | Dialogue action `"complete_quest"` advances chain |

**Why signals (departure from flag-polling):**
Quest events are rare (not per-frame). Signals are the correct Godot 4.x mechanism for event-driven state changes. The existing flag-polling pattern was designed for scene transitions (which need per-frame checks before `change_scene_to_file()`). Quest objectives don't need that — they fire once per event. This is a deliberate, scoped improvement, not a full refactor.

**Save integration:** `global.quest_state` dict serializes cleanly to `ConfigFile` using `set_value("quests", "state", quest_state)`. Dict survives JSON round-trip.

**Confidence: HIGH** — standard Godot 4.x singleton + signal pattern.

---

## Enemy AI Variants

### Recommendation: Base class + subclass scripts, no behavior tree addon

**Do NOT use a behavior tree addon** (e.g., Beehave, LimboAI) for this scale. 4 enemy types with distinct movement patterns do not require a behavior tree framework. The overhead of learning a BT addon is not justified.

**Pattern: `enemy_base.gd` with virtual methods, subclasses per type.**

```gdscript
# script/enemy_base.gd
class_name EnemyBase
extends CharacterBody2D

var health: int
var speed: float
var nav_agent: NavigationAgent2D

func enemy(): pass  # duck-type tag (matches existing pattern)

func _ready() -> void:
    nav_agent = $NavigationAgent2D
    _setup()

func _setup() -> void:
    pass  # override in subclass

func _physics_process(delta: float) -> void:
    _update_behavior(delta)

func _update_behavior(delta: float) -> void:
    pass  # override in subclass — default: navigate to player

func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        _on_death()

func _on_death() -> void:
    quest_manager.complete_objective_by_tag("kill_enemy", { "type": get_enemy_type() })
    queue_free()

func get_enemy_type() -> String:
    return "base"
```

**Four enemy types:**

| Type | Script | Key behavior |
|------|--------|-------------|
| Melee Charger | `enemy_melee.gd` | High speed when within aggro range, stops at contact range |
| Ranged Archer | `enemy_ranged.gd` | Maintains distance, fires `Area2D` projectile on timer |
| Tank | `enemy_tank.gd` | Low speed, high HP, knockback immunity flag |
| Fast Scout | `enemy_scout.gd` | Full speed, small aggro radius, flees when low HP |

**Pack/alert behavior:**
- Use Godot groups: `add_to_group("enemy_pack_A")` per room
- When one enemy enters alert state, call `get_tree().get_nodes_in_group("enemy_pack_A")` and set `alerted = true` on each
- Group ID generated per-room in `dungeon.gd` (e.g., `"enemy_pack_" + str(room_index)`)
- Simple — no signals needed. One function call, one loop.

**Projectile pattern:**
- `Area2D` with `CollisionShape2D` + `MeshInstance2D` (or `ColorRect`) as visual
- `velocity` set on fire, moved in `_physics_process`
- `body_entered` checks `body.has_method("player")` (matches existing duck-type pattern)
- Pool by reusing freed nodes? Not needed at this scale — `queue_free()` is fine.

**NavigationAgent2D (existing pattern, extended):**
- All enemy types reuse the existing `NavigationAgent2D` for pathfinding — already baked in `dungeon.gd._setup_navigation()`
- Fast Scout: set `NavigationAgent2D.max_speed` higher at runtime
- Ranged Archer: target position set to `player.position + flee_offset` when player is too close

**Confidence: HIGH** — all Godot 4.x built-ins verified. Pattern consistent with existing codebase.

---

## Dungeon Visual Theming

### Recommendation: Floor-range TileMapLayer themes via TileSet resource swapping

**Godot 4.x TileMap → TileMapLayer (4.3+ migration):**
Godot 4.3 deprecated the single `TileMap` node in favor of `TileMapLayer` nodes (one per layer). Each `TileMapLayer` has a single `TileSet` resource. **This project must use `TileMapLayer` if targeting Godot 4.6.** (HIGH confidence — Godot 4.3 changelog confirms this.)

**Pattern: one `TileSet` resource per visual theme, swapped at floor generation.**

```gdscript
# dungeon.gd
const TILESETS = {
    "cave":    preload("res://tilesets/cave_tileset.tres"),
    "ruins":   preload("res://tilesets/ruins_tileset.tres"),
    "crystal": preload("res://tilesets/crystal_tileset.tres"),
}

func _get_theme_for_floor(floor: int) -> String:
    if floor <= 33:   return "cave"
    elif floor <= 66: return "ruins"
    else:             return "crystal"

func _build_floor_background() -> void:
    var theme_key = _get_theme_for_floor(global.current_floor)
    var tile_layer = TileMapLayer.new()
    tile_layer.tile_set = TILESETS[theme_key]
    add_child(tile_layer)
    # ... fill tiles
```

**Three thematic zones (floors 1–100):**
| Zone | Floors | Visual identity | Color palette suggestion |
|------|--------|----------------|--------------------------|
| Cave | 1–33 | Rough stone, torches, roots | Warm brown/grey |
| Ruins | 34–66 | Carved stone, broken pillars, green moss | Cold grey/green |
| Crystal | 67–100 | Glowing veins, dark purple walls | Purple/cyan |

**Existing `_build_floor_background()` + `_build_outer_walls()`:**
These currently draw `ColorRect` shapes (not tile-based). If the existing floor is purely `ColorRect`/`RenderingServer` drawn, the theming approach is:
- Keep existing `ColorRect` structure
- Change `color` values based on theme key
- Add `TileMapLayer` overlay for decorative tiles (cracks, details) without replacing the collision/navigation system

This avoids a full rewrite of the floor generator.

**Hidden rooms and secrets:**
- Hidden rooms = additional `Rect2` regions generated by `dungeon.gd` but not connected to main path initially
- Reveal mechanic: `Area2D` trigger in a wall section; on player proximity, `_reveal_secret_room()` removes blocking `StaticBody2D` wall segments
- Secret room contents: lore object (`Label` on a `Sprite2D`), bonus chest (`Area2D` with interact), or shortcut stairs
- Implementation: pure GDScript, no addon needed

**Lore objects:**
- `LoreObject` = `Area2D` with `CollisionShape2D` + `Sprite2D`
- `body_entered` → `dialogue_manager.show_lore(lore_id)` — reuses dialogue UI panel with no choices
- Lore text stored in `res://data/lore/floor_lore.json`, keyed by floor range

**Boss floors:**
- Every 10th floor (10, 20, 30...) OR floor 100
- Same dungeon scene, different generation flags: `is_boss_floor = true`
- Boss = single enemy instance of `EnemyBoss` (subclass of `EnemyBase`) with higher stats + phase behavior
- Visual distinction: darker background color, different ambient light color via `CanvasModulate`
- No new scene needed — `CanvasModulate.color` set in `_ready()` when `is_boss_floor`

**Confidence: MEDIUM-HIGH** — TileMapLayer API confirmed Godot 4.3+. ColorRect-based approach inferred from architecture doc (no tile assets confirmed in `art/`). Boss floor pattern is standard for this genre.

---

## Supporting Libraries

### What to add as autoloads:

| Autoload | File | Purpose |
|----------|------|---------|
| `dialogue_manager` | `script/dialogue_manager.gd` | Load/parse dialogue JSON, show dialogue UI, fire action signals |
| `quest_manager` | `script/quest_manager.gd` | Quest state machine, objective tracking, reward dispatch |

### Utility file:

Add `script/utils.gd` as autoload (flagged as tech debt in PROJECT.md). Expose:
- `func clamp_to_rect(pos: Vector2, rect: Rect2) -> Vector2`
- `func random_point_in_rect(rect: Rect2) -> Vector2` (replace duplicated logic in dungeon.gd)
- `func floor_to_theme(floor: int) -> String` (centralize theme lookup)

### Do NOT add:

| What | Why |
|------|-----|
| Dialogic addon | Overkill, external dep, mismatched architecture |
| GodotDialogue / Dialogue Manager addon | Same reasons; also requires `.dialogue` file format |
| Beehave / LimboAI behavior tree | 4 enemy types don't justify BT complexity |
| Inventory addon | Not in scope (no crafting, no item system yet) |
| Any Godot 3.x-targeting addon | Project is Godot 4.6; 3.x addons will not load |

---

## Godot 4.x Built-ins Confirmed For Use

| Built-in | Version confirmed | Use |
|----------|------------------|-----|
| `FileAccess` | 4.0+ | File I/O (replaces 3.x `File`) |
| `JSON.parse_string()` | 4.0+ | Parse JSON (replaces 3.x `JSON.parse()`) |
| `NavigationAgent2D` | 4.0+ | Enemy pathfinding (already in use) |
| `TileMapLayer` | 4.3+ | Per-layer tilemap (replaces `TileMap`) |
| `CanvasModulate` | 4.0+ | Per-scene color tint (boss atmosphere) |
| `RichTextLabel` | 4.0+ | BBCode dialogue rendering |
| `Tween` (scene-tree tween) | 4.0+ | Typewriter animation |
| `ConfigFile` | 4.0+ | Save/load (already in use) |
| `add_to_group()` / `get_nodes_in_group()` | 4.0+ | Enemy pack alerting |
| Signal `emit()` / `connect()` | 4.0+ | Quest event propagation |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Dialogue | Custom JSON + autoload | Dialogic 2 addon | External dep, wrong architecture fit, overkill for 2–3 NPCs |
| Dialogue | Custom JSON + autoload | `.tres` Resource files | Harder to diff/author, same runtime cost |
| Quest | Custom autoload + global dict | GodotQuest addon | No active Godot 4-native version confirmed |
| Enemy AI | Base class + subclass | Beehave BT addon | 4 types don't justify BT overhead |
| Enemy AI | Base class + subclass | State machine per enemy | More code than needed for this scale |
| Theming | TileSet swap per theme | Separate dungeon scenes per theme | Would require 3 duplicate dungeon.tscn files |
| Theming | TileSet swap per theme | Shader-based recolor | Adds shader complexity, pixel art may not need it |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Dialogue — JSON + FileAccess API | HIGH | Core Godot 4 API, stable since 4.0 |
| Dialogue — no addon recommendation | HIGH | Addon landscape verified against project constraints |
| Quest — signal + global dict pattern | HIGH | Standard Godot 4 pattern |
| Enemy AI — base class inheritance | HIGH | Standard GDScript pattern |
| TileMapLayer (Godot 4.3+) | HIGH | Confirmed in Godot 4.3 release notes |
| ColorRect-based floor (existing) | MEDIUM | Inferred from architecture doc; actual floor builder not read |
| Boss floor CanvasModulate | MEDIUM | Pattern widely used; not verified against this specific project setup |
| Art asset availability per theme | LOW | `art/` directory not inspected; assumes pixel art tilesets must be created |

---

*Research complete: 2026-05-08*
