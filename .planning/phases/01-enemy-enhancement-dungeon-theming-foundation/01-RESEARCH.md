# Phase 1: Enemy Enhancement + Dungeon Theming Foundation — Research

**Researched:** 2026-05-08
**Domain:** Godot 4.6 GDScript — enemy architecture, signal systems, NavigationAgent2D, procedural dungeon coloring
**Confidence:** HIGH (all findings from direct codebase reads; no external dependencies)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRE-01 | Fix freed `player_ref` crash in `npc.gd` and `dungeon_npc.gd` | Exact lines identified; minimal 1-line guard each |
| PRE-02 | Fix health bar `max_value = 100` → `max_value = max_health` in enemy | Line 82 of `enemy.gd`; requires `max_health` var on base |
| PRE-03 | Add enemy spawn cap `min(5 + floor_no, 30)` in `dungeon.gd` | Line 222 of `dungeon.gd`; single expression change |
| ENM-01 | Ranged enemy — projectile attacks, lower HP | Base class + `enemy_ranged.gd` variant script |
| ENM-02 | Fast enemy — high speed, low HP, rush behavior | Base class + `enemy_fast.gd` variant script |
| ENM-03 | Tank enemy — high HP, slow, high damage | Base class + `enemy_tank.gd` variant script; nav mesh radius concern |
| ENM-04 | All enemy types scale stats by floor range | Scaling formulas; applied at spawn time in `dungeon.gd` |
| ENM-05 | Pack alert via signal, not per-frame polling | Signal on base class; Area2D group scan at detection time |
| DNG-01 | 2–3 dungeon visual themes by floor range | Palette swap on existing ColorRect nodes; 3 const blocks |
</phase_requirements>

---

## Summary

Phase 1 is a codebase-surgery phase. The existing `enemy.gd` is a monolithic 87-line script attached to `enemy.tscn`. Everything — stats, pathfinding, health bar, combat — lives in one file with hardcoded values (`health = 100`, `speed = 40`, `max_value = 100`). The refactor splits this into `enemy_base.gd` (shared logic) plus three thin variant scripts set via `set_script()` at spawn time.

The three prerequisite bugs are all trivially small changes (1–3 lines each) but block everything else — PRE-02 (health bar) and PRE-03 (spawn cap) are the most urgent. The pack alert system requires a new signal on the base class and a one-time Area2D scan when detection triggers, replacing nothing (the existing code has no alerting at all). Dungeon theming requires only adding a helper function to `dungeon.gd` that returns a color struct based on `floor_no`, then passing those colors into existing `_build_floor_background()` and `_make_wall()` calls.

**Primary recommendation:** Build in this order — PRE fixes → `enemy_base.gd` extraction → three variant scripts → stat scaling at spawn → pack alert signal → dungeon theme palettes. Each step is independently testable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Enemy stats (HP, speed, damage) | Entity script (`enemy_base.gd`) | `dungeon.gd` (applies floor scaling at spawn) | Stats are per-instance; floor number is known at spawn time |
| Enemy variant behavior | Variant scripts (`enemy_ranged.gd`, etc.) | `enemy_base.gd` (inherited base behavior) | Each type overrides only what differs |
| Pack alert signal emission | `enemy_base.gd` (detection callback) | — | Signal emitted when player first detected |
| Pack alert signal reception | `enemy_base.gd` (signal handler) | `dungeon.gd` (connects signals at spawn) | All enemies share the handler; dungeon wires them |
| Dungeon color theming | `dungeon.gd` (`_get_theme()` helper) | — | All ColorRect construction is already in `dungeon.gd` |
| Projectile spawning | `enemy_ranged.gd` | `dungeon.gd` scene tree (projectile added as child) | Ranged enemy owns its own attack logic |
| NavMesh baking | `dungeon.gd` (`_setup_navigation()`) | — | Already baked in `_ready()`; radius must cover tank size |

---

## Prerequisite Fixes (PRE-01, PRE-02, PRE-03)

### PRE-01: Freed player_ref crash

**Files:** `script/npc.gd` line 39–41, `script/dungeon_npc.gd` line 39

Both files have identical `_process()` pattern:

```gdscript
# npc.gd line 38-41 (CURRENT)
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if player_ref and player_ref.has_method("open_shop"):
            player_ref.open_shop()

# dungeon_npc.gd line 38-40 (CURRENT)
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        global.enter_dungeon = true
```

`player_ref` is set to `body` on `body_entered` and set to `null` on `body_exited`. The crash occurs if the player node is freed (scene change, death) while `player_nearby` is still true — `player_ref` becomes a freed reference, and `player_ref and ...` does NOT protect against this in GDScript 4.x (the `and` short-circuit only skips if the value is `null`/`false`, but a freed object reference is truthy).

