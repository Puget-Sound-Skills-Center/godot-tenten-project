# Phase 4: Dungeon Depth - Research

**Researched:** 2026-05-14
**Domain:** GDScript dungeon feature expansion — hidden rooms, boss floors, lore objects
**Confidence:** HIGH (all findings from direct codebase inspection; no external dependencies)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DNG-02 | Hidden rooms accessible via inspectable trigger; contains bonus treasure or lore | `_spawn_fetch_chest_if_needed()` pattern (Area2D + meta + body_entered/exited + E-press); insert after `_build_floor_exit()` in `_ready()` |
| DNG-03 | Every 25th floor is boss floor; tougher enemies; player must clear room to advance | `global.current_floor % 25 == 0` check in `_ready()`; enemy group "enemies" already exists; exit locked until group empty |
| DNG-04 | Lore objects inspectable; opens dialogue UI with story fragment | `dialogue_manager.open(npc_id, node_id)` already exists; add `"lore_object"` entry to `dialogue_data.DIALOGUES`; spawn via same Area2D proximity pattern |
</phase_requirements>

---

## Summary

Phase 4 adds three self-contained dungeon features, all implemented as modifications to `script/dungeon.gd` plus data entries in `script/dialogue_data.gd`. No new autoloads are required. Every pattern needed already exists in the codebase — hidden rooms reuse the fetch-chest Area2D/proximity/E-press pattern; boss floors reuse `_spawn_enemies()` with a floor-gated exit check; lore objects call `dialogue_manager.open()` exactly as dungeon NPCs do.

The scene-reload-per-floor architecture is not a risk for any of these features. Boss clear state (enemy count) is entirely runtime — it is read from `get_tree().get_nodes_in_group("enemies")`, which is rebuilt fresh each reload. Hidden rooms contain no persistent state (gold drops feed `global.money`; lore reads update nothing). Lore dialogue uses the existing dialogue lifecycle.

**Primary recommendation:** All three features are additions to `dungeon.gd._ready()` and new helper functions in `dungeon.gd`. `dialogue_data.gd` needs one new NPC ID block. No new files are required beyond optional lore data factoring.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hidden room generation | dungeon.gd (room builder) | — | Room layout is owned by dungeon scene; no cross-scene state |
| Hidden room treasure | dungeon.gd (gold pickup handler) | global (money add) | Gold is instant; same pattern as enemy money_drop |
| Boss floor detection | dungeon.gd `_ready()` | — | `global.current_floor` already available at scene start |
| Boss enemy spawning | dungeon.gd `_spawn_enemies()` | — | Existing function; boss path adds script mix and count override |
| Boss exit gate | dungeon.gd `_process()` / `_on_exit_body_entered()` | — | Exit entry point already exists; add enemies-alive check |
| Lore object spawn | dungeon.gd `_ready()` | — | Same pattern as fetch chest spawn |
| Lore content | dialogue_data.gd DIALOGUES const | — | All dialogue content lives here |
| Lore UI | dialogue_manager autoload | — | `open()` already handles pause, panel, advance |

---

## Architecture Analysis

### What Exists in dungeon.gd Relevant to Each Feature

**_ready() call chain (lines 76–100):**
```
_build_floor_background()
_build_outer_walls()
_build_random_obstacles()      → returns obstacles: Array[Rect2]
_setup_navigation(obstacles)
_spawn_player()
_spawn_enemies(floor_no, obstacles)
_spawn_dungeon_dialogue_npc(floor_no, obstacles)
_build_floor_exit(floor_no, obstacles)  → returns exit_pos: Vector2
_add_exit_barrier(exit_pos, obstacles)
[floor_no % 10 == 0] → _build_save_point(obstacles)
_build_hud(floor_no)
_spawn_fetch_chest_if_needed(obstacles)
[rng.randf() < 0.2] → _setup_puzzle(floor_no, obstacles, exit_pos)
```

**Enemy tracking:** Enemies are added to group `"enemies"` in `enemy_base._ready()` (line 23). `queue_free()` removes them from the group automatically. Live enemy count: `get_tree().get_nodes_in_group("enemies").size()`.

