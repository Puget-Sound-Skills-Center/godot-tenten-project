---
phase: 03-quest-system
plan: "01"
subsystem: quest-foundation
tags: [global-state, autoload, save-system, input-map]
dependency_graph:
  requires: []
  provides: [global.quest_state, global.items, global.unlocks, quest_data autoload, quest_manager autoload path, quest_log autoload path, Tab input action]
  affects: [script/global.gd, script/quest_data.gd, project.godot]
tech_stack:
  added: [quest_data.gd autoload]
  patterns: [var_to_str/str_to_var ConfigFile serialization, GDScript const dict registry, Godot autoload dependency ordering]
key_files:
  created: [script/quest_data.gd]
  modified: [script/global.gd, project.godot]
decisions:
  - Quest state stored in three separate dicts (quest_state, items, unlocks) under a 'quests' ConfigFile section, mirroring npc_state pattern
  - quest_data before quest_manager before quest_log in autoload order (dependency chain)
  - Tab bound via physical_keycode 4194305 (KEY_TAB constant)
metrics:
  duration: ~10 min
  completed: "2026-05-14"
requirements: [QST-09]
---

# Phase 3 Plan 01: Quest System Foundation Scaffold Summary

Wave 0 foundation scaffolding: adds three persistent state dicts to global.gd with full save/load/reset integration, creates the quest_data.gd registry autoload with 4 quest definitions, and registers all Phase 3 autoloads plus the Tab input action in project.godot.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add quest_state/items/unlocks to global.gd | 259dccb | script/global.gd |
| 2 | Create quest_data.gd with QUESTS const + get_quest | e10cc4a | script/quest_data.gd |
| 3 | Register autoloads + Tab input in project.godot | fd55220 | project.godot |

## Files Created/Modified

- `script/global.gd` — +22 lines: three dict declarations, reset block, 3x save lines, 12x load lines with null guards
- `script/quest_data.gd` — new file, 61 lines: 4 quest definitions + get_quest accessor
- `project.godot` — +7 lines: 3 autoload entries + quest_log input action block

## Key Verification Results

- `grep -c "var quest_state|var items|var unlocks|quests.*quest_state|quests.*items|quests.*unlocks" script/global.gd` → 9 matches
- All 3 functions (reset_for_new_game, save_to_slot, load_from_slot) + slot_preview still present
- quest_data.gd: 7 matches for 4 quest key strings + type-specific fields
- project.godot: quest_data at line 24 < quest_manager at 25 < quest_log at 26 (autoload section); quest_log input action at line 74 with physical_keycode 4194305
- Existing autoloads (global, dialogue_data) and input actions (interact) untouched

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. quest_manager.gd and quest_log.gd are referenced as autoload paths but their script files do not yet exist — this is intentional. Godot will error on load until Plans B and C (Wave 1/2) create those files. This is the expected Wave 0 state.

## Self-Check: PASSED

- `script/quest_data.gd` exists: confirmed
- `script/global.gd` modified: confirmed (22 insertions)
- `project.godot` modified: confirmed (7 insertions)
- Commits 259dccb, e10cc4a, fd55220: all present in git log
