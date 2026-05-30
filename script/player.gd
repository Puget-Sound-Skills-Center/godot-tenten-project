extends CharacterBody2D

const UITheme = preload("res://script/ui_theme.gd")

var enemy_inattack_range = false
var enemy_attack_cooldown = true
var ranged_hit_cooldown := true
var health = 100
var player_alive = true

var attack_ip = false
var shop_open = false

const MAX_UPGRADE_LEVEL = 50
const speed = 100
var current_dir = "none"

var _attacking_enemy: Node2D = null

var _shop_layer: CanvasLayer
var _shop_money_label: Label
var _dmg_level_label: Label
var _hp_level_label: Label
var _def_level_label: Label
var _dmg_btn: Button
var _hp_btn: Button
var _def_btn: Button

func _ready():
	add_to_group("player")
	$AnimatedSprite2D.play("front_idle")
	if global.player_current_health > 0:
		health = global.player_current_health
	else:
		health = global.get_max_health()
	global.player_current_attack = false
	HUD.show_hud()
	HUD.update_money(global.money)
	HUD.update_hp(health / float(global.get_max_health()), health, global.get_max_health())
	_setup_shop()

func _exit_tree():
	global.player_current_health = health
	global.player_current_attack = false
	HUD.hide_hud()
	if is_instance_valid(_shop_layer):
		_shop_layer.queue_free()

func _physics_process(delta):
	player_movement(delta)
	enemy_attack()
	attack()
	update_health()
	_update_hud()

	if health <= 0:
		if player_alive:
			global.player_dead = true
		player_alive = false
		health = 0

func player_movement(_delta):
	if Input.is_action_pressed("move_right"):
		current_dir = "right"
		play_anim(1)
		velocity.x = speed
		velocity.y = 0
	elif Input.is_action_pressed("move_left"):
		current_dir = "left"
		play_anim(1)
		velocity.x = -speed
		velocity.y = 0
	elif Input.is_action_pressed("move_down"):
		current_dir = "down"
		play_anim(1)
		velocity.y = speed
		velocity.x = 0
	elif Input.is_action_pressed("move_up"):
		current_dir = "up"
		play_anim(1)
		velocity.y = -speed
		velocity.x = 0
	else:
		play_anim(0)
		velocity.x = 0
		velocity.y = 0

	move_and_slide()

func play_anim(movement):
	var dir = current_dir
	var anim = $AnimatedSprite2D

	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			if attack_ip == false:
				anim.play("side_idle")
	if dir == "left":
		anim.flip_h = true
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			if attack_ip == false:
				anim.play("side_idle")
	if dir == "down":
		if movement == 1:
			anim.play("front_walk")
		elif movement == 0:
			if attack_ip == false:
				anim.play("front_idle")
	if dir == "up":
		if movement == 1:
			anim.play("back_walk")
		elif movement == 0:
			if attack_ip == false:
				anim.play("back_idle")

func player():
	pass

func _on_player_hitbox_body_entered(body):
	if body.has_method("enemy"):
		enemy_inattack_range = true
		_attacking_enemy = body

func _on_player_hitbox_body_exited(body):
	if body.has_method("enemy"):
		enemy_inattack_range = false
		_attacking_enemy = null

func enemy_attack():
	if enemy_inattack_range and enemy_attack_cooldown == true:
		var raw := 5
		if is_instance_valid(_attacking_enemy) and _attacking_enemy.get("damage") != null:
			raw = _attacking_enemy.damage
		var reduction = global.player_defense_level / 100.0
		var damage = max(1, int(raw * (1.0 - reduction)))
		health -= damage
		enemy_attack_cooldown = false
		$attack_cooldown.start()

func take_damage(amount: int) -> void:
	if not ranged_hit_cooldown:
		return
	var reduction = global.player_defense_level / 100.0
	var damage = max(1, int(amount * (1.0 - reduction)))
	health -= damage
	ranged_hit_cooldown = false
	get_tree().create_timer(0.5).timeout.connect(func(): ranged_hit_cooldown = true)