**Exit trigger:** `_on_exit_body_entered()` (line 379) — fires when player touches exit Area2D. Currently checks only `puzzle_active`. This is the sole exit gate.

**Fetch chest pattern (lines 785–835):** Area2D with CollisionShape2D + ColorRect visual + Label. `set_meta("player_near", false)`. body_entered/exited set the flag and toggle label visibility. `_process()` (lines 107–114) polls every child for `item_id` + `player_near` meta and consumes E-press. This is the canonical proximity-interact pattern.

**`_pick_save_position()`** (lines 410–421): General-purpose "find a clear position in the mid-room area" — avoids walls and obstacles. Reusable for any object placement.

**`_is_position_clear()`** (lines 235–246): Checks wall bounds, spawn zone (top-left corner), and obstacle rects. Does NOT check the exit zone or other placed objects.

**`dialogue_manager.open(npc_id, start_node)`** (dialogue_manager.gd line 111): Pauses tree, shows panel, renders node from `dialogue_data.DIALOGUES[npc_id][start_node]`. No-ops if panel already visible.

---

## Feature 1: Hidden Rooms (DNG-02)

### Recommended Approach

**Layout:** A visually distinct sub-region within the same room — not a separate scene, not a corridor. The dungeon scene has one flat 2D space; adding a walled-off alcove (a rectangular "pocket" bounded by `_make_wall()` calls) is fully consistent with the existing `_add_exit_barrier()` approach. A corridor would require Navigation rebake; an overlay conflicts with existing tiles.

**Trigger mechanism:** An inspectable wall tile — an Area2D placed adjacent to the alcove entrance with `set_meta("secret_wall", true)` and `set_meta("player_near", false)`. Player presses E while near it; the wall visual becomes transparent (ColorRect alpha → 0) and a gap opens. This reuses the `_process()` meta-polling loop verbatim. No pressure plate needed (more complex); no auto-enter (requires physics body removal and nav rebake).

**Visual hint:** The trigger tile's ColorRect uses a slightly warmer wall color — e.g., `Color(0.25, 0.18, 0.28)` vs standard wall `Color(0.18, 0.16, 0.22)` — subtle enough to reward attentive players. A short Label "?" over the tile makes it findable without being trivial. This costs zero additional nodes.

**Contents:** One gold pickup (`global.money += HIDDEN_ROOM_GOLD` on E-press) plus optionally one lore object (share the DNG-04 spawn). Gold amount: `50 + floor_no * 5` (scales with depth, always meaningful). No chest node needed — just apply gold directly on trigger activation, same pattern as item pickup in `_process()`.

**Spawn probability:** 30% per floor (`rng.randf() < 0.3`), triggered after `_setup_puzzle()` at end of `_ready()`.

**Insertion point:** New function `_spawn_hidden_room(floor_no, obstacles)` called at the end of `_ready()`:
```gdscript
if rng.randf() < 0.3:
    _spawn_hidden_room(floor_no, obstacles)
```

**Position:** Hidden room alcove placed in a fixed corner region (top-right quadrant) that does not overlap spawn zone (top-left) or exit zone (bottom-right). Walls built via `_make_wall()`. The entrance gap tile is a separate Area2D — NOT a StaticBody2D, so it does not block navigation.

**Conflict avoidance:**
- Alcove rect checked against `obstacles` array before placing; added to `obstacles` after.
- Entrance gap position checked with `_is_position_clear()`.
- Puzzle tiles use `_pick_puzzle_tile_position()` which already enforces `exit_pos` distance; hidden room is registered in `obstacles` before puzzle runs — so puzzle tiles will not overlap it.
- Enemy spawner uses `_is_position_clear()` against `obstacles` — same protection.

**`_process()` integration:** Extend the existing meta-polling loop to also check `"secret_wall"` meta (separate `elif` branch). This keeps all proximity-interact logic in one place.

