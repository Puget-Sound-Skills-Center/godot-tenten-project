# Phase 4: Dungeon Depth - Pattern Map

**Mapped:** 2026-05-14
**Files analyzed:** 6 new/modified components across 3 features
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `script/dungeon.gd` — `_spawn_hidden_room()` | utility (in dungeon) | event-driven | `dungeon.gd::_build_save_point()` lines 386–408 | exact |
| `script/dungeon.gd` — `_spawn_enemies()` boss variant | service (in dungeon) | CRUD | `dungeon.gd::_spawn_enemies()` lines 263–285 | exact (self-analog) |
| `script/dungeon.gd` — `_check_next_floor()` boss gate | middleware (in dungeon) | request-response | `dungeon.gd::_on_exit_body_entered()` lines 379–385 | exact (self-analog) |
| `script/dungeon.gd` — `_is_boss_floor()` | utility (in dungeon) | transform | `dungeon.gd::_get_dungeon_theme()` lines 358–364 | exact |
| `script/lore_object.gd` | component | request-response | `script/dungeon_dialogue_npc.gd` lines 1–65 | exact |
| `script/dialogue_data.gd` — lore entries | config | — | `dialogue_data.gd::dungeon_merchant` top-level key | exact |

---

## Pattern Assignments

### DNG-02: Hidden Room — `_spawn_hidden_room()` in `dungeon.gd`

**Analog:** `dungeon.gd::_build_save_point()` (lines 386–408) + `_spawn_fetch_chest_if_needed()` (lines 785–819)

**Why:** `_build_save_point` is the canonical "spawn an Area2D interactable at a random clear position" pattern. `_spawn_fetch_chest_if_needed` adds the proximity label + meta pattern for player-near detection.

**Insertion point:** After line 100 (`_spawn_fetch_chest_if_needed(obstacles)`), add:
```
if rng.randf() < HIDDEN_ROOM_PROBABILITY:
    _spawn_hidden_room(obstacles)
```

**Imports / constants to add** (after line 25, with other color constants):
```gdscript
const HIDDEN_ROOM_COLOR := Color(0.15, 0.10, 0.35)
const HIDDEN_ROOM_PROBABILITY := 0.35
const HIDDEN_TREASURE_GOLD := 50
```

**Core pattern — copy from `_build_save_point()` lines 386–408, modify:**
```gdscript
func _spawn_hidden_room(obstacles: Array) -> void:
    var pos := _pick_save_position(obstacles)   # reuse existing picker
    var area := Area2D.new()
    area.position = pos
    var shape_node := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(TILE, TILE)
    shape_node.shape = shape
    area.add_child(shape_node)
    var visual := ColorRect.new()
    visual.color = HIDDEN_ROOM_COLOR
    visual.position = Vector2(-TILE / 2.0, -TILE / 2.0)
    visual.size = Vector2(TILE, TILE)
    area.add_child(visual)
    var lbl := Label.new()
    lbl.text = "SECRET"
    lbl.position = Vector2(-TILE, -TILE - 6)
    lbl.add_theme_font_size_override("font_size", 6)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    area.add_child(lbl)
    area.body_entered.connect(_on_hidden_room_entered)
    add_child(area)
```

**Callback pattern — copy from `_on_save_body_entered()` lines 423–427:**
```gdscript
func _on_hidden_room_entered(body: Node2D) -> void:
    if not body.has_method("player"):
        return
    global.money += HIDDEN_TREASURE_GOLD
    # optional: spawn lore object or dialogue here
    # queue_free the area so it can only trigger once
```

**What to keep:** `_pick_save_position()` as-is — its 80-attempt loop already avoids spawn zone, walls, and obstacles.
**What to change:** Color, label text, callback action (grant gold / spawn lore instead of setting `save_point_active`). The Area2D must `queue_free()` itself after trigger (one-shot), unlike the save point which persists.

---

### DNG-03: Boss Floor — Enemy Spawn Variant + Exit Gate

#### 3a. Floor detection — `_is_boss_floor()` helper

**Analog:** `dungeon.gd::_get_dungeon_theme()` lines 358–364

```gdscript
# Analog (lines 358–364):
func _get_dungeon_theme(floor_no: int) -> Dictionary:
    if floor_no >= 67:
        return THEME_ABYSS
    elif floor_no >= 34:
        return THEME_RUINS
    else:
        return THEME_CAVE
```

**New function — add near line 358:**
```gdscript
func _is_boss_floor(floor_no: int) -> bool:
    return floor_no > 0 and floor_no % 25 == 0
```

