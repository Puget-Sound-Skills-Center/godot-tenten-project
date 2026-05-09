---
phase: "01-enemy-enhancement-dungeon-theming-foundation"
plan: "01-PLAN-B"
type: execute
wave: 2
depends_on:
  - "01-PLAN-A"
files_modified:
  - script/enemy_ranged.gd
  - script/enemy_fast.gd
  - script/enemy_tank.gd
autonomous: true
requirements:
  - ENM-01
  - ENM-02
  - ENM-03

must_haves:
  truths:
    - "enemy_ranged.gd backs away from the player when closer than 100px and fires a projectile on a 2s cooldown"
    - "enemy_fast.gd moves at speed 90 with a 150px detection radius — visibly faster than melee"
    - "enemy_tank.gd has 300 max_health, speed 22, and uses a red-tinted enlarged slime sprite"
    - "All three variant scripts set stats BEFORE calling super._ready() so health = max_health is correct"
    - "Projectiles self-destruct after 2s if they do not hit the player"
  artifacts:
    - path: "script/enemy_ranged.gd"
      provides: "Ranged enemy — maintains distance, fires orange projectile Area2D"
      exports: []
      contains: "extends \"res://script/enemy_base.gd\""
    - path: "script/enemy_fast.gd"
      provides: "Fast enemy — speed 90, small HP, large detection zone"
      contains: "extends \"res://script/enemy_base.gd\""
    - path: "script/enemy_tank.gd"
      provides: "Tank enemy — 300 HP, speed 22, damage 15, red tint"
      contains: "extends \"res://script/enemy_base.gd\""
  key_links:
    - from: "script/enemy_ranged.gd"
      to: "script/player.gd"
      via: "projectile body_entered calls body.take_damage(proj.get_meta(\"damage\"))"
      pattern: "take_damage"
    - from: "script/enemy_ranged.gd"
      to: "script/enemy_base.gd"
      via: "extends + super._ready()"
      pattern: "super\\._ready"
    - from: "script/enemy_tank.gd"
      to: "script/enemy_base.gd"
      via: "_nav_agent.radius = 10.0 after super._ready() creates _nav_agent"
      pattern: "_nav_agent\\.radius"
---

<objective>
Create the three enemy variant scripts: enemy_ranged.gd, enemy_fast.gd, enemy_tank.gd. Each extends enemy_base.gd, overrides stats before super._ready(), and adds any variant-specific behavior.

Purpose: Delivers ENM-01, ENM-02, ENM-03 — the actual gameplay variety. Plan C then wires these into dungeon spawning.
Output: Three new script files, each independently loadable via set_script() in dungeon.gd.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-RESEARCH.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-PATTERNS.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-A-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create script/enemy_fast.gd and script/enemy_tank.gd</name>

  <read_first>
    - script/enemy_base.gd (confirm _nav_agent var name, _ready() signature, detection_area node path)
  </read_first>

  <action>
**script/enemy_fast.gd** — stat-only variant, no behavior override:
```gdscript
extends "res://script/enemy_base.gd"

func _ready() -> void:
    max_health = 40
    speed = 90.0
    damage = 4
    money_drop = 800
    enemy_type = "fast"
    super._ready()
    var detect_shape := CircleShape2D.new()
    detect_shape.radius = 150.0
    $detection_area/CollisionShape2D.shape = detect_shape
```
Rule: all stat assignments BEFORE `super._ready()` so `health = max_health` in the base captures the overrides. Detection shape override AFTER `super._ready()` (which already sets it to 120px) — this replaces it with 150px.