### Implementation checklist
- `_spawn_hidden_room(floor_no: int, obstacles: Array) -> void` — new function
- `_on_secret_wall_activated(wall_area: Area2D, floor_no: int) -> void` — removes wall visual, awards gold, optionally spawns lore object
- Constants: `HIDDEN_ROOM_GOLD_BASE := 50`, `SECRET_WALL_COLOR := Color(0.25, 0.18, 0.28)`
- `_process()`: add `elif child.has_meta("secret_wall") and child.get_meta("player_near")` branch

---

## Feature 2: Boss Floors (DNG-03)

### Recommended Approach

**Detection:** `global.current_floor % 25 == 0 and global.current_floor > 0` check in `_ready()` — floors 25, 50, 75, 100. The `> 0` guard prevents floor 0 (unused) from triggering.

**Tougher enemy combination:** Use ALL four enemy scripts regardless of floor range, double the spawn count (capped at 30 by existing cap), and apply a 1.5× stat multiplier on top of the standard floor multiplier. This is the most readable approach given the existing `_pick_enemy_script()` function — add a `_pick_boss_enemy_script()` that always returns from the full set:
```gdscript
func _pick_boss_enemy_script() -> String:
    return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST, ENEMY_SCRIPT_TANK].pick_random()
```
And a boss-specific spawn call with `count = mini(count * 2, 30)` and `mult *= 1.5`.

**Exit gate — "player must clear room to advance":** The exit Area2D already exists. Add a `var boss_floor := false` flag and a `var boss_enemies_cleared := false` flag. In `_on_exit_body_entered()`, add:
```gdscript
if boss_floor and not boss_enemies_cleared:
    _update_boss_hud_label()
    return
```
In `_process()`, poll enemy group size when `boss_floor` is true:
```gdscript
if boss_floor and not boss_enemies_cleared:
    if get_tree().get_nodes_in_group("enemies").size() == 0:
        boss_enemies_cleared = true
        _unlock_boss_exit()
```
This is minimal polling: one group query per frame only on boss floors, and it stops once cleared.

**Why not track enemy count separately?** Enemies call `queue_free()` on death and are removed from the group automatically. Tracking a separate counter would require registering a death signal on each enemy — more coupling. Group size query is idiomatic Godot and is already used in `_on_pack_alerted()`.

**Exit visual feedback:** `_unlock_boss_exit()` recolors `floor_exit_visual` and changes `floor_exit_label.text` — same as `_unlock_exit()` for puzzles. Reuse that function or call it directly.

**HUD feedback — "this is a boss floor":** Add a `boss_floor_label: Label` to `_build_hud()`:
```gdscript
if floor_no % 25 == 0 and floor_no > 0:
    var blbl := Label.new()
    blbl.text = "BOSS FLOOR — Defeat all enemies to advance"
    blbl.position = Vector2(8, 56)
    blbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    canvas.add_child(blbl)
    boss_hud_label = blbl
```
The label updates to "Room cleared!" when `boss_enemies_cleared` becomes true.

**Scene reload safety:** `boss_floor` and `boss_enemies_cleared` are instance variables on dungeon.gd — they are initialized fresh every floor reload. No cross-scene state needed.

**Does not conflict with puzzles:** Boss floor skips `_setup_puzzle()` call — both systems gate the exit and would conflict. Add `if not boss_floor:` guard around the puzzle probability roll.

### Implementation checklist
- `var boss_floor := false` and `var boss_enemies_cleared := false` — instance vars
- `var boss_hud_label: Label = null` — instance var
- `_spawn_boss_enemies(floor_no: int, obstacles: Array) -> void` — new function
- `_pick_boss_enemy_script() -> String` — new function
- `_unlock_boss_exit() -> void` — reuses `_unlock_exit()` pattern
- `_on_exit_body_entered()` — add boss gate check
- `_process()` — add boss clear poll
- `_build_hud()` — add boss label when `floor_no % 25 == 0`
- `_ready()` — branch: `if boss_floor: _spawn_boss_enemies() else: _spawn_enemies()`; suppress puzzle on boss floors

---

## Feature 3: Lore Objects (DNG-04)

### Recommended Approach

