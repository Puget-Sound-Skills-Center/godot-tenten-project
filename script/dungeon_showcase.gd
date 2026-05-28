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
