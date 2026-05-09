# Phase 1: Enemy Enhancement + Dungeon Theming Foundation - Pattern Map

**Mapped:** 2026-05-08
**Files analyzed:** 8 (3 new, 5 modified)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `script/enemy_base.gd` (new) | entity/base | event-driven + request-response | `script/enemy.gd` | exact — direct refactor |
| `script/enemy_ranged.gd` (new) | entity/variant | event-driven | `script/enemy.gd` | role-match |
| `script/enemy_fast.gd` (new) | entity/variant | event-driven | `script/enemy.gd` | role-match |
| `script/enemy_tank.gd` (new) | entity/variant | event-driven | `script/enemy.gd` | role-match |
| `script/npc.gd` (modify) | entity/NPC | request-response | `script/dungeon_npc.gd` | exact |
| `script/dungeon_npc.gd` (modify) | entity/NPC | request-response | `script/npc.gd` | exact |
| `script/dungeon.gd` (modify) | scene/generator | batch + CRUD | `script/dungeon.gd` | self |
| `script/player.gd` (modify) | entity/player | event-driven | `script/player.gd` | self |

---

## Pattern Assignments

### `script/enemy_base.gd` (entity/base, event-driven)

**Analog:** `script/enemy.gd` — direct extraction; all existing logic moves here verbatim.

**Imports / extends pattern** (enemy.gd line 1):
```gdscript
extends CharacterBody2D
```

**Top-level vars pattern** (enemy.gd lines 3–13):
```gdscript
var speed = 40
var player_chase = false
var player: Node2D = null

var health = 100
var player_inattack_range = false
var can_take_damage = true

var money_drop = 1000

var _nav_agent: NavigationAgent2D
```
New base adds before these: `var max_health: int = 100`, `var damage: int = 5`, `var enemy_type: String = "melee"`, `signal alert_pack(origin_position: Vector2)`. Leading underscore on `_nav_agent` matches private node ref convention from CLAUDE.md.

**_ready() pattern** (enemy.gd lines 15–25):
```gdscript
func _ready() -> void:
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 4.0
	_nav_agent.target_desired_distance = 8.0
	_nav_agent.radius = 5.0
	add_child(_nav_agent)

	var detect_shape := CircleShape2D.new()
	detect_shape.radius = 120.0
	$detection_area/CollisionShape2D.shape = detect_shape
```
Base adds `health = max_health` and `add_to_group("enemies")` at top of `_ready()` before nav setup.

**_physics_process pattern** (enemy.gd lines 27–44):
```gdscript
func _physics_process(_delta):
	deal_with_damge()
	update_health()

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
```
Base extracts movement block into `_move_toward_player()` so variants can override it. The `deal_with_damge` typo is corrected to `deal_with_damage` in base.

**Duck-typing identity pattern** (enemy.gd line 56–57):
```gdscript
func enemy():
	pass
```
Preserved verbatim on base class — variants do NOT redeclare it (inherited).

**Signal handler pattern** (enemy.gd lines 46–54, 59–65):
```gdscript
func _on_detection_area_body_entered(body) -> void:
	if body.has_method("player"):
		player = body as Node2D
		player_chase = true

func _on_detection_area_body_exited(body) -> void:
	if body.has_method("player"):
		player = null
		player_chase = false

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_range = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_range = false
```
Pack alert: add `get_tree().call_group("enemies", "_on_pack_alerted", global_position)` inside `_on_detection_area_body_entered` after `player_chase = true`.

**Damage + health pattern** (enemy.gd lines 67–86) — fixes PRE-02:
```gdscript
func deal_with_damge():
	if player_inattack_range and global.player_current_attack == true:
		if can_take_damage == true:
			health -= global.get_attack_damage()
			$take_damage_cooldown.start()
			can_take_damage = false
			if health <= 0:
				global.money += money_drop
				self.queue_free()

func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true

func update_health():
	var healthbar = $healthbar
	healthbar.value = health
	if health >= 100:          # BUG — replace with max_health
		healthbar.visible = false
	else:
		healthbar.visible = true
```
Fixed version:
```gdscript
func update_health() -> void:
	var healthbar := $healthbar
	healthbar.max_value = max_health
	healthbar.value = health
	healthbar.visible = health < max_health
```
Pattern for `update_health` with `max_value` comes from `script/player.gd` lines 161–170 (player already does this correctly).

---

### `script/enemy_ranged.gd` (entity/variant, event-driven)

**Analog:** `script/enemy.gd` — same role; overrides `_move_toward_player()`.

**Extends pattern:**
```gdscript
extends "res://script/enemy_base.gd"
```
No `class_name` — consistent with CLAUDE.md: no custom class names in game scripts.

