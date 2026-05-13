---
phase: 01-enemy-enhancement-dungeon-theming-foundation
verified_at: 2026-05-13T23:40:00Z
status: gaps_found
must_haves_checked: 20
must_haves_passed: 18
must_haves_failed: 2
gaps:
  - truth: "Floor 50 enemies have ~2x base stats; floor 100 enemies have ~3x"
    status: failed
    reason: >
      Stat scaling in dungeon.gd _spawn_enemies() is applied BEFORE add_child() (lines 267-269).
      When add_child() fires, variant _ready() (enemy_fast, enemy_tank, enemy_ranged) overwrites
      max_health, speed, and money_drop with their type-specific base values, discarding the scaling.
      Only base melee enemies (which do not override stats in _ready()) receive correct scaling.
      The health re-sync (line 272, post-add_child) correctly sets health = max_health, but max_health
      is the unscaled variant base value at that point. At floor 50 a ranged enemy has max_health=60
      instead of ~120; a tank has 300 instead of ~600.
    artifacts:
      - path: "script/dungeon.gd"
        issue: >
          Lines 267-269 scale max_health/speed/money_drop before add_child. Variant _ready() fires
          on add_child and overwrites those values. Only line 272 (health re-sync) is correctly
          placed after add_child, but it syncs to the now-unscaled max_health.
    missing:
      - "Move the mult calculation and all three scaling assignments (max_health, speed, money_drop) to AFTER add_child, before the health re-sync on line 272."

  - truth: "player.gd take_damage() uses invincibility frames to prevent double-hit stacking"
    status: failed
    reason: >
      Plan A specified take_damage() must reuse enemy_attack_cooldown as invincibility frames
      ("if enemy_attack_cooldown == false: return"). The actual implementation at player.gd line 137
      omits this guard entirely — it applies damage unconditionally on every call. A ranged projectile
      can hit the player simultaneously with a melee enemy in the same frame and deal double damage,
      bypassing the intended invincibility window. The must_have truth "player.gd exposes take_damage(amount)
      so projectiles can deal damage" passes, but the invincibility-frame requirement from the plan's
      threat model (T-01A-04, T-01B-03) is unimplemented.
    artifacts:
      - path: "script/player.gd"
        issue: "take_damage() at line 137 has no invincibility-frame guard; damage is always applied."
    missing:
      - "Add guard at start of take_damage(): if not enemy_attack_cooldown: return"
      - "Add: enemy_attack_cooldown = false; $attack_cooldown.start() after applying damage (matching enemy_attack() pattern)"
---

# Phase 01: Enemy Enhancement & Dungeon Theming — Verification Report

**Phase Goal:** Players encounter meaningfully different enemies per floor range in a visually distinct dungeon — and the game no longer crashes or misreports health

**Verified:** 2026-05-13T23:40:00Z
**Status:** GAPS FOUND — 2 blockers
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Player can fight ranged, fast, and tank enemies — each with distinct movement and attack behavior | ✓ VERIFIED | enemy_ranged.gd, enemy_fast.gd, enemy_tank.gd all exist, extend enemy_base.gd, have distinct stats and behavior |
| 2 | Enemies on floor 50+ are visibly tougher than floor 1 (higher HP, speed, damage) | ✗ FAILED | Scaling applied before add_child() — variant _ready() overwrites; only base melee scales correctly |
| 3 | When one enemy spots the player, nearby enemies activate — without per-frame polling | ✓ VERIFIED | enemy_base.gd line 62: call_group in detection handler; _on_pack_alerted with player_chase guard |
| 4 | Dungeon color palette visibly changes at floor 34 and floor 67 | ✓ VERIFIED | dungeon.gd: THEME_CAVE/RUINS/ABYSS constants; _get_dungeon_theme(); _theme used in floor/wall/exit builders |
| 5 | Health bars show correct max health; no freed-reference crashes | ✓ VERIFIED | enemy_base.gd line 101: healthbar.max_value = max_health; npc.gd and dungeon_npc.gd both guard with is_instance_valid |

