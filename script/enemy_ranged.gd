extends "res://script/enemy_base.gd"

const PREFERRED_DISTANCE := 100.0
const FIRE_RANGE := 160.0

var _shoot_cooldown: Timer
var _shoot_ready := true
var _my_projectiles: Array = []


func _ready() -> void:
	max_health = 60
	speed = 35.0
	damage = 8
	money_drop = 1200
	enemy_type = "ranged"
	super._ready()

	_shoot_cooldown = Timer.new()
	_shoot_cooldown.wait_time = 2.0
	_shoot_cooldown.one_shot = true
	_shoot_cooldown.timeout.connect(_on_shoot_ready)
	add_child(_shoot_cooldown)


func _on_shoot_ready() -> void:
	_shoot_ready = true


func _move_toward_player() -> void:
	if not (player_chase and is_instance_valid(player)):
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("idle")
		return

	var dist := global_position.distance_to(player.global_position)

	if dist < PREFERRED_DISTANCE:
		var away := (global_position - player.global_position).normalized()
		velocity = away * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	$AnimatedSprite2D.play("move" if velocity.length() > 1.0 else "idle")
	$AnimatedSprite2D.flip_h = velocity.x < 0

	if _shoot_ready and dist < FIRE_RANGE:
		_fire_projectile()
		_shoot_ready = false
		_shoot_cooldown.start()


func _fire_projectile() -> void:
	var proj := Area2D.new()

	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	shape_node.shape = shape
	proj.add_child(shape_node)

	var visual := ColorRect.new()
	visual.color = Color(1.0, 0.6, 0.1)
	visual.size = Vector2(6.0, 6.0)
	visual.position = Vector2(-3.0, -3.0)
	proj.add_child(visual)

	proj.position = global_position
	proj.collision_layer = 0  # projectile on no layer
	proj.collision_mask = 1   # detect bodies on layer 1 (player)
	proj.set_meta("direction", (player.global_position - global_position).normalized())
	proj.set_meta("speed", 80.0)
	proj.set_meta("damage", damage)
	proj.body_entered.connect(_on_projectile_hit.bind(proj))
	get_parent().add_child(proj)
	_my_projectiles.append(proj)

	var t := Timer.new()
	t.wait_time = 2.0
	t.one_shot = true
	t.timeout.connect(func(): if is_instance_valid(proj): proj.queue_free())
	t.timeout.connect(t.queue_free)
	proj.add_child(t)
	t.start()


func _on_projectile_hit(body: Node2D, proj: Area2D) -> void:
	if body.has_method("player"):
		body.take_damage(proj.get_meta("damage"))
	if is_instance_valid(proj):
		proj.queue_free()


func _physics_process(_delta) -> void:
	deal_with_damage()
	update_health()
	_move_toward_player()
	_update_projectiles()


func _update_projectiles() -> void:
	_my_projectiles = _my_projectiles.filter(func(p): return is_instance_valid(p))
	for proj in _my_projectiles:
		var dir: Vector2 = proj.get_meta("direction")
		var spd: float = proj.get_meta("speed")
		proj.position += dir * spd * get_physics_process_delta_time()