**Fix — npc.gd `_process()`:**
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            player_ref.open_shop()
```

**Fix — dungeon_npc.gd `_process()`:**
```gdscript
func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        global.enter_dungeon = true
```

Also add `is_instance_valid(player_ref)` guard in `_on_body_exited` for belt-and-suspenders (low priority, but clean). [VERIFIED: direct code read]

### PRE-02: Health bar max_value

**File:** `script/enemy.gd` lines 80–86

```gdscript
# CURRENT (line 80-86)
func update_health():
    var healthbar = $healthbar
    healthbar.value = health
    if health >= 100:       # BUG: hardcoded 100
        healthbar.visible = false
    else:
        healthbar.visible = true
```

The `healthbar` ProgressBar node in `enemy.tscn` has no explicit `max_value` set in the tscn — it defaults to 100. [VERIFIED: enemy.tscn read, no `max_value` property set on the ProgressBar node]

**Fix:** After `enemy_base.gd` is created, the base class must declare `var max_health: int` and set it in `_ready()`. Then `update_health()` becomes:
```gdscript
func update_health():
    var healthbar = $healthbar
    healthbar.max_value = max_health
    healthbar.value = health
    healthbar.visible = health < max_health
```

This is the key reason `enemy_base.gd` must be created first — it introduces `max_health` as a named variable that variants can override before `_ready()` runs.

### PRE-03: Enemy spawn cap

**File:** `script/dungeon.gd` line 222

```gdscript
# CURRENT (line 221-223)
func _spawn_enemies(floor_no: int, obstacles: Array) -> void:
    var max_count := 5 + floor_no   # BUG: no cap — floor 95 = 100 enemies
    var count := rng.randi_range(1, max_count)
```

**Fix:**
```gdscript
var max_count := mini(5 + floor_no, 30)
```

`mini()` is the correct integer min function in GDScript 4. [VERIFIED: GDScript 4 built-in — `mini` for int, `minf` for float]

---

## enemy_base.gd Design

### What the base contains

`enemy_base.gd` is the refactored `enemy.gd`. It keeps all existing logic and adds:
- `max_health` and `damage` as overridable vars (variants set these before `super._ready()`)
- `enemy_type: String` for quest kill tracking (Phase 3 dependency)
- `alert_pack` signal for pack behavior (ENM-05)
- `_on_pack_alerted()` method that variants don't need to override

```gdscript
# script/enemy_base.gd
extends CharacterBody2D

signal alert_pack(origin_position: Vector2)

# --- Overridable stats (set by variant before _ready) ---
var max_health: int = 100
var speed: float = 40.0
var damage: int = 5          # per-hit damage dealt to player
var money_drop: int = 1000
var enemy_type: String = "melee"  # used by quest system in Phase 3

# --- Runtime state ---
var health: int
var player_chase := false
var player: Node2D = null
var player_inattack_range := false
var can_take_damage := true

var _nav_agent: NavigationAgent2D

func _ready() -> void:
    health = max_health
    _nav_agent = NavigationAgent2D.new()
    _nav_agent.path_desired_distance = 4.0
    _nav_agent.target_desired_distance = 8.0
    _nav_agent.radius = 5.0
    add_child(_nav_agent)

    var detect_shape := CircleShape2D.new()
    detect_shape.radius = 120.0
    $detection_area/CollisionShape2D.shape = detect_shape

func _physics_process(_delta):
    deal_with_damage()
    update_health()
    _move_toward_player()

func _move_toward_player() -> void:
    if player_chase and is_instance_valid(player):
        _nav_agent.target_position = player.global_position
        if not _nav_agent.is_navigation_finished():
            var next := _nav_agent.get_next_path_position()
            var direction: Vector2 = (next - global_position).normalized()
            velocity = direction * speed
        else:
            velocity = Vector2.ZERO
        move_and_slide()
        $AnimatedSprite2D.play("move")
        $AnimatedSprite2D.flip_h = velocity.x < 0
    else:
        velocity = Vector2.ZERO
        $AnimatedSprite2D.play("idle")

func _on_detection_area_body_entered(body) -> void:
    if body.has_method("player"):
        player = body as Node2D
        player_chase = true
        alert_pack.emit(global_position)   # ENM-05: signal pack

func _on_detection_area_body_exited(body) -> void:
    if body.has_method("player"):
        player = null
        player_chase = false

func _on_pack_alerted(origin_position: Vector2) -> void:
    # Called when a nearby enemy detected the player first
    if not player_chase:
        # Find the player via group — safe because player adds itself to "player" group
        var players := get_tree().get_nodes_in_group("player")
        if players.size() > 0:
            player = players[0] as Node2D
            player_chase = true

