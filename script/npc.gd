extends Node2D

var player_nearby = false
var player_ref = null
var _prompt_label: Label

func _ready():
	_build_visual()
	_build_interaction_area()

func _build_visual():
	var sprite = Sprite2D.new()
	sprite.texture = load("res://art/objects/chest_01.png")
	sprite.hframes = 4
	sprite.frame = 0
	sprite.position = Vector2(0, -8)
	add_child(sprite)

	_prompt_label = Label.new()
	_prompt_label.text = "E: Shop"
	_prompt_label.position = Vector2(-12, -22)
	_prompt_label.add_theme_font_size_override("font_size", 6)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _build_interaction_area():
	var area = Area2D.new()
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	shape_node.shape = circle
	area.add_child(shape_node)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		if not is_instance_valid(player_ref):
			player_nearby = false
			player_ref = null
			_prompt_label.visible = false
			return
		# Guard: if dialogue is already open, do not retrigger (WR-01 mitigation)
		if dialogue_manager._panel != null and dialogue_manager._panel.visible:
			return
		# Guard: if shop is already open, pressing E closes it
		if player_ref.shop_open:
			player_ref._close_shop()
			return
		# Dialogue trigger — select start_node based on quest state (DLG-03)
		var start := "greeting"
		var state: Dictionary = global.npc_state.get("elder", {})
		var story_chain: Dictionary = global.quest_state.get("story_chain", {})
		var story_status: String = String(story_chain.get("status", ""))
		var story_step: int = int(story_chain.get("step", 0))
		var cap_open: bool = quest_manager.active_quest_count() < 3
		if quest_manager.quest_ready("reach_floor_10"):
			start = "reach_floor_complete"
		elif quest_manager.quest_ready("fetch_ancient_relic"):
			start = "fetch_quest_complete"
		elif story_status == "active" and story_step == 0:
			start = "story_chain_accepted"
		elif state.get("quest_accepted_reach_floor_10", false):
			start = "quest_follow_up"
		elif _quest_unaccepted("story_chain") and cap_open:
			start = "story_chain_offer"
		elif _quest_unaccepted("fetch_ancient_relic") and cap_open:
			start = "fetch_quest_offer"
		elif _quest_unaccepted("reach_floor_10") and cap_open and not state.get("quest_accepted_reach_floor_10", false):
			start = "quest_offer"
		elif not cap_open:
			start = "quest_cap_reached"
		dialogue_manager.open("elder", start)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_nearby = true
		player_ref = body
		_prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_nearby = false
		player_ref = null
		_prompt_label.visible = false

func _quest_unaccepted(qid: String) -> bool:
	if not global.quest_state.has(qid):
		return true
	var st: String = String(global.quest_state[qid].get("status", ""))
	return st == ""
