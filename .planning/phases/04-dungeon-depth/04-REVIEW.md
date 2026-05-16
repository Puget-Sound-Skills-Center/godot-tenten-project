---
phase: 04-dungeon-depth
reviewed: 2026-05-16T10:15:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - script/lore_object.gd
  - script/dialogue_data.gd
  - script/dungeon.gd
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: fixed
fixed: 2026-05-16T10:18:00Z
---

# Phase 4: Code Review Report

**Reviewed:** 2026-05-16T10:15:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 4 adds boss floors, a hidden-room system, lore objects, and a dungeon-theme system. The implementation is structurally sound and consistent with project conventions. One critical bug was found: the hidden-room activation path in `_process()` fires the interact handler on the same frame as a lore-object or save-point interact (both scan `get_children()` in the same loop body with no mutual exclusion), and — more severely — the `_process()` loop that picks up `secret_wall` areas will also pick up the fetch-chest `Area2D` nodes because both share the `Area2D` + `has_meta("player_near")` pattern. A mismatched `obstacles.append(pos)` call appends a `Vector2` instead of a `Rect2`, breaking subsequent `_is_position_clear` calls. Five warnings cover: the lore-object's `_process()` dialogue-open guard reading a private field of `dialogue_manager` rather than using the public API; the `_pick_lore_node` floor thresholds skipping fragments for most of the 100-floor range; the secret-wall hint label visibility not being reset on `_on_secret_wall_activated`; and two same-frame multi-interact race conditions.

---

## Critical Issues

### CR-01: `obstacles.append(pos)` appends Vector2 instead of Rect2 — corrupts obstacle list

**File:** `script/dungeon.gd:998`

**Issue:** `_spawn_fetch_chest_if_needed` appends the raw `pos: Vector2` value into the `obstacles` array at line 998. Every other call site appends `Rect2` objects. Downstream consumers of `obstacles` — `_is_position_clear`, `_build_random_obstacles`, `_setup_navigation`, `_add_exit_barrier`, and every `_pick_*_position` helper — all call either `r.intersects(existing.grow(TILE))` or `pad.intersects(r)` on each element. Calling `.grow()` or `.intersects()` on a `Vector2` will cause a runtime type error on any floor where a fetch quest is active, crashing dungeon generation for every subsequent spawn call that receives the mutated array.

This was previously fixed for a similar bug (`a06204d`) where `Rect2` was required; the same mistake recurs here.

**Fix:**
```gdscript
# Replace line 998:
obstacles.append(Rect2(pos - Vector2(12, 12), Vector2(24, 24)))
```

---

## Warnings

### WR-01: `lore_object.gd` reads `dialogue_manager._panel` — private field coupling

**File:** `script/lore_object.gd:47`

**Issue:** `_process()` guards dialogue open with `dialogue_manager._panel != null and dialogue_manager._panel.visible`. This couples `lore_object.gd` to the internal `_panel` field of `dialogue_manager.gd`. The field is not documented as public. If `dialogue_manager` is refactored (e.g., panel renamed, or `_panel` made null during teardown), this silently stops working — the guard fails to an unhandled null dereference if `_panel` is null during the frame `dialogue_manager` is being freed, crashing the running game. The correct pattern, already used by `dungeon.gd:125` and `dungeon.gd:133`, is to check `_panel` existence before reading `.visible`, but the right fix is to use the already-public `dialogue_manager.open()` which itself no-ops when the panel is visible (line 117-118 of `dialogue_manager.gd`).

**Fix:**
```gdscript
# lore_object.gd _process(), replace lines 47-49:
func _process(_delta: float) -> void:
	if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
		dialogue_manager.open("lore_object", lore_id)
		# dialogue_manager.open() already no-ops if panel is visible (line 117-118)
```

### WR-02: `_process()` item-pickup loop can activate secret wall AND pick up item in same frame

**File:** `script/dungeon.gd:122-136`