**Insertion in `_ready()`** — after line 91 (`_spawn_enemies(floor_no, obstacles)`):
The call already exists; `_spawn_enemies` receives `floor_no`, so the boss branch goes inside that function.

#### 3b. Boss enemy spawn — inside `_spawn_enemies()`

**Analog:** `dungeon.gd::_spawn_enemies()` lines 263–285 + `_pick_enemy_script()` lines 366–374 + `_get_floor_multiplier()` lines 376–377

**Existing stat scaling pattern (lines 280–285) — copy and intensify:**
```gdscript
# Existing (lines 280–285):
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.speed = float(enemy.speed) * mult
enemy.money_drop = int(enemy.money_drop * mult)
enemy.health = enemy.max_health
```

**Boss modification — add a branch at the top of `_spawn_enemies()` after line 264:**
```gdscript
func _spawn_enemies(floor_no: int, obstacles: Array) -> void:
    if _is_boss_floor(floor_no):
        _spawn_boss_enemies(floor_no, obstacles)
        return
    # ... existing code unchanged ...
```

**New `_spawn_boss_enemies()` — self-analog of `_spawn_enemies()`, hard values:**
```gdscript
func _spawn_boss_enemies(floor_no: int, obstacles: Array) -> void:
    # Fixed count, always tank+ranged mix, 3x multiplier floor
    var count := rng.randi_range(3, 6)
    var packed: PackedScene = load(ENEMY_SCENE)
    var spawned := 0
    var attempts := 0
    while spawned < count and attempts < count * 30:
        attempts += 1
        var x := rng.randi_range(3, room_w / TILE - 3) * TILE
        var y := rng.randi_range(3, room_h / TILE - 3) * TILE
        var pos := Vector2(x, y)
        if not _is_position_clear(pos, obstacles, 14):
            continue
        var enemy: Node2D = packed.instantiate()
        # Boss floors: tank or ranged only
        var script_path := [ENEMY_SCRIPT_TANK, ENEMY_SCRIPT_RANGED].pick_random()
        enemy.set_script(load(script_path))
        enemy.position = pos
        add_child(enemy)
        var mult := _get_floor_multiplier(floor_no) * 1.5   # 1.5x on top of floor mult
        enemy.max_health = int(enemy.max_health * mult)
        enemy.speed = float(enemy.speed) * mult
        enemy.money_drop = int(enemy.money_drop * mult * 2)
        enemy.health = enemy.max_health
        enemy.add_to_group("boss_enemies")   # needed for clear detection
        spawned += 1
```

**What to keep:** `_is_position_clear()`, `_get_floor_multiplier()`, `load(ENEMY_SCENE)`, `set_script(load(...))` — all identical.
**What to change:** Fixed smaller count (3–6 elites vs. 1–30 normals), `add_to_group("boss_enemies")`, higher mult, restricted script pool.

#### 3c. Boss clear gate — block exit until all boss_enemies dead

**Analog:** `dungeon.gd::_on_exit_body_entered()` lines 379–385 + existing `puzzle_active` gate

```gdscript
# Existing gate pattern (lines 379–385):
func _on_exit_body_entered(body: Node2D) -> void:
    if not body.has_method("player"):
        return
    if puzzle_active:       # <-- existing gate
        return
    global.next_floor = true
```

**Add a parallel gate variable** (after line 73 `var floor_exit_label`):
```gdscript
var boss_floor_active := false
var boss_enemies_remaining := 0
```

**Extend `_on_exit_body_entered()`:**
```gdscript
func _on_exit_body_entered(body: Node2D) -> void:
    if not body.has_method("player"):
        return
    if puzzle_active:
        return
    if boss_floor_active and get_tree().get_nodes_in_group("boss_enemies").size() > 0:
        # Optional: flash HUD hint
        return
    global.next_floor = true
```

**In `_ready()`, after boss spawn:**
```gdscript
if _is_boss_floor(floor_no):
    boss_floor_active = true
    if floor_exit_visual:
        floor_exit_visual.color = Color(0.85, 0.20, 0.25)   # red = locked
```

**Boss cleared — update exit color.** Hook into `enemy_base.gd::deal_with_damage()` death path via group query in `_process()`, OR add a dedicated `_check_boss_clear()` called from `_process()`:
```gdscript
func _check_boss_clear() -> void:
    if not boss_floor_active:
        return
    if get_tree().get_nodes_in_group("boss_enemies").size() == 0:
        boss_floor_active = false
        if floor_exit_visual:
            floor_exit_visual.color = EXIT_UNLOCKED_COLOR
        if floor_exit_label:
            floor_exit_label.text = "OPEN"
```

