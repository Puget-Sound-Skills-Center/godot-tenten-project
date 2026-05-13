---
phase: 02-dialogue-system
verified_at: 2026-05-13T23:50:00Z
status: human_needed
must_haves_checked: 18
must_haves_passed: 18
must_haves_failed: 0
re_verification: false
human_verification:
  - test: "Open dialogue with world NPC (Elder)"
    expected: "Dialogue panel appears at bottom of screen with portrait placeholder, 'Elder' name in yellow, greeting text in white, and 'Press E to continue' prompt. Game enemies freeze (tree paused)."
    why_human: "Visual layout, font rendering at 4x pixel-art scale, and pause behavior require in-engine observation"
  - test: "Advance to quest_offer node and verify 2 choice buttons render"
    expected: "Two buttons appear — 'Accept Quest' and 'Decline Quest' — with 'Press E to continue' hidden. Only buttons respond to input."
    why_human: "Button rendering and E-key non-advance on choice nodes requires runtime confirmation"
  - test: "Accept quest, close dialogue, re-open NPC"
    expected: "Second visit opens at 'I remember you. How fare the depths?' (quest_follow_up), not the greeting. Confirms DLG-03 NPC memory."
    why_human: "State persistence across open/close cycle requires gameplay test"
  - test: "Decline quest path"
    expected: "Pressing 'Decline Quest' shows 'Perhaps another time. I will wait.' then closes. Quest flag NOT set (re-opening still shows greeting)."
    why_human: "Branch routing and flag non-write on decline requires runtime trace"
  - test: "Dungeon floor — dialogue NPC visible and interactable"
    expected: "On any dungeon floor, a chest_02 sprite NPC with 'E: Talk' prompt appears. Walking near it shows prompt. Pressing E opens Merchant dialogue with game paused."
    why_human: "Dungeon NPC spawn position, sprite visibility, and proximity trigger require in-engine observation"
  - test: "Floor advance while dialogue open"
    expected: "If player reaches exit while Merchant dialogue is open, floor transitions without leaving game in permanently paused state."
    why_human: "Race condition edge case requires manual test with deliberate timing"
---

# Phase 02: Dialogue System — Verification Report

**Phase Goal:** Players can have stateful, branching conversations with NPCs — including quest offer/decline — with the game pausing during dialogue
**Verified:** 2026-05-13T23:50:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

All 18 code-level must-haves VERIFIED. 6 behavioral items require human in-engine testing.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Player opens dialogue panel with portrait, name, text, advance-on-input; game pauses | VERIFIED | `dialogue_manager.gd` open() sets `get_tree().paused = true`, builds panel with `_speaker_lbl`, `_text_lbl`, `_advance_lbl` at runtime |
| 2 | Dialogue presents 2-choice branches; NPC responds differently per choice | VERIFIED | `dialogue_data.gd` `quest_offer` node has 2-entry `choices` array; `_render_node()` creates `Button.new()` per choice; `_on_choice_picked()` routes to `choice.get("next")` |
| 3 | NPC remembers quest accepted, shows different dialogue on repeat visit | VERIFIED | `npc.gd` reads `global.npc_state.get("elder", {}).get("quest_accepted_reach_floor_10", false)` and sets `start = "quest_follow_up"` on match |
| 4 | Player can accept or decline quest inline; declining causes different NPC response | VERIFIED | `dialogue_data.gd` "Accept Quest" routes to `quest_accepted`, "Decline Quest" routes to `quest_declined`; accept writes `global.npc_state[npc]["quest_accepted_reach_floor_10"] = true`, decline writes nothing |
| 5 | Dungeon NPC (merchant) appears inside dungeon rooms and is interactable | VERIFIED | `dungeon.gd` line 92 calls `_spawn_dungeon_dialogue_npc(floor_no, obstacles)`; `dungeon_dialogue_npc.gd` calls `dialogue_manager.open("dungeon_merchant", "greeting")` on interact |

