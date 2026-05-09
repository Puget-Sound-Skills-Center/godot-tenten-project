extends CharacterBody2D

signal alert_pack(origin_position: Vector2)

var max_health: int = 100
var speed = 40
var damage: int = 5
var money_drop = 1000
var enemy_type: String = "melee"

var health: int
var player_chase = false
var player: Node2D = null

var player_inattack_range = false
var can_take_damage = true

var _nav_agent: NavigationAgent2D

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 4.0
	_nav_agent.target_desired_distance = 8.0
	_nav_agent.radius = 5.0
	add_child(_nav_agent)

	var detect_shape := CircleShape2D.new()
	detect_shape.radius = 120.0
	$detection_area/CollisionShape2D.shape = detect_shape

func _physics_process(_delta):
	deal_with_damage()
	update_health()
	_move_toward_player()

func _move_toward_player() -> void:
	if player_chase and is_instance_valid(player):
		_nav_agent.target_position = player.global_position
		if not _nav_agent.is_navigation_finished():
			var next := _nav_agent.get_next_path_position()
			var direction: Vector2 = (next - global_position).normalized()
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		$AnimatedSprite2D.play("move")
		$AnimatedSprite2D.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("idle")

func enemy():
	pass

func _on_detection_area_body_entered(body) -> void:
	if body.has_method("player"):
		player = body as Node2D
		player_chase = true
		get_tree().call_group("enemies", "_on_pack_alerted", global_position)

func _on_detection_area_body_exited(body) -> void:
	if body.has_method("player"):
		player = null
		player_chase = false

func _on_pack_alerted(origin_position: Vector2) -> void:
	if player_chase:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node2D
		player_chase = true


func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_range = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_range = false

func deal_with_damage() -> void:
	if player_inattack_range and global.player_current_attack == true:
		if can_take_damage == true:
			health -= global.get_attack_damage()
			$take_damage_cooldown.start()
			can_take_damage = false
			if health <= 0:
				global.money += money_drop
				queue_free()

func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true

func update_health() -> void:
	var healthbar := $healthbar
	healthbar.max_value = max_health
	healthbar.value = health
	healthbar.visible = health < max_health