func enemy() -> void:
    pass

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_inattack_range = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
    if body.has_method("player"):
        player_inattack_range = false

func deal_with_damage() -> void:
    if player_inattack_range and global.player_current_attack:
        if can_take_damage:
            health -= global.get_attack_damage()
            $take_damage_cooldown.start()
            can_take_damage = false
            if health <= 0:
                global.money += money_drop
                queue_free()

func _on_take_damage_cooldown_timeout() -> void:
    can_take_damage = true

func update_health() -> void:
    var healthbar := $healthbar
    healthbar.max_value = max_health
    healthbar.value = health
    healthbar.visible = health < max_health
```

### set_script() with NavigationAgent2D — critical note

`set_script()` replaces the script on an **already-instantiated** node. In the spawn path in `dungeon.gd`, the sequence must be:

```gdscript
var enemy: Node2D = packed.instantiate()   # enemy.tscn instantiated, no _ready yet
enemy.set_script(load("res://script/enemy_ranged.gd"))  # replace script BEFORE add_child
enemy.position = pos
add_child(enemy)  # _ready() fires HERE on the variant script
```

**Why this works:** `add_child()` triggers `_ready()`. If `set_script()` is called before `add_child()`, the variant's `_ready()` runs, which can call `super._ready()` to run base initialization. The NavigationAgent2D is added during `_ready()` so it exists after. [VERIFIED: Godot 4 scene lifecycle — `_ready()` fires on `add_child`, not on `instantiate`] [ASSUMED: `set_script()` before `add_child` is the correct order; standard Godot pattern but not tested in this specific codebase]

### Signals for pack alert

The base class declares `signal alert_pack(origin_position: Vector2)`. `dungeon.gd` connects all spawned enemies to each other's signal at spawn time (see Pack Alert section below).

---

## Enemy Variant Designs

### enemy_ranged.gd (ENM-01)

**Behavior:** Maintains distance from player; fires a projectile on a cooldown; lower HP than melee.

**Art:** No dedicated ranged sprite in `art/characters/` — `skeleton.png` or `skeleton_swordless.png` exists and fits a ranged archer archetype. [VERIFIED: art directory listing]

```gdscript
# script/enemy_ranged.gd
extends "res://script/enemy_base.gd"

var _shoot_cooldown: Timer
var _shoot_ready := true
var _my_projectiles: Array = []
const PREFERRED_DISTANCE := 100.0

func _ready() -> void:
    max_health = 60
    speed = 35.0
    damage = 8
    money_drop = 1200
    enemy_type = "ranged"
    super._ready()

    _shoot_cooldown = Timer.new()
    _shoot_cooldown.wait_time = 2.0
    _shoot_cooldown.one_shot = true
    _shoot_cooldown.timeout.connect(_on_shoot_ready)
    add_child(_shoot_cooldown)

func _on_shoot_ready() -> void:
    _shoot_ready = true

func _move_toward_player() -> void:
    if not (player_chase and is_instance_valid(player)):
        velocity = Vector2.ZERO
        $AnimatedSprite2D.play("idle")
        return

    var dist := global_position.distance_to(player.global_position)

    if dist < PREFERRED_DISTANCE:
        # Back away
        var away := (global_position - player.global_position).normalized()
        velocity = away * speed
        move_and_slide()
    else:
        velocity = Vector2.ZERO

    $AnimatedSprite2D.play("move" if velocity.length() > 1 else "idle")

    if _shoot_ready and dist < 160.0:
        _fire_projectile()
        _shoot_ready = false
        _shoot_cooldown.start()

func _fire_projectile() -> void:
    var proj := Area2D.new()
    var shape_n := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 3.0
    shape_n.shape = shape
    proj.add_child(shape_n)

    var visual := ColorRect.new()
    visual.color = Color(1.0, 0.6, 0.1)
    visual.size = Vector2(6, 6)
    visual.position = Vector2(-3, -3)
    proj.add_child(visual)

    proj.position = global_position
    proj.set_meta("direction", (player.global_position - global_position).normalized())
    proj.set_meta("speed", 80.0)
    proj.set_meta("damage", damage)
    proj.body_entered.connect(_on_projectile_hit.bind(proj))
    get_parent().add_child(proj)
    _my_projectiles.append(proj)

    var t := Timer.new()
    t.wait_time = 2.0
    t.one_shot = true
    t.timeout.connect(func(): if is_instance_valid(proj): proj.queue_free())
    t.timeout.connect(t.queue_free)
    proj.add_child(t)
    t.start()

func _on_projectile_hit(body: Node2D, proj: Area2D) -> void:
    if body.has_method("player"):
        body.take_damage(proj.get_meta("damage"))
    if is_instance_valid(proj):
        proj.queue_free()

