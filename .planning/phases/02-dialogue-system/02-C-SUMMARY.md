---
phase: 2
plan: "02-03"
subsystem: dialogue-system
tags: [npc, dialogue, quest-memory, world-shop]
dependency_graph:
  requires:
    - 02-01  # global.npc_state Dictionary scaffolding
    - 02-02  # DialogueManager autoload + DialogueData tree
  provides:
    - shop-npc-dialogue-trigger
    - npc-memory-branching
  affects:
    - script/npc.gd  # _process() rewired to open DialogueManager
tech_stack:
  added: []
  patterns:
    - quest-state-driven start_node selection (npc_state.get with default)
    - shop_open guard pattern (preserve existing flow before layering new behavior)
key_files:
  created: []
  modified:
    - script/npc.gd
decisions:
  - npc_state key shape: "quest_accepted_<quest_id>" — concatenated in dialogue_manager.gd, read literally in npc.gd
  - shop_open == true takes precedence over dialogue trigger (existing toggle preserved)
  - start_node defaults to "greeting" when no quest state exists; "quest_follow_up" after acceptance
metrics:
  duration_min: 5
  completed: 2026-05-09
  tasks_completed: 2
  files_modified: 1
  files_created: 0
---

# Phase 2 Plan 02-03: Wire NPC Interaction Summary

Shop NPC (`script/npc.gd`) now triggers `DialogueManager.open("elder", start)` on interact, with `start` selected from `global.npc_state["elder"]["quest_accepted_reach_floor_10"]` for repeat-visit memory; existing shop toggle path preserved via `shop_open` guard.

## Tasks Completed

| Task | Title | Commit | Files |
| ---- | ----- | ------ | ----- |
| 2-C-01-03 | Replace npc.gd _process() with dialogue trigger + npc_state branching | da98981 | script/npc.gd |
| 2-C-04-verify | Verify quest offer/decline paths in dialogue_data.gd are reachable | (verify-only, no edit) | script/dialogue_data.gd, script/dialogue_manager.gd |

## Implementation Notes

**Task 2-C-01-03 — npc.gd _process() extension**

Replaced the 4-line `_process()` (which only called `player_ref.open_shop()`) with an 11-line version that adds two branches:

1. **shop_open guard** (mitigates T-2C-03): `if player_ref.shop_open: player_ref.open_shop(); return` — pressing E while shop is open still closes the shop, never opens dialogue on top of it.
2. **Dialogue trigger with state-driven start_node** (DLG-03): reads `global.npc_state.get("elder", {})` and selects `"quest_follow_up"` when `quest_accepted_reach_floor_10` flag is true; defaults to `"greeting"` otherwise. Then `DialogueManager.open("elder", start)`.

`is_instance_valid(player_ref)` early-return preserves the T-2C-01 mitigation against stale player references.

**Task 2-C-04-verify — End-to-end key parity**

No code changes required. Verified via grep:
- `dialogue_data.gd` has `quest_offer` (3 occurrences), `quest_declined` (2), `Decline Quest` button label (1).
- `dialogue_manager.gd._on_choice_picked` writes `global.npc_state[_current_npc]["quest_accepted_" + qid] = true` — concatenation produces `"quest_accepted_reach_floor_10"`.
- `npc.gd` reads `state.get("quest_accepted_reach_floor_10", false)` — exact string match.

The DLG-03 memory loop is closed: write key (manager) === read key (npc.gd).

## Acceptance Criteria

All 12 grep-based acceptance criteria from the plan pass (6 per task × 2 tasks):

Task 2-C-01-03:
- `DialogueManager.open` in npc.gd: 1 match ✓
- `interact` in npc.gd: 1 match ✓
- `npc_state` in npc.gd: 1 match ✓
- `shop_open` in npc.gd: 1 match ✓
- `quest_follow_up` in npc.gd: 1 match ✓
- `open_shop` in npc.gd: 1 match ✓

Task 2-C-04-verify:
- `quest_offer` in dialogue_data.gd: 3 matches (≥2) ✓
- `quest_declined` in dialogue_data.gd: 2 matches (≥2) ✓
- `Decline Quest` in dialogue_data.gd: 1 match ✓
- `quest_offer` in dialogue_manager.gd: 1 match (≥1) ✓
- `quest_accepted_` in dialogue_manager.gd: 1 match ✓
- `quest_accepted_reach_floor_10` in npc.gd: 1 match ✓

## Deviations from Plan

None — plan executed exactly as written. The verification task confirmed Plan B's `dialogue_data.gd` and `dialogue_manager.gd` outputs already satisfy the key-parity requirement; no targeted edits were needed.

## Threat Mitigations Applied

| Threat ID | Mitigation in Code |
| --------- | ------------------ |
| T-2C-01 (DoS, stale player_ref) | `if not is_instance_valid(player_ref): return` early-exit added at top of dialogue branch |
| T-2C-02 (npc_state key mismatch) | Acceptance criteria 2-C-04 grep-checks confirm write-side `"quest_accepted_" + qid` produces same string as read-side `"quest_accepted_reach_floor_10"` literal |
| T-2C-03 (shop + dialogue dual-open) | `if player_ref.shop_open: player_ref.open_shop(); return` guard short-circuits before DialogueManager.open call |

## Requirements Addressed

- **DLG-01** — World shop NPC opens dialogue on interact
- **DLG-02** — DialogueManager.open() called with valid npc_id ("elder")
- **DLG-03** — NPC memory branching via global.npc_state lookup
- **DLG-04** — Quest offer/decline reachable from world shop NPC (verified end-to-end)

## Self-Check: PASSED

- File `script/npc.gd`: FOUND
- File `.planning/phases/02-dialogue-system/02-C-SUMMARY.md`: FOUND
- Commit `da98981`: FOUND in `git log --oneline`