**_ready() override pattern** (copy from enemy_fast/tank pattern in RESEARCH.md):
```gdscript
func _ready() -> void:
	max_health = 60
	speed = 35.0
	damage = 8
	money_drop = 1200
	enemy_type = "ranged"
	super._ready()
	# variant-specific node setup after super
```
Rule: set all stat vars BEFORE `super._ready()` so base `health = max_health` picks them up.

**Timer creation pattern** (from player.gd `_setup_hud`/`_setup_shop` — same add_child idiom):
```gdscript
var _shoot_cooldown: Timer

# in _ready() after super._ready():
_shoot_cooldown = Timer.new()
_shoot_cooldown.wait_time = 2.0
_shoot_cooldown.one_shot = true
_shoot_cooldown.timeout.connect(_on_shoot_ready)
add_child(_shoot_cooldown)
```

**Projectile creation pattern** (new — no existing analog; use Area2D + ColorRect like dungeon.gd exit tile):
```gdscript
# dungeon.gd lines 241-258 — Area2D built in code with CollisionShape2D + visual
var area := Area2D.new()
var shape_node := CollisionShape2D.new()
var shape := RectangleShape2D.new()
shape.size = Vector2(TILE, TILE)
shape_node.shape = shape
area.add_child(shape_node)
var visual := ColorRect.new()
visual.color = EXIT_COLOR
visual.position = Vector2(-TILE / 2.0, -TILE / 2.0)
visual.size = Vector2(TILE, TILE)
area.add_child(visual)
```
Projectile uses CircleShape2D instead of Rect, adds to parent via `get_parent().add_child(proj)`.

**Instance-owned projectile tracking pattern** (new — prevents cross-enemy interference):
```gdscript
var _my_projectiles: Array = []

# in _fire_projectile(), after get_parent().add_child(proj):
_my_projectiles.append(proj)

# in _update_projectiles():
_my_projectiles = _my_projectiles.filter(func(p): return is_instance_valid(p))
for proj in _my_projectiles:
    var dir: Vector2 = proj.get_meta("direction")
    var spd: float = proj.get_meta("speed")
    proj.position += dir * spd * get_physics_process_delta_time()
```
Each ranged enemy instance owns its own projectile list. With N ranged enemies, each projectile is moved exactly once per frame — no N× speed bug. `filter(is_instance_valid)` purges freed refs at frame start.

**Self-cleanup timer pattern** (no existing analog — use lambda closure):
```gdscript
var t := Timer.new()
t.wait_time = 2.0
t.one_shot = true
t.timeout.connect(func(): if is_instance_valid(proj): proj.queue_free())
t.timeout.connect(t.queue_free)
proj.add_child(t)
t.start()
```

---

### `script/enemy_fast.gd` (entity/variant, event-driven)

**Analog:** `script/enemy.gd` — same role; no behavior override, only stat override.

**Full file pattern** (minimal variant):
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
Detection shape override uses same pattern as `enemy.gd` lines 22–25 — `CircleShape2D.new()` assigned to `$detection_area/CollisionShape2D.shape`.

---

### `script/enemy_tank.gd` (entity/variant, event-driven)

**Analog:** `script/enemy.gd` — same role; larger nav radius, tint + scale on sprite.

**Full file pattern:**
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
`_nav_agent` accessible because base declares it as a named var (not `$` path) — variant can reference it directly after `super._ready()` creates it.

---

### `script/npc.gd` (modify — PRE-01 fix)

**Analog:** `script/npc.gd` itself — 1-line guard change.

**Current pattern to replace** (npc.gd lines 38–41):
```gdscript
func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		if player_ref and player_ref.has_method("open_shop"):
			player_ref.open_shop()
```

**Fixed pattern:**
```gdscript
func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
			player_ref.open_shop()
```
Only change: `player_ref and` → `is_instance_valid(player_ref) and`. One token swap.

---

### `script/dungeon_npc.gd` (modify — PRE-01 fix)

**Analog:** `script/npc.gd` — identical structure, different action.

**Current pattern to replace** (dungeon_npc.gd lines 38–40):
```gdscript
func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		global.enter_dungeon = true
```

**Fixed pattern:**
```gdscript
func _process(_delta):
	if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
		global.enter_dungeon = true
```
Guard added before `Input.is_action_just_pressed` to short-circuit early.

---

### `script/dungeon.gd` (modify — PRE-03, spawn variant selection, stat scaling, theming)

**Analog:** `script/dungeon.gd` itself.

**PRE-03 spawn cap** (dungeon.gd line 222):
```gdscript
# CURRENT:
var max_count := 5 + floor_no

# FIXED:
var max_count := mini(5 + floor_no, 30)
```