**Score:** 4/5 truths verified

---

## Must-Haves Verification

### Plan A Must-Haves

#### ✓ No freed-reference crash in npc.gd
- **Checked:** npc.gd _process() body
- **Evidence:** npc.gd line 40: `if not is_instance_valid(player_ref):` early-return block before any player_ref dereference
- **Note:** Implementation uses early-return pattern rather than inline guard; behavior is equivalent and correct
- **Result:** PASS

#### ✓ No freed-reference crash in dungeon_npc.gd
- **Checked:** dungeon_npc.gd _process() body
- **Evidence:** dungeon_npc.gd line 39: `if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):`
- **Result:** PASS

#### ✓ Enemy health bars show correct proportion for any max_health value
- **Checked:** enemy_base.gd update_health()
- **Evidence:** Lines 100-103: `healthbar.max_value = max_health; healthbar.value = health`
- **Result:** PASS

#### ✓ Enemy spawn count never exceeds 30
- **Checked:** dungeon.gd _spawn_enemies()
- **Evidence:** Line 252: `var max_count := mini(5 + floor_no, 30)`
- **Result:** PASS

#### ✓ player.gd exposes take_damage(amount) so projectiles can deal damage
- **Checked:** player.gd
- **Evidence:** Line 137: `func take_damage(amount: int) -> void:` — applies scaled damage using player_defense_level
- **Result:** PASS

#### ✗ take_damage() uses invincibility frames to prevent double-hit stacking
- **Checked:** player.gd take_damage() body
- **Evidence:** Lines 137-140 — no `if not enemy_attack_cooldown: return` guard; damage applied unconditionally
- **Result:** FAIL — projectile hits stack with melee hits in same frame

#### ✓ enemy_base.gd exists with all behavior plus pack alert signal
- **Checked:** script/enemy_base.gd full file
- **Evidence:** signal alert_pack declared line 3; add_to_group("enemies") line 22; _move_toward_player() line 39; call_group line 62; _on_pack_alerted line 69; update_health with max_value fix lines 99-103
- **Result:** PASS

#### ✓ scenes/enemy.tscn references enemy_base.gd
- **Checked:** scenes/enemy.tscn ext_resource line
- **Evidence:** `path="res://script/enemy_base.gd"` confirmed
- **Result:** PASS

---

### Plan B Must-Haves

#### ✓ enemy_ranged.gd backs away when closer than 100px and fires projectile on 2s cooldown
- **Checked:** enemy_ranged.gd _move_toward_player() and _fire_projectile()
- **Evidence:** Line 3: `const PREFERRED_DISTANCE := 100.0`; line 38: `if dist < PREFERRED_DISTANCE:` backs away; line 20-21: Timer wait_time=2.0, one_shot=true; line 48: fires when dist < FIRE_RANGE and _shoot_ready
- **Note:** `collision_mask = 1` (line 71) deviates from plan's `collision_mask = 0` — this is an improvement enabling body_entered to fire correctly
- **Result:** PASS

#### ✓ enemy_fast.gd moves at speed 90 with 150px detection radius
- **Checked:** enemy_fast.gd full file
- **Evidence:** Line 6: `speed = 90.0`; line 11-12: `detect_shape.radius = 150.0` after super._ready()
- **Result:** PASS

#### ✓ enemy_tank.gd has 300 max_health, speed 22, red-tinted enlarged slime sprite
- **Checked:** enemy_tank.gd full file
- **Evidence:** Line 5: `max_health = 300`; line 6: `speed = 22.0`; line 15: `$AnimatedSprite2D.modulate = Color(0.6, 0.2, 0.2)`; line 16: `$AnimatedSprite2D.scale = Vector2(1.5, 1.5)`
- **Result:** PASS

