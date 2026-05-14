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

var npc_state: Dictionary = {}
var quest_state: Dictionary = {}
var items: Dictionary = {}
var unlocks: Dictionary = {}

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

# --- Save system ---

const SAVE_SLOT_COUNT := 4

var loaded_from_save := false
var player_loaded_pos := Vector2.ZERO

func reset_for_new_game() -> void:
	money = 0
	player_damage_level = 0
	player_health_level = 0
	player_defense_level = 0
	player_current_health = -1
	current_floor = 0
	dungeon_resume_floor = 1
	came_from_dungeon = false
	current_scene = "world"
	game_first_loading = true
	enter_dungeon = false
	exit_dungeon = false
	next_floor = false
	transition_scene = false
	npc_state = {}
	quest_state = {}
	items = {}
	unlocks = {}
	loaded_from_save = false

func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.cfg" % slot

func save_to_slot(slot: int, player_pos: Vector2) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "scene", current_scene)
	cfg.set_value("game", "current_floor", current_floor)
	cfg.set_value("game", "dungeon_resume_floor", dungeon_resume_floor)
	cfg.set_value("game", "money", money)
	cfg.set_value("player", "damage_level", player_damage_level)
	cfg.set_value("player", "health_level", player_health_level)
	cfg.set_value("player", "defense_level", player_defense_level)
	cfg.set_value("player", "current_health", player_current_health)
	cfg.set_value("player", "pos_x", player_pos.x)
	cfg.set_value("player", "pos_y", player_pos.y)
	cfg.set_value("meta", "saved_at", Time.get_datetime_string_from_system())
	cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))
	cfg.set_value("quests", "quest_state", var_to_str(quest_state))
	cfg.set_value("quests", "items", var_to_str(items))
	cfg.set_value("quests", "unlocks", var_to_str(unlocks))
	cfg.save(_slot_path(slot))

func load_from_slot(slot: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(slot)) != OK:
		return false
	current_scene = cfg.get_value("game", "scene", "world")
	current_floor = cfg.get_value("game", "current_floor", 0)
	dungeon_resume_floor = cfg.get_value("game", "dungeon_resume_floor", 1)
	money = cfg.get_value("game", "money", 0)
	player_damage_level = cfg.get_value("player", "damage_level", 0)
	player_health_level = cfg.get_value("player", "health_level", 0)
	player_defense_level = cfg.get_value("player", "defense_level", 0)
	player_current_health = cfg.get_value("player", "current_health", -1)
	player_loaded_pos = Vector2(
		cfg.get_value("player", "pos_x", 167.0),
		cfg.get_value("player", "pos_y", 110.0)
	)
	var raw = cfg.get_value("dialogue", "npc_state", "{}")
	npc_state = str_to_var(raw) if raw != "{}" else {}
	if npc_state == null:
		npc_state = {}
	var raw_qs := cfg.get_value("quests", "quest_state", "{}")
	quest_state = str_to_var(raw_qs) if raw_qs != "{}" else {}
	if quest_state == null:
		quest_state = {}
	var raw_items := cfg.get_value("quests", "items", "{}")
	items = str_to_var(raw_items) if raw_items != "{}" else {}
	if items == null:
		items = {}
	var raw_unlocks := cfg.get_value("quests", "unlocks", "{}")
	unlocks = str_to_var(raw_unlocks) if raw_unlocks != "{}" else {}
	if unlocks == null:
		unlocks = {}
	game_first_loading = false
	came_from_dungeon = false
	loaded_from_save = (current_scene != "dungeon")
	return true

func slot_preview(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(slot)) != OK:
		return {"empty": true}
	return {
		"empty": false,
		"scene": cfg.get_value("game", "scene", "world"),
		"floor": cfg.get_value("game", "current_floor", 0),
		"money": cfg.get_value("game", "money", 0),
		"saved_at": cfg.get_value("meta", "saved_at", ""),
	}