**script/enemy_tank.gd** — high HP/damage, slow, red-tinted sprite, larger nav radius:
```gdscript
extends "res://script/enemy_base.gd"

func _ready() -> void:
    max_health = 300
    speed = 22.0
    damage = 15
    money_drop = 2000
    enemy_type = "tank"
    super._ready()
    _nav_agent.radius = 10.0
    var detect_shape := CircleShape2D.new()
    detect_shape.radius = 100.0
    $detection_area/CollisionShape2D.shape = detect_shape
    $AnimatedSprite2D.modulate = Color(0.6, 0.2, 0.2)
    $AnimatedSprite2D.scale = Vector2(1.5, 1.5)
```
`_nav_agent` is accessed after `super._ready()` which creates and assigns it. `$AnimatedSprite2D` is a scene node on enemy.tscn — access via `$` path after super runs (node tree is ready after add_child in dungeon.gd).
  </action>

  <verify>
    <automated>grep -n "super._ready" D:/Unity/godot-tenten-project/script/enemy_fast.gd D:/Unity/godot-tenten-project/script/enemy_tank.gd</automated>
    <automated>grep -n "max_health = " D:/Unity/godot-tenten-project/script/enemy_fast.gd D:/Unity/godot-tenten-project/script/enemy_tank.gd</automated>
    <automated>grep -n "_nav_agent.radius = 10.0" D:/Unity/godot-tenten-project/script/enemy_tank.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/enemy_fast.gd contains `extends "res://script/enemy_base.gd"`
    - script/enemy_fast.gd contains `max_health = 40` before `super._ready()`
    - script/enemy_fast.gd contains `speed = 90.0` before `super._ready()`
    - script/enemy_fast.gd contains `enemy_type = "fast"`
    - script/enemy_fast.gd contains `detect_shape.radius = 150.0` after `super._ready()`
    - script/enemy_tank.gd contains `extends "res://script/enemy_base.gd"`
    - script/enemy_tank.gd contains `max_health = 300` before `super._ready()`
    - script/enemy_tank.gd contains `speed = 22.0` before `super._ready()`
    - script/enemy_tank.gd contains `enemy_type = "tank"`
    - script/enemy_tank.gd contains `_nav_agent.radius = 10.0` after `super._ready()`
    - script/enemy_tank.gd contains `$AnimatedSprite2D.modulate = Color(0.6, 0.2, 0.2)`
    - script/enemy_tank.gd contains `$AnimatedSprite2D.scale = Vector2(1.5, 1.5)`
  </acceptance_criteria>

  <done>enemy_fast.gd and enemy_tank.gd created with correct stat overrides, extend chain, and variant-specific setup.</done>
</task>

<task type="auto">
  <name>Task 2: Create script/enemy_ranged.gd with distance-keeping movement and projectile firing</name>

  <read_first>
    - script/enemy_base.gd (confirm _move_toward_player() signature and player var name)
    - script/player.gd (confirm take_damage() signature added in Plan A)
    - script/dungeon.gd lines 240-260 (confirm Area2D construction pattern for exit tile — projectile analogy)
  </read_first>

  <action>
Create `script/enemy_ranged.gd`. This variant overrides `_move_toward_player()` to maintain standoff distance and fires an orange projectile Area2D on a 2s cooldown.

**Full file:**
```gdscript
extends "res://script/enemy_base.gd"

const PREFERRED_DISTANCE := 100.0
const FIRE_RANGE := 160.0

var _shoot_cooldown: Timer
var _shoot_ready := true

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
        var away := (global_position - player.global_position).normalized()
        velocity = away * speed
        move_and_slide()
    else:
        velocity = Vector2.ZERO

    $AnimatedSprite2D.play("move" if velocity.length() > 1.0 else "idle")
    $AnimatedSprite2D.flip_h = velocity.x < 0

    if _shoot_ready and dist < FIRE_RANGE:
        _fire_projectile()
        _shoot_ready = false
        _shoot_cooldown.start()

func _fire_projectile() -> void:
    var proj := Area2D.new()

    var shape_node := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 3.0
    shape_node.shape = shape
    proj.add_child(shape_node)

    var visual := ColorRect.new()
    visual.color = Color(1.0, 0.6, 0.1)
    visual.size = Vector2(6.0, 6.0)
    visual.position = Vector2(-3.0, -3.0)
    proj.add_child(visual)

    proj.position = global_position
    proj.collision_layer = 0
    proj.collision_mask = 0
    proj.set_meta("direction", (player.global_position - global_position).normalized())
    proj.set_meta("speed", 80.0)
    proj.set_meta("damage", damage)
    proj.body_entered.connect(_on_projectile_hit.bind(proj))
    get_parent().add_child(proj)

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

func _physics_process(_delta) -> void:
    deal_with_damage()
    update_health()
    _move_toward_player()
    _update_projectiles()

func _update_projectiles() -> void:
    for child in get_parent().get_children():
        if child is Area2D and child.has_meta("direction"):
            var dir: Vector2 = child.get_meta("direction")
            var spd: float = child.get_meta("speed")
            child.position += dir * spd * get_physics_process_delta_time()
```

