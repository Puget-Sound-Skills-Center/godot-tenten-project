extends Node

var player_current_attack = false

var current_scene = "world"
var transition_scene = false

var player_exit_cliffside_posx = 171
var player_exit_cliffside_posy = 16
var player_start_posx = 155
var player_start_posy = 108

# Where the player is placed when returning to cliff_side from the dungeon
var player_exit_dungeon_posx = 352
var player_exit_dungeon_posy = 345

var game_first_loading = true

# Dungeon state
const DUNGEON_MAX_FLOOR = 100
var enter_dungeon = false
var exit_dungeon = false
var next_floor = false
var current_floor = 0
var dungeon_resume_floor = 1
var came_from_dungeon = false

var money = 0
var player_damage_level = 0
var player_health_level = 0
var player_defense_level = 0
var player_current_health = -1

func get_max_health() -> int:
	return int(100.0 * (1.0 + player_health_level * 0.01))

func get_attack_damage() -> int:
	return int(20.0 * (1.0 + player_damage_level * 0.01))

func finish_changescenes():
	if transition_scene == true:
		transition_scene = false
		if current_scene == "world":
			current_scene = "cliff_side"
		else:
			current_scene = "world"
