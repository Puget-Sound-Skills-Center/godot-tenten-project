# Dungeon Theme Showcase Scene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `scenes/dungeon_showcase.tscn` + `script/dungeon_showcase.gd` — a standalone scene with three themed rooms (CAVE, RUINS, ABYSS) connected by hallways, each populated with live enemies.

**Architecture:** Single Node2D scene, all structure built in GDScript `_ready()`. Three rooms at fixed X offsets joined by two 80px hallways with 96px-tall openings. One NavigationRegion2D covers all walkable areas. Follows puzzle_test.gd conventions exactly.

**Tech Stack:** Godot 4.6 / GDScript — no new dependencies.

---

## Layout Reference

```
CAVE [0..480]  HALL1 [480..560]  RUINS [560..1040]  HALL2 [1040..1120]  ABYSS [1120..1600]
```

| Constant | Value |
|---|---|
| ROOM_W | 480 |
| ROOM_H | 320 |
| TILE | 16 |
| HALL_W | 80 |
| HALL_H | 96 |
| HALL_WALL_H | 112  ← solid wall above/below each opening |
| CAVE_X | 0 |
| RUINS_X | 560 |
| ABYSS_X | 1120 |
| TOTAL_W | 1600 |

---

## Task 1: Scene file + skeleton script

**Files:**
- Create: `scenes/dungeon_showcase.tscn`
- Create: `script/dungeon_showcase.gd`

- [ ] **Create the scene file**

`scenes/dungeon_showcase.tscn`:
```
[gd_scene format=4 uid="uid://dshowcase0001"]

[ext_resource type="Script" uid="uid://dshowcase0002" path="res://script/dungeon_showcase.gd" id="1_show0"]

[node name="dungeon_showcase" type="Node2D"]
script = ExtResource("1_show0")
```

- [ ] **Create the skeleton script**

`script/dungeon_showcase.gd`:
```gdscript
extends Node2D

const TILE := 16
const PLAYER_SCENE := "res://scenes/player.tscn"
const ENEMY_SCENE  := "res://scenes/enemy.tscn"
const ENEMY_SCRIPT_BASE   := "res://script/enemy_base.gd"
const ENEMY_SCRIPT_RANGED := "res://script/enemy_ranged.gd"
const ENEMY_SCRIPT_FAST   := "res://script/enemy_fast.gd"
const ENEMY_SCRIPT_TANK   := "res://script/enemy_tank.gd"

const ROOM_W := 480
const ROOM_H := 320
const HALL_W := 80
const HALL_H := 96
const HALL_WALL_H := (ROOM_H - HALL_H) / 2

const CAVE_X  := 0
const RUINS_X := ROOM_W + HALL_W
const ABYSS_X := ROOM_W * 2 + HALL_W * 2
const TOTAL_W := ROOM_W * 3 + HALL_W * 2
const TOTAL_H := ROOM_H

const THEME_CAVE := {
	"floor": Color(0.07, 0.06, 0.09),
	"wall":  Color(0.18, 0.16, 0.22),
}
const THEME_RUINS := {
	"floor": Color(0.10, 0.08, 0.05),
	"wall":  Color(0.30, 0.22, 0.14),
}
const THEME_ABYSS := {
	"floor": Color(0.02, 0.02, 0.08),
	"wall":  Color(0.08, 0.06, 0.20),
}

var player_node: Node2D

func _ready() -> void:
	pass
```

- [ ] **Commit**

```bash
git add scenes/dungeon_showcase.tscn script/dungeon_showcase.gd
git commit -m "feat(showcase): add scene file and skeleton script"
```

---

## Task 2: Shared helpers + CAVE room

**Files:**
- Modify: `script/dungeon_showcase.gd`

- [ ] **Add `_make_bg`, `_make_wall`, `_make_label` helpers and `_build_cave_room`**

Replace `func _ready() -> void:` onwards with:

