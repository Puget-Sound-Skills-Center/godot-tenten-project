extends "res://script/enemy_base.gd"


func _ready() -> void:
	max_health = 40
	speed = 90.0
	damage = 4
	money_drop = 800
	enemy_type = "fast"
	super._ready()
	var detect_shape := CircleShape2D.new()
	detect_shape.radius = 150.0
	$detection_area/CollisionShape2D.shape = detect_shape
