---
phase: "03"
plan: "03"
subsystem: quest-integration
tags: [quest, enemy, dungeon, dialogue, fetch-chest]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [quest-engine-wiring]
  affects: [enemy_base, dungeon, dialogue_manager]
tech_stack:
  added: []
  patterns: [duck-typed identity, flag polling, Area2D runtime spawn]
key_files:
  modified:
    - script/enemy_base.gd
    - script/dungeon.gd
    - script/dialogue_manager.gd
decisions:
  - chest pickup uses existing interact action with dialogue guard to prevent double-consume
  - on_floor_reached called in both _check_next_floor and _save_and_exit for full coverage
  - fetch chest skips spawn if player already holds the item (idempotent)
metrics:
  duration: "~10 minutes"
  completed: "2026-05-14T23:36:43Z"
---

# Phase 03 Plan 03: Engine Integration Summary

Wire existing engine systems (enemy death, floor transitions, dialogue choices) to quest_manager.

## Tasks Completed

| Task | File | Change | Commit |
|------|------|--------|--------|
| 1 | enemy_base.gd | `quest_manager.on_enemy_killed(enemy_type)` before `queue_free()` | 8740863 |
| 2 | dungeon.gd | floor hooks + fetch chest spawn/proximity/pickup | 8740863 |
| 3 | dialogue_manager.gd | accept/complete/story_chain dispatch in `_on_choice_picked` | 8740863 |

## Integration Sites

### enemy_base.gd (line 94)
`deal_with_damage()` — inside `if health <= 0:` block, after money award, before removal. Passes `enemy_type` string so quest_manager can match kill-type quests.

### dungeon.gd
Three sub-changes:
1. `_ready()` (line 99): `_spawn_fetch_chest_if_needed(obstacles)` — only spawns if active fetch quest and player lacks the item.
2. `_check_next_floor()` (line 119): `quest_manager.on_floor_reached(global.current_floor)` — fires before `next_floor` flag is cleared, so floor number is still the current floor.
3. `_save_and_exit()` (line 129): same call as first statement — covers the save-point exit path.
4. New functions `_spawn_fetch_chest_if_needed`, `_on_fetch_chest_body_entered`, `_on_fetch_chest_body_exited` appended at end of file.
5. `_process()` poll loop: iterates `Area2D` children with `item_id` meta; on interact press (guarded against open dialogue) awards item and frees chest.

### dialogue_manager.gd (lines 178-183)
`_on_choice_picked` dispatch expanded:
- `quest_offer` branch now also calls `quest_manager.accept_quest(qid)` after npc_state mutation
- new `elif action == "quest_complete"` calls `quest_manager.complete_quest(qid2)`
- new `elif action == "story_chain_advance"` calls `quest_manager.advance_story_chain()`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Fetch chest requires active fetch quest in quest_manager; all data paths are wired.

## Threat Flags

None. No new network endpoints or auth paths introduced. Chest pickup is local game state mutation only.

## Self-Check: PASSED

- script/enemy_base.gd modified: confirmed (quest_manager.on_enemy_killed at line 94)
- script/dungeon.gd modified: confirmed (3 call sites + 3 new functions)
- script/dialogue_manager.gd modified: confirmed (3 dispatch lines at 178-183)
- Commit 8740863 exists in git log