func _on_attack_cooldown_timeout():
	enemy_attack_cooldown = true

func attack():
	var dir = current_dir

	if Input.is_action_just_pressed("left_click"):
		if dir == "none":
			return
		global.player_current_attack = true
		attack_ip = true
		if dir == "right":
			$AnimatedSprite2D.flip_h = false
			$AnimatedSprite2D.play("side_attack")
			$deal_attack_timer.start()
		if dir == "left":
			$AnimatedSprite2D.flip_h = true
			$AnimatedSprite2D.play("side_attack")
			$deal_attack_timer.start()
		if dir == "down":
			$AnimatedSprite2D.play("front_attack")
			$deal_attack_timer.start()
		if dir == "up":
			$AnimatedSprite2D.play("back_attack")
			$deal_attack_timer.start()

func _on_deal_attack_timer_timeout():
	$deal_attack_timer.stop()
	global.player_current_attack = false
	attack_ip = false

func update_health():
	var max_hp = global.get_max_health()
	health = min(health, max_hp)
	var healthbar = $healthbar
	healthbar.max_value = max_hp
	healthbar.value = health
	if health >= max_hp:
		healthbar.visible = false
	else:
		healthbar.visible = true

func _on_regen_timer_timeout() -> void:
	var max_hp = global.get_max_health()
	if health < max_hp and health > 0:
		health = min(health + 10, max_hp)

# --- Shop (opened by NPC) ---

func open_shop():
	shop_open = true
	_shop_layer.visible = true

func _close_shop():
	shop_open = false
	_shop_layer.visible = false

# --- Shop UI ---

func _setup_shop():
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 20
	_shop_layer.visible = false
	# Parent to the root viewport (not the player, which lives in the 960x540
	# SubViewport) so the shop UI renders at full physical resolution. Freed in
	# _exit_tree since it no longer auto-frees with the player.
	get_tree().root.add_child(_shop_layer)

	var bg := ColorRect.new()
	bg.color = UITheme.C_OVERLAY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.add_child(bg)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -135
	panel.offset_right  =  135
	panel.offset_top    = -112
	panel.offset_bottom =  112
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	_shop_layer.add_child(panel)

	# Header bar
	var header_bar := ColorRect.new()
	header_bar.color = UITheme.C_HEADER_BG
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size = Vector2(0, 22)
	panel.add_child(header_bar)

	var header_lbl := Label.new()
	header_lbl.text = "Upgrade Shop"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(header_lbl, 11)
	header_bar.add_child(header_lbl)

	var hdr_line := ColorRect.new()
	hdr_line.color = UITheme.C_BORDER
	hdr_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hdr_line.custom_minimum_size = Vector2(0, 1)
	header_bar.add_child(hdr_line)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    30)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_shop_money_label = Label.new()
	_shop_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_money_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	UITheme.apply_font(_shop_money_label, 9)
	vbox.add_child(_shop_money_label)

	vbox.add_child(UITheme.divider())

	# ── Upgrade rows ────────────────────────────────────────────────────────
	var dmg_row := HBoxContainer.new()
	dmg_row.add_theme_constant_override("separation", 6)
	_dmg_btn = Button.new()
	_dmg_btn.text = "ATK +1%  (50g)"
	_dmg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dmg_btn.pressed.connect(_upgrade_damage)
	UITheme.style_button(_dmg_btn, 9)
	dmg_row.add_child(_dmg_btn)
	_dmg_level_label = Label.new()
	_dmg_level_label.custom_minimum_size = Vector2(52, 0)
	_dmg_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dmg_level_label.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(_dmg_level_label, 8)
	dmg_row.add_child(_dmg_level_label)
	vbox.add_child(dmg_row)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	_hp_btn = Button.new()
	_hp_btn.text = "HP +1%  (50g)"
	_hp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_btn.pressed.connect(_upgrade_health)
	UITheme.style_button(_hp_btn, 9)
	hp_row.add_child(_hp_btn)
	_hp_level_label = Label.new()
	_hp_level_label.custom_minimum_size = Vector2(52, 0)
	_hp_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_level_label.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(_hp_level_label, 8)
	hp_row.add_child(_hp_level_label)
	vbox.add_child(hp_row)

	var def_row := HBoxContainer.new()
	def_row.add_theme_constant_override("separation", 6)
	_def_btn = Button.new()
	_def_btn.text = "DEF +1%  (50g)"
	_def_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_def_btn.pressed.connect(_upgrade_defense)
	UITheme.style_button(_def_btn, 9)
	def_row.add_child(_def_btn)
	_def_level_label = Label.new()
	_def_level_label.custom_minimum_size = Vector2(52, 0)
	_def_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_def_level_label.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(_def_level_label, 8)
	def_row.add_child(_def_level_label)
	vbox.add_child(def_row)

	vbox.add_child(UITheme.divider())

	var close_btn := Button.new()
	close_btn.text = "Close  [E]"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(_close_shop)
	UITheme.style_button(close_btn, 9)
	vbox.add_child(close_btn)

