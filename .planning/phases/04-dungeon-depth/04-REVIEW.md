---
phase: 04-dungeon-depth
reviewed: 2026-05-18T22:40:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - script/dungeon.gd
  - script/lore_object.gd
  - script/dialogue_data.gd
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: fixed
fixed: 2026-05-18
prior_review: 2026-05-16T10:15:00Z
prior_fixes_confirmed:
  - CR-01: fixed (obstacles.append(Rect2) at dungeon.gd:1007)
  - WR-01: fixed (private field coupling removed; dialogue_manager.open() guards itself)
  - WR-02: fixed (return after _save_and_exit() at dungeon.gd:120)
  - WR-03: fixed (labels hidden before queue_free at dungeon.gd:462-465)
  - WR-04: fixed (thresholds 17/34/51/68/85 at dungeon.gd:365-376)
  - WR-05: fixed (obstacles.append(Rect2) in both spawn helpers at dungeon.gd:349,358)
---

# Phase 4: Code Review Report (Re-Review)

**Reviewed:** 2026-05-18T22:40:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Re-review pass following six fixes committed after 2026-05-16. All six prior findings are confirmed fixed and closed. Two new warnings and three info items remain, none of which were regressions introduced by the fixes — they are pre-existing gaps exposed by reading the full implementation in context of the new Phase 4 callers.

CR-01 (obstacles type mismatch) is confirmed fixed at `dungeon.gd:1007`. WR-02 (early return after `_save_and_exit`) is confirmed fixed at line 120. WR-01 (private `_panel` coupling in `lore_object.gd`) is correctly resolved: `dialogue_manager.open()` itself no-ops when `_panel.visible` is true (line 117 of `dialogue_manager.gd`), so removing the guard from `lore_object.gd` is safe and the fix is complete. WR-03 (labels hidden before `queue_free`) confirmed at lines 462-465. WR-04 (lore thresholds) confirmed at lines 365-376 with even 17-floor spacing. WR-05 (both NPC/lore spawn helpers register obstacles) confirmed at lines 349 and 358.

New findings: `_spawn_hidden_room` never registers its picked position into `obstacles`, making call-order a correctness dependency rather than an invariant. The `_pick_save_position` fallback returns a center point that is never validated against obstacles, and Phase 4 added two new callers that increase exposure to this latent defect.

---

## Warnings

### WR-01: `_spawn_hidden_room` never registers spawned position into `obstacles`

**File:** `script/dungeon.gd:378-415`

**Issue:** `_spawn_hidden_room` calls `_pick_hidden_room_position(obstacles)` to find a clear slot, then builds the `Area2D` secret wall, but never appends the occupied position back into `obstacles`. Every other Phase 4 spawn helper that can overlap with subsequent spawns registers its footprint: `_spawn_dungeon_dialogue_npc` at line 349, `_spawn_lore_object` at line 358, `_spawn_fetch_chest_if_needed` at line 1007, and `_add_exit_barrier` at line 530 all call `obstacles.append(Rect2(...))` after placing their node.

Currently `_spawn_hidden_room` is called last in `_ready()` (line 115), so nothing spawns after it and no overlap occurs in practice. But this is a silent ordering dependency — if any future code adds a spawn call after `_spawn_hidden_room`, or if `_spawn_hidden_room` is ever called a second time (e.g., a future "multiple hidden rooms" feature), secret walls will overlap other objects. The pattern already exists in every peer function; this one was just missed.

**Fix:**
```gdscript
func _spawn_hidden_room(floor_no: int, obstacles: Array) -> void:
    var pos := _pick_hidden_room_position(obstacles)
    if pos == Vector2.ZERO:
        return
    # Register footprint before building, consistent with all other spawn helpers
    obstacles.append(Rect2(pos - Vector2(TILE / 2, TILE / 2), Vector2(TILE, TILE)))
    var area := Area2D.new()
    area.position = pos
    # ... rest unchanged
```

---

### WR-02: `_pick_save_position` fallback returns unvalidated center — two new Phase 4 callers increase exposure

**File:** `script/dungeon.gd:592-603`

