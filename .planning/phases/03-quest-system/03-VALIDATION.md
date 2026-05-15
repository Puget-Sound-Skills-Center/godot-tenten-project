---
phase: 3
slug: quest-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — Godot 4.6 GDScript project, no test runner configured |
| **Config file** | none |
| **Quick run command** | `grep` checks (structural correctness — see Per-Task map below) |
| **Full suite command** | Play in Godot Editor — accept quests, run dungeon, verify quest tracking behaviors |
| **Estimated runtime** | ~30 seconds (grep checks); ~10 minutes (manual play-test full flow) |

---

## Sampling Rate

- **After every task commit:** Run grep-based acceptance criteria from task `<acceptance_criteria>` block
- **After every plan wave:** Manual play-test in Godot Editor (run project, accept quest, verify tracking)
- **Before `/gsd-verify-work`:** Full manual play-test must pass all 6 success criteria
- **Max feedback latency:** 30 seconds (grep) / 10 minutes (play-test)

---

## Per-Task Verification Map

> Populated by planner during PLAN.md creation. Placeholder rows below derived from research.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 3-A-01 | A | 0 | QST-09 | grep | `grep "quest_state\|items\|unlocks" script/global.gd` | ⬜ pending |
| 3-A-02 | A | 0 | QST-09 | grep | `grep "quest_manager\|quest_data\|quest_log" project.godot` | ⬜ pending |
| 3-A-03 | A | 0 | QST-01 | grep | `grep "quest_state\|items\|unlocks" script/global.gd \| grep "var "` | ⬜ pending |
| 3-B-01 | B | 1 | QST-01,QST-06,QST-07,QST-08 | grep | `grep "on_enemy_killed\|accept_quest\|complete_quest" script/quest_manager.gd` | ⬜ pending |
| 3-B-02 | B | 1 | QST-09 | grep | `grep "var_to_str.*quest_state\|str_to_var.*quest_state" script/global.gd` | ⬜ pending |
| 3-C-01 | C | 1 | QST-01 | grep | `grep "quest_manager.on_enemy_killed" script/enemy_base.gd` | ⬜ pending |
| 3-C-02 | C | 1 | QST-02 | grep | `grep "_spawn_fetch_chest_if_needed\|has_active_fetch_quest" script/dungeon.gd` | ⬜ pending |
| 3-C-03 | C | 1 | QST-03 | grep | `grep "on_floor_reached" script/dungeon.gd` | ⬜ pending |
| 3-D-01 | D | 2 | QST-05 | grep | `grep "quest_log\|PROCESS_MODE_ALWAYS" script/quest_log.gd` | ⬜ pending |
| 3-D-02 | D | 2 | QST-05 | grep | `grep "get_tree().paused" script/quest_log.gd` | ⬜ pending |
| 3-E-01 | E | 2 | QST-04 | grep | `grep "story_chain\|advance_story_chain" script/quest_manager.gd` | ⬜ pending |
| 3-E-02 | E | 2 | QST-04 | grep | `ls script/blacksmith_npc.gd && grep "blacksmith" script/world.gd` | ⬜ pending |
| 3-F-01 | F | 3 | QST-07,QST-09 | grep | `grep "ancient_map_fragment" script/quest_data.gd` | ⬜ pending |
| 3-F-02 | F | 3 | QST-08 | grep | `grep "cliff_secret_door\|global.unlocks" script/cliff_side.gd` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 tasks must complete before any implementation waves begin. They establish the scaffolding that all other tasks depend on.

- [ ] `project.godot` — add `quest_manager`, `quest_data`, `quest_log` to `[autoload]` section
- [ ] `project.godot` — add `quest_log` input action (Tab key, physical_keycode 4194305) to `[input]` section
- [ ] `script/global.gd` — add `var quest_state: Dictionary = {}`, `var items: Dictionary = {}`, `var unlocks: Dictionary = {}` declarations
- [ ] `script/global.gd` — add `var_to_str` save entries (quest_state/items/unlocks) to all 4 slot save methods
- [ ] `script/global.gd` — add `str_to_var` load entries to all 4 slot load methods
- [ ] `script/global.gd` — add `quest_state = {}; items = {}; unlocks = {}` to `reset_for_new_game()`