**Score:** 5/5 truths verified by code

---

## Must-Haves Verification

### Plan 02-01: Autoload Registration + npc_state Scaffolding

#### project.godot autoloads registered
- **Checked:** `project.godot` [autoload] section
- **Evidence:** Lines 21-22: `dialogue_data="*res://script/dialogue_data.gd"` and `dialogue_manager="*res://script/dialogue_manager.gd"`
- **Result:** PASS

#### global.gd has npc_state dict variable
- **Checked:** `script/global.gd` line 34
- **Evidence:** `var npc_state: Dictionary = {}`
- **Result:** PASS

#### global.gd save_to_slot writes npc_state
- **Checked:** `script/global.gd` line 91
- **Evidence:** `cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))`
- **Result:** PASS

#### global.gd load_from_slot reads npc_state with null guard
- **Checked:** `script/global.gd` lines 110-113
- **Evidence:** `var raw := cfg.get_value("dialogue", "npc_state", "{}")` + `npc_state = str_to_var(raw) if raw != "{}" else {}` + `if npc_state == null: npc_state = {}`
- **Result:** PASS

#### global.gd reset_for_new_game resets npc_state to {}
- **Checked:** `script/global.gd` line 72
- **Evidence:** `npc_state = {}` inside `reset_for_new_game()`
- **Result:** PASS

### Plan 02-02: Dialogue Engine

#### script/dialogue_data.gd exists with dialogue trees
- **Checked:** file read
- **Evidence:** 69-line file with `DIALOGUES` const containing "elder" (5 nodes) and "dungeon_merchant" (2 nodes)
- **Result:** PASS

#### DialogueData lookup function exists
- **Checked:** `script/dialogue_data.gd` line 65
- **Evidence:** `func get_dialogue_node(npc_id: String, node_id: String) -> Dictionary` — note: name differs from plan spec (`get_node` → `get_dialogue_node`); this is intentional (avoids conflict with `Node.get_node()`); consistently called as `dialogue_data.get_dialogue_node()` in dialogue_manager.gd line 144
- **Result:** PASS

#### script/dialogue_manager.gd exists as CanvasLayer
- **Checked:** file read
- **Evidence:** `extends CanvasLayer`, `layer = 30` in `_ready()`
- **Result:** PASS

#### dialogue_manager.gd exposes open(), close(), force_close()
- **Checked:** `script/dialogue_manager.gd` lines 111, 124, 134
- **Evidence:** All three functions defined with correct signatures
- **Result:** PASS

#### dialogue_manager.gd pauses/unpauses tree
- **Checked:** `script/dialogue_manager.gd` lines 121, 126, 136
- **Evidence:** `get_tree().paused = true` in `open()`; `get_tree().paused = false` in both `close()` and `force_close()`
- **Result:** PASS

#### Dialogue panel built in GDScript at runtime
- **Checked:** `script/dialogue_manager.gd` `_build_dialogue_panel()` lines 31-107
- **Evidence:** Full node tree built via `ColorRect.new()`, `Panel.new()`, `MarginContainer.new()`, `HBoxContainer.new()`, `VBoxContainer.new()`, `Label.new()` — no `.tscn` UI nodes
- **Result:** PASS

#### Choice buttons visible only when node has choices
- **Checked:** `script/dialogue_manager.gd` `_render_node()` lines 154-169
- **Evidence:** `_choices_container.visible = false` / `_advance_lbl.visible = true` on empty choices; reversed when choices present; `Button.new()` per choice entry
- **Result:** PASS

#### PROCESS_MODE_ALWAYS applied to all UI nodes
- **Checked:** `script/dialogue_manager.gd` — `_pa()` helper at line 27-29
- **Evidence:** `_pa()` called on overlay, panel, margin, hbox, portrait, vbox, speaker_lbl, text_lbl, choices_container, advance_lbl, and each Button; CanvasLayer itself set `process_mode = Node.PROCESS_MODE_ALWAYS` in `_ready()`
- **Result:** PASS

