---
phase: 03-quest-system
plan: "02"
subsystem: quest-service
tags: [quest-manager, autoload, state-mutation, reward-dispatch, cap-enforcement]
dependency_graph:
  requires: [global.quest_state, global.items, global.unlocks, quest_data autoload]
  provides: [quest_manager public API — 10 methods]
  affects: [script/quest_manager.gd]
tech_stack:
  added: [quest_manager.gd autoload (stateless service)]
  patterns: [duck-typed dict mutation, match-based reward dispatch, guard-clause early returns]
key_files:
  created: [script/quest_manager.gd]
  modified: []
decisions:
  - quest_manager is extends Node (not CanvasLayer) — pure logic, no UI, no _ready
  - Fetch quest ready-check uses item count in global.items — no separate "carry" state needed
  - active_quest_count guards accept_quest at count >= 3 (D-04); duplicate active check prevents double-accept
  - Reward dispatch casts all values via int()/String() with get() defaults — safe against missing keys (T-03-02)
metrics:
  duration: ~8 min
  completed: "2026-05-14"
requirements: [QST-01, QST-02, QST-03, QST-04, QST-06, QST-07, QST-08]
---

# Phase 3 Plan 02: Quest Manager Service Summary

Stateless central service `quest_manager.gd` implementing all quest state mutations and query helpers. JWT-style chokepoint: no other script mutates `global.quest_state`, `global.items`, or `global.unlocks` directly. Enforces the 3-quest cap (D-04) and dispatches gold/item/unlock rewards on completion.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create quest_manager.gd with full 10-method public API | 28066ca | script/quest_manager.gd |

## Public API — All 10 Methods

```gdscript
# Quest lifecycle
func accept_quest(qid: String) -> bool
    # Copies quest_data.QUESTS[qid] into global.quest_state with status="active"
    # Returns false if: active_quest_count() >= 3, qid unknown, or quest already active/ready

func complete_quest(qid: String) -> bool
    # Dispatches: global.money += reward_gold
    #             global.items[reward_item] += 1  (if reward_item != "")
    #             global.unlocks[reward_unlock] = true  (if reward_unlock != "")
    # Sets status="complete"; returns false if qid not in quest_state

# Event hooks (called by integrations in Plan 03)
func on_enemy_killed(enemy_type: String) -> void
    # Increments progress for active kill quests matching enemy_type
    # Transitions to ready_to_complete when progress >= required

func on_floor_reached(floor_no: int) -> void
    # Marks active reach_floor quests ready_to_complete when floor_no >= target_floor

func advance_story_chain() -> void
    # Increments global.quest_state["story_chain"]["step"] if present and active
    # Silent no-op if quest absent or not active

# Queries (called by dungeon.gd, npc.gd, quest_log.gd, blacksmith_npc.gd)
func has_active_fetch_quest() -> bool
    # True iff any fetch quest is active AND its item_id not yet in global.items

func get_active_fetch_item_id() -> String
    # Returns item_id of first active fetch quest, or "" if none

func quest_ready(qid: String) -> bool
    # True if status == "ready_to_complete"
    # Fetch shortcut: also true if status=="active" AND global.items[item_id] >= 1

func active_quest_count() -> int
    # Counts entries with status in {"active", "ready_to_complete"}

func get_objective_string(qid: String) -> String
    # kill:        "Kill Melee Enemies (3/10)"
    # fetch:       "Find: Ancient Relic Fragment" / "Return: ... (Got it!)"
    # reach_floor: "Reach Floor 10" / "Reach Floor 10 (Done!)"
    # story_chain: "Talk to: Elder (step 1/3)" / "The Lost Fragment: Complete!"
```

## D-04 Cap Implementation

```gdscript
func accept_quest(qid: String) -> bool:
    if active_quest_count() >= 3:
        return false
    ...
```

One guard, one match. `active_quest_count()` counts both `active` and `ready_to_complete` statuses so a ready quest still occupies a slot until turned in.

## Reward Dispatch

All reward paths in `complete_quest`:
- Gold: `global.money += int(q.get("reward_gold", 0))`
- Item: `global.items[item_id] = int(global.items.get(item_id, 0)) + 1`
- Unlock: `global.unlocks[unlock_id] = true`

Missing keys silently no-op (T-03-02 mitigated via `get()` with defaults and `int()`/`String()` casts).

## Downstream Consumers

| Plan | Script | Methods Used |
|------|--------|-------------|
| 03-03 (integrations) | enemy_base.gd | `on_enemy_killed` |
| 03-03 (integrations) | dungeon.gd | `on_floor_reached`, `has_active_fetch_quest`, `get_active_fetch_item_id` |
| 03-03 (integrations) | dialogue_manager.gd | `advance_story_chain`, `accept_quest`, `complete_quest` |
| 03-04 (UI) | quest_log.gd | `get_objective_string`, `active_quest_count` |
| 03-05 (blacksmith/story) | blacksmith_npc.gd | `quest_ready`, `active_quest_count`, `complete_quest` |
| 03-05 (blacksmith/story) | npc.gd | `quest_ready`, `accept_quest` |

## Deviations from Plan

None — plan executed exactly as written. File content matches the plan's `<action>` block verbatim.

## Known Stubs

None. All 10 methods are fully implemented. quest_manager.gd has no TODO/FIXME/placeholder text.

## Threat Flags

None. All T-03-0x mitigations from the plan's threat model are present in the implementation:
- T-03-01: `get_quest(qid)` returns `{}` for unknown qid; `is_empty()` guard rejects it
- T-03-02: All reward values cast with defaults via `int(q.get(..., 0))` / `String(q.get(..., ""))`
- T-03-04: `active_quest_count() >= 3` rejects 4th accept call

## Self-Check: PASSED

- `script/quest_manager.gd` exists: confirmed (148 lines)
- `grep -c "^func "` = 10: confirmed
- All 10 signatures match plan exactly: confirmed
- `active_quest_count() >= 3` present (1 match): confirmed
- `global.money +=` present (1 match): confirmed
- `func _ready` present (0 matches): confirmed
- Commit 28066ca present in git log: confirmed
