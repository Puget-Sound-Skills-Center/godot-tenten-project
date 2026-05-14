---
phase: "03"
plan: "04"
subsystem: quest-log-ui
tags: [quest, ui, overlay, canvas-layer, tab-toggle]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [quest-log-overlay]
  affects: [pause-system, dialogue-manager]
tech_stack:
  added: []
  patterns: [canvas-layer-overlay, process-mode-always, duck-typed-autoload, runtime-ui-construction]
key_files:
  created: [script/quest_log.gd]
  modified: []
decisions:
  - "layer=29 keeps quest log below pause menu (layer 30+) but above game HUD"
  - "Dialogue guard prevents Tab opening quest log while NPC dialogue is active"
  - "max 3 entries matches UI-SPEC.md; overflow silently ignored"
  - "Autoload registration was handled in Plan 01 — script only needed here"
metrics:
  duration: "< 5 min"
  completed: "2026-05-14"
---

# Phase 03 Plan 04: Quest Log UI Overlay Summary

Created `script/quest_log.gd` — a Tab-toggled CanvasLayer overlay showing up to 3 active quests, pausing the scene tree while open.

## Node Hierarchy

```
CanvasLayer (layer=29, PROCESS_MODE_ALWAYS)
└── _overlay: ColorRect (full-rect, alpha=0.75, hidden by default)
    └── _panel: ColorRect (200x220px, anchored right, warm dark bg)
        └── MarginContainer (12px l/r, 8px t/b)
            └── _vbox: VBoxContainer (sep=4)
                ├── header: Label ("Quests", gold color, font_size=12)
                ├── divider: ColorRect (176x1px, semi-transparent)
                ├── _entries_vbox: VBoxContainer (sep=8, populated on open)
                ├── _empty_lbl: Label ("No active quests.", visible when 0 active)
                └── _hint_lbl: Label ("[Tab] Close", font_size=10)
```

Each entry in `_entries_vbox` is a VBoxContainer with:
- Quest display name (gold, font_size=12)
- Objective string from `quest_manager.get_objective_string(qid)` (white, font_size=11)
- Appends " — Return to NPC" when status is `ready_to_complete`

## Toggle / Pause Behavior

- **Open:** `_refresh()` rebuilds entries from `global.quest_state`, sets `_overlay.visible = true`, calls `get_tree().paused = true`
- **Close:** sets `_overlay.visible = false`, calls `get_tree().paused = false`
- All nodes use `PROCESS_MODE_ALWAYS` so the overlay responds to Tab while paused
- `force_close()` available for external callers (e.g. scene transitions)

## Dialogue Guard

`_unhandled_input` checks `dialogue_manager._panel != null and dialogue_manager._panel.visible` before allowing open — prevents quest log from opening on top of active NPC dialogue.

## Autoload Note

The `quest_log` autoload entry (`res://script/quest_log.gd`) was registered in `project.godot` during Plan 01. This plan only creates the script file itself.

## Deviations from Plan

None — plan executed exactly as written.