#### ✓ All three variants set stats BEFORE calling super._ready()
- **Checked:** All three variant files
- **Evidence:** enemy_fast.gd: stats lines 5-9, super._ready() line 10; enemy_tank.gd: stats lines 5-9, super._ready() line 10; enemy_ranged.gd: stats lines 12-16, super._ready() line 17
- **Result:** PASS

#### ✓ Projectiles self-destruct after 2s if they do not hit the player
- **Checked:** enemy_ranged.gd _fire_projectile()
- **Evidence:** Lines 79-85: Timer t, wait_time=2.0, one_shot=true, timeout calls proj.queue_free()
- **Result:** PASS

#### ✓ No cross-enemy projectile interference (_my_projectiles per instance)
- **Checked:** enemy_ranged.gd
- **Evidence:** Line 8: `var _my_projectiles: Array = []` (instance var); line 103: filter(is_instance_valid); _update_projectiles iterates only own array
- **Result:** PASS

---

### Plan C Must-Haves

#### ✓ Three distinct dungeon themes by floor range
- **Checked:** dungeon.gd constants and _get_dungeon_theme()
- **Evidence:** Lines 27-44: THEME_CAVE, THEME_RUINS, THEME_ABYSS dicts; lines 346-352: _get_dungeon_theme() with correct breakpoints (34, 67); line 80: `_theme = _get_dungeon_theme(floor_no)` first action after floor_no
- **Result:** PASS

#### ✓ Theme colors wired into all builders
- **Checked:** dungeon.gd builder functions
- **Evidence:** `_build_floor_background()` line 162: `bg.color = _theme.floor`; `_make_wall()` line 177: `visual.color = _theme.wall`; exit area line 292: `visual.color = _theme.exit`; echo puzzle line 692: `_theme.accent`
- **Result:** PASS

#### ✗ Floor 50 enemies have ~2x base stats; floor 100 have ~3x
- **Checked:** dungeon.gd _spawn_enemies() lines 264-272
- **Evidence:** Scaling applied lines 267-269 BEFORE add_child (line 271). Variant _ready() fires on add_child and overwrites max_health/speed/money_drop. Line 272 `enemy.health = enemy.max_health` re-syncs health but to unscaled max_health. Base melee enemy (no _ready() stat override) scales correctly.
- **Result:** FAIL — variant types (fast/tank/ranged) do not scale

#### ✓ Floor range enemy type selection (_pick_enemy_script)
- **Checked:** dungeon.gd _pick_enemy_script()
- **Evidence:** Lines 354-362: floors <10 → base only; 10-33 → base+fast; 34-66 → base+fast+ranged; 67+ → all four via pick_random()
- **Result:** PASS

#### ✓ NavMesh agent_radius updated to 10.0
- **Checked:** dungeon.gd _setup_navigation()
- **Evidence:** Line 153: `nav_poly.agent_radius = 10.0`
- **Result:** PASS

---

### Plan D Must-Haves

#### ✓ enemy_base.gd contains call_group pack alert in detection handler
- **Checked:** enemy_base.gd _on_detection_area_body_entered
- **Evidence:** Line 62: `get_tree().call_group("enemies", "_on_pack_alerted", global_position)`
- **Result:** PASS

#### ✓ Already-chasing enemies do not reset state on pack alert
- **Checked:** enemy_base.gd _on_pack_alerted
- **Evidence:** Lines 69-75: `if player_chase: return` as first statement; only inactive enemies proceed to get_nodes_in_group lookup
- **Result:** PASS

#### ✓ _on_pack_alerted uses get_nodes_in_group to find player
- **Checked:** enemy_base.gd _on_pack_alerted
- **Evidence:** Line 72: `var players := get_tree().get_nodes_in_group("player")`; includes `is_instance_valid(players[0])` guard (improvement over plan)
- **Result:** PASS

---

## Requirement Traceability

