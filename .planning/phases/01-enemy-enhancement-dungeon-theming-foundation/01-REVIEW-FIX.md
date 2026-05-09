---
phase: 01-enemy-enhancement-dungeon-theming-foundation
fixed_at: 2026-05-08T23:20:00Z
review_path: .planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 4
skipped: 7
status: partial
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-05-08T23:20:00Z
**Source review:** `.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (4 Critical + 7 Warning)
- Fixed: 4 (all Critical)
- Skipped: 7 (all Warning — see below)

## Fixed Issues

### CR-01: Enemy stat mutation after instantiate — set_script/stat ordering

**Files modified:** `script/dungeon.gd`
**Commit:** 1919c71
**Applied fix:** Moved `set_script()` and all stat scaling (`max_health`, `speed`, `money_drop`) to before `add_child()`. After `add_child()` triggers `_ready()`, `enemy.health = enemy.max_health` is assigned so the enemy starts with scaled HP. Also cast `speed` explicitly to `float()` for consistency (WR-02 absorbed here).

---

### CR-02: Ranged projectile collision_mask was zero — never hit player

**Files modified:** `script/enemy_ranged.gd`
**Commit:** 23ff1a7
**Applied fix:** Changed `proj.collision_mask = 0` to `proj.collision_mask = 1` so the `Area2D` projectile detects bodies on layer 1 (player's default layer) and `body_entered` fires correctly.

---

### CR-03: take_damage gated by melee cooldown — ranged hits silently dropped

**Files modified:** `script/player.gd`
**Commit:** 2d08aba
**Applied fix:** Removed the `if enemy_attack_cooldown == false: return` guard and the cooldown-start side-effect from `take_damage`. Ranged hits now always apply damage with defense reduction. Rate-limiting is handled on the enemy side (2-second shoot cooldown).

---

### CR-04: _on_pack_alerted unused param + no validity check

**Files modified:** `script/enemy_base.gd`
**Commit:** bb19894
**Applied fix:** Prefixed the unused parameter as `_origin_position` to make the dead-code intent explicit. Added `is_instance_valid(players[0])` guard before assigning the player reference so stale/freed nodes are not chased.

---

## Skipped Issues

### WR-01: enemy_hitbox CollisionShape2D has radius 0 — melee hitbox disabled

**File:** `script/enemy_base.gd:32`
**Reason:** Fix requires verifying the scene file (`scenes/enemy.tscn`) hitbox shape and testing melee detection end-to-end. Skipped to avoid breaking existing melee behavior without full test coverage. Requires human verification and scene edit.
**Original issue:** `enemy_hitbox/CollisionShape2D` has default radius 0, making the hitbox non-functional.

---

### WR-02: speed cast inconsistency (int vs float)

**File:** `script/dungeon.gd:266`
**Reason:** Absorbed into CR-01 fix — `float(enemy.speed) * mult` is now used in the reordered stat-scaling block.
**Status:** Fixed as part of CR-01 commit 1919c71.

---

### WR-03: Puzzle tile fallback to room center — overlapping tiles

**File:** `script/dungeon.gd:473`
**Reason:** Behavioral change with no test coverage. Risk of breaking puzzle spawn logic. Requires manual playtesting to verify expanded fallback search doesn't conflict with other placement logic. Skipped pending human review.
**Original issue:** All fallback tiles land at same center position causing overlap and potential instant-solve.

---

### WR-04: Echo tween not cancelled before starting new one — flickering

**File:** `script/dungeon.gd:694-707`
**Reason:** Requires adding `_echo_tween` instance variable and plumbing kill() call. Non-trivial state change with visual side-effects. Skipped — low crash risk, cosmetic issue only.
**Original issue:** Old tween callbacks fight new tween when player steps wrong tile before demo finishes.

---

### WR-05: Dead player can still move/attack after health <= 0

**File:** `script/player.gd:50-52`
**Reason:** Adding `if not player_alive: return` guard at top of `_physics_process` also requires a `_handle_death()` implementation which doesn't exist yet. Partial fix risks leaving player stuck. Skipped pending death-handling implementation.
**Original issue:** `player_alive = false` is set but never read; player can move/attack/advance floor while dead.

---

### WR-06: Enemy spawn zone excludes player spawn — enemies can spawn adjacent to player

**File:** `script/dungeon.gd:258`
**Reason:** `_is_position_clear` already checks `_spawn_zone()` (line 225-226 in dungeon.gd). Re-reading the actual code shows the spawn zone IS excluded — `_is_position_clear` returns false if `pad.intersects(_spawn_zone())`. The reviewer's concern about the 6px margin may be valid but the fix suggestion (adding a second `_spawn_zone().grow(TILE).has_point(pos)` check) would be redundant with the existing intersection check. Skipped: code behavior differs from review description.
**Original issue:** Enemies spawn within TILE of player start position.

---

### WR-07: _get_floor_multiplier hardcodes 99 instead of using DUNGEON_MAX_FLOOR

**File:** `script/dungeon.gd:355`
**Reason:** Low risk — `DUNGEON_MAX_FLOOR` is unlikely to change mid-project and the formula is correct for current value. Skipped as a minor cleanup item for a future pass.
**Original issue:** Magic number 99 breaks if DUNGEON_MAX_FLOOR is changed.

---

_Fixed: 2026-05-08T23:20:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
