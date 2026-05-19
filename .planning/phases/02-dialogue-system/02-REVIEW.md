---
phase: 02-dialogue-system
reviewed: 2026-05-18
depth: standard
files_reviewed: 7
files_reviewed_list:
  - script/dialogue_data.gd
  - script/dialogue_manager.gd
  - script/dungeon_dialogue_npc.gd
  - script/global.gd
  - script/npc.gd
  - script/world.gd
  - script/cliff_side.gd
findings:
  critical: 2
  warning: 3
  info: 3
  total: 8
status: fixed
fixed: 2026-05-18
---

# Phase 2: Code Review Report

**Reviewed:** 2026-05-18
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

This review is against the actual committed implementation — the prior review (2026-05-09) was conducted against incomplete stubs. The actual code is substantially more robust: the autoload case mismatch (old CR-01) is gone, `get_node` shadowing (old CR-02) is gone, `dialogue_manager._unhandled_input` does call `set_input_as_handled()` (old WR-03 fixed), and `dungeon.gd` correctly calls `dialogue_manager.force_close()` before both `reload_current_scene()` and `change_scene_to_file()`.

Two BLOCKER defects survive or are newly surfaced:

1. **`pause_menu` stomps dialogue pause state** — `pause_menu._unhandled_input` has no guard for dialogue being open. Pressing ESC during dialogue opens the pause panel on top and `_resume()` unconditionally unpauses the tree, leaving the dialogue overlay visible with an unpaused world beneath it.
2. **`world.gd` and `cliff_side.gd` scene transitions skip `force_close()`** — both scenes change scene without calling `dialogue_manager.force_close()`. If a player inside an NPC dialogue walks into a transition trigger, `get_tree().paused` carries into the new scene, which boots frozen with no visible cause.

Three warnings cover: a logic error in `npc.gd` that re-presents the story-chain advance choice on every Elder revisit at step 0 (advancing the chain repeatedly), a dead save/load string guard in `global.gd`, and an unguarded `quest_manager.accept_quest("")` call path in `dialogue_manager.gd`.

## Critical Issues

### CR-01: `pause_menu._unhandled_input` has no dialogue guard — ESC during dialogue corrupts pause state

**File:** `script/pause_menu.gd:19-29`
**Issue:** `pause_menu._unhandled_input` fires on `ui_cancel` with no check for whether the dialogue panel is open. `dialogue_manager.open()` already guards against the pause panel being visible (line 114 of dialogue_manager.gd), but the reverse is not true.

Failure sequence:
1. Player opens dialogue. `dialogue_manager.open()` sets `_panel.visible = true`, `get_tree().paused = true`.
2. Player presses ESC. `pause_menu._unhandled_input` fires (CanvasLayer is `PROCESS_MODE_ALWAYS`), sees neither save nor pause panel visible, calls `_open_pause()`.
3. Now both the dialogue panel (layer 30) and pause panel (layer 50) are visible.
4. Player clicks Resume → `_resume()` runs `get_tree().paused = false` while dialogue is still open.
5. Result: dialogue overlay is visible but the world is unpaused — enemies move, player can walk away, dialogue is never closeable (the advance E-press guard in `_unhandled_input` still fires but `close()` itself calls `paused = false` which is already false, so that's harmless — but the player is now stuck with an overlay they cannot dismiss if they walked out of the NPC's Area2D, since `_on_body_exited` does not close dialogue).

**Fix:** Add the reciprocal dialogue check in `pause_menu._unhandled_input`:

```gdscript
# script/pause_menu.gd
func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.is_action_pressed("ui_cancel"):
        return
    if global.current_scene == "home":
        return
    # Defer to dialogue if it owns the pause state.
    if dialogue_manager._panel != null and dialogue_manager._panel.visible:
        return
    if _save_panel.visible:
        _save_panel.visible = false
    elif _pause_panel.visible:
        _resume()
    else:
        _open_pause()
```

---

### CR-02: `world.gd` and `cliff_side.gd` scene transitions do not call `force_close()` — new scene boots frozen

