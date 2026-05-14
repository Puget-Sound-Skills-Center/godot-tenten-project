extends Node2D

# Blacksmith NPC (Phase 3 — kill quest giver + story chain step 1).
# Spawned at runtime by world.gd at position (220, 110).
# Mirrors dungeon_dialogue_npc.gd structure; no shop logic.

var player_nearby: bool = false
var player_ref: Node2D = null
var _prompt_label: Label

func _ready() -> void:
	_build_visual()
	_build_interaction_area()

func _build_visual() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/objects/chest_01.png")
	sprite.hframes = 4
	sprite.frame = 0
	sprite.position = Vector2(0, -8)
	add_child(sprite)

	_prompt_label = Label.new()
	_prompt_label.text = "E: Talk"
	_prompt_label.position = Vector2(-12, -22)
	_prompt_label.add_theme_font_size_override("font_size", 6)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _build_interaction_area() -> void:
	var area := Area2D.new()
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape_node.shape = circle
	area.add_child(shape_node)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _process(_delta: float) -> void:
	if not player_nearby:
		return
	if not is_instance_valid(player_ref):
		return
	if not Input.is_action_just_pressed("interact"):
		return
	if dialogue_manager._panel != null and dialogue_manager._panel.visible:
		return
	dialogue_manager.open("blacksmith", _select_start_node())

func _select_start_node() -> String:
	var state: Dictionary = global.npc_state.get("blacksmith", {})
	if quest_manager.quest_ready("kill_melee_10"):
		return "kill_quest_complete"
	if state.get("quest_accepted_kill_melee_10", false):
		return "kill_quest_followup"
	if global.quest_state.has("story_chain"):
		var sc: Dictionary = global.quest_state["story_chain"]
		if String(sc.get("status", "")) == "active" and int(sc.get("step", 0)) == 1:
			return "story_chain_step1"
	if state.get("story_chain_step1_seen", false):
		return "story_chain_step1_done"
	if quest_manager.active_quest_count() >= 3:
		return "kill_quest_cap_reached"
	return "kill_quest_offer"

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("player"):
		return
	player_nearby = true
	player_ref = body
	_prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not body.has_method("player"):
		return
	player_nearby = false
	player_ref = null
	_prompt_label.visible = false