func _update_projectiles() -> void:
    _my_projectiles = _my_projectiles.filter(func(p): return is_instance_valid(p))
    for proj in _my_projectiles:
        var dir: Vector2 = proj.get_meta("direction")
        var spd: float = proj.get_meta("speed")
        proj.position += dir * spd * get_physics_process_delta_time()
```

**Projectile damage design decision:** The existing player attack system uses a global flag (`global.player_current_attack`) polled by enemies. The inverse — enemies dealing damage to the player — uses `player_inattack_range` + an `attack_cooldown` Timer in `player.gd`. Projectiles cannot set `player_inattack_range` because they're not the enemy hitbox. The simplest fix: add a `take_damage(amount: int)` method to `player.gd` that the projectile calls directly. [ASSUMED: this is the correct approach — no existing projectile pattern in codebase to reference]

### enemy_fast.gd (ENM-02)

**Behavior:** Very high speed, low HP, no deviation from rush behavior.

```gdscript
# script/enemy_fast.gd
extends "res://script/enemy_base.gd"

func _ready() -> void:
    max_health = 40
    speed = 90.0
    damage = 4
    money_drop = 800
    enemy_type = "fast"
    super._ready()
    # Shrink detection shape for visual clarity
    var detect_shape := CircleShape2D.new()
    detect_shape.radius = 150.0  # Slightly larger — fast enemy spots earlier
    $detection_area/CollisionShape2D.shape = detect_shape
```

Fast enemy uses the inherited `_move_toward_player()` unchanged — higher speed does the work.

### enemy_tank.gd (ENM-03)

**Behavior:** High HP, slow, high damage. Larger collision radius.

```gdscript
# script/enemy_tank.gd
extends "res://script/enemy_base.gd"

func _ready() -> void:
    max_health = 300
    speed = 22.0
    damage = 15
    money_drop = 2000
    enemy_type = "tank"
    super._ready()
    # Override nav agent radius for larger body
    _nav_agent.radius = 10.0
    # Increase detection zone — tank is intimidating
    var detect_shape := CircleShape2D.new()
    detect_shape.radius = 100.0
    $detection_area/CollisionShape2D.shape = detect_shape
```

**NavMesh concern:** The nav polygon is baked with `agent_radius = 5.0` (dungeon.gd line 123). Tank's `_nav_agent.radius = 10.0` means it may fail to navigate through narrow gaps that the bake allows. The nav agent radius on the NavigationAgent2D component is used for avoidance, NOT for the polygon bake — the polygon bake radius (set on `NavigationPolygon`) determines passable passages. [VERIFIED: Godot 4 docs concept — NavigationPolygon.agent_radius shrinks walkable area during bake; NavigationAgent2D.radius is for avoidance only] [ASSUMED: bake_agent_radius of 5.0 in dungeon.gd line 123 refers to NavigationPolygon, which may be too small for tank avoidance but navigation will still work — tank just won't avoid other agents as precisely]

Practical approach: increase `NavigationPolygon.agent_radius` to `10.0` in `dungeon.gd` `_setup_navigation()` to accommodate tank. This slightly reduces navigable area near walls for all enemies, but with `TILE = 16` and passages at 2+ tiles wide, 10px radius is still safe. [ASSUMED: safe margin, needs playtesting]

---

## Pack Alert System (ENM-05)

### Design

When any enemy's `_on_detection_area_body_entered` fires for the player, it:
1. Sets its own `player_chase = true`
2. Emits `alert_pack(global_position)`

`dungeon.gd` at spawn time connects every enemy's `alert_pack` signal to every OTHER enemy's `_on_pack_alerted()` method. This is an O(n²) connection but with a cap of 30 enemies that is 870 connections max — acceptable, all one-time at spawn.

```gdscript
# In dungeon.gd _spawn_enemies(), after all enemies are spawned:
func _connect_pack_alerts(enemies: Array) -> void:
    for i in enemies.size():
        for j in enemies.size():
            if i == j:
                continue
            if enemies[i].has_signal("alert_pack"):
                enemies[i].alert_pack.connect(enemies[j]._on_pack_alerted)
```

**Alternative (simpler):** Use a single Group-based approach — when any enemy detects player, call `get_tree().call_group("enemies", "_on_pack_alerted", global_position)`. This requires all enemies to be in group "enemies" (add in `_ready()`). No O(n²) connections needed.

```gdscript
# In enemy_base.gd _ready():
add_to_group("enemies")

# In _on_detection_area_body_entered:
func _on_detection_area_body_entered(body) -> void:
    if body.has_method("player"):
        player = body as Node2D
        player_chase = true
        get_tree().call_group("enemies", "_on_pack_alerted", global_position)