**File:** `script/world.gd:38`, `script/cliff_side.gd:31`, `script/cliff_side.gd:37`
**Issue:** `get_tree().paused` is a property on the `SceneTree` itself, not on the root scene. It persists across `change_scene_to_file()`. If the player is in dialogue when a scene-transition trigger fires, the new scene boots with `paused = true` and no dialogue panel to unpause it — the game is frozen.

`world.gd:35-40` — transition to `cliff_side.tscn`:
```gdscript
func change_scene():
    if global.transition_scene == true:
        if global.current_scene == "world":
            get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")  # NO force_close
            global.game_first_loading = false
            global.finish_changescenes()
```

`cliff_side.gd:28-37` — both transition paths:
```gdscript
func change_scene():
    if global.transition_scene == true:
        if global.current_scene == "cliff_side":
            get_tree().change_scene_to_file("res://scenes/world.tscn")  # NO force_close
            global.finish_changescenes()
    if global.enter_dungeon == true:
        global.enter_dungeon = false
        global.current_scene = "dungeon"
        get_tree().change_scene_to_file("res://scenes/dungeon.tscn")  # NO force_close
```

Contrast: `dungeon.gd` correctly calls `dialogue_manager.force_close()` before both `reload_current_scene()` (line 148) and `change_scene_to_file()` (line 158).

**Fix:** Add `force_close()` before every `change_scene_to_file()` in both files:

```gdscript
# script/world.gd
func change_scene():
    if global.transition_scene == true:
        if global.current_scene == "world":
            dialogue_manager.force_close()
            get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")
            global.game_first_loading = false
            global.finish_changescenes()

# script/cliff_side.gd
func change_scene():
    if global.transition_scene == true:
        if global.current_scene == "cliff_side":
            dialogue_manager.force_close()
            get_tree().change_scene_to_file("res://scenes/world.tscn")
            global.finish_changescenes()
    if global.enter_dungeon == true:
        global.enter_dungeon = false
        global.current_scene = "dungeon"
        dialogue_manager.force_close()
        get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
```

## Warnings

### WR-01: `npc.gd` routes story_chain step 0 to `story_chain_accepted` — repeating the choice advances the chain on every Elder revisit

**File:** `script/npc.gd:63-64`
**Issue:** When `story_status == "active"` and `story_step == 0`, the Elder is routed to `"story_chain_accepted"`:

```gdscript
elif story_status == "active" and story_step == 0:
    start = "story_chain_accepted"
```

`story_chain_accepted` in `dialogue_data.gd:86-93` contains one choice:
```gdscript
{"label": "(Set out)", "next": "", "action": "story_chain_advance"}
```

Every time the player talks to the Elder while the story chain is active at step 0, they are presented with "(Set out)" again — and clicking it calls `quest_manager.advance_story_chain()` a second (third, Nth) time. Depending on how `advance_story_chain` handles already-advanced state, this could silently skip quest steps or create a step-count inconsistency.

The intent is likely for this revisit path to show a reminder without the action button, or to route to a neutral follow-up like `"quest_follow_up"`.

**Fix:** Add a separate reminder node, or re-route step-0 revisits to a neutral node:

```gdscript
# In dialogue_data.gd, add to "elder":
"story_chain_reminder": {
    "speaker": "Elder",
    "text": "Find the Blacksmith by the forge. He knows where the Map Fragment went.",
    "next": "",
    "choices": []
},

# In npc.gd:63:
elif story_status == "active" and story_step == 0:
    start = "story_chain_reminder"
```

Alternatively, guard `advance_story_chain()` in `quest_manager` to be idempotent at each step boundary.

---

### WR-02: `global.gd` save/load empty-dict guard is dead code — real saves never produce `"{}"`

**File:** `script/global.gd:119-120`, `123-124`, `127-128`, `131-132`
**Issue:** The save path writes:
```gdscript
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))
```

For `npc_state = {}`, `var_to_str({})` returns `"{ }"` (with internal space) — not `"{}"`. The load guard:
```gdscript
var raw = cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}
```

The `raw != "{}"` check never fires for real saves — `"{ }" != "{}"` is always true, so `str_to_var` always runs. The trailing null-guard (`if npc_state == null: npc_state = {}`) is the only actual defense. The early-return path exists only for the default string `"{}"` which appears only when the key is missing from disk (old saves pre-dialogue). This is fragile and misleading.