### Plan 02-03: NPC Interaction Wiring

#### script/npc.gd calls dialogue_manager.open() on interact
- **Checked:** `script/npc.gd` line 57
- **Evidence:** `dialogue_manager.open("elder", start)` inside `_process()` interact branch
- **Result:** PASS

#### npc.gd checks global.npc_state for start_node selection
- **Checked:** `script/npc.gd` lines 53-56
- **Evidence:** `var state: Dictionary = global.npc_state.get("elder", {})` + `if state.get("quest_accepted_reach_floor_10", false): start = "quest_follow_up"`
- **Result:** PASS

#### Dialogue does NOT open when shop is already open
- **Checked:** `script/npc.gd` lines 46-51
- **Evidence:** Two guards: `if dialogue_manager._panel != null and dialogue_manager._panel.visible: return` (prevents retrigger); `if player_ref.shop_open: player_ref.open_shop(); return` (shop toggle preserved)
- **Result:** PASS

#### Key parity: flag written by dialogue_manager matches flag read by npc.gd
- **Checked:** `dialogue_manager.gd` line 177, `npc.gd` line 55
- **Evidence:** Manager writes `global.npc_state[_current_npc]["quest_accepted_" + qid]` where `qid = "reach_floor_10"` → key is `"quest_accepted_reach_floor_10"`; npc.gd reads `state.get("quest_accepted_reach_floor_10", false)` — exact match
- **Result:** PASS

### Plan 02-04: Dungeon Dialogue NPC

#### script/dungeon_dialogue_npc.gd exists and opens dialogue on interact
- **Checked:** file read
- **Evidence:** `_process()` line 43: `dialogue_manager.open("dungeon_merchant", "greeting")`; "E: Talk" prompt label; `has_method("player")` duck-typed identity check preserved
- **Result:** PASS

#### script/dungeon.gd spawns dungeon_dialogue_npc per floor
- **Checked:** `script/dungeon.gd` lines 92, 275-279
- **Evidence:** `_spawn_dungeon_dialogue_npc(floor_no, obstacles)` called in `_ready()` after `_spawn_enemies`; function uses `_pick_save_position(obstacles)` for clear placement and `load("res://script/dungeon_dialogue_npc.gd").new()`
- **Result:** PASS

#### script/dungeon.gd calls force_close() before reload_current_scene()
- **Checked:** `script/dungeon.gd` lines 114-115
- **Evidence:** `dialogue_manager.force_close()` immediately before `get_tree().reload_current_scene()` in `_check_next_floor()`; also called in `_exit_to_cliffside()` at line 123 (defensive, belt-and-suspenders)
- **Result:** PASS

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `project.godot` | dialogue_data + dialogue_manager autoloads | VERIFIED | Lines 21-22 |
| `script/global.gd` | npc_state dict with save/load/reset | VERIFIED | Lines 34, 72, 91, 110-113 |
| `script/dialogue_data.gd` | Dialogue trees for elder + dungeon_merchant | VERIFIED | 69 lines, DIALOGUES const, get_dialogue_node() |
| `script/dialogue_manager.gd` | CanvasLayer UI + pause lifecycle | VERIFIED | 204 lines, layer=30, open/close/force_close |
| `script/npc.gd` | DialogueManager.open() on interact + npc_state check | VERIFIED | Lines 46-57 |
| `script/dungeon_dialogue_npc.gd` | Proximity NPC calling DialogueManager | VERIFIED | 56 lines, "E: Talk", duck-typed identity |
| `script/dungeon.gd` | Spawn dungeon NPC + force_close guard | VERIFIED | Lines 92, 114-115, 275-279 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `npc.gd` | `dialogue_manager` | `dialogue_manager.open("elder", start)` | WIRED | line 57 |
| `dungeon_dialogue_npc.gd` | `dialogue_manager` | `dialogue_manager.open("dungeon_merchant", "greeting")` | WIRED | line 43 |
| `dialogue_manager.gd` | `dialogue_data` | `dialogue_data.get_dialogue_node()` | WIRED | line 144 |
| `dialogue_manager.gd` | `global.npc_state` | `global.npc_state[_current_npc]["quest_accepted_" + qid] = true` | WIRED | line 177 |
| `npc.gd` | `global.npc_state` | `global.npc_state.get("elder", {})` | WIRED | line 54 |
| `dungeon.gd` | `dungeon_dialogue_npc.gd` | `load("res://script/dungeon_dialogue_npc.gd").new()` | WIRED | line 277 |
| `dungeon.gd` | `dialogue_manager.force_close()` | before `reload_current_scene()` | WIRED | line 114 |
| `global.gd` | ConfigFile | `var_to_str(npc_state)` save / `str_to_var` load | WIRED | lines 91, 110-113 |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — no runnable entry points accessible without Godot editor (GDScript requires the engine runtime).

