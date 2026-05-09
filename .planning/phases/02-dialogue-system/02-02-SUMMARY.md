---
phase: 02-dialogue-system
plan: 02-02
subsystem: dialogue-engine
tags: [godot, gdscript, canvaslayer, ui, pause-lifecycle, dialogue-tree]

requires:
  - 02-01 (autoloads registered, npc_state persisted)
provides:
  - DialogueData.get_node(npc_id, node_id) -> Dictionary lookup API
  - DialogueData.DIALOGUES const with elder + dungeon_merchant trees
  - DialogueManager.open(npc_id, start_node) public API
  - DialogueManager.close() public API
  - DialogueManager.force_close() no-side-effect close (for scene reload)
  - Dialogue panel UI rendered at CanvasLayer layer=30
  - Pause-during-dialogue lifecycle (get_tree().paused = true on open)
  - Quest flag side effect on quest_offer choice (writes to global.npc_state)
affects: [02-03, 02-04]

tech-stack:
  added: []
  patterns:
    - CanvasLayer autoload at layer=30 (above shop=20, below pause=50) — same pattern as pause_menu.gd
    - _pa() helper stamps PROCESS_MODE_ALWAYS on every UI child so input fires while paused
    - Build UI in code (no .tscn) via add_child() chain; clear stale buttons via queue_free() per-render
    - _unhandled_input gated on _panel.visible to avoid stealing input when closed
    - Advance prompt visibility doubles as the gate for advance-vs-choice input handling

key-files:
  created:
    - script/dialogue_data.gd
    - script/dialogue_manager.gd
  modified: []

key-decisions:
  - "Dialogue panel UI is built imperatively in code (no .tscn) — matches existing pause_menu.gd and player.gd shop construction style"
  - "force_close() duplicates close() body rather than calling close() — keeps the no-side-effect contract explicit; prevents future drift if close() ever grows hooks (e.g., emitting a dialogue_closed signal)"
  - "_unhandled_input gates advance on _advance_lbl.visible — not a separate state machine variable. The label IS the state indicator: if it is visible, we are on an advance-only node; if it is hidden, choices are pending and the interact key must be ignored to avoid skipping choice nodes"
  - "_next_node is reset to '' when entering a choice node — prevents stale advance-target leaking from a previous advance-only node"
  - "Choice button signal binds the full choice dict (not an index). queue_free()-then-rebuild on every render cycle means lambda-bound dicts never reference stale buttons"

patterns-established:
  - "Mirror pause_menu.gd._pa() verbatim — copy the helper into every CanvasLayer autoload that needs to survive a paused tree"
  - "Empty-dict guard on data lookup (DialogueData.get_node returns {} on miss) lets the manager auto-close on bad node ids without raising"
  - "The advance prompt label is both UI element and state flag — _advance_lbl.visible == 'this is an advance-only node'"

requirements-completed:
  - DLG-01
  - DLG-02

duration: ~3min
completed: 2026-05-09
---

# Phase 2 Plan 02: Dialogue Engine (DialogueData + DialogueManager)

**Two new autoload scripts that are the engine of the dialogue system — pure data (DialogueData) and CanvasLayer UI with pause lifecycle (DialogueManager). These are the contracts Wave 3 (Plans 02-03 and 02-04) will wire NPCs against.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-09T17:10:00Z
- **Completed:** 2026-05-09T17:13:00Z
- **Tasks:** 2
- **Files created:** 2
- **Files modified:** 0

## Accomplishments

- Created `script/dialogue_data.gd` as a pure-data autoload extending Node, with the `DIALOGUES` const containing the elder NPC tree (greeting, quest_offer w/ 2 choices, quest_accepted, quest_declined, quest_follow_up) and dungeon_merchant tree (greeting, merchant_offer)
- Provided `DialogueData.get_node(npc_id, node_id)` returning empty dict on miss — supports the manager's auto-close-on-unknown-node fail-safe
- Created `script/dialogue_manager.gd` as a CanvasLayer autoload at layer=30 with full UI built in code: full-rect overlay + bottom-strip Panel + MarginContainer + HBox (portrait + right column) + speaker label + body label + choice container + advance prompt
- Mirrored pause_menu.gd's `_pa()` helper and applied it to **every** child node so input fires while paused
- Implemented `open(npc_id, start_node="root")`, `close()`, and `force_close()` — open pauses tree, close/force_close unpause and clear state
- `_render_node()` reads from DialogueData, populates labels, switches between advance prompt and choice buttons, queue_free()s stale buttons each render
- `_on_choice_picked()` writes `quest_accepted_<qid>` flag to `global.npc_state` on `quest_offer` action
- `_unhandled_input()` advances on `interact` key only when panel is visible AND on advance-only nodes (does not skip choice nodes)

## Task Commits