The same pattern appears for `quest_state`, `items`, and `unlocks` on lines 123-132.

**Fix:** Use a type-safe pattern that makes the intent explicit:

```gdscript
# script/global.gd — all four dict fields
var raw := cfg.get_value("dialogue", "npc_state", "")
var parsed = str_to_var(raw) if raw != "" else null
npc_state = parsed if (parsed is Dictionary) else {}
```

This correctly handles: missing key (empty string default), empty `"{ }"` produced by `var_to_str({})`, and `str_to_var` returning null or a non-dict on corrupt data.

---

### WR-03: `dialogue_manager._on_choice_picked` calls `quest_manager.accept_quest(qid)` with potentially empty `qid`

**File:** `script/dialogue_manager.gd:179-183`
**Issue:**

```gdscript
if action == "quest_offer":
    var qid: String = choice.get("quest_id", "")
    if not global.npc_state.has(_current_npc):
        global.npc_state[_current_npc] = {}
    global.npc_state[_current_npc]["quest_accepted_" + qid] = true
    quest_manager.accept_quest(qid)
```

If a choice dict has `action: "quest_offer"` but omits `quest_id` (typo in dialogue_data.gd, or a future author's mistake), `qid` is `""`. Two effects:
1. `global.npc_state[_current_npc]["quest_accepted_"] = true` — a junk key persists in save data.
2. `quest_manager.accept_quest("")` is called with an empty string quest ID.

The same applies to `quest_complete` at line 186 — `quest_manager.complete_quest("")` on missing `quest_id`.

**Fix:**

```gdscript
if action == "quest_offer":
    var qid: String = choice.get("quest_id", "")
    if qid.is_empty():
        push_warning("dialogue_manager: quest_offer action missing quest_id in choice dict")
    else:
        if not global.npc_state.has(_current_npc):
            global.npc_state[_current_npc] = {}
        global.npc_state[_current_npc]["quest_accepted_" + qid] = true
        quest_manager.accept_quest(qid)
elif action == "quest_complete":
    var qid2: String = choice.get("quest_id", "")
    if not qid2.is_empty():
        quest_manager.complete_quest(qid2)
```

## Info

### IN-01: `npc.gd:71` — redundant condition in quest routing

**File:** `script/npc.gd:71`
**Issue:**

```gdscript
elif _quest_unaccepted("reach_floor_10") and cap_open and not state.get("quest_accepted_reach_floor_10", false):
```

The last condition (`not state.get("quest_accepted_reach_floor_10", false)`) is always true when `_quest_unaccepted("reach_floor_10")` is true. If the quest was accepted, `_quest_unaccepted` checks `quest_state` status and returns false, so the `elif` branch never reaches the third condition. Dead code that adds maintenance confusion.

**Fix:** Remove the redundant condition:

```gdscript
elif _quest_unaccepted("reach_floor_10") and cap_open:
    start = "quest_offer"
```

---

### IN-02: `dungeon_dialogue_npc.gd` lacks the `is_instance_valid` guard present in `npc.gd`

**File:** `script/dungeon_dialogue_npc.gd:39`
**Issue:** `npc.gd:40-44` guards `player_ref` with `is_instance_valid` before use. `dungeon_dialogue_npc.gd:39` checks `is_instance_valid(player_ref)` inline in the condition, which is correct, but also accesses `player_ref` in signal callbacks without guard. This is fine given floor reloads reset NPC state, but is an asymmetry that makes the codebase inconsistent and is a maintenance trap for future NPC variants.

**Fix:** No immediate action required. When a third NPC type is added, extract a shared `_can_interact() -> bool` helper to enforce the pattern.

---

### IN-03: `dialogue_manager` layer 30 is a bare magic number

**File:** `script/dialogue_manager.gd:21`
**Issue:** `layer = 30` is an architectural decision (between shop=20 and pause=50) with no named constant. The layer stack is documented only in `02-UI-SPEC.md`.

**Fix (optional polish):** Add constants to `global.gd`:

```gdscript
const LAYER_HUD := 10
const LAYER_SHOP := 20
const LAYER_DIALOGUE := 30
const LAYER_PAUSE := 50
```

Low priority; matches existing project pattern where all other layer assignments are also bare integers.

---

_Reviewed: 2026-05-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