```gdscript
var player_node: Node2D

func _ready() -> void:
	_build_cave_room()

func _make_bg(rect: Rect2, color: Color) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.position = rect.position
	bg.size = rect.size
	bg.z_index = -10
	add_child(bg)

func _make_wall(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = color
	visual.position = -rect.size / 2.0
	visual.size = rect.size
	body.add_child(visual)
	add_child(body)

func _make_label(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)

func _build_cave_room() -> void:
	var x := CAVE_X
	_make_bg(Rect2(x, 0, ROOM_W, ROOM_H), THEME_CAVE.floor)
	_make_wall(Rect2(x, 0, ROOM_W, TILE), THEME_CAVE.wall)
	_make_wall(Rect2(x, ROOM_H - TILE, ROOM_W, TILE), THEME_CAVE.wall)
	_make_wall(Rect2(x, 0, TILE, ROOM_H), THEME_CAVE.wall)
	_make_wall(Rect2(x + ROOM_W - TILE, 0, TILE, HALL_WALL_H), THEME_CAVE.wall)
	_make_wall(Rect2(x + ROOM_W - TILE, ROOM_H - HALL_WALL_H, TILE, HALL_WALL_H), THEME_CAVE.wall)
	_make_label(Vector2(x + 20, 22), "CAVE  ·  Floors 1-33")
```

- [ ] **Open `dungeon_showcase.tscn` in Godot editor and run the scene**

Expected: dark purple-black floor, dark grey walls, label "CAVE · Floors 1-33" in top-left. Player not yet spawned — scene loads without errors (check Output panel).

- [ ] **Commit**

```bash
git add script/dungeon_showcase.gd
git commit -m "feat(showcase): build cave room with floor, walls, and label"
```

---

## Task 3: Hallway 1 + RUINS room

**Files:**
- Modify: `script/dungeon_showcase.gd`

- [ ] **Add `_build_hallway_1` and `_build_ruins_room`, call both from `_ready`**

Add after `_build_cave_room()` in `_ready`:
```gdscript
	_build_hallway_1()
	_build_ruins_room()
```

Add functions:
```gdscript
func _build_hallway_1() -> void:
	var x := CAVE_X + ROOM_W
	_make_bg(Rect2(x, 0, HALL_W, ROOM_H), THEME_CAVE.floor)
	_make_wall(Rect2(x, 0, HALL_W, HALL_WALL_H), THEME_CAVE.wall)
	_make_wall(Rect2(x, ROOM_H - HALL_WALL_H, HALL_W, HALL_WALL_H), THEME_CAVE.wall)

func _build_ruins_room() -> void:
	var x := RUINS_X
	_make_bg(Rect2(x, 0, ROOM_W, ROOM_H), THEME_RUINS.floor)
	_make_wall(Rect2(x, 0, ROOM_W, TILE), THEME_RUINS.wall)
	_make_wall(Rect2(x, ROOM_H - TILE, ROOM_W, TILE), THEME_RUINS.wall)
	_make_wall(Rect2(x, 0, TILE, HALL_WALL_H), THEME_RUINS.wall)
	_make_wall(Rect2(x, ROOM_H - HALL_WALL_H, TILE, HALL_WALL_H), THEME_RUINS.wall)
	_make_wall(Rect2(x + ROOM_W - TILE, 0, TILE, HALL_WALL_H), THEME_RUINS.wall)
	_make_wall(Rect2(x + ROOM_W - TILE, ROOM_H - HALL_WALL_H, TILE, HALL_WALL_H), THEME_RUINS.wall)
	_make_label(Vector2(x + 20, 22), "RUINS  ·  Floors 34-66")
```

- [ ] **Run the scene**

Expected: CAVE room (dark) connects through an 80px-wide, 96px-tall corridor to a warm brown RUINS room. Output panel: no errors.

- [ ] **Commit**

```bash
git add script/dungeon_showcase.gd
git commit -m "feat(showcase): add hallway 1 and ruins room"
```

---

## Task 4: Hallway 2 + ABYSS room

**Files:**
- Modify: `script/dungeon_showcase.gd`

- [ ] **Add `_build_hallway_2` and `_build_abyss_room`, call both from `_ready`**

Add after `_build_ruins_room()` in `_ready`:
```gdscript
	_build_hallway_2()
	_build_abyss_room()
```

