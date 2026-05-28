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
	_build_cave_room()
	_build_hallway_1()
	_build_ruins_room()
	_build_hallway_2()
	_build_abyss_room()
	_spawn_player()
	_setup_navigation()
	_spawn_cave_enemies()
	_spawn_ruins_enemies()
	_spawn_abyss_enemies()

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
	_make_label(Vector2(x + 20, 22), "CAVE  *  Floors 1-33")

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
	_make_label(Vector2(x + 20, 22), "RUINS  *  Floors 34-66")

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
	_make_label(Vector2(x + 20, 22), "ABYSS  *  Floors 67-100")

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

func _setup_navigation() -> void:
	var geo := NavigationMeshSourceGeometryData2D.new()
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(CAVE_X + TILE, TILE),
		Vector2(CAVE_X + TILE, ROOM_H - TILE),
		Vector2(CAVE_X + ROOM_W - TILE, ROOM_H - TILE),
		Vector2(CAVE_X + ROOM_W - TILE, TILE),
	]))
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(CAVE_X + ROOM_W - TILE, HALL_WALL_H),
		Vector2(CAVE_X + ROOM_W - TILE, ROOM_H - HALL_WALL_H),
		Vector2(RUINS_X + TILE, ROOM_H - HALL_WALL_H),
		Vector2(RUINS_X + TILE, HALL_WALL_H),
	]))
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(RUINS_X + TILE, TILE),
		Vector2(RUINS_X + TILE, ROOM_H - TILE),
		Vector2(RUINS_X + ROOM_W - TILE, ROOM_H - TILE),
		Vector2(RUINS_X + ROOM_W - TILE, TILE),
	]))
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(RUINS_X + ROOM_W - TILE, HALL_WALL_H),
		Vector2(RUINS_X + ROOM_W - TILE, ROOM_H - HALL_WALL_H),
		Vector2(ABYSS_X + TILE, ROOM_H - HALL_WALL_H),
		Vector2(ABYSS_X + TILE, HALL_WALL_H),
	]))
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
