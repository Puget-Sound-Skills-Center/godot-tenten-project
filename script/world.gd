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
	_spawn_elder_npc()
	_spawn_blacksmith_npc()
	_spawn_merchant_npc()

func _spawn_elder_npc() -> void:
	var npc = load("res://script/npc.gd").new()
	npc.position = Vector2(167, 110)
	add_child(npc)

func _spawn_blacksmith_npc() -> void:
	var npc = load("res://script/blacksmith_npc.gd").new()
	npc.position = Vector2(240, 110)
	add_child(npc)

func _spawn_merchant_npc() -> void:
	var npc = load("res://script/shop_npc.gd").new()
	npc.position = Vector2(110, 130)
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
			global.go_to("res://scenes/cliff_side.tscn")
			global.game_first_loading = false
			global.finish_changescenes()
