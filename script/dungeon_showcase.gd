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