**NPC ID:** Use a single shared ID `"lore_object"` in `dialogue_data.DIALOGUES`. Fragment selection is done by choosing a `start_node` string: `"fragment_1"` through `"fragment_6"`. The correct fragment is selected at spawn time based on floor range — no floor-range logic inside `dialogue_data.gd`.

**Fragment selection by floor range:**
```gdscript
func _pick_lore_node(floor_no: int) -> String:
    if floor_no < 20:    return "fragment_1"
    elif floor_no < 40:  return "fragment_2"
    elif floor_no < 60:  return "fragment_3"
    elif floor_no < 75:  return "fragment_4"
    elif floor_no < 90:  return "fragment_5"
    else:                return "fragment_6"
```
This gives world-building coherence (deeper floor = later lore) without randomness that could confuse story order. Six fragments cover the full 1–100 range at natural thresholds that align with the CAVE/RUINS/ABYSS theme boundaries.

**Why not random?** Random selection would show end-game lore on floor 2. Floor-range selection is deterministic and makes lore feel earned.

**Why one shared npc_id?** `dialogue_manager.open()` takes `(npc_id, start_node)` — the start_node disambiguates the fragment. One `"lore_object"` entry is cleaner than 6 fake NPC IDs. `dialogue_data.get_dialogue_node("lore_object", "fragment_1")` works with the existing lookup.

**Number of fragments:** 6. Covers all floor ranges, tells a coherent story arc (dungeon origin → escalating danger → final revelation).

**Dialogue lifecycle:** `dialogue_manager.open("lore_object", node)` pauses the tree, shows the panel, player presses E to advance, panel closes — identical to NPC interaction. No changes to `dialogue_manager.gd` required.

**Spawn trigger:** Area2D with `set_meta("lore_node", fragment_node_string)` and `set_meta("player_near", false)`. Player presses E when near. `_process()` polling loop handles it — third `elif` branch after item pickup and secret wall checks.

**Persistence after reading:** Lore object stays in the room (does not `queue_free()`). Player can re-read. The object disappearing would feel punishing; re-reading is fine since the dialogue content is static.

**Spawn probability:** Always spawned (one per floor) — lore is the core DNG-04 requirement, not optional. Call `_spawn_lore_object(floor_no, obstacles)` unconditionally from `_ready()`.

**dialogue_data.gd additions:**
```gdscript
"lore_object": {
    "fragment_1": {
        "speaker": "Ancient Inscription",
        "text": "These halls were carved by hands that sought to reach what lies beneath. They found it.",
        "next": "", "choices": []
    },
    "fragment_2": { ... },  # 5 more entries
}
```
Speaker label `"Ancient Inscription"` (or `"Worn Tablet"`, `"Stone Rune"`) — same for all 6 so the portrait placeholder color identifies the object type.

**Visual:** ColorRect `Color(0.55, 0.40, 0.20)` (warm amber — same as fetch chest but distinguishable by Label text `"LORE"`). Size 20×20. Label above reads `"[E] Inspect"` when player is near (hidden otherwise).

### Implementation checklist
- `_spawn_lore_object(floor_no: int, obstacles: Array) -> void` — new function
- `_pick_lore_node(floor_no: int) -> String` — new function
- `_process()` — add `elif child.has_meta("lore_node") and child.get_meta("player_near")` branch
- `dialogue_data.gd` — add `"lore_object"` block with `fragment_1` through `fragment_6`
- Constants: `LORE_OBJECT_COLOR := Color(0.55, 0.40, 0.20)`

---

## Integration Risks and Mitigations

### Risk 1: Boss floor + puzzle conflict — dual exit gate
**What:** Both puzzle system and boss clear system set `puzzle_active` / check enemy count to gate the exit. If both run simultaneously, `_on_exit_body_entered()` could be locked permanently.
**Mitigation:** Boss floors skip puzzle setup entirely. In `_ready()`:
```gdscript
if boss_floor:
    _spawn_boss_enemies(floor_no, obstacles)
else:
    _spawn_enemies(floor_no, obstacles)
    if rng.randf() < PUZZLE_PROBABILITY:
        _setup_puzzle(floor_no, obstacles, exit_pos)
```
The `else` branch ensures mutually exclusive execution. `puzzle_active` stays `false` on boss floors, so the existing puzzle check in `_on_exit_body_entered()` does not interfere.

