---
phase: 03-quest-system
reviewed: 2026-05-18T22:40:00-07:00
depth: standard
files_reviewed: 7
files_reviewed_list:
  - script/quest_data.gd
  - script/quest_manager.gd
  - script/quest_log.gd
  - script/blacksmith_npc.gd
  - script/world.gd
  - script/cliff_side.gd
  - script/dialogue_data.gd
findings:
  critical: 3
  warning: 5
  info: 3
  total: 11
status: fixed
fixed: 2026-05-18
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-18T22:40:00-07:00
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

The quest system is structurally sound — state machine transitions, reward dispatch,
and the fetch chest spawn guard are all correctly coded. However three blockers were
found: enemy deaths are never reported to `quest_manager` (the kill quest can never
complete), `complete_quest()` has no status guard so it pays out repeatedly on every
NPC visit after a quest is already `"complete"`, and the quest log's `_toggle()` can
unconditionally unpause the tree even when a dialogue was the entity that paused it,
producing a game-state desync. Five warnings cover the story chain advance being
triggered silently even when the quest is not accepted, the `blacksmith_npc.gd`
sprite misusing a chest asset, NPC position overlap in world.gd, the secret door
having a one-frame visual gap, and the fetch chest `ready_to_complete` transition
never being set. Three info items flag the hardcoded `"(step %d/3)"` string, a
missing `"dungeon_merchant"` NPC in the autoload list, and a silently swallowed
missing-action path in `dialogue_manager`.

---

## Critical Issues

### CR-01: Enemy deaths never call `quest_manager.on_enemy_killed()` — kill quest permanently stuck

**File:** `script/enemy.gd:73-75`

**Issue:** `deal_with_damge()` calls `self.queue_free()` on death with no call to
`quest_manager.on_enemy_killed()`. `quest_manager.on_enemy_killed()` is the only
path that advances kill-quest progress and sets status to `"ready_to_complete"`.
Because the hook is never called, `kill_melee_10` progress stays at 0 forever.
The quest can be accepted, tracked in the log, and never completed regardless of
how many enemies the player kills.

There is no indirect path: dungeon.gd does not iterate children and call the hook;
no signal is emitted on enemy death. The method exists in `quest_manager.gd` but
has zero callers.

**Fix:**
```gdscript
# script/enemy.gd  — inside deal_with_damge(), replacing the queue_free block
if health <= 0:
    global.money += money_drop
    var etype: String = "melee"   # or read from an exported var if enemy types diverge
    quest_manager.on_enemy_killed(etype)
    self.queue_free()
```

To support ranged enemies later, add `@export var enemy_type: String = "melee"` at
the top of `enemy.gd` and pass `enemy_type` instead of the literal.

---

### CR-02: `complete_quest()` has no completed-state guard — double-payout on every revisit

**File:** `script/quest_manager.gd:29-42`

**Issue:** `complete_quest()` checks only that the quest exists
(`global.quest_state.has(qid)`), then unconditionally pays out gold, adds the item,
sets the unlock, and sets status to `"complete"`. It does not reject the call when
status is already `"complete"`.

`dialogue_manager._on_choice_picked()` calls `complete_quest()` every time the
player picks the `"quest_complete"` action choice. Because `dialogue_manager.open()`
is re-enterable (it only guards against same-frame re-open, not same-quest-already-
complete), a player can re-open the NPC dialogue, see the completion node again
(blacksmith `_select_start_node()` returns `"kill_quest_complete"` while
`quest_ready()` is true, and `quest_ready()` remains true for status `"ready_to_complete"`
but NOT `"complete"` — however the NPC state flag `quest_accepted_kill_melee_10`
persists and `kill_quest_followup` is shown after first completion, so this is the
normal path). The real exposure is the Elder's `"reach_floor_complete"` and
`"fetch_quest_complete"` nodes: neither NPC has a post-completion routing guard in
`dialogue_data.gd`, so revisiting shows the same completion node and calling
`complete_quest()` again pays gold, adds items, and re-sets unlocks every time.

**Fix:**
```gdscript
func complete_quest(qid: String) -> bool:
    if not global.quest_state.has(qid):
        return false
    var q: Dictionary = global.quest_state[qid]
    # Guard: only pay out once
    if q.get("status", "") == "complete":
        return false
    var gold: int = int(q.get("reward_gold", 0))
    global.money += gold
    # ... rest unchanged
```