**Variant spawn pattern** — replace enemy instantiation block (dungeon.gd lines 224–236):
```gdscript
# CURRENT — lines 224-236:
var packed: PackedScene = load(ENEMY_SCENE)
...
var enemy: Node2D = packed.instantiate()
enemy.position = pos
add_child(enemy)

# NEW — cache scripts as module-level consts (add near top of file):
const ENEMY_SCRIPT_BASE   := "res://script/enemy_base.gd"
const ENEMY_SCRIPT_RANGED := "res://script/enemy_ranged.gd"
const ENEMY_SCRIPT_FAST   := "res://script/enemy_fast.gd"
const ENEMY_SCRIPT_TANK   := "res://script/enemy_tank.gd"

# CORRECT order — set_script before add_child so variant _ready() fires with correct script.
# Apply scaling AFTER add_child (variant _ready() sets type-specific base stats first):
var enemy: Node2D = packed.instantiate()
enemy.set_script(load(_pick_enemy_script(floor_no)))
enemy.position = pos
add_child(enemy)  # _ready() fires HERE: variant sets base stats, super sets health = max_health
# THEN apply scaling (variant base stats are now set):
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.attack_damage *= mult
enemy.speed *= mult
enemy.current_health = enemy.max_health  # re-sync after scaling
```
`set_script()` before `add_child()` is mandatory — variant's `_ready()` must fire with the correct script.
Scaling is applied AFTER `add_child()` so variant `_ready()` sets type-specific base stats first.
`current_health = max_health` re-sync is mandatory after scaling — without it health is the pre-scale value.

**_pick_enemy_script helper pattern:**
```gdscript
func _pick_enemy_script(floor_no: int) -> String:
	if floor_no < 10:
		return ENEMY_SCRIPT_BASE
	elif floor_no < 34:
		return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_FAST].pick_random()
	elif floor_no < 67:
		return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST].pick_random()
	else:
		return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST, ENEMY_SCRIPT_TANK].pick_random()
```

**_get_floor_multiplier helper pattern:**
```gdscript
func _get_floor_multiplier(floor_no: int) -> float:
	return 1.0 + (floor_no - 1) / 99.0 * 2.0
```

**NavMesh agent_radius update** (dungeon.gd line 123):
```gdscript
# CURRENT:
nav_poly.agent_radius = 5.0

# UPDATED (accommodates tank avoidance radius):
nav_poly.agent_radius = 10.0
```

**Theme constants pattern** (add after existing color consts, dungeon.gd lines 9–21):
```gdscript
const THEME_CAVE := {
	"floor": Color(0.07, 0.06, 0.09),
	"wall":  Color(0.18, 0.16, 0.22),
	"exit":  Color(0.20, 0.85, 0.30),
	"accent": Color(0.35, 0.30, 0.55),
}
const THEME_RUINS := {
	"floor": Color(0.10, 0.08, 0.05),
	"wall":  Color(0.30, 0.22, 0.14),
	"exit":  Color(0.85, 0.75, 0.20),
	"accent": Color(0.55, 0.40, 0.20),
}
const THEME_ABYSS := {
	"floor": Color(0.02, 0.02, 0.08),
	"wall":  Color(0.08, 0.06, 0.20),
	"exit":  Color(0.60, 0.20, 0.90),
	"accent": Color(0.30, 0.10, 0.60),
}

var _theme: Dictionary
```

**_get_dungeon_theme helper + _ready() integration:**
```gdscript
func _get_dungeon_theme(floor_no: int) -> Dictionary:
	if floor_no >= 67:
		return THEME_ABYSS
	elif floor_no >= 34:
		return THEME_RUINS
	else:
		return THEME_CAVE

# In _ready(), as first statement after floor_no is set:
_theme = _get_dungeon_theme(floor_no)
```

**_build_floor_background refactor** (dungeon.gd lines 130–136) — replace `FLOOR_COLOR` with `_theme.floor`:
```gdscript
func _build_floor_background() -> void:
	var bg := ColorRect.new()
	bg.color = _theme.floor      # was: FLOOR_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(room_w, room_h)
	bg.z_index = -10
	add_child(bg)
```

**_make_wall refactor** (dungeon.gd line 138+) — replace `WALL_COLOR` with `_theme.wall` in the ColorRect.color assignment inside `_make_wall`. Pattern: the wall ColorRect color line changes from `WALL_COLOR` to `_theme.wall`. EXIT_COLOR references change to `_theme.exit`. ECHO_TILE_COLOR changes to `_theme.accent`.

---

### `script/player.gd` (modify — add take_damage(), scale enemy damage)

**Analog:** `script/player.gd` itself.