### Risk 2: Hidden room alcove overlaps exit zone or spawn zone
**What:** `_is_position_clear()` checks `_spawn_zone()` (top-left 6×6 tile area) but not the exit zone (bottom-right). A hidden room placed near the exit corner would block or visually merge with the exit tile.
**Mitigation:** Place the hidden room alcove in the top-right quadrant: `x ∈ [room_w * 0.55, room_w - 7*TILE]`, `y ∈ [TILE*2, room_h * 0.45]`. This is the only quadrant not reserved by either zone. Add a check against `_exit_zone()` in `_spawn_hidden_room()`:
```gdscript
if alcove_rect.intersects(_exit_zone()) or alcove_rect.intersects(_spawn_zone()):
    return  # skip this floor
```

### Risk 3: `_process()` meta-polling loop grows unwieldy with 3 feature branches
**What:** The `_process()` loop currently iterates all children for fetch chest meta. Adding secret wall and lore object as `elif` branches inside the same loop keeps one scan but adds complexity.
**Mitigation:** Each branch is guarded by a distinct meta key (`"item_id"`, `"secret_wall"`, `"lore_node"`). Only one branch fires per frame per object. Add a `break` after each activation to short-circuit. The loop is already present; three `elif` clauses is acceptable complexity for this scope.

### Risk 4: Lore dialogue opens when dialogue panel already visible
**What:** If the player stands on a lore object while a dungeon NPC dialogue is open and presses E, `dialogue_manager.open()` no-ops (line 116: `if _panel.visible: return`). This is correct behavior — no action needed.
**Mitigation:** None required. `dialogue_manager.open()` already guards this. The lore object's `_process()` branch should also check `dialogue_manager._panel != null and dialogue_manager._panel.visible` before triggering — same guard as the fetch chest branch at line 109.

### Risk 5: Boss floor enemy count race — enemies die before boss_enemies_cleared check
**What:** If all boss enemies die before the player reaches the exit, `_process()` poll detects `size() == 0`, sets `boss_enemies_cleared = true`, and unlocks the exit — correct. No race condition; the poll runs every frame.
**Mitigation:** No issue. This is the intended flow.

### Risk 6: Floor 100 boss floor — `DUNGEON_MAX_FLOOR` handling
**What:** Floor 100 is `DUNGEON_MAX_FLOOR`. The exit on floor 100 already shows "FINAL" and routes to cliffside. If floor 100 is also a boss floor (100 % 25 == 0), the boss gate must also be cleared before the FINAL exit triggers.
**Mitigation:** The boss gate in `_on_exit_body_entered()` runs before the `global.next_floor = true` assignment, so it blocks both NEXT and FINAL. This is correct — the player must clear the boss to see the final floor exit. No special case needed.

---

## New File / Function Checklist

### Modified files

**`script/dungeon.gd`**
- Add constants: `HIDDEN_ROOM_GOLD_BASE`, `SECRET_WALL_COLOR`, `LORE_OBJECT_COLOR`, `BOSS_FLOOR_STAT_MULT`
- Add instance vars: `boss_floor`, `boss_enemies_cleared`, `boss_hud_label`
- Modify `_ready()`: add boss detection, branch spawn calls, call `_spawn_hidden_room()` and `_spawn_lore_object()`
- Modify `_build_hud()`: add boss floor label
- Modify `_on_exit_body_entered()`: add boss gate check
- Modify `_process()`: add boss clear poll + secret wall branch + lore object branch
- New: `_spawn_boss_enemies(floor_no, obstacles)`
- New: `_pick_boss_enemy_script() -> String`
- New: `_unlock_boss_exit()`
- New: `_spawn_hidden_room(floor_no, obstacles)`
- New: `_on_secret_wall_activated(wall_area, floor_no)`
- New: `_spawn_lore_object(floor_no, obstacles)`
- New: `_pick_lore_node(floor_no) -> String`