Add functions:
```gdscript
func _build_hallway_2() -> void:
	var x := RUINS_X + ROOM_W
	_make_bg(Rect2(x, 0, HALL_W, ROOM_H), THEME_RUINS.floor)
	_make_wall(Rect2(x, 0, HALL_W, HALL_WALL_H), THEME_RUINS.wall)
	_make_wall(Rect2(x, ROOM_H - HALL_WALL_H, HALL_W, HALL_WALL_H), THEME_RUINS.wall)

func _build_abyss_room() -> void:
	var x := ABYSS_X
	_make_bg(Rect2(x, 0, ROOM_W, ROOM_H), THEME_ABYSS.floor)
	_make_wall(Rect2(x, 0, ROOM_W, TILE), THEME_ABYSS.wall)
	_make_wall(Rect2(x, ROOM_H - TILE, ROOM_W, TILE), THEME_ABYSS.wall)
	_make_wall(Rect2(x, 0, TILE, HALL_WALL_H), THEME_ABYSS.wall)
	_make_wall(Rect2(x, ROOM_H - HALL_WALL_H, TILE, HALL_WALL_H), THEME_ABYSS.wall)
	_make_wall(Rect2(x + ROOM_W - TILE, 0, TILE, ROOM_H), THEME_ABYSS.wall)
	_make_label(Vector2(x + 20, 22), "ABYSS  ·  Floors 67-100")
```

- [ ] **Run the scene**

Expected: all three rooms visible — CAVE (dark purple), RUINS (warm brown), ABYSS (near-black deep blue). Three labels. Connecting passages visible. Output panel: no errors.

- [ ] **Commit**

```bash
git add script/dungeon_showcase.gd
git commit -m "feat(showcase): add hallway 2 and abyss room"
```

---

## Task 5: Player + camera

**Files:**
- Modify: `script/dungeon_showcase.gd`

- [ ] **Add `_spawn_player`, call from `_ready`**

Add after `_build_abyss_room()` in `_ready`:
```gdscript
	_spawn_player()
```

Add function:
```gdscript
func _spawn_player() -> void:
	var packed: PackedScene = load(PLAYER_SCENE)
	player_node = packed.instantiate()
	player_node.position = Vector2(CAVE_X + ROOM_W / 2, ROOM_H / 2)
	add_child(player_node)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = TOTAL_W
	cam.limit_bottom = TOTAL_H
	cam.limit_smoothed = true
	cam.drag_horizontal_enabled = true
	cam.drag_vertical_enabled = true
	player_node.add_child(cam)
```

- [ ] **Run the scene**

Expected: player spawns in CAVE room center (240, 160). Camera follows. Player can walk left/right into walls, and forward toward the hallway. Output panel: no errors.

- [ ] **Walk through all three rooms**

Walk right from CAVE through the hallway opening, through RUINS, through the second hallway, into ABYSS. All passages navigable, no invisible walls blocking the openings.

- [ ] **Commit**

```bash
git add script/dungeon_showcase.gd
git commit -m "feat(showcase): spawn player with camera"
```

---

## Task 6: Navigation region

**Files:**
- Modify: `script/dungeon_showcase.gd`

- [ ] **Add `_setup_navigation`, call from `_ready` after `_spawn_player`**

Add after `_spawn_player()` in `_ready`:
```gdscript
	_setup_navigation()
```

Add function:
```gdscript
func _setup_navigation() -> void:
	var geo := NavigationMeshSourceGeometryData2D.new()

	# Cave interior
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(CAVE_X + TILE, TILE),
		Vector2(CAVE_X + TILE, ROOM_H - TILE),
		Vector2(CAVE_X + ROOM_W - TILE, ROOM_H - TILE),
		Vector2(CAVE_X + ROOM_W - TILE, TILE),
	]))
	# Hallway 1 passage (spans through both wall gaps)
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(CAVE_X + ROOM_W - TILE, HALL_WALL_H),
		Vector2(CAVE_X + ROOM_W - TILE, ROOM_H - HALL_WALL_H),
		Vector2(RUINS_X + TILE, ROOM_H - HALL_WALL_H),
		Vector2(RUINS_X + TILE, HALL_WALL_H),
	]))
	# Ruins interior
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(RUINS_X + TILE, TILE),
		Vector2(RUINS_X + TILE, ROOM_H - TILE),
		Vector2(RUINS_X + ROOM_W - TILE, ROOM_H - TILE),
		Vector2(RUINS_X + ROOM_W - TILE, TILE),
	]))
	# Hallway 2 passage
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(RUINS_X + ROOM_W - TILE, HALL_WALL_H),
		Vector2(RUINS_X + ROOM_W - TILE, ROOM_H - HALL_WALL_H),
		Vector2(ABYSS_X + TILE, ROOM_H - HALL_WALL_H),
		Vector2(ABYSS_X + TILE, HALL_WALL_H),
	]))
	# Abyss interior
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(ABYSS_X + TILE, TILE),
		Vector2(ABYSS_X + TILE, ROOM_H - TILE),
		Vector2(ABYSS_X + ROOM_W - TILE, ROOM_H - TILE),
		Vector2(ABYSS_X + ROOM_W - TILE, TILE),
	]))

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 10.0
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, geo)

	var nav_region := NavigationRegion2D.new()
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
```

