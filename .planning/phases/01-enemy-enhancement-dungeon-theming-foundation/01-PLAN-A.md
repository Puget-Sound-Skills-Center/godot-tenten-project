---
phase: "01-enemy-enhancement-dungeon-theming-foundation"
plan: "01-PLAN-A"
type: execute
wave: 1
depends_on: []
files_modified:
  - script/npc.gd
  - script/dungeon_npc.gd
  - script/enemy_base.gd
  - script/dungeon.gd
  - script/player.gd
autonomous: true
requirements:
  - PRE-01
  - PRE-02
  - PRE-03

must_haves:
  truths:
    - "No freed-reference crash occurs when player scene changes while NPC interaction is pending"
    - "Enemy health bars show the correct proportion for any max_health value (not capped at 100)"
    - "Enemy spawn count never exceeds 30 regardless of floor number"
    - "player.gd exposes take_damage(amount) so projectiles can deal damage"
    - "enemy_base.gd exists and contains all behavior from enemy.gd plus pack alert signal"
  artifacts:
    - path: "script/enemy_base.gd"
      provides: "Refactored enemy base class with max_health, damage, enemy_type, alert_pack signal, _on_pack_alerted handler"
      exports: ["enemy()"]
    - path: "script/npc.gd"
      provides: "is_instance_valid guard on player_ref"
      contains: "is_instance_valid(player_ref)"
    - path: "script/dungeon_npc.gd"
      provides: "is_instance_valid guard on player_ref"
      contains: "is_instance_valid(player_ref)"
    - path: "script/dungeon.gd"
      provides: "Spawn cap mini(5 + floor_no, 30)"
      contains: "mini(5 + floor_no, 30)"
    - path: "script/player.gd"
      provides: "take_damage(amount: int) method and _attacking_enemy reference"
      contains: "func take_damage"
  key_links:
    - from: "script/enemy_base.gd"
      to: "scenes/enemy.tscn"
      via: "ext_resource script path updated in .tscn"
      pattern: "enemy_base\\.gd"
    - from: "script/enemy_base.gd"
      to: "global"
      via: "global.player_current_attack, global.get_attack_damage(), global.money"
      pattern: "global\\."
    - from: "script/player.gd"
      to: "take_damage"
      via: "projectile body_entered calls body.take_damage(proj_damage)"
      pattern: "func take_damage"
---

<objective>
Fix three pre-existing bugs (freed-reference crash, health bar max_value, spawn cap) and create enemy_base.gd by refactoring enemy.gd. Add take_damage() to player.gd. Update enemy.tscn to reference the new base script.

Purpose: Unblocks all variant scripts (Plan B) and pack alert (Plan D). No new behavior — correctness and foundation only.
Output: enemy_base.gd, patched npc.gd, patched dungeon_npc.gd, patched dungeon.gd (spawn cap), patched player.gd (take_damage + _attacking_enemy).
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-RESEARCH.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-PATTERNS.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix PRE-01 (freed player_ref) in npc.gd and dungeon_npc.gd; fix PRE-03 (spawn cap) in dungeon.gd</name>

  <read_first>
    - script/npc.gd (read full file — confirm _process body at lines 38-41)
    - script/dungeon_npc.gd (read full file — confirm _process body at lines 38-40)
    - script/dungeon.gd lines 218-230 (confirm spawn cap line at ~222)
  </read_first>

  <action>
Three minimal edits:

**npc.gd `_process()`** — replace `player_ref and` with `is_instance_valid(player_ref) and`:
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            player_ref.open_shop()
```

**dungeon_npc.gd `_process()`** — add `is_instance_valid(player_ref) and` before the Input check:
```gdscript
func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        global.enter_dungeon = true
```

**dungeon.gd `_spawn_enemies()`** — change `var max_count := 5 + floor_no` to:
```gdscript
var max_count := mini(5 + floor_no, 30)
```
`mini()` is the GDScript 4 integer min — do NOT use `min()` (returns float).
  </action>

  <verify>
    <automated>grep -n "is_instance_valid(player_ref)" D:/Unity/godot-tenten-project/script/npc.gd D:/Unity/godot-tenten-project/script/dungeon_npc.gd</automated>
    <automated>grep -n "mini(5 + floor_no, 30)" D:/Unity/godot-tenten-project/script/dungeon.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/npc.gd contains `is_instance_valid(player_ref) and player_ref.has_method("open_shop")`
    - script/dungeon_npc.gd contains `is_instance_valid(player_ref) and Input.is_action_just_pressed`
    - script/dungeon.gd contains `mini(5 + floor_no, 30)` (exact string, integer mini not float min)
  </acceptance_criteria>

  <done>Three files patched. Grep confirms all three strings present.</done>
</task>

<task type="auto">
  <name>Task 2: Create script/enemy_base.gd (refactor of enemy.gd) and update scenes/enemy.tscn script reference</name>

  <read_first>
    - script/enemy.gd (read full file — source of all logic to carry over)
    - scenes/enemy.tscn (read full file — find ext_resource line pointing to enemy.gd)
  </read_first>

  <action>
Create `script/enemy_base.gd` as a full refactor of `enemy.gd`. Carry over ALL existing behavior verbatim, then apply these additions and fixes:

**Additions over enemy.gd:**
- `signal alert_pack(origin_position: Vector2)` — declared at top of file
- `var max_health: int = 100` — added to top-level vars
- `var damage: int = 5` — added to top-level vars
- `var enemy_type: String = "melee"` — added to top-level vars
- In `_ready()`: add `health = max_health` as the FIRST statement (before nav setup)
- In `_ready()`: add `add_to_group("enemies")` immediately after `health = max_health`
- In `_on_detection_area_body_entered`: after `player_chase = true`, add `get_tree().call_group("enemies", "_on_pack_alerted", global_position)`
- New method `_on_pack_alerted(origin_position: Vector2) -> void` (see below)
- Extract movement logic from `_physics_process` into `_move_toward_player() -> void` (variants override this)

**PRE-02 fix in update_health:**
Replace the old update_health body with:
```gdscript
func update_health() -> void:
    var healthbar := $healthbar
    healthbar.max_value = max_health
    healthbar.value = health
    healthbar.visible = health < max_health