# _on_pack_alerted unchanged
```

**Recommendation:** Use `call_group` approach. Simpler, no O(n²) connections, consistent with Godot idiom. No per-frame polling involved — fires once per detection event. [ASSUMED: `call_group` performance is acceptable for 30 enemies; it iterates the group once per call, which is O(n) not O(n²)]

**Important:** `_on_pack_alerted` must check `is_instance_valid(player)` or use the group lookup pattern shown above to safely get the player node.

---

## Stat Scaling System (ENM-04)

### Formula

Stats scale by floor range bracket. Applied at spawn time in `dungeon.gd` after `set_script()` and after `add_child()` (so variant `_ready()` sets type-specific base stats first).

```gdscript
# dungeon.gd — helper function
func _get_floor_multiplier(floor_no: int) -> float:
    # Floor 1 = 1.0x, Floor 100 = 3.0x, linear interpolation
    return 1.0 + (floor_no - 1) / 99.0 * 2.0

# Applied in _spawn_enemies AFTER add_child (variant _ready() has already run):
var enemy: Node2D = packed.instantiate()
enemy.set_script(load(_pick_enemy_script(floor_no)))
enemy.position = pos
add_child(enemy)   # _ready() fires here — variant sets base stats, super sets health = max_health
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.health = enemy.max_health  # re-sync after scaling
enemy.speed = enemy.speed * mult
enemy.money_drop = int(enemy.money_drop * mult)
```

**Integration point in `player.gd`:** The `enemy_attack()` function at line 122–128 currently hardcodes `5` as the damage value. This needs to read from the enemy:

```gdscript
func enemy_attack():
    if enemy_inattack_range and enemy_attack_cooldown == true:
        var attacker = _get_nearest_enemy_in_range()  # need helper
        var raw_damage = attacker.damage if (attacker and is_instance_valid(attacker)) else 5
        var reduction = global.player_defense_level / 100.0
        var damage = max(1, int(raw_damage * (1.0 - reduction)))
        health -= damage
        enemy_attack_cooldown = false
        $attack_cooldown.start()
```

Simpler approach: player.gd already tracks `enemy_inattack_range` via the hitbox. The hitbox `body_entered` already has the body reference. Store a reference to the attacking enemy:

```gdscript
var _attacking_enemy: Node2D = null

func _on_player_hitbox_body_entered(body):
    if body.has_method("enemy"):
        enemy_inattack_range = true
        _attacking_enemy = body

func enemy_attack():
    if enemy_inattack_range and enemy_attack_cooldown:
        var raw = 5
        if is_instance_valid(_attacking_enemy) and _attacking_enemy.get("damage") != null:
            raw = _attacking_enemy.damage
        ...
```

[ASSUMED: `get("damage")` duck-typed property access is safe in GDScript 4 — returns null if property doesn't exist]

### Floor ranges for stat display purposes

| Range | Label | Multiplier |
|-------|-------|-----------|
| 1–33 | Cave | 1.0x – 1.65x |
| 34–66 | Ruins | 1.66x – 2.32x |
| 67–100 | Abyss | 2.33x – 3.0x |

---

## Dungeon Theme System (DNG-01)

### Current coloring

`dungeon.gd` uses these constants at the top (lines 9–21):

```gdscript
const FLOOR_COLOR := Color(0.07, 0.06, 0.09)   # near-black dark purple
const WALL_COLOR := Color(0.18, 0.16, 0.22)    # muted purple-gray
```

These are passed into `_build_floor_background()` (background ColorRect) and `_make_wall()` (wall ColorRect). All visual tiles are ColorRects — no external tileset.

### Minimal theme implementation

Add a `_get_dungeon_theme(floor_no: int) -> Dictionary` function that returns floor/wall colors. Pass these into existing build calls.

```gdscript
# dungeon.gd — add these constants
const THEME_CAVE := {
    "floor": Color(0.07, 0.06, 0.09),   # existing — dark cave
    "wall":  Color(0.18, 0.16, 0.22),
    "exit":  Color(0.20, 0.85, 0.30),
    "accent": Color(0.35, 0.30, 0.55),  # puzzle echo color — fits cave
}
const THEME_RUINS := {
    "floor": Color(0.10, 0.08, 0.05),   # warm brown-black stone
    "wall":  Color(0.30, 0.22, 0.14),
    "exit":  Color(0.85, 0.75, 0.20),   # golden exit
    "accent": Color(0.55, 0.40, 0.20),
}
const THEME_ABYSS := {
    "floor": Color(0.02, 0.02, 0.08),   # near-black blue void
    "wall":  Color(0.08, 0.06, 0.20),
    "exit":  Color(0.60, 0.20, 0.90),   # purple/void exit
    "accent": Color(0.30, 0.10, 0.60),
}