---

## Requirement Traceability

| Req ID | Status | Evidence |
|--------|--------|----------|
| DLG-01 | SATISFIED | `dialogue_manager.open()` pauses tree; panel has portrait, speaker label, text label, advance prompt; `_unhandled_input` advances on E |
| DLG-02 | SATISFIED | `quest_offer` node in `dialogue_data.gd` has 2-entry choices array; `_render_node()` creates Button per choice; `_on_choice_picked()` routes to choice-specific next node |
| DLG-03 | SATISFIED | `npc.gd` reads `global.npc_state["elder"]["quest_accepted_reach_floor_10"]`; `dialogue_manager.gd` writes same key on accept; key parity confirmed |
| DLG-04 | SATISFIED | "Accept Quest" → `quest_accepted` node + flag written; "Decline Quest" → `quest_declined` node, no flag written; both paths have non-empty text |
| DLG-05 | SATISFIED (code) | `dungeon_dialogue_npc.gd` exists and wired; `dungeon.gd` spawns one per floor; REQUIREMENTS.md shows "Pending" — this is a doc inconsistency, not a code gap |

**Note on DLG-05:** REQUIREMENTS.md traceability table marks DLG-05 as "Pending" while the code fully implements it. The requirements file needs updating.

---

## Success Criteria

| # | Criteria | Status | Notes |
|---|----------|--------|-------|
| 1 | Player walks up to NPC, opens dialogue panel with portrait, name, text, advance-on-input | VERIFIED (code) | Panel built at runtime in dialogue_manager.gd; human test needed for visual layout |
| 2 | Dialogue presents 2-choice branches; NPC responds differently per choice | VERIFIED | quest_offer node confirmed; both branches have distinct destination nodes and text |
| 3 | NPC remembers if quest accepted, shows different dialogue on repeat visit | VERIFIED | npc_state key parity confirmed across write (dialogue_manager) and read (npc.gd) sites |
| 4 | Player can accept or decline quest inline; declining causes different NPC response | VERIFIED | Both choice paths confirmed in dialogue_data.gd; only accept writes npc_state flag |
| 5 | Dungeon NPC appears inside dungeon rooms and is interactable | VERIFIED (code) | Per-floor spawn confirmed in dungeon.gd; human test needed for in-game visibility |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `dialogue_manager.gd` | 113 | `pause_menu._pause_panel != null` — direct private field access across autoloads | Info | Works but brittle; if pause_menu renames `_pause_panel`, this silently misbehaves. Not a blocker. |

No TODO/FIXME/placeholder comments, empty implementations, or hardcoded empty data found in phase 2 files.

---

## Deviations from Plan (Non-blocking)

**`get_node()` renamed to `get_dialogue_node()`:** Plan 02-02 specified `DialogueData.get_node()` but the implementation uses `get_dialogue_node()`. This avoids a shadowing conflict with `Node.get_node()` which is a built-in Godot method. The rename is internally consistent — `dialogue_manager.gd` calls `dialogue_data.get_dialogue_node()` correctly. No functional impact.