**Notes:**
- `collision_layer = 0` and `collision_mask = 0` on the projectile Area2D means it does not physically collide with walls; it only uses `body_entered` for player detection. The `body_entered` signal on Area2D fires when physics bodies (CharacterBody2D) enter the area — player's CharacterBody2D will trigger it.
- Projectile movement is driven by `_update_projectiles()` in `_physics_process` — iterates children of the dungeon scene that have the "direction" meta. This avoids attaching a separate script to each projectile node.
- The 2s Timer on each projectile is the leak-prevention mechanism. If projectile does not hit within 2s, it is freed.
  </action>

  <verify>
    <automated>grep -n "super._ready" D:/Unity/godot-tenten-project/script/enemy_ranged.gd</automated>
    <automated>grep -n "PREFERRED_DISTANCE" D:/Unity/godot-tenten-project/script/enemy_ranged.gd</automated>
    <automated>grep -n "take_damage" D:/Unity/godot-tenten-project/script/enemy_ranged.gd</automated>
    <automated>grep -n "queue_free" D:/Unity/godot-tenten-project/script/enemy_ranged.gd</automated>
    <automated>grep -n "collision_mask = 0" D:/Unity/godot-tenten-project/script/enemy_ranged.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/enemy_ranged.gd contains `extends "res://script/enemy_base.gd"`
    - script/enemy_ranged.gd contains `max_health = 60` before `super._ready()`
    - script/enemy_ranged.gd contains `enemy_type = "ranged"`
    - script/enemy_ranged.gd contains `func _move_toward_player() -> void:`
    - script/enemy_ranged.gd contains `const PREFERRED_DISTANCE := 100.0`
    - script/enemy_ranged.gd contains `func _fire_projectile() -> void:`
    - script/enemy_ranged.gd contains `body.take_damage(proj.get_meta("damage"))`
    - script/enemy_ranged.gd contains `t.wait_time = 2.0` (auto-free timer)
    - script/enemy_ranged.gd contains `collision_mask = 0` on projectile
    - script/enemy_ranged.gd does NOT contain `_shoot_ready = true` inside `_fire_projectile` (must be in `_on_shoot_ready`)
  </acceptance_criteria>

  <done>enemy_ranged.gd created with distance-keeping movement, projectile firing on cooldown, auto-free timer, and player take_damage() integration.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| projectile Area2D → player CharacterBody2D | body_entered fires; calls take_damage() on body |
| enemy_ranged._update_projectiles → dungeon scene children | Iterates all Area2D children with "direction" meta — no filtering beyond meta presence |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01B-01 | Denial of Service | Projectile node leak if player dies before hit | mitigate | 2s Timer auto-queues projectile free regardless of hit; implemented in _fire_projectile |
| T-01B-02 | Denial of Service | _update_projectiles iterates all dungeon Area2D children | accept | At most 30 enemies × 1 active projectile each = 30 Area2D nodes; linear scan is O(n) acceptable |
| T-01B-03 | Denial of Service | Freed player reference in _fire_projectile | mitigate | `is_instance_valid(player)` guard in `_move_toward_player()` before calling `_fire_projectile()` — projectile only fires when player is valid |
| T-01B-04 | Spoofing | Non-player Area2D with "direction" meta moved by _update_projectiles | accept | Only enemy_ranged creates such nodes; no external input path exists in single-player game |
</threat_model>

<verification>
After all tasks complete:
1. All three files contain `extends "res://script/enemy_base.gd"` — confirmed via grep
2. Each file sets stats before `super._ready()` — confirmed via grep line ordering
3. enemy_ranged.gd `_fire_projectile` calls `body.take_damage()` on player hit
4. enemy_tank.gd `_nav_agent.radius = 10.0` appears after `super._ready()`
5. No file contains `class_name` declaration (CLAUDE.md requirement)
</verification>

<success_criteria>
- ENM-01: enemy_ranged.gd backs away at < 100px, fires projectile at < 160px on 2s cooldown, projectile calls player.take_damage()
- ENM-02: enemy_fast.gd overrides speed = 90.0 and detection radius to 150px; inherits all base movement
- ENM-03: enemy_tank.gd overrides max_health = 300, speed = 22.0, damage = 15; tank uses red-tinted enlarged sprite
- All three variants extend enemy_base.gd, set stats before super._ready()
</success_criteria>

<output>
After completion, create `.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-B-SUMMARY.md`
</output>