**Issue:** The `_process()` loop iterates all children checking first for `item_id` areas, then for `secret_wall` areas. Both branches `break` after firing, but if the player stands on the intersection of a fetch-chest area and a secret-wall area, E-press on the same frame activates only whichever appears first in child order — not a crash, but the ordering is non-deterministic and both checks share the same `Input.is_action_just_pressed("interact")` query. More critically, fetch-chest areas carry `has_meta("player_near")` (set at lines 993-994) and the secret-wall branch at line 131 also checks `has_meta("player_near")` — but fetch-chest areas do NOT have `has_meta("secret_wall")`, so that branch is safe. However the item-pickup branch at line 123 checks `has_meta("item_id") and has_meta("player_near")` — it does NOT check `not has_meta("secret_wall")`. A secret-wall area that also somehow gained `item_id` meta would be consumed silently. This is not currently possible, but the structural pattern is fragile.

The deeper issue: `save_point_active` is polled at line 118 before the child loop. A player standing on both a save point and a secret wall will save-and-exit AND would trigger the child loop on the same frame, because `_save_and_exit()` calls `get_tree().change_scene_to_file()` which defers the scene change — the rest of `_process()` still executes on that frame. This can cause `_on_secret_wall_activated` to run (awarding gold) just before the scene tears down.

**Fix:** Gate the child-loop behind an early return if `_save_and_exit()` was called:
```gdscript
func _process(_delta: float) -> void:
	if save_point_active and Input.is_action_just_pressed("interact"):
		_save_and_exit()
		return   # <-- add this; prevents child loop on same frame
	_check_next_floor()
	_check_boss_clear()
	# ... rest of loop
```

### WR-03: Secret-wall hint label not hidden after `_on_secret_wall_activated` — dangling visible label

**File:** `script/dungeon.gd:453-457`

**Issue:** `_on_secret_wall_activated` calls `area.queue_free()` but does not first hide the hint label (`"hint_label"` meta) or prompt label (`"prompt_label"` meta). `queue_free()` defers freeing to end-of-frame. Between activation and frame end, both labels remain visible. If the player activates while standing inside the area, `_on_secret_wall_body_exited` never fires (the body-exited signal fires only when the physics body leaves, but `queue_free` removes the Area2D before the exit signal is sent), so both labels remain visible until the node is freed. In practice the frame gap is imperceptible, but if anything delays the free (e.g., deferred signal from physics), the labels persist visibly.

**Fix:**
```gdscript
func _on_secret_wall_activated(area: Area2D) -> void:
	var floor_no: int = int(area.get_meta("floor_no"))
	var gold := HIDDEN_ROOM_GOLD_BASE + floor_no * 5
	global.money += gold
	# Hide labels before freeing so they don't flash if free is deferred
	var hint_lbl: Label = area.get_meta("hint_label")
	var prompt_lbl: Label = area.get_meta("prompt_label")
	if hint_lbl:
		hint_lbl.visible = false
	if prompt_lbl:
		prompt_lbl.visible = false
	area.queue_free()
```

### WR-04: `_pick_lore_node` fragment coverage gap — floors 1-19 always show fragment_1, floors 90-100 show fragment_6

**File:** `script/dungeon.gd:361-373`

**Issue:** The function maps `floor_no < 20` to `fragment_1`. With `DUNGEON_MAX_FLOOR = 100`, floors 1 through 19 (19% of the game) always display `fragment_1`. There are 6 fragments covering a 100-floor range, so a linear mapping would give ~16-17 floors per fragment. The current thresholds (20, 40, 60, 75, 90) leave fragment_1 over-represented and fragments 3/4 sharing a narrow mid-range. This is a design defect — players who play the first 19 floors repeatedly (very common at game start) see only the first lore fragment regardless of how many lore objects they read.

Additionally, the function uses `floor_no` directly but `dungeon.gd:84-85` clamps `floor_no` to `[1, DUNGEON_MAX_FLOOR]` before calling most helpers. `_pick_lore_node` is called with the unclamped raw value from `_spawn_lore_object` (line 357 passes `floor_no` which is the already-clamped local from `_ready` line 84). This is safe but should be noted.

**Fix:** Redistribute thresholds for even coverage:
```gdscript
func _pick_lore_node(floor_no: int) -> String:
	if floor_no < 17:
		return "fragment_1"
	elif floor_no < 34:
		return "fragment_2"
	elif floor_no < 51:
		return "fragment_3"
	elif floor_no < 68:
		return "fragment_4"
	elif floor_no < 85:
		return "fragment_5"
	else:
		return "fragment_6"
```

