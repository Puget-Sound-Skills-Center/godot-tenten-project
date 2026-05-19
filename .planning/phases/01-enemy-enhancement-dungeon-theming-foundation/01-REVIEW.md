---
phase: 01-enemy-enhancement-dungeon-theming-foundation
reviewed: 2026-05-18T22:40:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - script/enemy_base.gd
  - script/enemy_fast.gd
  - script/enemy_tank.gd
  - script/enemy_ranged.gd
  - script/player.gd
  - script/npc.gd
  - script/dungeon_npc.gd
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: fixed
fixed: 2026-05-18
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-18T22:40:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 1 adds three enemy variants (`enemy_fast`, `enemy_tank`, `enemy_ranged`) extending a new `enemy_base.gd`, wires pack-alert via `call_group`, and introduces a `take_damage()` method on the player for ranged projectile hits. The base/variant inheritance is structurally sound and the fast/tank overrides are clean. Two critical issues were found: the invincibility-frame cooldown is shared across melee and ranged damage sources, so a melee hit during which ranged projectiles fire causes all those projectile hits to be silently discarded; and when a ranged enemy is killed while projectiles are in flight, those projectiles freeze in place (remain collidable) until their 2-second self-destruct timer fires — a ghost-hit hazard. Four warnings cover an inverted shop-toggle in `npc.gd`, a dead `alert_pack` signal declaration, player spawning with 0 HP after death, and a fragile `_on_pack_alerted` readiness window. Three info items cover the dead signal, a per-frame filter cost, and undocumented autoload dependencies.

---

## Critical Issues

### CR-01: Shared cooldown flag suppresses all projectile damage during melee hit cooldown

**File:** `script/player.gd:140`

**Issue:** `take_damage()` (the entry point called by ranged projectiles via `_on_projectile_hit`) gates on `not enemy_attack_cooldown` and returns early if the cooldown is inactive. The same `enemy_attack_cooldown` flag and `$attack_cooldown` timer are also consumed by `enemy_attack()` (melee contact). A melee hit sets `enemy_attack_cooldown = false` and starts the timer. For the entire timer duration every call to `take_damage()` silently returns, dealing zero damage. On a floor with mixed melee and ranged enemies, the player is immune to all ranged hits whenever a melee enemy is in contact — the ranged enemies become non-threatening.

```gdscript
# player.gd:139-146 — current (broken)
func take_damage(amount: int) -> void:
    if not enemy_attack_cooldown:   # blocks ranged hits during melee cooldown
        return
    ...
    enemy_attack_cooldown = false
    $attack_cooldown.start()
```

**Fix:** Give ranged/external damage its own cooldown flag, or remove the gate entirely (ranged projectile rate is already capped by the enemy-side shoot cooldown):

```gdscript
var ranged_hit_cooldown := true

func take_damage(amount: int) -> void:
    if not ranged_hit_cooldown:
        return
    var reduction = global.player_defense_level / 100.0
    var damage = max(1, int(amount * (1.0 - reduction)))
    health -= damage
    ranged_hit_cooldown = false
    $ranged_cooldown.start()   # new 0.5 s one-shot Timer node in player.tscn

func _on_ranged_cooldown_timeout() -> void:
    ranged_hit_cooldown = true
```

---

### CR-02: Ranged enemy freed mid-flight — in-flight projectiles freeze and remain collidable

**File:** `script/enemy_ranged.gd:95-108`

**Issue:** Projectile movement is driven exclusively by `_update_projectiles()` inside the ranged enemy's `_physics_process`. When the enemy is killed (`queue_free()`), its process loop stops immediately. Any in-flight `Area2D` projectile stops moving at its last position but remains in the scene tree as a live, collidable node until its 2-second self-destruct timer fires. A player moving into the frozen projectile receives a damage hit from a ghost object — especially misleading because the visual (a 6×6 `ColorRect`) is small and the enemy that fired it is gone.

The `_my_projectiles` array is also abandoned with potentially live entries; there is no `_exit_tree()` or `_notification(NOTIFICATION_PREDELETE)` cleanup.

**Fix:** Make projectiles self-propelled so they move independently of the enemy's lifetime. Minimal approach — add `_exit_tree()` to `enemy_ranged.gd` to free all tracked projectiles when the enemy dies:

```gdscript
func _exit_tree() -> void:
    for proj in _my_projectiles:
        if is_instance_valid(proj):
            proj.queue_free()
    _my_projectiles.clear()
```

Longer-term fix: extract a `projectile.gd` script that extends `Area2D` and self-propels in its own `_physics_process`, removing the dependency on the spawning enemy entirely.

---

## Warnings

### WR-01: `npc.gd` shop-toggle logic is inverted — E re-opens shop instead of closing it

**File:** `script/npc.gd:49-51`

**Issue:** The inline comment says "pressing E closes it (existing behavior)" but the guard body calls `player_ref.open_shop()` when `shop_open` is already `true`. This calls open again rather than closing.

```gdscript
# current (wrong):
if player_ref.shop_open:
    player_ref.open_shop()   # opens again — should close
    return
```

**Fix:**