**`script/dialogue_data.gd`**
- Add `"lore_object"` key to `DIALOGUES` const with nodes `fragment_1` through `fragment_6`

### No new files required
No new autoloads, no new scenes, no new scripts. All three features live in the two files above.

---

## Common Pitfalls

### Pitfall 1: Enemy group size check timing
**What goes wrong:** Checking `get_nodes_in_group("enemies").size()` in `_ready()` before `_spawn_enemies()` returns zero — enemies are added by `add_child()` which is synchronous, so they ARE in the group by the time `_process()` first runs. Safe.
**How to avoid:** Poll only in `_process()`, never in `_ready()`.

### Pitfall 2: `_make_wall()` creates StaticBody2D — blocks navigation
**What goes wrong:** Hidden room alcove walls are built with `_make_wall()`, which creates StaticBody2D. Navigation is baked in `_setup_navigation()` which runs before the hidden room is built. If alcove walls are added after nav bake, enemies can pathfind through them.
**How to avoid:** Call `_spawn_hidden_room()` BEFORE `_setup_navigation()`, and add the alcove rects to `obstacles` so they are included in the nav bake. Reorder `_ready()` accordingly:
```gdscript
var obstacles := _build_random_obstacles(floor_no)
var hidden_room_rect := _maybe_reserve_hidden_room(floor_no)  # returns Rect2 or Rect2()
if hidden_room_rect != Rect2():
    obstacles.append(hidden_room_rect)
_setup_navigation(obstacles)
# ... then build walls and place objects using reserved rect
```

### Pitfall 3: `dialogue_manager.open()` called without matching DIALOGUES entry
**What goes wrong:** If `"lore_object"` key or `"fragment_N"` node is missing from `dialogue_data.DIALOGUES`, `get_dialogue_node()` returns `{}`, and `dialogue_manager._render_node()` calls `close()` immediately (fail-safe at line 146). Player sees panel flash and close.
**How to avoid:** Add all 6 fragment nodes to `dialogue_data.gd` before testing. Verify with `dialogue_data.DIALOGUES.has("lore_object")` in `_spawn_lore_object()` — if false, skip spawn rather than showing broken UI.

### Pitfall 4: `queue_free()` on boss enemies during `get_nodes_in_group()` iteration
**What goes wrong:** If `_process()` queries the group while an enemy is mid-`queue_free()`, Godot may include the dying node in the group results for one additional frame.
**How to avoid:** `queue_free()` defers removal to end-of-frame; `get_nodes_in_group()` in `_process()` runs at start-of-frame. The node is gone by next frame. The `size() == 0` check will be correct on the frame after the last death. This is standard Godot behavior — no workaround needed.

### Pitfall 5: Hidden room entrance area blocks player movement
**What goes wrong:** The secret wall trigger is an Area2D. If it has a CollisionShape2D set to layer 1 (physics), it will block the player's CharacterBody2D.
**How to avoid:** Set Area2D collision layer to 0 and mask to match player layer only — or use the existing tile pattern where `area.z_index = -1` and the shape only detects bodies, not blocks them. Area2D does not block CharacterBody2D by default in Godot 4. Confirm the CollisionShape2D is on the Area2D (detection only), not wrapped in a StaticBody2D.

---

## Code Examples

### Boss floor detection in `_ready()`
```gdscript
# [VERIFIED: dungeon.gd direct inspection]
boss_floor = (floor_no % 25 == 0 and floor_no > 0)
if boss_floor:
    _spawn_boss_enemies(floor_no, obstacles)
else:
    _spawn_enemies(floor_no, obstacles)
    if rng.randf() < PUZZLE_PROBABILITY:
        _setup_puzzle(floor_no, obstacles, exit_pos)
```

### Boss exit gate in `_on_exit_body_entered()`
```gdscript
# [VERIFIED: matches existing pattern in dungeon.gd line 379]
func _on_exit_body_entered(body: Node2D) -> void:
    if not body.has_method("player"):
        return
    if puzzle_active:
        return
    if boss_floor and not boss_enemies_cleared:
        if boss_hud_label:
            boss_hud_label.text = "BOSS FLOOR — Defeat all enemies to advance"
        return
    global.next_floor = true
```