```

**Fix typo:** `deal_with_damge()` → `deal_with_damage()` in both definition and call site.

**Full file content** (write exactly this):
```gdscript
extends CharacterBody2D

signal alert_pack(origin_position: Vector2)

var max_health: int = 100
var speed = 40
var damage: int = 5
var money_drop = 1000
var enemy_type: String = "melee"

var health: int
var player_chase = false
var player: Node2D = null

var player_inattack_range = false
var can_take_damage = true

var _nav_agent: NavigationAgent2D

func _ready() -> void:
    health = max_health
    add_to_group("enemies")

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

func enemy():
    pass

func _on_detection_area_body_entered(body) -> void:
    if body.has_method("player"):
        player = body as Node2D
        player_chase = true
        get_tree().call_group("enemies", "_on_pack_alerted", global_position)

func _on_detection_area_body_exited(body) -> void:
    if body.has_method("player"):
        player = null
        player_chase = false

func _on_pack_alerted(origin_position: Vector2) -> void:
    if player_chase:
        return
    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player = players[0] as Node2D
        player_chase = true

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_inattack_range = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
    if body.has_method("player"):
        player_inattack_range = false

func deal_with_damage() -> void:
    if player_inattack_range and global.player_current_attack == true:
        if can_take_damage == true:
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

**Update scenes/enemy.tscn:** Find the `ext_resource` line that reads `path="res://script/enemy.gd"` and change it to `path="res://script/enemy_base.gd"`. The `uid` attribute may differ — keep everything else unchanged, only swap the path string.

**Do NOT delete script/enemy.gd yet** — leave it in place to avoid breaking any scene references not yet updated. The .tscn update is the only change needed to make enemy.tscn use the base class.
  </action>

  <verify>
    <automated>grep -n "signal alert_pack" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "add_to_group" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "healthbar.max_value = max_health" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "_on_pack_alerted" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "enemy_base.gd" D:/Unity/godot-tenten-project/scenes/enemy.tscn</automated>
  </verify>

  <acceptance_criteria>
    - script/enemy_base.gd exists and contains `signal alert_pack(origin_position: Vector2)`
    - script/enemy_base.gd contains `add_to_group("enemies")`
    - script/enemy_base.gd contains `healthbar.max_value = max_health`
    - script/enemy_base.gd contains `func _on_pack_alerted(origin_position: Vector2) -> void:`
    - script/enemy_base.gd contains `health = max_health` before `_nav_agent = NavigationAgent2D.new()`
    - script/enemy_base.gd contains `get_tree().call_group("enemies", "_on_pack_alerted", global_position)`
    - script/enemy_base.gd contains `func _move_toward_player() -> void:`
    - script/enemy_base.gd does NOT contain `deal_with_damge` (typo must be gone)
    - scenes/enemy.tscn contains `enemy_base.gd` in its ext_resource path
  </acceptance_criteria>

  <done>enemy_base.gd created with all base behavior, additions, and PRE-02 fix. enemy.tscn updated to reference it.</done>
</task>

<task type="auto">
  <name>Task 3: Add take_damage() and _attacking_enemy to player.gd; add player to "player" group</name>

  <read_first>
    - script/player.gd (read full file — confirm enemy_attack() at ~122, hitbox handlers at ~114, top-level var block)
  </read_first>

  <action>
Three changes to player.gd:

**1. Add top-level var** (in the existing var block near line 13, after the last existing var):
```gdscript
var _attacking_enemy: Node2D = null
```

**2. Update `_on_player_hitbox_body_entered` and add `_on_player_hitbox_body_exited`:**

Current body_entered (line ~114):
```gdscript
func _on_player_hitbox_body_entered(body):
    if body.has_method("enemy"):
        enemy_inattack_range = true
```