| Req ID | Description (abbreviated) | Status | Evidence |
|--------|--------------------------|--------|----------|
| PRE-01 | Fix freed player_ref crash | ✓ SATISFIED | is_instance_valid guards in npc.gd:40, dungeon_npc.gd:39 |
| PRE-02 | Fix health bar max_value | ✓ SATISFIED | enemy_base.gd:101 healthbar.max_value = max_health |
| PRE-03 | Enemy spawn cap | ✓ SATISFIED | dungeon.gd:252 mini(5 + floor_no, 30) |
| ENM-01 | Ranged enemy type | ✓ SATISFIED | enemy_ranged.gd exists, wired via set_script in dungeon.gd |
| ENM-02 | Fast enemy type | ✓ SATISFIED | enemy_fast.gd exists, wired via _pick_enemy_script |
| ENM-03 | Tank enemy type | ✓ SATISFIED | enemy_tank.gd exists, wired via _pick_enemy_script |
| ENM-04 | All types scale stats by floor | ✗ BLOCKED | Scaling overwritten by variant _ready(); base melee scales, variants do not |
| ENM-05 | Pack / alert behavior | ✓ SATISFIED | call_group in detection + _on_pack_alerted with guard |
| DNG-01 | Distinct visual themes by floor range | ✓ SATISFIED | THEME_CAVE/RUINS/ABYSS + _get_dungeon_theme() + _theme wired into all builders |

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `script/enemy_base.gd` | Base class with pack alert | ✓ VERIFIED | All required methods and signals present |
| `script/enemy_ranged.gd` | Ranged variant | ✓ VERIFIED | Substantive, extends base, wired via dungeon.gd |
| `script/enemy_fast.gd` | Fast variant | ✓ VERIFIED | Substantive, extends base, wired via dungeon.gd |
| `script/enemy_tank.gd` | Tank variant | ✓ VERIFIED | Substantive, extends base, wired via dungeon.gd |
| `script/npc.gd` | is_instance_valid guard | ✓ VERIFIED | Guard present line 40 |
| `script/dungeon_npc.gd` | is_instance_valid guard | ✓ VERIFIED | Guard present line 39 |
| `script/dungeon.gd` | Theme system + variant spawning | ✓ VERIFIED (partial) | Themes correct; scaling has ordering bug |
| `script/player.gd` | take_damage() method | ✓ VERIFIED (partial) | Method exists; invincibility frame guard missing |
| `scenes/enemy.tscn` | References enemy_base.gd | ✓ VERIFIED | ext_resource path confirmed |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| enemy_base.gd detection handler | all enemies group | call_group("enemies", "_on_pack_alerted") | ✓ WIRED | Line 62 |
| enemy_base.gd _on_pack_alerted | player node | get_nodes_in_group("player") | ✓ WIRED | Line 72; player adds to "player" group in _ready() line 29 |
| dungeon.gd _spawn_enemies | variant scripts | set_script(load(_pick_enemy_script(floor_no))) | ✓ WIRED | Line 265 |
| dungeon.gd _spawn_enemies | _get_floor_multiplier | mult applied to stats | ✗ BROKEN | Multiplier applied before add_child; overwritten by variant _ready() |
| enemy_ranged.gd projectile | player.take_damage | body.take_damage(proj.get_meta("damage")) | ✓ WIRED | Line 90 |
| dungeon.gd builders | _theme dict | _theme.floor / _theme.wall / _theme.exit / _theme.accent | ✓ WIRED | All four keys used in correct builders |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| script/dungeon.gd | 267-269 | Stat scaling before add_child() — overwritten by variant _ready() | BLOCKER | ENM-04: variant enemies do not scale on deep floors |
| script/player.gd | 137-140 | take_damage() missing invincibility-frame guard | WARNING | Projectile + melee can double-hit in same frame; no crash, but damage stacking unintended |

---

## Behavioral Spot-Checks