```gdscript
if player_ref.shop_open:
    player_ref._close_shop()
    return
```

Note: `_close_shop()` uses a leading underscore marking it private by convention. Consider renaming it `close_shop()` if it needs to be called from outside `player.gd`.

---

### WR-02: `alert_pack` signal declared but never emitted — dead API

**File:** `script/enemy_base.gd:3` and `script/enemy_base.gd:62`

**Issue:** Line 3 declares `signal alert_pack(origin_position: Vector2)`. It is never emitted anywhere. Pack alerting is implemented via `get_tree().call_group("enemies", "_on_pack_alerted", global_position)` on line 62. Any external code connecting to `enemy.alert_pack` (e.g., a dungeon system wanting to react to pack activation) will never receive it. The declaration is misleading dead code.

**Fix — Option A:** Emit the signal alongside the call_group call so external listeners work:

```gdscript
func _on_detection_area_body_entered(body) -> void:
    if body.has_method("player"):
        player = body as Node2D
        player_chase = true
        alert_pack.emit(global_position)
        get_tree().call_group("enemies", "_on_pack_alerted", global_position)
```

**Fix — Option B:** If no external listener is planned, delete the signal declaration on line 3.

---

### WR-03: Player spawns with 0 HP after dying in the dungeon

**File:** `script/player.gd:33`

**Issue:** `_ready()` restores health with `if global.player_current_health >= 0`. When the player dies, `health` reaches 0 and `_exit_tree()` persists that to `global.player_current_health`. On the next scene load the condition `>= 0` is satisfied by the value 0, so `health` is restored to 0. On the first `_physics_process` call `health <= 0` is immediately true, setting `player_alive = false`. The player spawns effectively dead.

```gdscript
# current (wrong):
if global.player_current_health >= 0:
    health = global.player_current_health
```

**Fix:**

```gdscript
if global.player_current_health > 0:
    health = global.player_current_health
else:
    health = global.get_max_health()
```

---

### WR-04: `_on_pack_alerted` can run on enemies whose `_ready()` has not yet completed

**File:** `script/enemy_base.gd:69-75`

**Issue:** All three subclasses call `super._ready()` at the end of their own `_ready()`. When `dungeon.gd` adds multiple enemies in the same frame during floor generation, `call_group("enemies", "_on_pack_alerted", ...)` (triggered by the first enemy detecting the player) can reach enemies that are in the `"enemies"` group (added by `_ready()`) but whose subclass `_ready()` has not yet run — meaning `_nav_agent` may not yet exist if `add_to_group("enemies")` runs before `add_child(_nav_agent)` completes across all nodes. Any future code added to `_on_pack_alerted` that accesses `_nav_agent` will null-deref on those nodes.

**Fix:** Guard with `is_node_ready()` (Godot 4 built-in; returns `false` until `_ready()` has finished):

```gdscript
func _on_pack_alerted(_origin_position: Vector2) -> void:
    if not is_node_ready():
        return
    if player_chase:
        return
    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0 and is_instance_valid(players[0]):
        player = players[0] as Node2D
        player_chase = true
```

---

## Info

### IN-01: Dead `alert_pack` signal declaration should be removed or wired

**File:** `script/enemy_base.gd:3`

See WR-02. As a standalone info item: the unused signal declaration creates a false impression of an event-driven pack-alert API. Readers will expect `alert_pack` to fire and may write listeners that silently never trigger. Delete line 3 if `call_group` is the permanent design.

---

### IN-02: `_my_projectiles` array is filtered every physics frame even when empty or fully freed

**File:** `script/enemy_ranged.gd:103`

**Issue:** `_my_projectiles.filter(...)` reconstructs the array every frame regardless of its contents. After all projectiles from a volley expire, the filter runs on an empty array each frame for the rest of the enemy's life. Low overhead at current scale but unnecessary.

**Fix:** Eagerly remove entries in `_on_projectile_hit` and in the timer callback so the array stays minimal:

```gdscript
func _on_projectile_hit(body: Node2D, proj: Area2D) -> void:
    if body.has_method("player"):
        body.take_damage(proj.get_meta("damage"))
    if is_instance_valid(proj):
        _my_projectiles.erase(proj)
        proj.queue_free()
```

Then `_update_projectiles` only needs to iterate, with no filter pass needed each frame.

---

### IN-03: `npc.gd` references `dialogue_manager` and `quest_manager` as implicit autoloads without null guards

**File:** `script/npc.gd:46,59,67-71,75`

**Issue:** `dialogue_manager` and `quest_manager` are used as bare autoload names. Neither is listed in CLAUDE.md's component table or autoload registry. If either singleton is absent from `project.godot`, every `E` keypress near the NPC crashes with `Invalid get index on base null`. There are no `if dialogue_manager` guards.

**Fix (minimal):** Add existence checks at the top of the interact block:

```gdscript
if not dialogue_manager or not quest_manager:
    push_warning("npc.gd: dialogue_manager or quest_manager autoload not found")
    return
```

**Fix (proper):** Register both autoloads in `project.godot` and add them to the CLAUDE.md component table so their existence is architecturally documented.

---

_Reviewed: 2026-05-18T22:40:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
