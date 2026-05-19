extends CharacterBody2D

var speed = 40
var player_chase = false
var player: Node2D = null

var health = 100
var player_inattack_range = false
var can_take_damage = true

var money_drop = 1000
var enemy_type: String = "melee"

var _nav_agent: NavigationAgent2D

func _ready() -> void:
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 4.0
	_nav_agent.target_desired_distance = 8.0
	_nav_agent.radius = 5.0
	add_child(_nav_agent)

	# Give each instance its own shape so radius change doesn't affect all enemies
	var detect_shape := CircleShape2D.new()
	detect_shape.radius = 120.0
	$detection_area/CollisionShape2D.shape = detect_shape

func _physics_process(_delta):
	deal_with_damge()
	update_health()

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

func _on_detection_area_body_entered(body) -> void:
	if body.has_method("player"):
		player = body as Node2D
		player_chase = true

func _on_detection_area_body_exited(body) -> void:
	if body.has_method("player"):
		player = null
		player_chase = false

func enemy():
	pass

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_range = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_range = false

func deal_with_damge():
	if player_inattack_range and global.player_current_attack == true:
		if can_take_damage == true:
			health -= global.get_attack_damage()
			$take_damage_cooldown.start()
			can_take_damage = false
			if health <= 0:
				global.money += money_drop
				quest_manager.on_enemy_killed(enemy_type)
				self.queue_free()

func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true

func update_health():
	var healthbar = $healthbar
	healthbar.value = health
	if health >= 100:
		healthbar.visible = false
	else:
		healthbar.visible = true