func _get_dungeon_theme(floor_no: int) -> Dictionary:
    if floor_no >= 67:
        return THEME_ABYSS
    elif floor_no >= 34:
        return THEME_RUINS
    else:
        return THEME_CAVE
```

Then in `_ready()`:
```gdscript
var theme := _get_dungeon_theme(floor_no)
_build_floor_background(theme.floor)   # pass color as arg
_build_outer_walls(theme.wall)
# _make_wall already takes color from WALL_COLOR — refactor to use theme.wall
```

**Refactor scope:** `_build_floor_background()` and `_make_wall()` currently use the top-level constants directly. They must be updated to accept a color parameter, OR a module-level `_current_theme` variable is set at `_ready()` start and read by all builders. The module-level variable approach is fewer changes:

```gdscript
var _theme: Dictionary  # set in _ready()

func _ready() -> void:
    ...
    _theme = _get_dungeon_theme(floor_no)
    _build_floor_background()   # reads _theme.floor internally
    _build_outer_walls()        # reads _theme.wall internally
```

All `_make_wall()` calls use `_theme.wall` instead of `WALL_COLOR`. [VERIFIED: all `_make_wall` calls in dungeon.gd use the `WALL_COLOR` constant — 4 direct uses in `_build_outer_walls` and obstacle generation]

**HUD floor label** can show theme name for free: `"Dungeon Floor %d / %d  [Cave]"`.

---

## Navigation / NavMesh Considerations

### Current state

`dungeon.gd` `_setup_navigation()` (lines 102–128) bakes a `NavigationPolygon` with:
- `agent_radius = 5.0` (line 123)
- Walkable outline: room interior minus 1-tile border
- Obstacle holes: each wall rect punched out

This runs synchronously in `_ready()` via `NavigationServer2D.bake_from_source_geometry_data()`. [VERIFIED: dungeon.gd lines 102–128]

### Changes needed for Phase 1

1. **Tank enemy:** Set `NavigationPolygon.agent_radius = 10.0` (up from 5.0). Tank's nav agent avoidance radius is also 10.0. The polygon bake with 10px radius means passages must be at least 20px wide — with `TILE = 16`, two-tile passages (32px) are fine; single-tile passages (16px) would be too narrow for tank. Room walls are 1 tile thick, room interior is always multiple tiles wide, so navigation remains viable. [ASSUMED: no single-tile-wide corridors exist — dungeon generates open rooms, not corridors]

2. **Async bake option:** Not needed for Phase 1. Room sizes (480–1280px at floor 100) are small enough for synchronous bake. [ASSUMED: no perceptible stutter on target hardware — Godot 4 NavigationServer2D sync bake is fast for 2D geometry]

3. **Ranged enemy keep-distance:** Ranged enemy moves away from player when closer than 100px. This uses direct `velocity` assignment, NOT NavigationAgent2D path following when backing away. The nav agent is still used when chasing (for obstacle avoidance). Backing away uses raw direction vector — may clip corners, but acceptable for v1. [ASSUMED: corner clipping acceptable for ranged enemy retreat]

---

## Build Order

Recommended task sequence — each step verifiable independently:

```
Wave 0 (Prerequisite fixes — no new architecture)
  Task 0.1: PRE-03 — spawn cap in dungeon.gd (1 line)
  Task 0.2: PRE-01 — is_instance_valid guards in npc.gd and dungeon_npc.gd (2 lines)

Wave 1 (Base class extraction — unlocks everything)
  Task 1.1: Create script/enemy_base.gd (refactor of enemy.gd)
           - All existing behavior preserved
           - Add: max_health var, health = max_health in _ready()
           - Add: damage var
           - Add: enemy_type var
           - Add: alert_pack signal + call_group call in detection callback
           - Add: _on_pack_alerted() method
           - Fix: PRE-02 (update_health uses max_health)
           - Add: add_to_group("enemies") in _ready()
  Task 1.2: Update script/enemy.gd to extend enemy_base.gd
           OR rename enemy.gd → enemy_base.gd and update enemy.tscn ext_resource path
           (Option B is cleaner — fewer files)
  Task 1.3: Add take_damage(amount: int) to player.gd
           Task 1.4: Update player.gd enemy_attack() to read attacker.damage

Wave 2 (Enemy variants)
  Task 2.1: Create script/enemy_ranged.gd
  Task 2.2: Create script/enemy_fast.gd
  Task 2.3: Create script/enemy_tank.gd
  Task 2.4: Update dungeon.gd _spawn_enemies() to pick variant by floor range
           and apply stat scaling multiplier

