extends Node2D

const UITheme = preload("res://script/ui_theme.gd")

var _load_panel: Control
var _load_slot_buttons: Array = []
var _feedback_lbl: Label

func _ready() -> void:
	global.current_scene = "home"
	_build_ui()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)

	# ── Background ──────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# Subtle scanline-style accent strip at top
	var top_strip := ColorRect.new()
	top_strip.color = Color(0.76, 0.62, 0.28, 0.08)
	top_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_strip.custom_minimum_size = Vector2(0, 3)
	canvas.add_child(top_strip)

	# Dim center vignette (two overlapping rects for atmosphere)
	var vig_left := ColorRect.new()
	vig_left.color = Color(0.0, 0.0, 0.0, 0.30)
	vig_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	vig_left.anchor_right = 0.2
	canvas.add_child(vig_left)

	var vig_right := ColorRect.new()
	vig_right.color = Color(0.0, 0.0, 0.0, 0.30)
	vig_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	vig_right.anchor_left = 0.8
	canvas.add_child(vig_right)

	# ── Gold decorative dividers ─────────────────────────────────────────────
	var top_line := ColorRect.new()
	top_line.color = UITheme.C_BORDER
	top_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_top = 60
	top_line.offset_bottom = 61
	top_line.offset_left = 80
	top_line.offset_right = -80
	canvas.add_child(top_line)

	var bot_line := ColorRect.new()
	bot_line.color = UITheme.C_BORDER
	bot_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bot_line.offset_top = 62
	bot_line.offset_bottom = 63
	bot_line.offset_left = 80
	bot_line.offset_right = -80
	canvas.add_child(bot_line)

	# ── Title ───────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Pixel Dungeon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 14
	title.offset_bottom = 52
	title.offset_left = -160
	title.offset_right = 160
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(title, 28)
	canvas.add_child(title)

	var sub := Label.new()
	sub.text = "A Dungeon Awaits"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 68
	sub.offset_bottom = 84
	sub.offset_left = -120
	sub.offset_right = 120
	sub.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(sub, 8)
	canvas.add_child(sub)

	# ── Menu panel ──────────────────────────────────────────────────────────
	var menu_panel := Panel.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	# Symmetric offsets sized to hug the button stack so the panel is centered
	# on screen with even margins (no empty strip at the bottom).
	menu_panel.offset_left   = -94
	menu_panel.offset_right  =  94
	menu_panel.offset_top    = -59
	menu_panel.offset_bottom =  59
	menu_panel.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	canvas.add_child(menu_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	menu_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var new_btn := _make_btn("New Game")
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var load_btn := _make_btn("Load Save")
	load_btn.pressed.connect(_on_open_load)
	vbox.add_child(load_btn)

	var exit_btn := _make_btn("Exit")
	exit_btn.pressed.connect(_on_exit)
	vbox.add_child(exit_btn)

	# ── Version / hint ──────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text = "Move: WASD   Attack: Click   Interact: E"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -18
	hint.offset_bottom = -4
	hint.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(hint, 7)
	canvas.add_child(hint)

	_build_load_panel(canvas)

func _make_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(160, 26)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(btn, 10)
	return btn

func _build_load_panel(canvas: CanvasLayer) -> void:
	var overlay := ColorRect.new()
	overlay.color = UITheme.C_OVERLAY
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	canvas.add_child(overlay)
	_load_panel = overlay

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -148
	panel.offset_right  =  148
	panel.offset_top    = -118
	panel.offset_bottom =  118
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	overlay.add_child(panel)

	# Header
	var header_bar := ColorRect.new()
	header_bar.color = UITheme.C_HEADER_BG
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size = Vector2(0, 22)
	panel.add_child(header_bar)

	var header_lbl := Label.new()
	header_lbl.text = "Load Save"
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
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_feedback_lbl = Label.new()
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.add_theme_color_override("font_color", UITheme.C_ERROR)
	_feedback_lbl.visible = false
	UITheme.apply_font(_feedback_lbl, 8)
	vbox.add_child(_feedback_lbl)

	for i in global.SAVE_SLOT_COUNT:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 24)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_load_slot.bind(i + 1))
		UITheme.style_button(btn, 9)
		vbox.add_child(btn)
		_load_slot_buttons.append(btn)

	vbox.add_child(UITheme.divider())

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): _load_panel.visible = false)
	UITheme.style_button(cancel_btn, 9)
	vbox.add_child(cancel_btn)

func _refresh_load_slots() -> void:
	for i in global.SAVE_SLOT_COUNT:
		var slot := i + 1
		var preview := global.slot_preview(slot)
		if preview.get("empty", true):
			_load_slot_buttons[i].text = "Slot %d   Empty" % slot
		else:
			var scene_str: String = preview.get("scene", "world")
			var gold: int = preview.get("money", 0)
			var floor_no: int = preview.get("floor", 0)
			var when: String = preview.get("saved_at", "")
			if floor_no > 0:
				_load_slot_buttons[i].text = "Slot %d  [%s Fl.%d %dg] %s" % [slot, scene_str, floor_no, gold, when]
			else:
				_load_slot_buttons[i].text = "Slot %d  [%s %dg] %s" % [slot, scene_str, gold, when]

func _on_new_game() -> void:
	global.reset_for_new_game()
	global.go_to("res://scenes/world.tscn")

func _on_open_load() -> void:
	_refresh_load_slots()
	_feedback_lbl.visible = false
	_load_panel.visible = true

func _on_load_slot(slot: int) -> void:
	if not global.load_from_slot(slot):
		_feedback_lbl.text = "Slot %d is empty." % slot
		_feedback_lbl.visible = true
		return
	global.active_save_slot = slot
	_load_panel.visible = false
	var scene_file := "res://scenes/world.tscn"
	match global.current_scene:
		"cliff_side": scene_file = "res://scenes/cliff_side.tscn"
		"dungeon":    scene_file = "res://scenes/dungeon.tscn"
	global.go_to(scene_file)

func _on_exit() -> void:
	get_tree().quit()
