---
phase: 2
slug: dialogue-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-09
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — Godot 4.6 GDScript project, no test runner configured |
| **Config file** | none |
| **Quick run command** | `grep` checks (structural correctness — see Per-Task map below) |
| **Full suite command** | Play in Godot Editor — interact with NPCs, verify dialogue behaviors |
| **Estimated runtime** | ~30 seconds (grep checks); ~5 minutes (manual play-test) |

---

## Sampling Rate

- **After every task commit:** Run grep-based acceptance criteria from task `<acceptance_criteria>` block
- **After every plan wave:** Manual play-test in Godot Editor (run project, interact with NPCs)
- **Before `/gsd-verify-work`:** Full manual play-test must pass all 5 success criteria
- **Max feedback latency:** 30 seconds (grep) / 5 minutes (play-test)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 2-A-01 | A | 0 | DLG-01 | grep | `grep "dialogue_manager" project.godot` | ⬜ pending |
| 2-A-02 | A | 0 | DLG-01, DLG-03 | grep | `grep "npc_state" script/global.gd` | ⬜ pending |
| 2-B-01 | B | 1 | — | grep | `ls script/dialogue_data.gd script/dialogue_manager.gd` | ⬜ pending |
| 2-B-02 | B | 1 | DLG-01 | grep | `grep "get_tree().paused = true" script/dialogue_manager.gd` | ⬜ pending |
| 2-B-03 | B | 1 | DLG-01 | grep | `grep "PROCESS_MODE_ALWAYS" script/dialogue_manager.gd` | ⬜ pending |
| 2-B-04 | B | 1 | DLG-02 | grep | `grep "Button.new" script/dialogue_manager.gd` | ⬜ pending |
| 2-C-01 | C | 2 | DLG-01, DLG-02, DLG-03, DLG-04 | grep | `grep "DialogueManager.open" script/npc.gd` | ⬜ pending |
| 2-C-02 | C | 2 | DLG-02 | grep | `grep "choices" script/dialogue_data.gd` | ⬜ pending |
| 2-C-03 | C | 2 | DLG-03 | grep | `grep "npc_state" script/npc.gd` | ⬜ pending |
| 2-C-04 | C | 2 | DLG-04 | grep | `grep "quest_offer" script/dialogue_data.gd script/dialogue_manager.gd` | ⬜ pending |
| 2-D-01 | D | 2 | DLG-05 | grep | `ls script/dungeon_dialogue_npc.gd && grep "dungeon_dialogue_npc" script/dungeon.gd` | ⬜ pending |
| 2-D-02 | D | 2 | DLG-05 | grep | `grep "DialogueManager.open" script/dungeon_dialogue_npc.gd` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 tasks must complete before any implementation waves begin. They establish the scaffolding that all other tasks depend on.

- [ ] `project.godot` — add `dialogue_data` and `dialogue_manager` to `[autoload]` section
- [ ] `script/global.gd` — add `npc_state` dict + `var_to_str` save + `str_to_var` load + reset entries

*No test framework to install — project uses GDScript with no external test runner.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dialogue panel opens and player cannot move | DLG-01 | Requires runtime observation | Walk to NPC, press E, verify panel appears and player is frozen |
| Choice buttons appear for branching node | DLG-02 | Requires visual inspection | Trigger a 2-choice node; verify 2 buttons rendered; pick each path |
| NPC shows different text after quest accept | DLG-03 | Requires state + dialogue flow | Accept quest, close dialogue, re-open; verify different opening text |
| Accepting quest sets npc_state flag | DLG-04 | Requires runtime state inspection | Accept quest; save game; load save; verify quest still accepted |
| Declining quest shows NPC refusal dialogue | DLG-04 | Requires behavioral observation | Trigger quest offer; decline; verify NPC responds with decline text |
| Dungeon NPC visible and interactable in room | DLG-05 | Requires visual + input verification | Enter dungeon; find NPC; press E; dialogue panel opens |
| game pauses during dialogue (no enemy movement) | DLG-01 | Requires runtime observation | Open dialogue while near enemies; verify enemies freeze |
| Dialogue closes cleanly (game unpauses) | DLG-01 | Requires runtime observation | Advance through all nodes; verify game unpauses, player can move |

---

## Validation Sign-Off

- [ ] All tasks have grep-verifiable `<acceptance_criteria>`
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0: autoloads registered, npc_state wired in global.gd
- [ ] No watch-mode flags (no test runner)
- [ ] Feedback latency < 30s (grep) / 5min (play-test)
- [ ] `nyquist_compliant: true` set in frontmatter after all tasks pass

**Approval:** pending
