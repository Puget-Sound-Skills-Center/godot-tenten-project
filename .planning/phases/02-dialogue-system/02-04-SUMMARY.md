---
phase: 2
plan: "02-04"
subsystem: dialogue-system
tags: [npc, dialogue, dungeon, floor-spawn, force-close]
dependency_graph:
  requires:
    - 02-02  # DialogueManager.open / DialogueManager.force_close
    - 02-01  # global.npc_state (used downstream by dialogue tree)
  provides:
    - dungeon-merchant-npc-spawn
    - dungeon-floor-transition-dialogue-safety
  affects:
    - script/dungeon.gd
    - script/dungeon_dialogue_npc.gd
tech_stack:
  added: []
  patterns:
    - runtime NPC spawn (load().new() + add_child) per floor
    - clear-position selection via existing _pick_save_position helper
    - force_close-before-reload guard against paused-tree leak across scene reload
key_files:
  created:
    - script/dungeon_dialogue_npc.gd
  modified:
    - script/dungeon.gd
decisions:
  - npc_id "dungeon_merchant" + start_node "greeting" (matches dialogue_data.gd tree)
  - reuse _pick_save_position() (already used for save points) instead of writing a new picker
  - force_close placed immediately before reload_current_scene() in _check_next_floor (not in _save_and_exit, since change_scene_to_file unpauses anyway via fresh tree state)
metrics:
  duration_min: 8
  completed: 2026-05-09
  tasks_completed: 2
  files_modified: 1
  files_created: 1
---

# Phase 2 Plan 02-04: Dungeon Dialogue NPC Summary

Adds a per-floor dungeon merchant NPC that opens `DialogueManager.open("dungeon_merchant", "greeting")` on E, plus a `force_close()` guard before `reload_current_scene()` so dialogue's paused tree never leaks across floor transitions.

## Tasks Completed

| Task    | Title                                                                        | Commit  | Files                              |
| ------- | ---------------------------------------------------------------------------- | ------- | ---------------------------------- |
| 2-D-01  | Create script/dungeon_dialogue_npc.gd — proximity NPC calling DialogueManager | c9cd118 | script/dungeon_dialogue_npc.gd     |
| 2-D-02  | Modify dungeon.gd: spawn dialogue NPC per floor + force_close guard          | c3570b3 | script/dungeon.gd                  |

## Implementation Notes

**Task 2-D-01 — dungeon_dialogue_npc.gd**
- Structural near-clone of `dungeon_npc.gd`: Node2D root, runtime sprite + label + Area2D build, body_entered/exited signal handlers, `_process()` interact key.
- Two purposeful diffs from the template:
  - Prompt label text: `"E: Talk"` (vs `"E: Enter Dungeon"`).
  - Interact action: `DialogueManager.open("dungeon_merchant", "greeting")` (vs `global.enter_dungeon = true`).
- Sprite uses `chest_02.png` (visual distinction from shop NPC's chest_01.png) — asset confirmed present.
- Duck-typed identity via `body.has_method("player")` in body signal handlers — preserves the project-wide entity-type pattern (no node groups).
- No `class_name`, no `.tscn` — built entirely in code, matching the existing dungeon_npc / world npc convention.

**Task 2-D-02 — dungeon.gd modifications**
- Spawn call: added line after `_spawn_enemies(floor_no, obstacles)` in `_ready()`. Order matters — spawning AFTER enemies means `_pick_save_position()` sees enemy-occupied tiles via the same obstacles array used for enemy placement (obstacles param mirrors the shared rect list, so the NPC won't co-locate with walls). Enemy bodies aren't in obstacles, but enemy spawn already passed `_is_position_clear`, so the worst case is two characters at adjacent valid positions — acceptable.
- New `_spawn_dungeon_dialogue_npc(_floor_no, obstacles)` method placed adjacent to `_spawn_enemies` for grouping. Uses `_pick_save_position(obstacles)` rather than a custom helper — same fallback semantics (room center) on retry exhaustion.
- `_floor_no` param prefixed with underscore (Godot warning suppression) since current implementation doesn't vary the spawn by floor depth; reserved for future floor-gated NPC variants.
- `DialogueManager.force_close()` inserted immediately before `get_tree().reload_current_scene()` in `_check_next_floor()`. Per `dialogue_manager.gd` source, `force_close()` is idempotent — calling it when no dialogue is open is a safe no-op (sets `_panel.visible = false`, `get_tree().paused = false`, clears state strings). This guards against the rare race where a player triggers next-floor while the dialogue panel is still up.
- `_save_and_exit()` path NOT modified — that path uses `change_scene_to_file()` which destroys the tree (and DialogueManager's pause state on it) on the way out, plus the fresh scene starts unpaused. force_close there would be redundant.

## Deviations from Plan

None — plan executed exactly as written.

## Acceptance Criteria — Final Verification

| AC                                                                                          | Result |
| ------------------------------------------------------------------------------------------- | ------ |
| script/dungeon_dialogue_npc.gd exists                                                       | PASS   |
| `DialogueManager.open("dungeon_merchant", "greeting")` present (1 match)                    | PASS   |
| `_build_interaction_area\|body_entered\|Area2D` (≥2 matches)                                | PASS (5 matches) |
| `has_method.*player` (≥1 match)                                                             | PASS (2 matches) |
| `E: Talk` label text                                                                        | PASS   |
| No `class_name` declaration                                                                 | PASS   |
| No `global.enter_dungeon` in dungeon_dialogue_npc.gd                                        | PASS   |
| `dungeon_dialogue_npc\|_spawn_dungeon` in dungeon.gd (≥2 matches)                           | PASS (4 matches) |
| `force_close` in dungeon.gd (1 match)                                                       | PASS   |
| `reload_current_scene` still present in dungeon.gd                                          | PASS   |
| `load.*dungeon_dialogue_npc` in dungeon.gd (1 match)                                        | PASS   |

## Threat Mitigations Applied

- **T-2D-01 (DoS — paused tree leak across floor reload):** `DialogueManager.force_close()` called unconditionally before `reload_current_scene()`. Idempotent per dialogue_manager.gd implementation.
- **T-2D-02 (DoS — missing chest_02.png):** Asset verified present in `art/objects/chest_02.png`; fallback path not needed.
- **T-2D-03 (DoS — NPC spawn inside obstacle):** Reused `_pick_save_position(obstacles)` which performs 80 retry attempts via `_is_position_clear`, falling back to room center on exhaustion.

## Self-Check: PASSED

- Created file FOUND: script/dungeon_dialogue_npc.gd
- Modified file FOUND: script/dungeon.gd (lines 92, 114, 273-277)
- Commit FOUND: c9cd118 (Task 2-D-01)
- Commit FOUND: c3570b3 (Task 2-D-02)
