extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

var _pause_panel: Control
var _save_panel: Control
var _feedback_lbl: Label
var _save_slot_buttons: Array = []

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_panel()
	_build_save_panel()

func _pa(node: Node) -> Node:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	return node

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_action_pressed("ui_cancel"):
		return
	if global.player_dead:
		return
	if global.current_scene == "home":
		return
	if dialogue_manager._panel != null and dialogue_manager._panel.visible:
		return
	if _save_panel.visible:
		_save_panel.visible = false
	elif _pause_panel.visible:
		_resume()
	else:
		_open_pause()

func _open_pause() -> void:
	_pause_panel.visible = true
	get_tree().paused = true

func _resume() -> void:
	_pause_panel.visible = false
	_save_panel.visible = false
	get_tree().paused = false

func _build_pause_panel() -> void:
	var overlay := _pa(ColorRect.new()) as ColorRect
	overlay.color = UITheme.C_OVERLAY
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	_pause_panel = overlay

	var panel := _pa(Panel.new()) as Panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -95
	panel.offset_right  =  95
	panel.offset_top    = -90
	panel.offset_bottom =  90
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	overlay.add_child(panel)

	# Header bar
	var header_bar := _pa(ColorRect.new()) as ColorRect
	header_bar.color = UITheme.C_HEADER_BG
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size = Vector2(0, 22)
	panel.add_child(header_bar)

	var header_lbl := _pa(Label.new()) as Label
	header_lbl.text = "-- PAUSED --"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(header_lbl, 11)
	header_bar.add_child(header_lbl)

	# Bottom border on header
	var hdr_line := _pa(ColorRect.new()) as ColorRect
	hdr_line.color = UITheme.C_BORDER
	hdr_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hdr_line.custom_minimum_size = Vector2(0, 1)
	header_bar.add_child(hdr_line)

	var margin := _pa(MarginContainer.new()) as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    30)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := _pa(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	for pair in [["Resume Game", _resume], ["Save Game", _open_save_panel], ["Home Screen", _go_home]]:
		var btn := _pa(Button.new()) as Button
		btn.text = pair[0]
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(pair[1])
		UITheme.style_button(btn, 10)
		vbox.add_child(btn)

func _build_save_panel() -> void:
	var overlay := _pa(ColorRect.new()) as ColorRect
	overlay.color = UITheme.C_OVERLAY
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	_save_panel = overlay

	var panel := _pa(Panel.new()) as Panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -145
	panel.offset_right  =  145
	panel.offset_top    = -118
	panel.offset_bottom =  118
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	overlay.add_child(panel)

	# Header bar
	var header_bar := _pa(ColorRect.new()) as ColorRect
	header_bar.color = UITheme.C_HEADER_BG
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size = Vector2(0, 22)
	panel.add_child(header_bar)

	var header_lbl := _pa(Label.new()) as Label
	header_lbl.text = "Save to Slot"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(header_lbl, 11)
	header_bar.add_child(header_lbl)

	var hdr_line := _pa(ColorRect.new()) as ColorRect
	hdr_line.color = UITheme.C_BORDER
	hdr_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hdr_line.custom_minimum_size = Vector2(0, 1)
	header_bar.add_child(hdr_line)

	var margin := _pa(MarginContainer.new()) as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    30)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := _pa(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_feedback_lbl = _pa(Label.new()) as Label
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.add_theme_color_override("font_color", UITheme.C_SUCCESS)
	_feedback_lbl.visible = false
	UITheme.apply_font(_feedback_lbl, 8)
	vbox.add_child(_feedback_lbl)

	for i in global.SAVE_SLOT_COUNT:
		var btn := _pa(Button.new()) as Button
		btn.custom_minimum_size = Vector2(0, 24)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_save_to_slot.bind(i + 1))
		UITheme.style_button(btn, 9)
		vbox.add_child(btn)
		_save_slot_buttons.append(btn)

	vbox.add_child(UITheme.divider())

	var cancel_btn := _pa(Button.new()) as Button
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): _save_panel.visible = false)
	UITheme.style_button(cancel_btn, 9)
	vbox.add_child(cancel_btn)

func _open_save_panel() -> void:
	_feedback_lbl.visible = false
	for i in global.SAVE_SLOT_COUNT:
		var slot := i + 1
		var preview := global.slot_preview(slot)
		if preview.get("empty", true):
			_save_slot_buttons[i].text = "Slot %d   Empty" % slot
		else:
			var scene_str: String = preview.get("scene", "world")
			var gold: int = preview.get("money", 0)
			var floor_no: int = preview.get("floor", 0)
			if floor_no > 0:
				_save_slot_buttons[i].text = "Slot %d  [%s Fl.%d %dg]" % [slot, scene_str, floor_no, gold]
			else:
				_save_slot_buttons[i].text = "Slot %d  [%s %dg]" % [slot, scene_str, gold]
	_save_panel.visible = true

func _on_save_to_slot(slot: int) -> void:
	var player_pos := Vector2.ZERO
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_pos = players[0].position
	global.save_to_slot(slot, player_pos)
	_feedback_lbl.text = "Saved to Slot %d!" % slot
	_feedback_lbl.visible = true
	var preview := global.slot_preview(slot)
	var scene_str: String = preview.get("scene", "world")
	var gold: int = preview.get("money", 0)
	var floor_no: int = preview.get("floor", 0)
	if floor_no > 0:
		_save_slot_buttons[slot - 1].text = "Slot %d  [%s Fl.%d %dg]" % [slot, scene_str, floor_no, gold]
	else:
		_save_slot_buttons[slot - 1].text = "Slot %d  [%s %dg]" % [slot, scene_str, gold]

func _go_home() -> void:
	get_tree().paused = false
	_pause_panel.visible = false
	_save_panel.visible = false
	global.current_scene = "home"
	global.go_to("res://scenes/home_screen.tscn")