**Issue:** When 80 placement attempts fail, `_pick_save_position` returns `Vector2(room_w / 2, room_h / 2)` (line 603) without checking that point against `obstacles` or the room boundary. This pre-existed Phase 4, but Phase 4 added two new callers: `_spawn_dungeon_dialogue_npc` (line 348) and `_spawn_lore_object` (line 357) both call `_pick_save_position`. On densely-packed floors (high floor numbers where `_build_random_obstacles` places up to 25 obstacles), all three callers — save point, dialogue NPC, and lore object — could fall back to the same `(room_w/2, room_h/2)` center, stacking all three objects on a single tile. If that center point falls inside a wall obstacle the objects are unreachable or visually buried.

The 80-attempt loop makes the fallback rare, but "rare" is not "impossible" — on floor 100 with 25 obstacles and a small room, the probability is non-trivial.

**Fix:** Validate the fallback point, or return a sentinel and let callers skip the spawn:
```gdscript
func _pick_save_position(obstacles: Array) -> Vector2:
    for i in 80:
        var min_tx := 8
        var max_tx := maxi(min_tx + 1, room_w / TILE - 8)
        var min_ty := 4
        var max_ty := maxi(min_ty + 1, room_h / TILE - 12)
        var x := rng.randi_range(min_tx, max_tx) * TILE + TILE / 2
        var y := rng.randi_range(min_ty, max_ty) * TILE + TILE / 2
        var p := Vector2(x, y)
        if _is_position_clear(p, obstacles, 10):
            return p
    return Vector2.ZERO  # sentinel: callers check for ZERO and skip spawn

# In each caller:
func _spawn_dungeon_dialogue_npc(_floor_no: int, obstacles: Array) -> void:
    var pos := _pick_save_position(obstacles)
    if pos == Vector2.ZERO:
        return
    obstacles.append(Rect2(pos - Vector2(16, 16), Vector2(32, 32)))
    # ...

func _spawn_lore_object(floor_no: int, obstacles: Array) -> void:
    if not dialogue_data.DIALOGUES.has("lore_object"):
        return
    var pos := _pick_save_position(obstacles)
    if pos == Vector2.ZERO:
        return
    obstacles.append(Rect2(pos - Vector2(16, 16), Vector2(32, 32)))
    # ...
```

Note: `_build_save_point` also calls `_pick_save_position` and would need the same sentinel guard if this fix is applied.

---

## Info

### IN-01: `LORE_OBJECT_COLOR` constant defined but never referenced

**File:** `script/dungeon.gd:26`

**Issue:** `const LORE_OBJECT_COLOR := Color(0.55, 0.40, 0.20)` is declared at the top of `dungeon.gd` but is never used in that file. The identical literal `Color(0.55, 0.40, 0.20)` is hardcoded inside `lore_object.gd:14`. The constant is dead code in its declaring file and does not reach the file that needs it.

**Fix:** Either remove the constant from `dungeon.gd`, or wire it through: expose a `color` export var on `lore_object.gd` and assign `LORE_OBJECT_COLOR` when spawning in `_spawn_lore_object`.

---

### IN-02: `_spawn_lore_object` guards via internal `DIALOGUES` const rather than public API

**File:** `script/dungeon.gd:355`

**Issue:** `if not dialogue_data.DIALOGUES.has("lore_object")` accesses the `DIALOGUES` constant directly, coupling `dungeon.gd` to `dialogue_data`'s internal structure. The public API is `dialogue_data.get_dialogue_node(npc_id, node_id)` which returns `{}` on a miss. If `dialogue_data` is ever refactored to a different backing structure (database, resource file, etc.), this guard silently breaks without a compile-time error.

**Fix:**
```gdscript
func _spawn_lore_object(floor_no: int, obstacles: Array) -> void:
    if dialogue_data.get_dialogue_node("lore_object", "fragment_1").is_empty():
        return
    # ... rest unchanged
```

---

### IN-03: `dungeon_merchant` speaker name inconsistent across dialogue nodes

**File:** `script/dialogue_data.gd:181, 186, 192`

**Issue:** The `dungeon_merchant` NPC uses `"Merchant"` as the speaker name in the `greeting` (line 181) and `merchant_offer` (line 186) nodes, but `"Dungeon Merchant"` in `story_chain_step2` (line 192). The dialogue panel header will show a different name depending on which branch triggers, which reads as a different character speaking.

**Fix:** Standardize to `"Dungeon Merchant"` throughout the `dungeon_merchant` block to distinguish from the overworld shop NPC.

---

_Reviewed: 2026-05-18T22:40:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
