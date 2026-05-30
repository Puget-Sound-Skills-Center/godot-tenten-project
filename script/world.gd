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
	_setup_camera()

func _setup_camera() -> void:
	var cam := $player/Camera2D as Camera2D
	if cam == null:
		return
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = true
	cam.limit_smoothed = true
	_apply_map_limits(cam, $TileMap/Ground)

# Clamp the camera to the tilemap's world-space bounds so no off-map area shows.
func _apply_map_limits(cam: Camera2D, layer: TileMapLayer) -> void:
	if layer == null or layer.tile_set == null:
		return
	var used := layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var ts := layer.tile_set.tile_size
	var xform := layer.get_global_transform()
	var p0: Vector2 = xform * (Vector2(used.position) * Vector2(ts))
	var p1: Vector2 = xform * (Vector2(used.position + used.size) * Vector2(ts))
	cam.limit_left = int(min(p0.x, p1.x))
	cam.limit_top = int(min(p0.y, p1.y))
	cam.limit_right = int(max(p0.x, p1.x))
	cam.limit_bottom = int(max(p0.y, p1.y))

func _spawn_elder_npc() -> void:
	var npc = load("res://script/npc.gd").new()
	npc.position = Vector2(210, 125)
	add_child(npc)

func _spawn_blacksmith_npc() -> void:
	var npc = load("res://script/blacksmith_npc.gd").new()
	npc.position = Vector2(285, 125)
	add_child(npc)

func _spawn_merchant_npc() -> void:
	var npc = load("res://script/shop_npc.gd").new()
	npc.position = Vector2(105, 125)
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