**Call site in `_process()`** — add after `_check_next_floor()` at line 105:
```gdscript
func _process(_delta: float) -> void:
    if save_point_active and Input.is_action_just_pressed("interact"):
        _save_and_exit()
    _check_next_floor()
    _check_boss_clear()    # <-- add here
    # ... rest unchanged
```

**Risk:** `get_nodes_in_group("boss_enemies")` polls every frame. Acceptable for small counts (3–6 enemies). Alternative: decrement a counter in a signal, but group query matches existing project pattern (no signals between scenes).

---

### DNG-04: Lore Object — `script/lore_object.gd` (new file)

**Analog:** `script/dungeon_dialogue_npc.gd` lines 1–65 (exact structural match)

**What to keep identically:**
- `extends Node2D`
- `var player_nearby`, `var player_ref`, `var _prompt_label: Label`
- `_ready()` calling `_build_visual()` + `_build_interaction_area()`
- `_build_interaction_area()` lines 27–36 — CircleShape2D radius 20, body_entered/exited
- `_on_body_entered()` / `_on_body_exited()` lines 54–64 — duck-type `has_method("player")`
- `_process()` guard: `dialogue_manager._panel != null and _panel.visible` — lines 41–42

**What to change:**

1. `_build_visual()` — swap sprite texture to a lore-appropriate art asset (e.g., `res://art/objects/chest_02.png` or a stone tablet if one exists). Change `_prompt_label.text` from `"E: Talk"` to `"E: Inspect"`.

2. Add an exported/set variable for which lore entry to show:
```gdscript
var lore_id: String = "lore_floor_1"   # set by dungeon.gd before add_child
```

3. `_process()` interact block — replace the quest-state branch logic (lines 44–52) with a simple direct call:
```gdscript
func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        if dialogue_manager._panel != null and dialogue_manager._panel.visible:
            return
        dialogue_manager.open("lore", lore_id)
```

**Full simplified structure (copy dungeon_dialogue_npc.gd, apply above three changes).**

**Spawning from `dungeon.gd` — analog: `_spawn_dungeon_dialogue_npc()` lines 287–291:**
```gdscript
# Existing (lines 287–291):
func _spawn_dungeon_dialogue_npc(_floor_no: int, obstacles: Array) -> void:
    var pos := _pick_save_position(obstacles)
    var npc := load("res://script/dungeon_dialogue_npc.gd").new()
    npc.position = pos
    add_child(npc)
```

**New `_spawn_lore_object()` — identical structure:**
```gdscript
func _spawn_lore_object(floor_no: int, obstacles: Array) -> void:
    var pos := _pick_save_position(obstacles)
    var lore := load("res://script/lore_object.gd").new()
    lore.position = pos
    lore.lore_id = _pick_lore_id(floor_no)   # selects lore entry by floor range
    add_child(lore)

func _pick_lore_id(floor_no: int) -> String:
    if floor_no < 25:
        return "lore_caves_%d" % rng.randi_range(1, 3)
    elif floor_no < 50:
        return "lore_ruins_%d" % rng.randi_range(1, 3)
    else:
        return "lore_abyss_%d" % rng.randi_range(1, 3)
```

**Call site insertion in `_ready()`** — after line 92 (`_spawn_dungeon_dialogue_npc(floor_no, obstacles)`):
```gdscript
_spawn_lore_object(floor_no, obstacles)
```

---

### DNG-04 (data): Lore Entries in `script/dialogue_data.gd`

**Analog:** `dialogue_data.gd` top-level key `"dungeon_merchant"` (or `"elder"`) — same schema.

**Schema (from lines 13–20):**
```gdscript
const DIALOGUES := {
    "elder": { "greeting": { "speaker": ..., "text": ..., "next": ..., "choices": [] } },
    "dungeon_merchant": { ... },
    # ADD:
    "lore": {
        "lore_caves_1": {
            "speaker": "Ancient Inscription",
            "text": "The first delvers came seeking treasure. Most did not return.",
            "next": "",
            "choices": []
        },
        "lore_caves_2": { ... },
        "lore_caves_3": { ... },
        "lore_ruins_1": { ... },
        # etc.
    }
}
```

**Rules:**
- `speaker` = object name ("Ancient Inscription", "Crumbling Tablet", "Worn Journal")
- `next` = `""` (closes panel — lore is read-only, no branching)
- `choices` = `[]` always (no quest actions needed for lore)
- No `action` field needed

