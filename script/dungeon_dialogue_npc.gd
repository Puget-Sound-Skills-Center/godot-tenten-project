extends Node2D

var player_nearby = false
var player_ref = null
var _prompt_label: Label

func _ready():
	_build_visual()
	_build_interaction_area()

func _build_visual():
	var sprite = Sprite2D.new()
	sprite.texture = load("res://art/objects/chest_02.png")
	sprite.hframes = 4
	sprite.frame = 0
	sprite.scale = Vector2(4, 4)
	sprite.position = Vector2(0, -32)
	add_child(sprite)

	_prompt_label = Label.new()
	_prompt_label.text = "E: Talk"
	_prompt_label.position = Vector2(-12, -76)
	_prompt_label.add_theme_font_size_override("font_size", 6)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _build_interaction_area():
	var area = Area2D.new()
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 36.0
	shape_node.shape = circle
	area.add_child(shape_node)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _process(_delta):
	if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
		# Guard: if dialogue is already open, do not retrigger (WR-01 mitigation)
		if dialogue_manager._panel != null and dialogue_manager._panel.visible:
			return
		var start := "greeting"
		if global.quest_state.has("story_chain"):
			var sc: Dictionary = global.quest_state["story_chain"]
			var status: String = String(sc.get("status", ""))
			var step: int = int(sc.get("step", 0))
			if status == "active" and step == 2:
				start = "story_chain_step2"
			elif status == "complete":
				start = "story_chain_complete"
		dialogue_manager.open("dungeon_merchant", start)

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