1. **Task 2-B-01: Create dialogue_data.gd** — `b7667b9` (feat)
2. **Task 2-B-02: Create dialogue_manager.gd** — `70d9256` (feat)

## Files Created/Modified

- `script/dialogue_data.gd` — NEW. 68 lines. Extends Node. `DIALOGUES` const + `get_node()` lookup. No class_name (project convention).
- `script/dialogue_manager.gd` — NEW. 194 lines. Extends CanvasLayer. layer=30, PROCESS_MODE_ALWAYS, `_pa()` helper, full UI build, open/close/force_close, _render_node, _on_choice_picked, _unhandled_input. No class_name.

## Verification

All grep acceptance criteria from PLAN.md `<verification>` block confirmed:

- `script/dialogue_data.gd` exists; `extends Node` on line 1
- `"choices"` appears 7 times (1 per node dict — covers all 7 nodes across both NPCs)
- `"quest_offer"` appears 3 times (node key + action field + comment context)
- `func get_node(npc_id: String, node_id: String) -> Dictionary` defined on line 65
- `dungeon_merchant` tree present (1 match — top-level NPC key)
- `class_name` absent in both files (0 matches)
- `script/dialogue_manager.gd` exists
- `get_tree().paused = true` (1 match) inside `open()`
- `get_tree().paused = false` (2 matches) inside `close()` and `force_close()`
- `PROCESS_MODE_ALWAYS` (5 matches: _ready CanvasLayer self + _pa body + State Visibility Contract docs)
- `func _pa` (1 match) — helper present
- `Button.new` (1 match) inside `_render_node`
- `quest_offer` (1 match) inside `_on_choice_picked`
- `npc_state` (3 matches) — quest flag write path
- `layer = 30` (1 match)
- `force_close` (3 matches: function definition, two doc-comment references)

Threat-model mitigations T-2B-01 and T-2B-02 implemented:
- T-2B-01 (DoS via unknown node id): `if node.is_empty(): close()` guard in `_render_node` prevents infinite loop on bad lookups
- T-2B-02 (DoS via stuck pause): `force_close()` is unconditionally safe; ready for dungeon.gd to call before `reload_current_scene()` in Plan 02-04

## Decisions Made

- **force_close() duplicates close() body rather than delegating.** Keeps the no-side-effect guarantee explicit. If `close()` ever grows side effects (e.g., emitting a `dialogue_closed` signal that a quest tracker subscribes to), `force_close()` should NOT trigger them — duplicating the body now prevents future drift.
- **`_advance_lbl.visible` is the state flag for advance-vs-choice input gating.** Avoids introducing a parallel state variable that could desync from the visible UI. The label IS the state.
- **`_next_node` reset to "" when entering a choice node.** Prevents a stale advance-target from a previous advance-only node leaking into the choice node and being followed if the player somehow triggers `_unhandled_input` (defensive — the visibility gate already prevents it, but cheaper to also reset the value).
- **Choice button binds the full choice dict, not an index.** Combined with queue_free()-then-rebuild on every render, no lambda ever closes over a stale button reference.
- **No `class_name` declarations** — matches the project-wide convention (verified across global.gd, pause_menu.gd, npc.gd). Autoloads are referenced by their bare global name (`DialogueData`, `DialogueManager`).

## Deviations from Plan

None — plan executed exactly as written. Both tasks committed atomically immediately after each file write.

## Issues Encountered

None. Plan A (02-01) had already registered the autoload paths in `project.godot`, so the moment Wave 2 created the script files the autoload resolution becomes valid (no project.godot edit needed in this plan).

## Self-Check: PASSED

- script/dialogue_data.gd → FOUND (68 lines, b7667b9)
- script/dialogue_manager.gd → FOUND (194 lines, 70d9256)
- Commit b7667b9 → FOUND in `git log`
- Commit 70d9256 → FOUND in `git log`
- Autoload identifiers `dialogue_data` and `dialogue_manager` registered in `project.godot` (verified — registration done in plan 02-01, files now resolve)
- All grep AC pass (counts above)

## Next Phase Readiness

- `DialogueData` and `DialogueManager` autoloads are now backed by real implementations
- `DialogueManager.open("elder", "greeting")` is ready to be called from `npc.gd` (Plan 02-03 will wire the world-facing NPC trigger)
- `DialogueManager.open("dungeon_merchant", "greeting")` is ready to be called from a new dungeon NPC script (Plan 02-04 will create `dungeon_dialogue_npc.gd` and spawn it from `dungeon.gd`)
- `DialogueManager.force_close()` is ready to be called from `dungeon.gd._check_next_floor()` before `reload_current_scene()` to prevent stuck-pause across floor transitions
- **Wave 3 (Plans 02-03 and 02-04) is unblocked**

---
*Phase: 02-dialogue-system*
*Completed: 2026-05-09*