Not runnable without Godot editor. Skipped — game is a Godot 4 scene with no CLI entry point.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PRE-01 | Plan A | Freed player_ref crash fix | ✓ SATISFIED | npc.gd:40, dungeon_npc.gd:39 |
| PRE-02 | Plan A | Health bar max_value fix | ✓ SATISFIED | enemy_base.gd:101 |
| PRE-03 | Plan A | Spawn cap | ✓ SATISFIED | dungeon.gd:252 |
| ENM-01 | Plan B/C | Ranged enemy | ✓ SATISFIED | enemy_ranged.gd + dungeon.gd wiring |
| ENM-02 | Plan B/C | Fast enemy | ✓ SATISFIED | enemy_fast.gd + dungeon.gd wiring |
| ENM-03 | Plan B/C | Tank enemy | ✓ SATISFIED | enemy_tank.gd + dungeon.gd wiring |
| ENM-04 | Plan C | Stat scaling by floor | ✗ BLOCKED | Scaling order bug — variant stats overwritten |
| ENM-05 | Plan D | Pack alert | ✓ SATISFIED | call_group + _on_pack_alerted |
| DNG-01 | Plan C | Visual themes | ✓ SATISFIED | Three theme dicts + _get_dungeon_theme() + builder wiring |

---

## Human Verification Required

### 1. Visual theme palette at floor boundaries

**Test:** Set `global.current_floor = 1`, enter dungeon, note wall/floor colors. Set to 34, enter dungeon, verify warm brown palette. Set to 67, enter dungeon, verify near-black blue floor and dark purple walls.
**Expected:** Three visually distinct color environments.
**Why human:** Cannot render ColorRect values without running Godot editor.

### 2. Enemy visual distinctiveness in play

**Test:** At floor 10+, fight fast enemies. At floor 34+, fight ranged enemies. At floor 67+, fight tank enemies.
**Expected:** Fast enemies visibly faster; ranged enemies back away and fire orange projectiles; tank enemies visibly larger and red-tinted.
**Why human:** Animation and visual behavior require runtime observation.

---

## Gaps Summary

**2 gaps blocking full goal achievement:**

**GAP 1 — BLOCKER — ENM-04: Variant stat scaling lost (dungeon.gd)**

Root cause: `dungeon.gd` `_spawn_enemies()` applies `_get_floor_multiplier()` scaling to `max_health`, `speed`, and `money_drop` at lines 267-269, which execute BEFORE `add_child()` at line 271. When `add_child()` fires, the variant script's `_ready()` (e.g., `enemy_ranged._ready()` sets `max_health = 60`) overwrites the scaled value. The health re-sync on line 272 correctly runs after `add_child()` but syncs to the now-unscaled `max_health`.

Fix: Move lines 267-269 to after line 271 (after `add_child`), keeping line 272 last:
```gdscript
var enemy: Node2D = packed.instantiate()
enemy.set_script(load(_pick_enemy_script(floor_no)))
enemy.position = pos
add_child(enemy)  # variant _ready() fires here, sets type base stats
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.speed = float(enemy.speed) * mult
enemy.money_drop = int(enemy.money_drop * mult)
enemy.health = enemy.max_health
```

**GAP 2 — WARNING — take_damage() missing invincibility frames (player.gd)**

Root cause: `player.gd` `take_damage()` at line 137 omits the `enemy_attack_cooldown` check that `enemy_attack()` uses. Projectile hits can stack with simultaneous melee hits, dealing double damage in the same frame. The plan's threat model (T-01A-04) explicitly required this guard.

Fix: Add guard and cooldown activation to `take_damage()`:
```gdscript
func take_damage(amount: int) -> void:
    if not enemy_attack_cooldown:
        return
    var reduction = global.player_defense_level / 100.0
    var damage = max(1, int(amount * (1.0 - reduction)))
    health -= damage
    enemy_attack_cooldown = false
    $attack_cooldown.start()
```

---

_Verified: 2026-05-13T23:40:00Z_
_Verifier: Claude (gsd-verifier)_