**Insertion point:** After the last top-level NPC key in `DIALOGUES`, before the closing `}` of the dict.

---

## Shared Patterns

### Duck-typed player identity check
**Source:** `script/enemy_base.gd` line 59, `script/dungeon_dialogue_npc.gd` line 55
**Apply to:** All new Area2D callbacks
```gdscript
if body.has_method("player"):
```

### Dialogue open guard (prevents double-trigger)
**Source:** `script/dungeon_dialogue_npc.gd` lines 41–42
**Apply to:** `lore_object.gd::_process()`
```gdscript
if dialogue_manager._panel != null and dialogue_manager._panel.visible:
    return
```

### Area2D interactable construction
**Source:** `dungeon.gd::_build_save_point()` lines 386–408
**Apply to:** `_spawn_hidden_room()`, `lore_object.gd::_build_interaction_area()`
```gdscript
var area := Area2D.new()
area.position = pos
var shape_node := CollisionShape2D.new()
var shape := RectangleShape2D.new()
shape.size = Vector2(TILE, TILE)
shape_node.shape = shape
area.add_child(shape_node)
```

### Position picker (random, collision-aware)
**Source:** `dungeon.gd::_pick_save_position()` lines 410–421
**Apply to:** `_spawn_hidden_room()`, `_spawn_lore_object()`
```gdscript
# Reuse _pick_save_position(obstacles) as-is — no changes needed.
```

### Enemy stat scaling
**Source:** `dungeon.gd` lines 280–285
**Apply to:** `_spawn_boss_enemies()`
```gdscript
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.speed = float(enemy.speed) * mult
enemy.money_drop = int(enemy.money_drop * mult)
enemy.health = enemy.max_health
```

### Exit gate pattern (block advance on condition)
**Source:** `dungeon.gd::_on_exit_body_entered()` lines 379–385, `puzzle_active` variable line 61
**Apply to:** `boss_floor_active` gate in `_on_exit_body_entered()`
```gdscript
if puzzle_active:
    return
# Mirror:
if boss_floor_active and get_tree().get_nodes_in_group("boss_enemies").size() > 0:
    return
```

### Script-loading NPC spawn
**Source:** `dungeon.gd::_spawn_dungeon_dialogue_npc()` lines 287–291
**Apply to:** `_spawn_lore_object()`
```gdscript
var npc := load("res://script/dungeon_dialogue_npc.gd").new()
npc.position = pos
add_child(npc)
```

---

## No Analog Found

No files are completely without analog. All Phase 4 features map directly to existing patterns.

| File | Note |
|------|------|
| `lore_object.gd` | Structurally identical to `dungeon_dialogue_npc.gd`; only `lore_id` var + simplified `_process` differ |
| Boss floor group tracking | `add_to_group()` + `get_nodes_in_group()` is a Godot built-in; no existing game code uses groups for this, but the pattern is trivial |

---

## Risk Notes for Planner

| Risk | Detail | Mitigation |
|------|--------|------------|
| `_pick_save_position` contention | Hidden room + lore object + save point + dialogue NPC all call it on the same floor | Each call gets its own position; 80-attempt loop handles crowding. On dense floors (high floor_no with many obstacles) positions may collapse to room center fallback. Acceptable. |
| Boss floor + puzzle conflict | `_ready()` can currently spawn both a puzzle AND boss enemies on the same floor if `rng.randf() < PUZZLE_PROBABILITY` | Add `if not _is_boss_floor(floor_no):` guard around the puzzle spawn at line 99–100 |
| `boss_floor_active` + `puzzle_active` both blocking exit | Both gates fire independently; player could be soft-locked if both are active | Above mitigation (no puzzle on boss floor) eliminates the conflict |
| `dialogue_data.gd` lore key count | 9 lore entries minimum (3 per theme × 3 themes) adds ~100 lines to the file | No architectural issue; file is already ~200+ lines, purely data |
| `lore_object.gd` `lore_id` must be set before `_ready()` | `_ready()` fires on `add_child()` — `lore_id` must be assigned before that line | Set `lore.lore_id = ...` before `add_child(lore)` in `_spawn_lore_object()` |

---

## Metadata

**Analog search scope:** `script/dungeon.gd`, `script/dungeon_dialogue_npc.gd`, `script/quest_manager.gd`, `script/enemy_base.gd`, `script/npc.gd`, `script/global.gd`, `script/dialogue_data.gd`
**Files scanned:** 7
**Pattern extraction date:** 2026-05-14
