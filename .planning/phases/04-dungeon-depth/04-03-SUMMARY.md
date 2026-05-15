---
phase: 04-dungeon-depth
plan: "03"
subsystem: dungeon
tags: [gdscript, hidden-rooms, exploration, gold-reward, area2d, meta-polling]

requires:
  - phase: 04-01
    provides: lore object pattern and _spawn_lore_object() placement
  - phase: 04-02
    provides: boss_floor_active var and boss floor suppression pattern

provides:
  - _spawn_hidden_room() with Area2D secret wall, hint/prompt labels, proximity detection
  - _pick_hidden_room_position() with spawn/exit zone avoidance
  - _on_secret_wall_body_entered/exited signal handlers setting player_near meta
  - _on_secret_wall_activated() awarding 50 + floor_no * 5 gold and queue_free
  - _process() elif polling branch for secret_wall meta
  - SECRET_WALL_COLOR, HIDDEN_ROOM_PROBABILITY, HIDDEN_ROOM_GOLD_BASE constants

affects: [dungeon-exploration, player-rewards, quest-system]

tech-stack:
  added: []
  patterns:
    - "Secret wall uses same player_near meta proximity pattern as fetch chest"
    - "Area2D body_entered/exited with .bind(area) for stateless signal handlers"
    - "Vector2.ZERO sentinel from position picker signals no valid placement; caller returns early"
    - "boss_floor_active guard reused to suppress hidden rooms on milestone floors"

key-files:
  created: []
  modified:
    - script/dungeon.gd

key-decisions:
  - "SECRET_WALL_COLOR Color(0.25, 0.18, 0.28) — slightly warmer than WALL_COLOR to hint at secret without being obvious"
  - "Hint label ('?') and prompt label ('[E] Secret?') stored as meta references for clean show/hide in signal handlers"
  - "Gold formula: 50 + floor_no * 5 — scales meaningfully without overwhelming economy"
  - "One-shot activation via queue_free() satisfies T-04-06 double-activation threat"
  - "_pick_hidden_room_position() adds explicit _exit_zone() pad check on top of _is_position_clear() since that func only checks _spawn_zone()"

patterns-established:
  - "Player-near prompt pattern: set_meta player_near false at spawn, body_entered sets true + shows labels, body_exited resets; _process polls and acts on interact"

requirements-completed: [DNG-02]

duration: 12min
completed: 2026-05-14
---

# Phase 04 Plan 03: Hidden Rooms Summary

**30%-probability secret wall tile per non-boss floor awards scaled gold (50 + floor * 5) on E-press using Area2D proximity meta pattern**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-14T04:47:00Z
- **Completed:** 2026-05-14T04:59:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Secret wall Area2D with SECRET_WALL_COLOR, hidden hint/prompt labels, and floor_no meta spawns on 30% of non-boss floors
- Proximity enter/exit signal handlers show "[E] Secret?" prompt when player approaches
- _process() elif branch activates hidden room on E-press, awards scaled gold, queue_frees tile (one-shot)
- Placement avoids both spawn zone (via _is_position_clear) and exit zone (explicit pad check)
- Graceful skip when no valid position found after 80 attempts

## Task Commits

1. **Task 1: Add constants and _spawn_hidden_room() + _on_secret_wall_activated()** - `2628a9a` (feat)
2. **Task 2: Wire _spawn_hidden_room() into _ready() and add _process() polling branch** - `ff9f72e` (feat)

## Files Created/Modified
- `script/dungeon.gd` - Added 3 constants, 5 new functions, elif branch in _process(), call site in _ready()

## Decisions Made
- Reused `_pick_save_position()` loop structure verbatim for `_pick_hidden_room_position()` — consistent 80-attempt pattern across all placement helpers
- Added explicit `pad.intersects(_exit_zone())` check in `_pick_hidden_room_position()` because `_is_position_clear()` only guards `_spawn_zone()`; this satisfies T-04-07
- `area.queue_free()` in `_on_secret_wall_activated()` satisfies T-04-06 (double-activation prevention) — area removed before next _process() frame

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Hidden room system complete and satisfies DNG-02
- Pattern is composable — future plans can add room content (enemies, chests) inside the Area2D
- Phase 04-04 (boss floors or lore continuation) can build on boss_floor_active suppression pattern already in place

---
*Phase: 04-dungeon-depth*
*Completed: 2026-05-14*
