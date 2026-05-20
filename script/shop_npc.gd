extends Node2D

# Shop merchant NPC. Spawned at runtime by world.gd.
# Opens the player's upgrade shop on interact. Blocks if dialogue panel is visible.

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
	sprite.frame = 2
	sprite.position = Vector2(0, -8)
	add_child(sprite)

	var name_lbl := Label.new()
	name_lbl.text = "SHOP"
	name_lbl.position = Vector2(-10, -26)
	name_lbl.add_theme_font_size_override("font_size", 6)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	add_child(name_lbl)

	_prompt_label = Label.new()
	_prompt_label.text = "E: Shop"
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
		player_nearby = false
		player_ref = null
		_prompt_label.visible = false
		return
	if not Input.is_action_just_pressed("interact"):
		return
	# Block if dialogue is open — shop and dialogue are mutually exclusive
	if dialogue_manager._panel != null and dialogue_manager._panel.visible:
		return
	if player_ref.shop_open:
		player_ref._close_shop()
		return
	player_ref.open_shop()

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
