---
phase: "01-enemy-enhancement-dungeon-theming-foundation"
plan: "01-PLAN-B"
subsystem: "enemy-variants"
tags: [enemy, combat, gdscript, godot]

dependency_graph:
  requires:
    - "01-PLAN-A"  # enemy_base.gd, player.take_damage()
  provides:
    - "enemy_fast.gd"
    - "enemy_tank.gd"
    - "enemy_ranged.gd"
  affects:
    - "script/dungeon.gd"  # Plan C wires these via set_script()

tech_stack:
  added: []
  patterns:
    - "GDScript extends chain via string path (res://script/enemy_base.gd)"
    - "Instance-owned projectile array prevents cross-enemy interference"
    - "Duck-typed body.has_method(player) for projectile hit detection"
    - "2s Timer auto-free on each projectile node (leak prevention)"

key_files:
  created:
    - script/enemy_fast.gd
    - script/enemy_tank.gd
    - script/enemy_ranged.gd
  modified: []

decisions:
  - "Ranged enemy projectiles are instance-scoped (_my_projectiles per enemy) rather than scanned via get_parent().get_children() — prevents O(N) per-projectile movement with N ranged enemies"
  - "Projectile collision_layer/mask both 0: relies solely on body_entered signal from player's CharacterBody2D entering the Area2D"
  - "Tank nav radius enlarged to 10.0 (base 5.0) after super._ready() creates the NavigationAgent2D node"

metrics:
  duration: "~10 minutes"
  completed: "2026-05-09"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 1 Plan B: Enemy Variant Scripts Summary

**One-liner:** Three enemy variants (fast/tank/ranged) extending enemy_base.gd — ranged fires orange Area2D projectiles on 2s cooldown with instance-scoped tracking.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create enemy_fast.gd and enemy_tank.gd | 595e87b | script/enemy_fast.gd, script/enemy_tank.gd |
| 2 | Create enemy_ranged.gd with distance-keeping and projectile firing | 67f5f38 | script/enemy_ranged.gd |

## What Was Built

**enemy_fast.gd** — Stat-only variant. speed=90 (base 40), max_health=40, detection radius 150px (base 120px). No behavior override — inherits full NavigationAgent2D pathfinding from base. Visibly faster than melee enemy.

**enemy_tank.gd** — High HP/low speed variant. max_health=300, speed=22, damage=15. Red-tinted sprite (modulate 0.6,0.2,0.2), enlarged 1.5x scale, nav radius 10px for wider pathfinding. Detection radius reduced to 100px (shorter aggro range by design).

**enemy_ranged.gd** — Behavior-override variant. Backs away when closer than 100px, stays still otherwise. Fires an orange Area2D projectile at player when within 160px on a 2s cooldown (Timer, one_shot=true). Each instance owns its `_my_projectiles` array. `_update_projectiles()` moves only that instance's projectiles. `filter(is_instance_valid)` purges freed refs each frame. Each projectile auto-frees via a 2s Timer on the proj node, covering the case where player dies before hit. Projectile hit calls `body.take_damage()` via duck-typed `body.has_method("player")` check.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. No UI or data display involved in this plan.

## Threat Surface Scan

All threat mitigations from the plan's threat model implemented:

| Threat | Mitigation | Status |
|--------|-----------|--------|
| T-01B-01: Projectile node leak if player dies before hit | 2s Timer auto-queues proj.queue_free() | Implemented |
| T-01B-02: Stale freed refs in _my_projectiles | filter(is_instance_valid) at start of _update_projectiles | Implemented |
| T-01B-03: Freed player ref in _fire_projectile | is_instance_valid(player) guard in _move_toward_player() before _fire_projectile call | Implemented |
| T-01B-04: N ranged enemies move all projectiles N× per frame | _my_projectiles is instance-scoped | Implemented |

No new security-relevant surface introduced beyond the plan's threat model.

## Self-Check: PASSED

Files confirmed:
- FOUND: script/enemy_fast.gd
- FOUND: script/enemy_tank.gd
- FOUND: script/enemy_ranged.gd

Commits confirmed:
- FOUND: 595e87b
- FOUND: 67f5f38
