extends Node2D


func _ready() -> void:
	if global.loaded_from_save:
		$player.position = global.player_loaded_pos
		global.loaded_from_save = false
	elif global.game_first_loading == true:
		$player.position.x = global.player_start_posx
		$player.position.y = global.player_start_posy
	else:
		$player.position.x = global.player_exit_cliffside_posx
		$player.position.y = global.player_exit_cliffside_posy
	_spawn_shop_npc()
	_spawn_blacksmith_npc()

func _spawn_blacksmith_npc() -> void:
	var npc = load("res://script/blacksmith_npc.gd").new()
	npc.position = Vector2(240, 110)  # was 220; increased gap from shop NPC at (167,110)
	add_child(npc)

func _spawn_shop_npc():
	var npc = load("res://script/npc.gd").new()
	npc.position = Vector2(167, 110)
	add_child(npc)

func _process(_delta):
	change_scene()


func _on_cliffside_trasition_point_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true

func change_scene():
	if global.transition_scene == true:
		if global.current_scene == "world":
			dialogue_manager.force_close()
			get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")
			global.game_first_loading = false
			global.finish_changescenes()
