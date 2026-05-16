extends Node2D

var player_nearby := false
var player_ref: Node2D = null
var _prompt_label: Label
var lore_id: String = "fragment_1"

func _ready() -> void:
	_build_visual()
	_build_interaction_area()

func _build_visual() -> void:
	var visual := ColorRect.new()
	visual.color = Color(0.55, 0.40, 0.20)
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	add_child(visual)

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Inspect"
	_prompt_label.position = Vector2(-16, -26)
	_prompt_label.add_theme_font_size_override("font_size", 7)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.visible = false
	add_child(_prompt_label)

	var name_lbl := Label.new()
	name_lbl.text = "LORE"
	name_lbl.position = Vector2(-8, -8)
	name_lbl.add_theme_font_size_override("font_size", 5)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
	add_child(name_lbl)

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
	if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
		dialogue_manager.open("lore_object", lore_id)

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
