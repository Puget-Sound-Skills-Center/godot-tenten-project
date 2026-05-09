extends "res://script/enemy_base.gd"


func _ready() -> void:
	max_health = 300
	speed = 22.0
	damage = 15
	money_drop = 2000
	enemy_type = "tank"
	super._ready()
	_nav_agent.radius = 10.0
	var detect_shape := CircleShape2D.new()
	detect_shape.radius = 100.0
	$detection_area/CollisionShape2D.shape = detect_shape
	$AnimatedSprite2D.modulate = Color(0.6, 0.2, 0.2)
	$AnimatedSprite2D.scale = Vector2(1.5, 1.5)