Wave 3 (Dungeon themes)
  Task 3.1: Add theme constants and _get_dungeon_theme() to dungeon.gd
  Task 3.2: Refactor _make_wall / _build_floor_background to use _theme
  Task 3.3: Update EXIT_COLOR, puzzle tile colors to use accent from theme
```

### Enemy variant spawn distribution by floor range

```gdscript
# dungeon.gd _spawn_enemies() — pick script by floor range
func _pick_enemy_script(floor_no: int) -> GDScript:
    if floor_no < 10:
        return load("res://script/enemy_base.gd")  # cave: melee only
    elif floor_no < 34:
        # Cave upper: melee + fast
        return [load("res://script/enemy_base.gd"),
                load("res://script/enemy_fast.gd")].pick_random()
    elif floor_no < 67:
        # Ruins: melee + ranged
        return [load("res://script/enemy_base.gd"),
                load("res://script/enemy_ranged.gd"),
                load("res://script/enemy_fast.gd")].pick_random()
    else:
        # Abyss: all types including tank
        return [load("res://script/enemy_base.gd"),
                load("res://script/enemy_ranged.gd"),
                load("res://script/enemy_fast.gd"),
                load("res://script/enemy_tank.gd")].pick_random()
```

Cache the `load()` calls as module-level consts to avoid repeated disk reads per spawn. [ASSUMED: performance concern at 30 enemies; caching is standard practice]

---

## Art Assets for Enemy Variants

Existing sprites in `art/characters/`: [VERIFIED: directory listing]
- `slime.png` — used by current `enemy.tscn` (AnimatedSprite2D atlas at rows 0, 1, 2, 3)
- `skeleton.png` — available, not used in any scene currently
- `skeleton_swordless.png` — available, not used
- `player.png` — player only

**Assignment (suggested, LOW confidence — needs art audit):**
- `enemy_base.gd` (melee): slime — existing
- `enemy_fast.gd`: skeleton_swordless — fits fast, light enemy
- `enemy_ranged.gd`: skeleton — fits archer archetype
- `enemy_tank.gd`: No sprite available. Options: (a) recolor slime sprite at 2x scale, (b) placeholder colored rect, (c) new art. [ASSUMED: recolor + scale approach is acceptable for v1]

For tank sprite workaround using modulate + scale (no new art needed):
```gdscript
# In enemy_tank._ready(), after super._ready():
$AnimatedSprite2D.modulate = Color(0.6, 0.2, 0.2)  # red tint
$AnimatedSprite2D.scale = Vector2(1.5, 1.5)          # bigger
```

[ASSUMED: this is visually acceptable for v1 — planner should flag as risk]

---

## Validation Architecture

### How to verify each requirement

Since no test runner is configured (`addons/godot_ai` provides `test_handler.gd` for editor-side execution via MCP), validation is play-testing in editor + visual inspection:

| Req | Verification Method | Pass Condition |
|-----|---------------------|----------------|
| PRE-01 | Load world scene, interact with shop NPC, change scene mid-interaction | No crash; no freed reference error in output |
| PRE-02 | Spawn enemy with `max_health = 300` (tank); take damage | Health bar shows correct proportion, not 300/100 overflow |
| PRE-03 | Set `current_floor = 95` in global, enter dungeon | Enemy count ≤ 30 (count children with `has_method("enemy")`) |
| ENM-01 | Enter dungeon on floor 35+ | Ranged enemy backs away, fires projectile, projectile moves |
| ENM-02 | Enter dungeon on floor 15+ | Fast enemy noticeably faster than melee; dies in fewer hits |
| ENM-03 | Enter dungeon on floor 67+ | Tank takes many hits; moves slowly; deals high damage |
| ENM-04 | Compare floor 1 enemy HP vs floor 50 enemy HP | Floor 50 enemy has ~2x base HP via debug print |
| ENM-05 | Enter dungeon; approach 1 enemy silently, observe others | Distant enemies activate when first one detects player |
| DNG-01 | Enter dungeon at floor 1, 34, 67 | Clearly different color palettes on floor, walls |

**Debug helpers to add temporarily:**
```gdscript
# In _spawn_enemies, after spawning:
print("Spawned %d enemies (cap 30), floor %d" % [spawned, floor_no])
# In enemy_base._ready():
print("Enemy spawned: type=%s, hp=%d, speed=%.1f" % [enemy_type, max_health, speed])
```

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Tank sprite missing | HIGH | LOW | Use modulate+scale on slime sprite for v1 |
| `set_script()` before `add_child()` order causes _ready() to miss node refs | MEDIUM | HIGH | Test Wave 1 in isolation before building variants; log node path in _ready |
| Projectile damage requires player.take_damage() — new player.gd method | HIGH | MEDIUM | Add take_damage() in Wave 1 Task 1.3; it's a 3-line method |
| NavMesh bake radius 10px blocks narrow passages on higher floors | LOW | MEDIUM | Room generator always uses 2+ tile wide walls; verify at floor 80+ |
| pack alert causes all 30 enemies to path simultaneously → stutter | MEDIUM | MEDIUM | call_group fires once at detection; nav updates spread across physics frames; cap remains 30 |
| Ranged projectile Area2D collision mask not set — hits walls | MEDIUM | MEDIUM | Set projectile collision_mask = 0 (no physical collisions); it only uses body_entered for player detection |
| Floor theme `_theme` dict not initialized before first `_make_wall` call | LOW | HIGH | Set `_theme = _get_dungeon_theme(floor_no)` as first line of `_ready()` |

---

## Open Questions (RESOLVED)

1. **Projectile → player damage path**
   - What we know: player.gd uses an `enemy_inattack_range` flag + cooldown timer; projectiles can't use this system
   - What's unclear: Should `take_damage(amount)` bypass the cooldown timer or respect it?
   - RESOLVED: Reuse existing `$attack_cooldown` Timer. `take_damage()` checks `enemy_attack_cooldown` and shares the cooldown timer with melee — projectile hits get the same invincibility window, preventing projectile + melee double-hit stacking. No separate invincibility timer needed.

2. **enemy.tscn script path after rename**
   - What we know: `enemy.tscn` ext_resource points to `res://script/enemy.gd`
   - What's unclear: Rename `enemy.gd` → `enemy_base.gd`? Or keep `enemy.gd` as thin wrapper?
   - RESOLVED: Rename `enemy.gd` → `enemy_base.gd` and update `enemy.tscn` ext_resource reference. Cleaner for Phase 3 kill tracking. Requires one `.tscn` edit — covered in Plan A.

