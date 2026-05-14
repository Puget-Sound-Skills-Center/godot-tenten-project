extends Node2D

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

func _spawn_dungeon_npc():
	var npc = load("res://script/dungeon_npc.gd").new()
	npc.position = Vector2(352, 315)
	add_child(npc)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	change_scene()

func _on_cliffside_exit_point_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true

func change_scene():
	if global.transition_scene == true:
		if global.current_scene == "cliff_side":
			get_tree().change_scene_to_file("res://scenes/world.tscn")
			global.finish_changescenes()
	if global.enter_dungeon == true:
		global.enter_dungeon = false
		global.current_floor = clampi(global.dungeon_resume_floor, 1, global.DUNGEON_MAX_FLOOR)
		global.current_scene = "dungeon"
		get_tree().change_scene_to_file("res://scenes/dungeon.tscn")

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
	add_child(door)