### Boss clear poll in `_process()`
```gdscript
# [VERIFIED: group "enemies" confirmed in enemy_base.gd line 23]
if boss_floor and not boss_enemies_cleared:
    if get_tree().get_nodes_in_group("enemies").size() == 0:
        boss_enemies_cleared = true
        _unlock_boss_exit()
```

### Lore object spawn
```gdscript
# [VERIFIED: matches fetch chest pattern dungeon.gd lines 785–819]
func _spawn_lore_object(floor_no: int, obstacles: Array) -> void:
    var lore_node := _pick_lore_node(floor_no)
    if not dialogue_data.DIALOGUES.has("lore_object"):
        return
    var pos := _pick_save_position(obstacles)
    var area := Area2D.new()
    area.position = pos
    var shape_node := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 12.0
    shape_node.shape = circle
    area.add_child(shape_node)
    var visual := ColorRect.new()
    visual.color = LORE_OBJECT_COLOR
    visual.size = Vector2(20, 20)
    visual.position = Vector2(-10, -10)
    area.add_child(visual)
    var lbl := Label.new()
    lbl.text = "[E] Inspect"
    lbl.add_theme_font_size_override("font_size", 8)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    lbl.position = Vector2(-16, -24)
    lbl.visible = false
    area.add_child(lbl)
    area.set_meta("lore_node", lore_node)
    area.set_meta("player_near", false)
    area.set_meta("prompt_label", lbl)
    area.body_entered.connect(_on_lore_body_entered.bind(area))
    area.body_exited.connect(_on_lore_body_exited.bind(area))
    add_child(area)
```

