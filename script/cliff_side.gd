extends Node2D

var _secret_door: StaticBody2D = null

func _ready() -> void:
	_spawn_dungeon_npc()
	if global.loaded_from_save:
		$player.position = global.player_loaded_pos
		global.loaded_from_save = false
	elif global.came_from_dungeon:
		var p = $player
		p.position.x = global.player_exit_dungeon_posx
		p.position.y = global.player_exit_dungeon_posy
		global.came_from_dungeon = false
	_build_secret_door()
	_setup_camera()

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(1, 1)
	cam.position_smoothing_enabled = true
	cam.limit_smoothed = true
	$player.add_child(cam)
	_apply_map_limits(cam, $TileMap/Ground)
	cam.reset_smoothing()

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

func _spawn_dungeon_npc():
	var npc = load("res://script/dungeon_npc.gd").new()
	npc.position = Vector2(1407, 1266)
	add_child(npc)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	change_scene()
	if _secret_door != null and bool(global.unlocks.get("cliff_secret_door", false)):
		_secret_door.queue_free()
		_secret_door = null

func _on_cliffside_exit_point_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true

func change_scene():
	if global.transition_scene == true:
		if global.current_scene == "cliff_side":
			dialogue_manager.force_close()
			global.go_to("res://scenes/world.tscn")
			global.finish_changescenes()
	if global.enter_dungeon == true:
		global.enter_dungeon = false
		global.current_floor = clampi(global.dungeon_resume_floor, 1, global.DUNGEON_MAX_FLOOR)
		global.current_scene = "dungeon"
		dialogue_manager.force_close()
		global.go_to("res://scenes/dungeon.tscn")

func _build_secret_door() -> void:
	if bool(global.unlocks.get("cliff_secret_door", false)):
		return
	var door := StaticBody2D.new()
	door.name = "cliff_secret_door"
	door.position = Vector2(80, 60)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape_node.shape = rect
	door.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = Color(0.3, 0.2, 0.1, 1.0)
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	door.add_child(visual)
	var lbl := Label.new()
	lbl.text = "Sealed Passage"
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.position = Vector2(-20, -22)
	door.add_child(lbl)
	_secret_door = door
	add_child(door)