---

### CR-03: `quest_log._toggle()` unconditionally sets `get_tree().paused = false` — desync when dialogue owns the pause

**File:** `script/quest_log.gd:132-139`

**Issue:** `_toggle()` closes the overlay by setting `get_tree().paused = false`
directly. The existing guard in `_unhandled_input()` (line 127) blocks Tab from
*opening* the log while dialogue is visible, but it does not cover the case where:

1. Dialogue opens → pauses tree.
2. Dialogue auto-advances to a node that hides `_panel` before the player presses E
   (e.g., an internal state bug, or force_close from dungeon reload).
3. The tree is still paused but `dialogue_manager._panel.visible` is false.
4. Player presses Tab → log opens (guard passes), then presses Tab again → `_toggle()`
   sets `paused = false`, unpausing a tree that dialogue_manager still considers
   paused.

Additionally, `_toggle()` is callable from external code (e.g., `force_close()` is
public), and if called while a pause_menu pause is active, it will silently unpause
the game under the pause menu overlay.

The safer pattern — used by `dialogue_manager.open()` — is to check the pause-menu
ownership state before mutating `paused`.

**Fix:**
```gdscript
func _toggle() -> void:
    if _overlay.visible:
        _overlay.visible = false
        # Only release pause if WE set it (dialogue_manager and pause_menu
        # each own their own pause; only unpause if nothing else is pausing).
        if not (dialogue_manager._panel != null and dialogue_manager._panel.visible):
            if not (pause_menu._pause_panel != null and pause_menu._pause_panel.visible):
                get_tree().paused = false
    else:
        _refresh()
        _overlay.visible = true
        get_tree().paused = true
```

---

## Warnings

### WR-01: Fetch chest never sets quest status to `"ready_to_complete"` — `quest_ready()` falls through to item-count shortcut only

**File:** `script/dungeon.gd:124-131` (chest pickup in `_process`)

**Issue:** When the player picks up the fetch chest item, `dungeon.gd._process()` adds
the item to `global.items` and frees the chest Area2D. It does not call any
`quest_manager` method to mark the quest ready. The quest status stays `"active"`.

`quest_manager.quest_ready()` has a shortcut (lines 106-109) that returns `true` if
status is `"active"` and the player carries the item, so the NPC *will* show the
completion node. But `active_quest_count()` (lines 112-118) counts all `"active"` or
`"ready_to_complete"` entries — the fetch quest keeps occupying an active-quest slot
even after the item is collected, which is correct behaviour. The real problem is the
quest log objective string: `get_objective_string()` for a fetch quest with status
still `"active"` and item in inventory shows `"Return: ... (Got it!)"` — this is
correct. So gameplay works, but the state model is inconsistent: the quest is
effectively ready but its status field never reflects it. If any future code path
checks `status == "ready_to_complete"` directly (instead of through `quest_ready()`),
it will silently miss the fetch quest.

**Fix:** In `dungeon.gd._process()`, after adding the item to `global.items`, call:
```gdscript
# After: global.items[iid] = int(global.items.get(iid, 0)) + 1
for qid in global.quest_state.keys():
    var q: Dictionary = global.quest_state[qid]
    if q.get("type") == "fetch" and q.get("item_id", "") == iid and q.get("status") == "active":
        q["status"] = "ready_to_complete"
        break
```
Or add a `on_item_collected(item_id)` hook to `quest_manager.gd` following the
`on_enemy_killed` pattern.

---

### WR-02: `story_chain_advance` action fires even if story_chain quest was never accepted

**File:** `script/dialogue_data.gd:91` and `script/quest_manager.gd:70-77`

**Issue:** The `"story_chain_accepted"` dialogue node (elder, line 91) has a choice
with `"action": "story_chain_advance"`. `dialogue_manager._on_choice_picked()` calls
`quest_manager.advance_story_chain()` unconditionally when this action string is seen.

`advance_story_chain()` guards on `global.quest_state.has("story_chain")` but this
entry is created by `accept_quest("story_chain")` which fires on the *same* choice
(action `"quest_offer"` runs on the *previous* node `"story_chain_offer"`, not here).
The sequence for `"story_chain_accepted"` is: the player already accepted via
`story_chain_offer`, so `quest_state["story_chain"]` exists and step advances from 0
to 1 correctly.