func _upgrade_cost(current_level: int) -> int:
	return 50 + current_level * 10

func _update_hud() -> void:
	var max_hp := global.get_max_health()
	var pct: float = float(health) / float(max_hp)
	HUD.update_hp(pct, health, max_hp)
	HUD.update_money(global.money)

	var lore_text := ""
	for key in global.items:
		if global.items[key]:
			lore_text = String(key).replace("_", " ").capitalize()
			break
	if lore_text.is_empty():
		HUD.hide_lore()
	else:
		HUD.show_lore(lore_text)

	if shop_open:
		_shop_money_label.text = "Gold: %d g" % global.money

		var dmg_lvl = global.player_damage_level
		var hp_lvl = global.player_health_level
		var def_lvl = global.player_defense_level

		if dmg_lvl >= MAX_UPGRADE_LEVEL:
			_dmg_btn.text = "Attack +1%  (MAXED)"
			_dmg_btn.disabled = true
			_dmg_level_label.text = "MAX"
		else:
			var cost = _upgrade_cost(dmg_lvl)
			_dmg_btn.text = "Attack +1%%  (%dg)" % cost
			_dmg_btn.disabled = global.money < cost
			_dmg_level_label.text = "Lv %d/50" % dmg_lvl

		if hp_lvl >= MAX_UPGRADE_LEVEL:
			_hp_btn.text = "Max HP +1%  (MAXED)"
			_hp_btn.disabled = true
			_hp_level_label.text = "MAX"
		else:
			var cost = _upgrade_cost(hp_lvl)
			_hp_btn.text = "Max HP +1%%  (%dg)" % cost
			_hp_btn.disabled = global.money < cost
			_hp_level_label.text = "Lv %d/50" % hp_lvl

		if def_lvl >= MAX_UPGRADE_LEVEL:
			_def_btn.text = "Defense +1%  (MAXED)"
			_def_btn.disabled = true
			_def_level_label.text = "MAX"
		else:
			var cost = _upgrade_cost(def_lvl)
			_def_btn.text = "Defense +1%%  (%dg)" % cost
			_def_btn.disabled = global.money < cost
			_def_level_label.text = "Lv %d/50" % def_lvl

func _upgrade_damage():
	var cost = _upgrade_cost(global.player_damage_level)
	if global.money >= cost and global.player_damage_level < MAX_UPGRADE_LEVEL:
		global.money -= cost
		global.player_damage_level += 1

func _upgrade_health():
	var cost = _upgrade_cost(global.player_health_level)
	if global.money >= cost and global.player_health_level < MAX_UPGRADE_LEVEL:
		global.money -= cost
		global.player_health_level += 1
		health = global.get_max_health()

func _upgrade_defense():
	var cost = _upgrade_cost(global.player_defense_level)
	if global.money >= cost and global.player_defense_level < MAX_UPGRADE_LEVEL:
		global.money -= cost
		global.player_defense_level += 1
