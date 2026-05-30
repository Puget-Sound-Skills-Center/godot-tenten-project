extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

var _hp_bar: ProgressBar
var _hp_label: Label
var _money_label: Label
var _lore_panel: Panel
var _lore_label: Label

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# HP bar
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_row)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(160, 18)
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.show_percentage = false
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.add_theme_color_override("font_color", UITheme.C_TEXT)
	UITheme.apply_font(_hp_label, 12)
	hp_row.add_child(_hp_label)

	# Gold counter
	_money_label = Label.new()
	_money_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	UITheme.apply_font(_money_label, 13)
	vbox.add_child(_money_label)

	# Lore hint
	_lore_panel = Panel.new()
	_lore_panel.add_theme_stylebox_override("panel", UITheme.panel_style(1))
	_lore_panel.custom_minimum_size = Vector2(200, 24)
	_lore_panel.visible = false
	vbox.add_child(_lore_panel)

	_lore_label = Label.new()
	_lore_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lore_label.clip_text = true
	_lore_label.add_theme_constant_override("margin_left", 6)
	_lore_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(_lore_label, 11)
	_lore_panel.add_child(_lore_label)

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false

func update_hp(pct: float, current: int, maximum: int) -> void:
	_hp_bar.value = clampf(pct, 0.0, 1.0)
	_hp_label.text = "%d/%d" % [current, maximum]

func update_money(amount: int) -> void:
	_money_label.text = "G: %d" % amount

func show_lore(text: String) -> void:
	_lore_label.text = text
	_lore_panel.visible = true

func hide_lore() -> void:
	_lore_panel.visible = false