**Existing enemy_attack pattern to modify** (player.gd lines 122–128):
```gdscript
func enemy_attack():
	if enemy_inattack_range and enemy_attack_cooldown == true:
		var reduction = global.player_defense_level / 100.0
		var damage = max(1, int(5 * (1.0 - reduction)))
		health -= damage
		enemy_attack_cooldown = false
		$attack_cooldown.start()
```
Add `var _attacking_enemy: Node2D = null` to top-level vars (line ~13 area, matching existing var block style).

**Updated hitbox handler** (player.gd lines 114–120):
```gdscript
# CURRENT:
func _on_player_hitbox_body_entered(body):
	if body.has_method("enemy"):
		enemy_inattack_range = true

# UPDATED:
func _on_player_hitbox_body_entered(body):
	if body.has_method("enemy"):
		enemy_inattack_range = true
		_attacking_enemy = body

func _on_player_hitbox_body_exited(body):
	if body.has_method("enemy"):
		enemy_inattack_range = false
		_attacking_enemy = null
```

**Updated enemy_attack** reads attacker damage:
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

**New take_damage() method** (add after enemy_attack, matching function style — no type hints on older functions):
```gdscript
func take_damage(amount: int) -> void:
	if not can_take_damage:
		return
	var reduction = global.player_defense_level / 100.0
	var damage = max(1, int(amount * (1.0 - reduction)))
	health -= damage
	can_take_damage = false
	$attack_cooldown.start()
```
Note: reuses existing `$attack_cooldown` Timer and `enemy_attack_cooldown` flag as invincibility mechanism. Add `var can_take_damage := true` to top-level vars — or alias via `enemy_attack_cooldown` (already exists). Simplest: `take_damage` checks `enemy_attack_cooldown` and shares the cooldown timer with melee. This gives projectile hits the same cooldown window as melee, preventing projectile + melee double-hit stacking.

**update_health pattern** (player.gd lines 161–170) — already correct; this is the reference for enemy_base.gd's fix:
```gdscript
func update_health():
	var max_hp = global.get_max_health()
	health = min(health, max_hp)
	var healthbar = $healthbar
	healthbar.max_value = max_hp
	healthbar.value = health
	if health >= max_hp:
		healthbar.visible = false
	else:
		healthbar.visible = true
```

---

## Shared Patterns

### Duck-typing identity check
**Source:** `script/enemy.gd` line 47, `script/npc.gd` line 44, `script/player.gd` line 115
**Apply to:** All entity scripts, all collision callbacks
```gdscript
if body.has_method("player"):   # check for player
if body.has_method("enemy"):    # check for enemy
```
Never use node groups or `is` type checks — always `has_method()`.

### is_instance_valid guard
**Source:** `script/enemy.gd` line 31 (existing), fixes PRE-01
**Apply to:** Every place a stored node reference is dereferenced after it may have been freed
```gdscript
if is_instance_valid(some_ref) and some_ref.has_method("..."):
```

### Node built in code (no .tscn UI)
**Source:** `script/npc.gd` lines 11–36, `script/dungeon.gd` lines 130–136, 138+
**Apply to:** All projectile nodes, all timer nodes in variant scripts
```gdscript
var node := SomeNode.new()
node.property = value
add_child(node)
```

### Global state access
**Source:** `script/enemy.gd` line 68, `script/player.gd` line 124
**Apply to:** All scripts that read player stats or floor info
```gdscript
global.player_current_attack     # bare global. prefix, no $
global.get_attack_damage()       # method call on autoload
global.player_defense_level
```

### set_script() spawn pattern
**Source:** No existing analog — new pattern for Phase 1
**Apply to:** `dungeon.gd` `_spawn_enemies()` only
```gdscript
var enemy: Node2D = packed.instantiate()   # instantiate first
enemy.set_script(load(script_path))        # set script BEFORE add_child
enemy.position = pos
add_child(enemy)                           # _ready() fires HERE — variant sets base stats
# THEN apply scaling (post-add_child, after variant _ready() has run):
var mult := _get_floor_multiplier(floor_no)
enemy.max_health = int(enemy.max_health * mult)
enemy.current_health = enemy.max_health   # re-sync after scaling
```

### Timer signal connection
**Source:** `script/player.gd` lines 247–248, `script/npc.gd` lines 34–35
**Apply to:** All new Timer nodes in variant scripts
```gdscript
some_timer.timeout.connect(_on_timer_name)
area.body_entered.connect(_on_body_entered)
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Projectile node (inline in enemy_ranged.gd) | utility/object | request-response | No projectile pattern exists; closest is dungeon exit Area2D construction |

---

## Metadata

**Analog search scope:** `script/` directory (all 8 .gd files read)
**Files scanned:** `enemy.gd`, `npc.gd`, `dungeon_npc.gd`, `player.gd`, `dungeon.gd`
**Pattern extraction date:** 2026-05-08