Replace with:
```gdscript
func _on_player_hitbox_body_entered(body):
    if body.has_method("enemy"):
        enemy_inattack_range = true
        _attacking_enemy = body

func _on_player_hitbox_body_exited(body):
    if body.has_method("enemy"):
        enemy_inattack_range = false
        _attacking_enemy = null
```
If `_on_player_hitbox_body_exited` already exists, only add the `_attacking_enemy = null` line inside it.

**3. Update `enemy_attack()` to read attacker.damage:**
```gdscript
func enemy_attack():
    if enemy_inattack_range and enemy_attack_cooldown == true:
        var raw := 5
        if is_instance_valid(_attacking_enemy) and _attacking_enemy.get("damage") != null:
            raw = _attacking_enemy.damage
        var reduction = global.player_defense_level / 100.0
        var damage = max(1, int(raw * (1.0 - reduction)))
        health -= damage
        enemy_attack_cooldown = false
        $attack_cooldown.start()
```

**4. Add `take_damage(amount: int) -> void` method** (add after enemy_attack, before the next function):
```gdscript
func take_damage(amount: int) -> void:
    if enemy_attack_cooldown == false:
        return
    var reduction = global.player_defense_level / 100.0
    var damage = max(1, int(amount * (1.0 - reduction)))
    health -= damage
    enemy_attack_cooldown = false
    $attack_cooldown.start()
```
This reuses the existing `enemy_attack_cooldown` flag and `$attack_cooldown` Timer as invincibility frames — projectile hits share the same cooldown window as melee to prevent double-hit stacking.

**5. Add player to "player" group** — in `_ready()`, add:
```gdscript
add_to_group("player")
```
This is required so `enemy_base._on_pack_alerted()` can locate the player via `get_nodes_in_group("player")`.
  </action>

  <verify>
    <automated>grep -n "_attacking_enemy" D:/Unity/godot-tenten-project/script/player.gd</automated>
    <automated>grep -n "func take_damage" D:/Unity/godot-tenten-project/script/player.gd</automated>
    <automated>grep -n "add_to_group" D:/Unity/godot-tenten-project/script/player.gd</automated>
    <automated>grep -n "_attacking_enemy.get" D:/Unity/godot-tenten-project/script/player.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/player.gd contains `var _attacking_enemy: Node2D = null`
    - script/player.gd contains `_attacking_enemy = body` inside `_on_player_hitbox_body_entered`
    - script/player.gd contains `_attacking_enemy = null` inside `_on_player_hitbox_body_exited`
    - script/player.gd contains `func take_damage(amount: int) -> void:`
    - script/player.gd contains `_attacking_enemy.get("damage")` inside enemy_attack
    - script/player.gd contains `add_to_group("player")`
  </acceptance_criteria>

  <done>player.gd updated: _attacking_enemy tracking, scaled melee damage, take_damage() for projectiles, "player" group membership.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| enemy → player | Enemy body_entered triggers player damage; must validate reference validity |
| projectile → player | Projectile Area2D body_entered calls take_damage; player must guard invincibility frames |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01A-01 | Denial of Service | `_spawn_enemies` — unbounded enemy count | mitigate | `mini(5 + floor_no, 30)` cap — implemented in Task 1 (PRE-03) |
| T-01A-02 | Denial of Service | freed player_ref dereference in npc.gd/dungeon_npc.gd | mitigate | `is_instance_valid(player_ref)` guard — implemented in Task 1 (PRE-01) |
| T-01A-03 | Denial of Service | pack alert cascade — all 30 enemies activate simultaneously, spike nav pathfinding | accept | `call_group` fires once per detection; nav path updates spread across physics frames; cap of 30 limits total cost |
| T-01A-04 | Denial of Service | freed `_attacking_enemy` ref in enemy_attack() | mitigate | `is_instance_valid(_attacking_enemy)` check before `.get("damage")` — implemented in Task 3 |
</threat_model>

<verification>
After all tasks complete:
1. `grep -rn "is_instance_valid(player_ref)" script/npc.gd script/dungeon_npc.gd` — must return 1 match per file
2. `grep -n "mini(5 + floor_no, 30)" script/dungeon.gd` — must return exactly 1 match
3. `grep -n "enemy_base.gd" scenes/enemy.tscn` — must return 1 match in ext_resource path
4. `grep -n "signal alert_pack" script/enemy_base.gd` — must return 1 match
5. `grep -n "func take_damage" script/player.gd` — must return 1 match
6. `grep -n "add_to_group" script/player.gd` — must include `"player"` group
</verification>

<success_criteria>
- PRE-01: Both NPC scripts use is_instance_valid(player_ref) before dereferencing
- PRE-02: enemy_base.gd update_health sets healthbar.max_value = max_health (not hardcoded 100)
- PRE-03: dungeon.gd spawn cap is mini(5 + floor_no, 30)
- enemy_base.gd exists with signal, group membership, pack alert handler, _move_toward_player() virtual
- player.gd exposes take_damage() and tracks _attacking_enemy for scaled melee damage
- enemy.tscn references enemy_base.gd
</success_criteria>

<output>
After completion, create `.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-A-SUMMARY.md`
</output>