### WR-05: `_spawn_lore_object` and `_spawn_dungeon_dialogue_npc` both call `_pick_save_position` — may return identical position

**File:** `script/dungeon.gd:346-359`

**Issue:** `_spawn_dungeon_dialogue_npc` (line 347) and `_spawn_lore_object` (line 355) both call `_pick_save_position(obstacles)`. `_pick_save_position` does not register its returned position back into `obstacles`, so both calls can independently land on the same tile. The NPC and lore object would overlap visually and their interaction areas would collide, causing both to receive the same body_entered events simultaneously. On small rooms (early floors) where `_is_position_clear` has fewer valid spots, this is more likely.

**Fix:** After computing each position, append a padding rect to `obstacles` before the next spawn call:
```gdscript
func _spawn_dungeon_dialogue_npc(_floor_no: int, obstacles: Array) -> void:
	var pos := _pick_save_position(obstacles)
	obstacles.append(Rect2(pos - Vector2(16, 16), Vector2(32, 32)))  # reserve slot
	var npc: Node2D = load("res://script/dungeon_dialogue_npc.gd").new()
	npc.position = pos
	add_child(npc)

func _spawn_lore_object(floor_no: int, obstacles: Array) -> void:
	if not dialogue_data.DIALOGUES.has("lore_object"):
		return
	var pos := _pick_save_position(obstacles)
	obstacles.append(Rect2(pos - Vector2(16, 16), Vector2(32, 32)))  # reserve slot
	var lore: Node2D = load("res://script/lore_object.gd").new()
	lore.lore_id = _pick_lore_node(floor_no)
	lore.position = pos
	add_child(lore)
```

---

## Info

### IN-01: `dialogue_data.gd` — `"dungeon_merchant"` speaker name inconsistency

**File:** `script/dialogue_data.gd:179,192`

**Issue:** The `dungeon_merchant` NPC uses `"Merchant"` as the speaker name in the `greeting` and `merchant_offer` nodes (lines 181, 186) but `"Dungeon Merchant"` in the `story_chain_step2` node (line 192). Players will see the speaker name change mid-conversation depending on which branch triggers. The name shown in the dialogue panel header will be inconsistent.

**Fix:** Standardize to one name throughout the `dungeon_merchant` block. Prefer `"Dungeon Merchant"` as it differentiates from the overworld shop NPC.

### IN-02: `LORE_OBJECT_COLOR` constant defined in `dungeon.gd` but never used there

**File:** `script/dungeon.gd:26`

**Issue:** `const LORE_OBJECT_COLOR := Color(0.55, 0.40, 0.20)` is declared at line 26 but is never referenced in `dungeon.gd`. The actual amber color `Color(0.55, 0.40, 0.20)` is hardcoded inside `lore_object.gd:14` as a literal. The constant serves no purpose as currently written.

**Fix:** Either reference `LORE_OBJECT_COLOR` from `dungeon.gd` when spawning the lore object (pass it to the script or expose the color as an exported var on `lore_object.gd`), or remove the unused constant.

### IN-03: `_spawn_lore_object` guards with `dialogue_data.DIALOGUES.has("lore_object")` — accessing private const

**File:** `script/dungeon.gd:353`

**Issue:** The guard `dialogue_data.DIALOGUES.has("lore_object")` directly accesses the `DIALOGUES` const from `dialogue_data`. The public API is `dialogue_data.get_dialogue_node(npc_id, node_id)` which returns `{}` on missing keys. Accessing the internal `DIALOGUES` constant couples `dungeon.gd` to the internal data structure. If `dialogue_data` is later refactored to use a different backing structure, this guard will silently break.

**Fix:**
```gdscript
func _spawn_lore_object(floor_no: int, obstacles: Array) -> void:
	# Use public API instead of accessing internal DIALOGUES const
	if dialogue_data.get_dialogue_node("lore_object", "fragment_1").is_empty():
		return
	# ... rest unchanged
```

---

_Reviewed: 2026-05-16T10:15:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
