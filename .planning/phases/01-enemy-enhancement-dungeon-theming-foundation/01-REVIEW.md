---
phase: 01-enemy-enhancement-dungeon-theming-foundation
reviewed: 2026-05-08T23:16:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - scenes/enemy.tscn
  - script/dungeon.gd
  - script/dungeon_npc.gd
  - script/enemy_base.gd
  - script/enemy_fast.gd
  - script/enemy_ranged.gd
  - script/enemy_tank.gd
  - script/npc.gd
  - script/player.gd
findings:
  critical: 4
  warning: 7
  info: 3
  total: 14
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-08T23:16:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Phase 1 implementation: `enemy_base.gd` and three variant scripts (`enemy_fast.gd`, `enemy_ranged.gd`, `enemy_tank.gd`), the updated `dungeon.gd` with theming and enemy scaling, `player.gd`, `npc.gd`, `dungeon_npc.gd`, and `scenes/enemy.tscn`.

The core architecture (duck-typed identity, global flag polling, runtime-built UI) is consistent with the existing codebase. However, several correctness bugs and one data-loss risk were found. The most serious issues are: enemy stats are mutated on a shared base scene instance (stat bleed between enemies), the ranged projectile uses zero collision layers so it can never hit anything via Godot physics, `take_damage` in `player.gd` is gated behind the wrong cooldown flag causing it to ignore ranged hits when the player recently took melee damage, and enemy health is initialised twice — once by the script's `_ready()` and once overwritten by `dungeon.gd` — but the ordering is fragile.

---

## Critical Issues

### CR-01: Enemy stat mutation after `instantiate()` corrupts shared resource — potential data bleed

**File:** `script/dungeon.gd:261-268`

After instantiating the enemy scene and replacing its script, `dungeon.gd` writes directly to `enemy.max_health`, `enemy.health`, `enemy.speed`, and `enemy.money_drop` on the live node *before* `_ready()` has been called (because `add_child` triggers `_ready`). But the write occurs *after* `add_child` (line 263 is after line 262), so `_ready()` runs first — which sets `health = max_health` using the base value — and then the dungeon overwrites `max_health` and sets `health` again. This is correct only by accident of ordering. More critically, `set_script()` (line 261) is called on an already-instantiated node; Godot re-runs `_ready()` for script replacement on some versions, which would double-call `_ready()` and add a second `NavigationAgent2D` child and replace the `detection_area` collision shape twice. This can cause orphaned nodes and broken navigation.

**Fix:** Set the script *before* adding to the scene tree, set stat overrides before `add_child`, then let `_ready()` pick them up:
```gdscript
var enemy: Node2D = packed.instantiate()
enemy.set_script(load(_pick_enemy_script(floor_no)))
# Stat scaling before _ready fires
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.speed = enemy.speed * mult
enemy.money_drop = int(enemy.money_drop * mult)
enemy.position = pos
add_child(enemy)          # _ready() now sees scaled max_health
enemy.health = enemy.max_health
```

---

### CR-02: Ranged projectile collision layers are zero — projectile never detects the player

**File:** `script/enemy_ranged.gd:70-71`

```gdscript
proj.collision_layer = 0
proj.collision_mask = 0
```

Both are explicitly zeroed. `Area2D` with `collision_mask = 0` never generates `body_entered` signals. `_on_projectile_hit` is connected to `body_entered` but will never fire. The projectile moves and disappears after 2 seconds, doing zero damage. The ranged enemy is completely non-functional as a threat.

**Fix:** Assign a collision mask that overlaps the player's collision layer. Based on the existing scene setup (enemy detection area uses layer/mask 2, the player `CharacterBody2D` is on the default layer 1):
```gdscript
proj.collision_layer = 0   # projectile itself on no layer (fine)
proj.collision_mask = 1    # detect bodies on layer 1 (player)
```

---

### CR-03: `player.take_damage()` is silently ignored when melee cooldown is active — ranged hits are lost

**File:** `script/player.gd:137-144`