3. **Skeleton sprite animation names**
   - What we know: `slime.png` animations in enemy.tscn are named "idle", "move", "death"
   - What's unclear: Does `skeleton.png` have the same animation row layout?
   - RESOLVED: Use slime sprite with color modulation for all v1 variants — no sprite-swap needed. Tank uses red modulate + 1.5x scale; fast and ranged use default slime. Avoids animation-name mismatch risk entirely for Phase 1. Sprite differentiation deferred to Phase 2.

---

## Sources

### Primary (HIGH confidence)
- `script/enemy.gd` — direct read, all line numbers verified
- `script/dungeon.gd` — direct read, all line numbers verified
- `script/npc.gd` — direct read
- `script/dungeon_npc.gd` — direct read
- `script/player.gd` — direct read
- `script/global.gd` — direct read
- `scenes/enemy.tscn` — direct read, node structure and ProgressBar confirmed
- `art/characters/` — directory listing

### Assumed (needs validation)
- A1: `set_script()` before `add_child()` is the correct order for variant injection
- A2: `call_group` for pack alert doesn't introduce perceptible stutter at 30 enemies
- A3: `NavigationPolygon.agent_radius = 10.0` leaves navigable passages intact (room geometry dependent)
- A4: Tank sprite via modulate+scale on slime is visually acceptable for v1
- A5: Ranged enemy backing-away clips corners — acceptable for v1

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `set_script()` before `add_child()` makes variant `_ready()` fire with correct script | enemy_base.gd Design | Variant stats not applied; all enemies use base stats |
| A2 | `call_group` at 30 enemies causes no stutter | Pack Alert | Pack alert triggering causes frame drop on old hardware |
| A3 | NavMesh `agent_radius = 10.0` still navigable in dungeon rooms | NavMesh | Tank enemies get stuck; pathfinding fails |
| A4 | Slime sprite + modulate+scale passes as tank visual for v1 | Art Assets | Player confusion; enemies look identical |
| A5 | Ranged enemy retreat clips room corners | Enemy Variants | Ranged enemy gets stuck in corners |

---

## Metadata

**Confidence breakdown:**
- Prerequisite fixes: HIGH — exact file/line verified
- enemy_base.gd design: HIGH — all current behavior verified; API additions are additive
- Enemy variants: MEDIUM — behavior design is clear; art assets and `set_script()` ordering assumed
- Pack alert: MEDIUM — `call_group` approach is standard Godot idiom; untested in this codebase
- Stat scaling: HIGH — formula and integration points verified against existing global.gd methods
- Dungeon themes: HIGH — all ColorRect construction verified; palette change is minimal
- NavMesh: MEDIUM — Godot 4 nav behavior verified conceptually; tunnel-narrowing effect is assumed safe

**Research date:** 2026-05-08
**Valid until:** 2026-06-08 (stable Godot 4.6 — no churn expected)