- [ ] **Run the scene**

Expected: no errors. Navigation bakes silently. (Enemies not yet spawned — will be verified in Task 7.)

- [ ] **Commit**

```bash
git add script/dungeon_showcase.gd
git commit -m "feat(showcase): bake navigation region covering all rooms and hallways"
```

---

## Task 7: Enemy spawning

**Files:**
- Modify: `script/dungeon_showcase.gd`

- [ ] **Add `_spawn_cave_enemies`, `_spawn_ruins_enemies`, `_spawn_abyss_enemies`, call all from `_ready`**

Add after `_setup_navigation()` in `_ready`:
```gdscript
	_spawn_cave_enemies()
	_spawn_ruins_enemies()
	_spawn_abyss_enemies()
```

Add functions:
```gdscript
func _spawn_cave_enemies() -> void:
	var packed: PackedScene = load(ENEMY_SCENE)
	var positions := [Vector2(180, 160), Vector2(360, 200)]
	var scripts   := [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_BASE]
	for i in positions.size():
		var enemy: Node2D = packed.instantiate()
		enemy.set_script(load(scripts[i]))
		enemy.position = positions[i]
		add_child(enemy)

func _spawn_ruins_enemies() -> void:
	var packed: PackedScene = load(ENEMY_SCENE)
	var positions := [Vector2(RUINS_X + 120, 160), Vector2(RUINS_X + 300, 220)]
	var scripts   := [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_FAST]
	for i in positions.size():
		var enemy: Node2D = packed.instantiate()
		enemy.set_script(load(scripts[i]))
		enemy.position = positions[i]
		add_child(enemy)

func _spawn_abyss_enemies() -> void:
	var packed: PackedScene = load(ENEMY_SCENE)
	var positions := [Vector2(ABYSS_X + 120, 140), Vector2(ABYSS_X + 280, 200), Vector2(ABYSS_X + 380, 150)]
	var scripts   := [ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST, ENEMY_SCRIPT_TANK]
	for i in positions.size():
		var enemy: Node2D = packed.instantiate()
		enemy.set_script(load(scripts[i]))
		enemy.position = positions[i]
		add_child(enemy)
```

- [ ] **Run the scene**

Expected:
- CAVE: 2 base enemies (dark grey) idle, detect and chase player when approached
- RUINS: 1 base + 1 fast enemy, chase player
- ABYSS: 1 ranged + 1 fast + 1 tank, chase player (tank is slower, ranged shoots)
- Enemies navigate through hallways to reach player

- [ ] **Walk to RUINS and ABYSS and verify enemies cross hallways to pursue**

Walk into RUINS room — CAVE enemies should path through hallway 1. Walk into ABYSS — RUINS enemies should path through hallway 2.

- [ ] **Commit**

```bash
git add script/dungeon_showcase.gd
git commit -m "feat(showcase): spawn enemies in all three themed rooms"
```

---

## Self-Review Checklist

- [x] **Spec coverage**
  - Three themed rooms (CAVE, RUINS, ABYSS): Tasks 2–4
  - Sequential hallways, player walks freely: Tasks 3–4 + Task 5 verification
  - Theme labels + floor ranges: Tasks 2–4
  - Enemy loadout per room (CAVE:2×base, RUINS:base+fast, ABYSS:ranged+fast+tank): Task 7
  - Single navigation region: Task 6
  - Player spawns in CAVE center with Camera2D: Task 5
  - No global state touched: confirmed — no `global.` references in any task
  - Standalone scene: confirmed — no autoload dependencies added

- [x] **Placeholder scan**: no TBDs, all code blocks complete

- [x] **Type consistency**: `_make_wall(Rect2, Color)`, `_make_bg(Rect2, Color)`, `_make_label(Vector2, String)` — consistent across all tasks. `RUINS_X`, `ABYSS_X` constants used in Tasks 3, 4, 6, 7 — all match Task 1 definition.