```gdscript
func take_damage(amount: int) -> void:
    if enemy_attack_cooldown == false:
        return
    ...
    enemy_attack_cooldown = false
    $attack_cooldown.start()
```

`take_damage` is the entry point called by ranged projectiles. It reuses `enemy_attack_cooldown`, which is also consumed by melee contact (`enemy_attack()`). If the player is already in melee cooldown, all incoming projectile hits during that window are silently dropped — zero damage, no feedback. At higher floors with multiple ranged enemies firing simultaneously, this means most projectile hits deal no damage, making the ranged enemy even weaker than intended.

**Fix:** Introduce a separate cooldown for external/ranged damage, or simply apply damage unconditionally in `take_damage` (ranged hits are already rate-limited by the projectile cooldown on the enemy side):
```gdscript
func take_damage(amount: int) -> void:
    var reduction = global.player_defense_level / 100.0
    var damage = max(1, int(amount * (1.0 - reduction)))
    health -= damage
```

---

### CR-04: `_on_pack_alerted` adds player reference without validity check — stale reference if player died mid-alert

**File:** `script/enemy_base.gd:69-75`

```gdscript
func _on_pack_alerted(origin_position: Vector2) -> void:
    if player_chase:
        return
    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player = players[0] as Node2D
        player_chase = true
```

`get_nodes_in_group("player")` returns the node even after `player_alive` becomes `false` (the player node is not freed on death — `player_alive` is just a flag). Alerted enemies then chase a "dead" player indefinitely. More critically, the `origin_position` parameter is received but never used — the pack alert was presumably designed to send enemies toward the detection origin (so off-screen enemies move toward where the player was spotted), but instead they all attempt pathfinding to the actual player position. This is a logic error: the parameter is dead code.

**Fix:** Use `origin_position` as the initial chase target, or at minimum validate the player is alive:
```gdscript
func _on_pack_alerted(_origin_position: Vector2) -> void:
    if player_chase:
        return
    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0 and is_instance_valid(players[0]):
        player = players[0] as Node2D
        player_chase = true
```
And consider prefixing the unused `origin_position` parameter with `_` to make the dead-code intent explicit.

---

## Warnings

### WR-01: `enemy_base.gd` collision shape override uses a scene-path node reference that breaks for variant scripts

**File:** `script/enemy_base.gd:32`

```gdscript
$detection_area/CollisionShape2D.shape = detect_shape
```

This direct node path reference works because the base `enemy.tscn` has that node. However, `enemy_fast.gd`, `enemy_ranged.gd`, and `enemy_tank.gd` all call `super._ready()` which runs this line — after `set_script()` replaces the script on the already-instantiated node. If the node path is ever renamed in the `.tscn`, all four scripts break simultaneously with no clear error source. The `enemy_hitbox/CollisionShape2D` in the `.tscn` has no shape assigned at all (line 160: `CircleShape2D_md0e3` has default radius 0), meaning the hitbox is effectively disabled unless the script sets it. There is no code in any script that sets the hitbox shape — melee damage detection via `enemy_hitbox` is non-functional.

**Fix:** Set a non-zero shape for `enemy_hitbox/CollisionShape2D` in `enemy.tscn` (e.g., radius 10), or assign it in `_ready()`:
```gdscript
var hitbox_shape := CircleShape2D.new()
hitbox_shape.radius = 10.0
$enemy_hitbox/CollisionShape2D.shape = hitbox_shape
```

---

### WR-02: Floor multiplier applies `speed * mult` but variant scripts set speed to floats — `int` cast only on health/money

**File:** `script/dungeon.gd:266`

```gdscript
enemy.speed = enemy.speed * mult
```

`speed` is declared `var speed = 40` (untyped int) in `enemy_base.gd`, but variant scripts assign floats (`speed = 90.0`, `speed = 35.0`, `speed = 22.0`). The multiplier product is a float regardless. The missing `int()` cast on `money_drop` line is present, but `speed` has no issue since floats work in `move_and_slide`. However `max_health` and `money_drop` are cast with `int()` while `speed` is not — inconsistent and will produce slightly different behaviour if GDScript's type inference changes. Low-severity but inconsistent.