However: if a player somehow arrives at `"story_chain_accepted"` node without a valid
quest entry (e.g., direct `dialogue_manager.open("elder", "story_chain_accepted")`
from a future code path, or a save-file with partial state), `advance_story_chain()`
silently does nothing — but the `step` value never increments, so step 1 at the
Blacksmith is never reachable. No error is surfaced. The action handler has no return
value and no way for the caller to know it was a no-op.

Additionally, there is no `story_chain_advance` action handler for step 2 at the
dungeon merchant — `"story_chain_step2"` uses `"quest_complete"` directly, which is
correct (it completes rather than advances). But step 1 at the blacksmith
(`"story_chain_step1"`, line 169) advances step from 1 to 2 via `story_chain_advance`.
After that, there is no dungeon NPC routing that checks step == 2 and opens
`"story_chain_step2"` — this routing gap is in `dungeon_npc.gd` / `dungeon.gd` and
is out of scope here, but is noted as a dependency risk.

**Fix:** Add a guard log (print) in `advance_story_chain()` when the quest does not
exist, to surface the silent no-op during development:
```gdscript
func advance_story_chain() -> void:
    if not global.quest_state.has("story_chain"):
        push_warning("advance_story_chain called but story_chain quest not in quest_state")
        return
```

---

### WR-03: `blacksmith_npc.gd` uses `chest_01.png` as its sprite — wrong asset, misleading identity

**File:** `script/blacksmith_npc.gd:17`

**Issue:** The Blacksmith NPC loads `"res://art/objects/chest_01.png"` (4-frame
spritesheet) as its visual. This is an object (chest) sprite, not a character sprite.
The asset file exists on disk, so there is no load-time crash. However:

1. The Blacksmith is visually indistinguishable from a treasure chest, creating player
   confusion about NPC vs. interactive object identity.
2. `sprite.hframes = 4` sets up 4 horizontal frames but `sprite.frame = 0` is the
   only frame shown — this is a static display using a chest spritesheet, which is
   not intentional NPC appearance.
3. When the fetch quest chest also appears in the dungeon (also visually a brown
   `ColorRect`), two different systems share near-identical visual language.

**Fix:** Replace with the correct character sprite (e.g., `art/characters/blacksmith.png`
if it exists, or a placeholder distinct from chest art). If no character art is
available yet, use a distinct colored `ColorRect` as a placeholder rather than
reusing an object asset:
```gdscript
# Temporary placeholder until art is ready
var placeholder := ColorRect.new()
placeholder.color = Color(0.6, 0.4, 0.2, 1.0)
placeholder.size = Vector2(16, 16)
placeholder.position = Vector2(-8, -16)
add_child(placeholder)
```

---

### WR-04: Blacksmith at (220, 110) and shop NPC at (167, 110) — interaction areas overlap

**File:** `script/world.gd:18-25`

**Issue:** `_spawn_blacksmith_npc()` places the blacksmith at `Vector2(220, 110)`.
`_spawn_shop_npc()` places the shop NPC at `Vector2(167, 110)`. Both NPCs use
`CircleShape2D` with `radius = 20.0` for their interaction areas. The distance
between them is `220 - 167 = 53` pixels. With radius 20 each, the combined reach is
40 pixels, leaving only a 13-pixel gap between interaction zones.

At Godot's pixel-art scale of 4.0, 13 logical pixels is 52 screen pixels — narrow
but not technically overlapping. However the `_process()` poll in `blacksmith_npc.gd`
fires on `Input.is_action_just_pressed("interact")` while `player_nearby` is true. If
the player stands in the gap between the two NPCs (within 20px of both), one E press
will trigger both NPCs' `_process()` checks simultaneously on the same frame. The
first one to call `dialogue_manager.open()` will succeed; the second will hit the
`if _panel.visible: return` guard in `dialogue_manager.open()` and silently no-op.
This is recoverable but produces inconsistent behavior depending on scene tree order.

