extends Node2D

func _ready() -> void:
	_spawn_dungeon_npc()
	if global.came_from_dungeon:
		var p = $player
		p.position.x = global.player_exit_dungeon_posx
		p.position.y = global.player_exit_dungeon_posy
		global.came_from_dungeon = false

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