**REQUIREMENTS.md DLG-05 status:** File shows "Pending" in traceability table but marks `[x]` for DLG-01 through DLG-04. The dungeon NPC implementation is complete. The REQUIREMENTS.md traceability table row for DLG-05 needs updating to "Complete".

---

## Human Verification Required

### 1. Dialogue panel visual layout

**Test:** Enter world scene, walk up to the shop NPC (Elder), press E.
**Expected:** Bottom-strip dialogue panel appears: dark semi-transparent overlay, 72x72 portrait placeholder (dark blue-grey rect), "Elder" in yellow text, greeting text in white with word wrap, "Press E to continue" in grey. Enemies in scene (none in world) would freeze.
**Why human:** Font rendering at 4x pixel-art scale, panel height proportion, and color accuracy require in-engine observation.

### 2. Choice button rendering on quest_offer node

**Test:** From greeting, press E once to reach quest_offer node.
**Expected:** "Press E to continue" disappears; two buttons appear — "Accept Quest" and "Decline Quest" — vertically stacked. Pressing E does NOT advance (choice nodes block advance-key).
**Why human:** Button layout, font size at 12px, and E-key non-advance behavior on choice nodes requires runtime confirmation.

### 3. NPC memory — repeat visit after quest accept

**Test:** Accept quest → close dialogue → re-open NPC with E.
**Expected:** Second visit shows "I remember you. How fare the depths?" — not the greeting. Confirms DLG-03 state persistence within a session.
**Why human:** State persistence across open/close dialogue cycle requires gameplay observation.

### 4. Decline quest path — no flag set

**Test:** Open dialogue → reach quest_offer → press "Decline Quest" → close → re-open NPC.
**Expected:** After decline, dialogue shows "Perhaps another time. I will wait." then closes. Re-opening shows greeting again (not quest_follow_up), confirming decline does not set the accepted flag.
**Why human:** Branch routing and conditional flag non-write requires runtime trace.

### 5. Dungeon floor — NPC visible and interactable

**Test:** Enter any dungeon floor. Locate the merchant NPC (chest_02 sprite).
**Expected:** NPC visible somewhere in room (not in wall, not in spawn corner). Walking near it shows "E: Talk" prompt. Pressing E opens Merchant dialogue: "Merchant" name, greeting text, game pauses (enemies stop).
**Why human:** NPC spawn position within the room, sprite rendering, and proximity trigger area require in-engine observation.

### 6. Floor advance while dialogue open (edge case)

**Test:** Open merchant dialogue in dungeon, then step onto floor exit.
**Expected:** Floor transitions without game being stuck in permanently paused state on the new floor.
**Why human:** Race condition between dialogue_manager.force_close() and reload_current_scene() requires deliberate manual timing to trigger.

---

## Summary

All 18 code-level must-haves pass. The dialogue system infrastructure is fully implemented and correctly wired:

- Autoloads registered in `project.godot`
- `global.npc_state` persisted with save/load/reset
- `dialogue_data.gd` provides branching trees for elder and dungeon_merchant NPCs
- `dialogue_manager.gd` builds UI at runtime, manages pause lifecycle, handles quest flag writes
- `npc.gd` triggers dialogue with state-driven start_node selection
- `dungeon_dialogue_npc.gd` handles dungeon merchant interaction
- `dungeon.gd` spawns one NPC per floor and guards against paused-tree leakage on floor advance

One documentation inconsistency: REQUIREMENTS.md marks DLG-05 as "Pending" in the traceability table despite full code implementation. This needs a single-line update.

Status is **human_needed** because 6 behavioral items (visual layout, choice button rendering, NPC memory, branch routing, dungeon NPC spawn, and the force_close race condition) require in-engine gameplay testing to fully confirm.

---

_Verified: 2026-05-13T23:50:00Z_
_Verifier: Claude (gsd-verifier)_