*No test framework to install — project uses GDScript with no external test runner.*

---

## Phase Requirements → Verification Map

| Req ID | Behavior | Test Method | Verifiable Condition |
|--------|----------|-------------|----------------------|
| QST-01 | Kill quest auto-tracks enemy kills | Accept kill quest, kill 10 melee enemies | `global.quest_state["kill_melee_10"]["progress"] == 10`; status = "ready_to_complete" |
| QST-02 | Fetch quest: pick up item in dungeon, return to NPC | Accept fetch quest, enter dungeon, open chest, return to elder | `global.items["ancient_relic_fragment"] == 1`; NPC offers complete dialogue |
| QST-03 | Reach-floor quest: arrive at target floor alive | Accept reach quest, reach floor 10 | `global.quest_state["reach_floor_10"]["reached"] == true` after floor advance |
| QST-04 | Story chain: 3-step multi-NPC sequence | Accept chain from elder, talk blacksmith, find dungeon merchant | `global.quest_state["story_chain"]["step"]` advances 0→1→2→complete |
| QST-05 | Quest log shows active quests | Press Tab, verify panel opens with entries | Panel visible; up to 3 entries; each shows name + objective |
| QST-06 | Completing quest rewards gold | Complete any quest, check gold | `global.money` increased by reward_gold amount |
| QST-07 | Quest can reward special item | Complete story chain | `global.items["ancient_map_fragment"] == 1`; lore HUD slot visible in player HUD |
| QST-08 | Quest can unlock dialogue/areas | Complete reach-floor or story chain | `global.unlocks["cliff_secret_door"] == true`; blocking collision removed in cliff_side |
| QST-09 | Quest state persists across save/load | Save mid-quest, load, verify state intact | `global.quest_state` keys and progress values identical after load cycle |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Quest log panel opens on Tab, game pauses | QST-05, D-02 | Requires runtime observation | Press Tab in-game; verify panel appears and enemies freeze |
| Quest log shows name + objective only (no rewards) | QST-05, D-03 | Requires visual inspection | Open quest log; verify entries show only name + objective string |
| Quest log closes on second Tab press, game unpauses | QST-05, D-02 | Requires runtime observation | Press Tab twice; verify panel disappears, player can move |
| Tab does not open quest log while dialogue is open | D-02, pitfall 1 | Requires behavioral observation | Open NPC dialogue; press Tab; verify quest log does NOT open |
| Kill count increments live in quest log | QST-01 | Requires runtime display | Accept kill quest; open log; kill enemy; reopen log; verify counter updated |
| Fetch chest appears in dungeon only when fetch quest active | D-06 | Requires conditional spawn | Run without quest → no chest; accept fetch quest → enter dungeon → chest present |
| Lore artifact HUD slot appears on item reward | D-09, QST-07 | Requires visual HUD verification | Complete story chain; verify small lore panel appears in HUD corner |
| 3-quest cap enforced (NPCs stop offering at 3 active) | D-04 | Requires behavioral observation | Accept 3 quests; approach NPC; verify no quest offer appears |
| Story chain quest log shows next NPC to visit | D-11 | Requires display inspection | Accept chain; open log; verify shows "Talk to: Blacksmith" |
| Save/load preserves quest progress across session | QST-09 | Requires full save/load cycle | Accept kill quest with 5/10 progress; save; load; verify 5/10 shown in log |

---

## Validation Sign-Off

- [ ] All tasks have grep-verifiable `<acceptance_criteria>`
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0: autoloads registered, global.gd dicts wired (quest_state, items, unlocks)
- [ ] No watch-mode flags (no test runner)
- [ ] Feedback latency < 30s (grep) / 10min (play-test)
- [ ] `nyquist_compliant: true` set in frontmatter after all tasks pass

**Approval:** pending