**Fix:** Be explicit:
```gdscript
enemy.speed = float(enemy.speed) * mult
```

---

### WR-03: `_pick_puzzle_tile_position` falls back to room center when no position found — tiles placed at same fallback position overlap

**File:** `script/dungeon.gd:473`

```gdscript
return Vector2(room_w / 2, room_h / 2)
```

If 120 placement attempts all fail (heavily obstructed room at high floor counts), every remaining tile falls back to the exact same center position. Multiple puzzle tiles stacked at one position means stepping that single spot completes multiple tile events simultaneously, potentially solving the puzzle instantly or causing out-of-order state corruption. The `_pick_save_position` function has the same fallback at line 399, and `_pick_exit_position` at line 309.

**Fix:** Track attempt count and log a warning; for tile placement specifically, expand the search radius when attempts fail rather than returning a fixed fallback:
```gdscript
# After 120 attempts, try unconstrained:
for i in 40:
    var x := rng.randi_range(2, room_w / TILE - 2) * TILE + TILE / 2
    var y := rng.randi_range(2, room_h / TILE - 2) * TILE + TILE / 2
    var p := Vector2(x, y)
    if _is_position_clear(p, obstacles, 6):
        return p
push_warning("Puzzle tile fallback to room center")
return Vector2(room_w / 2, room_h / 2)
```

---

### WR-04: Echo puzzle replay does not reset tile colors for already-activated tiles — visual state is misleading

**File:** `script/dungeon.gd:696-706`

`_play_echo_demo()` resets all tiles to `_theme.accent` at the start (line 697), but `echo_input_index` is reset to 0 (line 696) without clearing which tiles the player already confirmed. If the player steps a correct tile, it turns `PUZZLE_TILE_DONE_COLOR`, then steps a wrong tile — `_play_echo_demo()` resets colors — but after the replay finishes, `echo_input_index` is 0, meaning the already-green tiles now show `_theme.accent` color but would need to be re-stepped. This is correct behavior for a Simon Says reset, but the label at line 729 says "Replaying sequence..." without resetting `echo_input_index` to 0 before the tween completes — `_finish_echo_demo` does reset it. This is fine. However, `_play_echo_demo` resets colors mid-tween if called while a previous tween is still running (player steps wrong before the demo finishes): the new tween starts while the previous tween's callbacks are still queued. Godot tweens are not cancelled, so the old tween continues firing `_set_tile_color` callbacks and fighting the new tween — tile colors flicker erratically.

**Fix:** Store the tween reference and kill it before starting a new one:
```gdscript
var _echo_tween: Tween = null

func _play_echo_demo() -> void:
    if _echo_tween:
        _echo_tween.kill()
    echo_demo_active = true
    echo_input_index = 0
    for t in puzzle_tiles:
        _set_tile_color(t, _theme.accent)
    _echo_tween = create_tween()
    ...
```

---

### WR-05: `player.gd` does not prevent movement or attacks while dead — ghost movement after `health <= 0`

**File:** `script/player.gd:50-52`

```gdscript
if health <= 0:
    player_alive = false
    health = 0
```

`player_alive` is set to `false` but `player_movement()` and `attack()` are called unconditionally on lines 44-47 *before* this check. The dead player can still move, attack, step puzzle tiles, and enter the exit — advancing the floor while dead. The `player_alive` flag is set but never read anywhere in `player.gd`.

**Fix:** Guard the physics callbacks:
```gdscript
func _physics_process(delta):
    if not player_alive:
        return
    player_movement(delta)
    enemy_attack()
    attack()
    update_health()
    if health <= 0:
        player_alive = false
        health = 0
        _handle_death()
```

---

### WR-06: `_spawn_enemies` does not exclude the player spawn zone from enemy placement

**File:** `script/dungeon.gd:253-258`

```gdscript
var x := rng.randi_range(3, room_w / TILE - 3) * TILE
var y := rng.randi_range(3, room_h / TILE - 3) * TILE
var pos := Vector2(x, y)
if not _is_position_clear(pos, obstacles, 14):
    continue
```

