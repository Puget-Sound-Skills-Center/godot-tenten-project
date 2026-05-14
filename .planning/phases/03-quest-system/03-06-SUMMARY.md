---
phase: "03"
plan: "06"
subsystem: quest-system
tags: [hud, ui, lore, cliff-side, reward-visibility]
dependency_graph:
  requires: [03-05B]
  provides: [lore-hud-slot, cliff-secret-door]
  affects: [script/player.gd, script/cliff_side.gd]
tech_stack:
  added: []
  patterns: [runtime-ui-construction, duck-typed-global-state, flag-polling]
key_files:
  modified:
    - script/player.gd
    - script/cliff_side.gd
decisions:
  - Lore panel placed at Vector2(8,24) directly below money label at Vector2(8,8) — avoids HUD overlap
  - Secret door built as StaticBody2D (solid collision) rather than Area2D — keeps passage physically blocked until unlock
  - Door visibility toggled by global.unlocks["cliff_secret_door"] early-return guard — matches existing unlock pattern in global.gd
metrics:
  duration: "8m"
  completed: "2026-05-14"
---

# Phase 3 Plan 06: Lore HUD Slot and Cliff Secret Door Summary

Surfaced two previously invisible reward types: a lore artifact HUD slot in player.gd and a sealed passage StaticBody2D in cliff_side.gd. Both integrate with existing global state dictionaries without modifying save/load logic.

## What Was Built

### Task 1 — Lore Artifact HUD Slot (script/player.gd)

- Added `_lore_panel` (ColorRect, 80x16, dark amber `Color(0.25,0.20,0.10,0.9)`) at `Vector2(8,24)` in `_hud_layer`
- Added `_lore_label` (font size 8, gold `Color(1.0,0.85,0.4)`) as child of `_lore_panel`
- `_update_hud()` iterates `global.items`; if any key has value > 0, panel becomes visible and label shows the key name (underscores replaced, capitalized). Panel hides when inventory is empty.
- Panel toggles every physics frame via existing `_physics_process` → `_update_hud()` call — no new timer or signal needed.

### Task 2 — Cliff Secret Door (script/cliff_side.gd)

- `_build_secret_door()` called at end of `_ready()` (after all existing spawn/position logic)
- If `global.unlocks.get("cliff_secret_door", false)` is truthy, function returns immediately — door absent
- Otherwise: spawns a `StaticBody2D` named `"cliff_secret_door"` at `Vector2(80,60)` with a 24x24 `RectangleShape2D`, a dark-brown `ColorRect` visual, and a "Sealed Passage" `Label` at font size 6

## Verification Results

| Check | Result |
|-------|--------|
| `_lore_panel\|_lore_label` matches in player.gd | 16 |
| `_build_secret_door\|cliff_secret_door` matches in cliff_side.gd | 4 |
| `for key in global.items` matches in player.gd | 1 |
| `StaticBody2D.new()` matches in cliff_side.gd | 1 |

## Manual Playtest Checklist (End-of-Phase)

1. Start new game, accept story chain quest from town NPC
2. Complete blacksmith reward step — verify `global.items` receives a key with value > 0
3. Enter cliff_side scene — confirm lore HUD panel appears below gold counter with correct item name
4. Complete dungeon merchant reward step — verify cliff door absent when `global.unlocks["cliff_secret_door"] = true`
5. Save game, reload from slot — confirm lore panel still visible and door still absent (persistence via global.gd save/load)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — HUD slot and door are wired to live global state (`global.items`, `global.unlocks`). Display correctness depends on upstream quest reward steps (03-04, 03-05B) populating those dictionaries.

## Self-Check: PASSED

- `script/player.gd` modified — confirmed via grep (16 lore matches)
- `script/cliff_side.gd` modified — confirmed via grep (4 secret door matches)
- `.planning/phases/03-quest-system/03-06-SUMMARY.md` created