### `_process()` extended polling loop structure
```gdscript
# [VERIFIED: extends existing loop at dungeon.gd lines 106–114]
for child in get_children():
    if child is Area2D and child.has_meta("item_id") and child.has_meta("player_near"):
        if bool(child.get_meta("player_near")) and Input.is_action_just_pressed("interact"):
            if dialogue_manager._panel != null and dialogue_manager._panel.visible:
                continue
            var iid: String = String(child.get_meta("item_id"))
            global.items[iid] = int(global.items.get(iid, 0)) + 1
            child.queue_free()
            break
    elif child is Area2D and child.has_meta("secret_wall") and child.has_meta("player_near"):
        if bool(child.get_meta("player_near")) and Input.is_action_just_pressed("interact"):
            if dialogue_manager._panel != null and dialogue_manager._panel.visible:
                continue
            _on_secret_wall_activated(child)
            break
    elif child is Area2D and child.has_meta("lore_node") and child.has_meta("player_near"):
        if bool(child.get_meta("player_near")) and Input.is_action_just_pressed("interact"):
            if dialogue_manager._panel != null and dialogue_manager._panel.visible:
                continue
            dialogue_manager.open("lore_object", String(child.get_meta("lore_node")))
            break
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Separate scene per room type | Single flat scene, walled sub-regions | No scene load needed; consistent with project pattern |
| Signal-based enemy death tracking | Group size poll in `_process()` | Simpler; no per-enemy signal registration; idiomatic Godot |
| Unique npc_id per lore fragment | Shared npc_id + per-fragment start_node | One DIALOGUES entry, 6 nodes; cleaner than 6 fake NPC IDs |

---

## Open Questions (RESOLVED)

1. **Hidden room — should it also contain a lore object?**
   - What we know: DNG-02 says "bonus treasure or lore"; DNG-04 spawns a lore object unconditionally per floor already.
   - What's unclear: Should the hidden room have its own exclusive lore object, or just gold?
   - **Recommendation:** Hidden room contains gold only on non-boss, non-lore floors. On floors where `_spawn_lore_object()` already placed an object in the main room, the hidden room adds a second gold pickup. This avoids two lore popups per floor. Planner can adjust if desired.

2. **Boss floor — should the boss HUD label disappear after clear?**
   - What we know: `_unlock_exit()` changes the exit color and label. `boss_hud_label` persists.
   - **Recommendation:** Update `boss_hud_label.text` to `"Room cleared! Proceed."` in `_unlock_boss_exit()`. Keeps the player informed without removing the label.

3. **Boss floor 25 — only BASE enemies are available at floor 25 (floor < 34 threshold in `_pick_enemy_script()`). Should boss floor override use all 4 types even at floor 25?**
   - **Recommendation:** Yes. Boss floors explicitly break the normal progression to signal "special floor." Showing a Tank enemy on floor 25 is a meaningful surprise. `_pick_boss_enemy_script()` always draws from all 4 scripts.

4. **Lore fragment 6 (floors 90–100) — should it hint at the end of the dungeon?**
   - **Recommendation:** Yes. Fragment 6 should reference the deepest point. Content is Claude's discretion (no user constraint); write it as a final revelation. Planner should author all 6 texts.

---

## Environment Availability

Step 2.6: SKIPPED — phase is pure GDScript code changes. No external tools, CLIs, runtimes, or services required beyond the Godot editor already in use.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — manual editor play-test only |
| Config file | none |
| Quick run command | Open Godot editor, F5, navigate to dungeon |
| Full suite command | Same — no automated runner |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DNG-02 | Hidden room appears; secret wall triggers; gold awarded | manual smoke | Run to floor with 30% chance; press E on hint tile | ❌ manual only |
| DNG-02 | Hidden room does not overlap exit zone or spawn zone | manual | Inspect room at various floors for layout conflicts | ❌ manual only |
| DNG-03 | Floor 25 spawns boss enemies (all 4 types visible) | manual smoke | Enter dungeon, use global.current_floor = 25 cheat or play to floor 25 | ❌ manual only |
| DNG-03 | Exit blocked until all enemies killed | manual | Reach exit on boss floor with enemies alive; verify no advance | ❌ manual only |
| DNG-03 | Exit unlocks after all enemies die | manual | Kill all enemies on boss floor; verify exit color changes and advance works | ❌ manual only |
| DNG-04 | Lore object appears every floor | manual smoke | Run 3 floors; verify amber rect present each floor | ❌ manual only |
| DNG-04 | E-press opens dialogue panel with lore text | manual | Approach lore object; press E; verify panel shows correct fragment | ❌ manual only |
| DNG-04 | Correct fragment shown for floor range | manual | Test floor 1, 25, 50, 75, 95; verify distinct texts | ❌ manual only |

### Wave 0 Gaps
None — no test infrastructure exists or is expected. All validation is manual play-test in the Godot editor. This matches Phase 3 precedent.

---

## Security Domain

Not applicable. This phase adds in-process GDScript dungeon generation features. No network, authentication, input parsing of external data, or cryptography involved.

---

## Sources

### Primary (HIGH confidence)
- `script/dungeon.gd` — direct inspection; all function signatures, line numbers, and patterns verified
- `script/global.gd` — direct inspection; `current_floor`, group and save/load confirmed
- `script/enemy_base.gd` — direct inspection; `"enemies"` group, `queue_free()` on death confirmed
- `script/dialogue_manager.gd` — direct inspection; `open()` signature, guard conditions, lifecycle confirmed
- `script/dialogue_data.gd` — direct inspection; `DIALOGUES` const structure and `get_dialogue_node()` confirmed

### Secondary (MEDIUM confidence)
- None required — all findings from codebase inspection.

### Tertiary (LOW confidence)
- None.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `get_nodes_in_group("enemies")` returns zero within one frame of last enemy `queue_free()` | Boss Floors | Boss exit unlocks one frame late — negligible UX impact |
| A2 | Area2D CollisionShape2D does not block CharacterBody2D movement in Godot 4.6 | Hidden Rooms pitfall | Secret wall tile would block player; fix by confirming collision layer settings |

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — GDScript/Godot 4.6 only; no external libs
- Architecture: HIGH — all insertion points verified from source
- Pitfalls: HIGH — derived from actual code structure and Godot physics model

**Research date:** 2026-05-14
**Valid until:** Stable indefinitely — no external dependencies; valid until dungeon.gd is significantly restructured