`_is_position_clear` checks obstacles but not `_spawn_zone()` (which it does check in the puzzle tile picker). The player always spawns at `Vector2(2 * TILE + 8, 2 * TILE + 8)`. An enemy can spawn directly adjacent to or on top of the player start position — `rng.randi_range(3, ...)` starts at tile 3 (48px), and the player is at tile ~2 (40px), so with radius 14 this is only a 6px margin. Enemies spawning in the player start zone trigger detection and pack-alert immediately on floor load.

**Fix:** Add spawn zone exclusion to `_is_position_clear` call in `_spawn_enemies`, matching the pattern used for puzzle tiles:
```gdscript
if not _is_position_clear(pos, obstacles, 14):
    continue
if _spawn_zone().grow(TILE).has_point(pos):
    continue
```

---

### WR-07: `_get_floor_multiplier` reaches max 3.0 at floor 100 but `DUNGEON_MAX_FLOOR` is not confirmed — off-by-one if max < 100

**File:** `script/dungeon.gd:354-355`

```gdscript
func _get_floor_multiplier(floor_no: int) -> float:
    return 1.0 + (floor_no - 1) / 99.0 * 2.0
```

The formula assumes `DUNGEON_MAX_FLOOR == 100` (denominator 99 = max - 1). If `global.DUNGEON_MAX_FLOOR` is ever changed (e.g., to 50 for a shorter game), the multiplier never reaches 3.0, and at floor 50 it returns only ~2.0 instead of the intended 3.0 maximum. The hardcoded `99` is a magic number that should reference the constant.

**Fix:**
```gdscript
func _get_floor_multiplier(floor_no: int) -> float:
    var denom := float(global.DUNGEON_MAX_FLOOR - 1)
    return 1.0 + (floor_no - 1) / denom * 2.0
```

---

## Info

### IN-01: `enemy_base.gd` variable shadows built-in node method name

**File:** `script/enemy_base.gd:13`

```gdscript
var player: Node2D = null
```

The variable is named `player`, which is also the name of the duck-typing identity method (`func player(): pass`) declared in `player.gd`. Within `enemy_base.gd` itself, there is also a `func enemy(): pass` marker on line 55. There is no conflict in GDScript since methods and variables have separate namespaces, but the variable `player` storing a node reference while the entity identity pattern uses `has_method("player")` creates a confusing naming collision that will mislead future maintainers.

**Fix:** Rename the node reference variable to `player_node` or `_player_ref` to distinguish it from the duck-typing marker.

---

### IN-02: `money_drop` default value of 1000 in `enemy_base.gd` is inconsistent with intent

**File:** `script/enemy_base.gd:8`

```gdscript
var money_drop = 1000
```

All variant scripts set lower values (800, 1200, 2000). The base enemy (`enemy_type = "melee"`) keeps the 1000 default. At floor 1, `_get_floor_multiplier` returns 1.0, so a base melee enemy drops 1000 gold. The shop costs start at 50g. This makes the economy trivially easy on the first kill. The fast enemy drops 800 less, the tank drops 2000 — the base enemy drops more than the fast variant, which is counterintuitive.

**Fix:** Reduce `money_drop` in `enemy_base.gd` to a value consistent with the intended economy (e.g., `var money_drop = 500`) or document that the current values are placeholder.

---

### IN-03: Commented-out / unused `puzzle_label` null-check pattern is inconsistent

**File:** `script/dungeon.gd` (multiple locations, e.g., lines 541, 551, 553, 619, 621)

`puzzle_label` is always constructed in `_build_hud()` which is called unconditionally in `_ready()` before `_setup_puzzle()`. The repeated `if puzzle_label:` null guards (appearing ~15 times) are dead code — `puzzle_label` is never null when these execute. The guards add noise and imply the label might be absent, which it never is.

**Fix:** Remove the null guards or assign `puzzle_label` earlier in `_ready()` and document that it is always valid post-`_ready`.

---

_Reviewed: 2026-05-08T23:16:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