**Fix:** Increase the X separation to at least 60px (min gap = 20px after subtracting
both radii) or reduce interaction radii:
```gdscript
func _spawn_blacksmith_npc() -> void:
    var npc = load("res://script/blacksmith_npc.gd").new()
    npc.position = Vector2(240, 110)  # was 220; now 73px gap from shop at 167
    add_child(npc)
```

---

### WR-05: Secret door has a one-frame visual flash — `add_child()` makes it visible before any `_ready()` hide logic can run

**File:** `script/cliff_side.gd:39-61`

**Issue:** `_build_secret_door()` calls `add_child(door)` as the last line. At the
frame this runs, the door's `visual` ColorRect is visible with full opacity. There is
no frame where it is hidden before being added. This means on the frame `cliff_side`
loads, the door flashes visible for at least one render frame before any `_ready()`
on the door's children could hide it.

More importantly: the current logic only spawns the door when `cliff_secret_door` is
NOT unlocked (line 40-41 early return). This means the door appears as a solid brown
`ColorRect` obstacle until the unlock is granted, which is the intended behavior.
What is missing is any runtime response to the unlock being granted mid-session: if
the player completes `reach_floor_10` or `story_chain` while in cliff_side (both give
`cliff_secret_door` unlock), the door StaticBody2D is already in the tree with active
collision. The collision is never removed — `_build_secret_door()` only runs once in
`_ready()`. The door stays blocking until the scene reloads.

**Fix:** Either store a reference to `door` and remove it when the unlock is granted,
or poll the unlock in `_process()`:
```gdscript
# In cliff_side.gd
var _secret_door: StaticBody2D = null

func _build_secret_door() -> void:
    if bool(global.unlocks.get("cliff_secret_door", false)):
        return
    # ... build door as before ...
    _secret_door = door
    add_child(door)

func _process(_delta: float) -> void:
    change_scene()
    if _secret_door != null and bool(global.unlocks.get("cliff_secret_door", false)):
        _secret_door.queue_free()
        _secret_door = null
```

---

## Info

### IN-01: Hardcoded `"(step %d/3)"` in `get_objective_string()` — breaks if `npc_sequence` length changes

**File:** `script/quest_manager.gd:147`

**Issue:** The objective string for `story_chain` type uses the literal `3` in
`"Talk to: %s (step %d/3)"`. The actual sequence length is `seq.size()` (currently 3
in `quest_data.gd`), but if a quest designer adds a 4th NPC to `npc_sequence`, the
displayed total stays `3` while the step counter reaches `4`.

**Fix:**
```gdscript
return "Talk to: %s (step %d/%d)" % [next_npc.capitalize(), step + 1, seq.size()]
```

---

### IN-02: `dialogue_data.gd` elder NPC has no routing for post-completion revisit of `"fetch_ancient_relic"`

**File:** `script/dialogue_data.gd` (elder section, no post-complete node)

**Issue:** After `fetch_ancient_relic` is completed, the elder has no dialogue node
for subsequent visits. There is no NPC-side routing in `dungeon_npc.gd` or an elder
NPC script that redirects to a `"fetch_quest_done"` node. The elder would need a
`_select_start_node()` equivalent (like `blacksmith_npc.gd` has) to guard against
re-showing `"fetch_quest_complete"`. Without it, CR-02 (double payout) is directly
exercised by revisiting the elder after fetch completion.

**Fix:** Add a post-completion node to `dialogue_data.gd` and ensure the elder NPC
routing checks `global.quest_state["fetch_ancient_relic"].get("status") == "complete"`
before routing to `"fetch_quest_complete"`.

---

### IN-03: `dialogue_manager._on_choice_picked()` silently ignores unknown `action` values

**File:** `script/dialogue_manager.gd:178-189`

**Issue:** `_on_choice_picked()` handles `"quest_offer"`, `"quest_complete"`, and
`"story_chain_advance"`. Any other action string (e.g., a typo like `"quest_complet"`,
or a future action like `"give_item"`) silently passes through with no warning, no
error, and no visual feedback. The action is dropped and the dialogue advances
normally, making typos in `dialogue_data.gd` very hard to debug.

**Fix:** Add a warning for unknown non-empty actions:
```gdscript
elif action != "":
    push_warning("dialogue_manager: unknown action '%s' on node '%s/%s'" % [action, _current_npc, _current_node])
```

---

_Reviewed: 2026-05-18T22:40:00-07:00_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
