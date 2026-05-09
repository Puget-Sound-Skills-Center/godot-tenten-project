---
phase: 1
slug: enemy-enhancement-dungeon-theming-foundation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-08
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — Godot 4.6 GDScript project, no test runner configured |
| **Config file** | none |
| **Quick run command** | `grep -r "is_instance_valid" script/npc.gd script/dungeon_npc.gd` |
| **Full suite command** | Play in Godot Editor — enter dungeon, verify enemy behaviors |
| **Estimated runtime** | ~30 seconds (grep checks); ~5 minutes (manual play-test) |

---

## Sampling Rate

- **After every task commit:** Run grep-based acceptance criteria from task `<acceptance_criteria>` block
- **After every plan wave:** Manual play-test in Godot Editor (run project, enter dungeon)
- **Before `/gsd-verify-work`:** Full manual play-test must pass all 5 success criteria
- **Max feedback latency:** 30 seconds (grep) / 5 minutes (play-test)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 1-A-01 | A | 1 | PRE-01 | T-01A-01 | No freed-ref crash when leaving dungeon | grep | `grep "is_instance_valid" script/npc.gd script/dungeon_npc.gd` | ✅ green |
| 1-A-02 | A | 1 | PRE-02, PRE-03 | T-01A-02 | Health bar shows correct max; spawn capped | grep | `grep "max_health" script/enemy_base.gd && grep "mini(5" script/dungeon.gd` | ✅ green |
| 1-A-03 | A | 1 | PRE-01 | — | player.take_damage exists | grep | `grep "func take_damage" script/player.gd` | ✅ green |
| 1-B-01 | B | 2 | ENM-02, ENM-03 | — | Fast/tank scripts exist with stat overrides | grep | `grep "speed \*= 1.5" script/enemy_fast.gd && grep "max_health \*= 2" script/enemy_tank.gd` | ✅ green |
| 1-B-02 | B | 2 | ENM-01 | T-01B-02 | Ranged uses _my_projectiles (no scene-wide scan) | grep | `grep "_my_projectiles" script/enemy_ranged.gd` | ✅ green |
| 1-C-01 | C | 3 | DNG-01 | — | Theme dict covers 3 floor ranges | grep | `grep "_get_dungeon_theme" script/dungeon.gd` | ✅ green |
| 1-C-02 | C | 3 | ENM-01, ENM-02, ENM-03, ENM-04 | — | Spawner picks variant + applies scaling | grep | `grep "enemy_ranged\|enemy_fast\|enemy_tank" script/dungeon.gd` | ✅ green |
| 1-D-01 | D | 2 | ENM-05 | T-01D-01 | Pack alert uses call_group (no _process polling) | grep | `grep "call_group" script/enemy_base.gd` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*No test framework to install — this project uses GDScript with no external test runner.*

Existing infrastructure covers all phase requirements via:
- Grep-based acceptance criteria (per task)
- Godot Editor play-test (manual behavioral verification)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Enemy health bar shows correct max HP | PRE-02 | Requires visual inspection in running game | Run project → enter dungeon → observe health bar max matches enemy HP |
| Ranged enemy backs away + fires projectile | ENM-01 | Requires behavioral observation | Enter dungeon on floor 34+ → verify ranged enemy retreats and shoots |
| Fast enemy visibly faster than melee | ENM-02 | Requires comparative observation | Enter dungeon on floor 67+ → compare fast enemy movement speed to melee |
| Tank enemy visually distinct (modulate tint) | ENM-03 | Requires visual inspection | Enter dungeon on floor 67+ → verify tank enemy has red/dark modulate |
| Floor 50 enemies tougher than floor 1 | ENM-04 | Requires comparative play | Die on floor 1 vs floor 50, observe HP bar depletion rate |
| Pack activates on single detection | ENM-05 | Requires behavioral observation | Approach one enemy → verify nearby enemies activate without approaching them |
| Dungeon color changes at floor 34 and floor 67 | DNG-01 | Requires visual inspection | Advance to floor 34 → observe color palette shift; advance to floor 67 → observe second shift |
| No freed-reference crash on scene exit | PRE-01 | Requires runtime observation | Exit dungeon mid-run → verify no error in Godot Output panel |

---

## Validation Sign-Off

- [ ] All tasks have grep-verifiable `<acceptance_criteria>`
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0: N/A (no test framework)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (grep) / 5min (play-test)
- [ ] `nyquist_compliant: true` set in frontmatter after all tasks pass

**Approval:** ✅ all grep checks green — 2026-05-09
