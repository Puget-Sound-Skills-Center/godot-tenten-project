extends CanvasLayer

var _pause_panel: Control
var _save_panel: Control
var _feedback_lbl: Label
var _save_slot_buttons: Array = []

func _ready() -> void:
	layer = 50
	_build_pause_panel()
	_build_save_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_action_pressed("ui_cancel"):
		return
	if global.current_scene == "home":
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
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.60)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	_pause_panel = overlay

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -90
	panel.offset_right = 90
	panel.offset_top = -82
	panel.offset_bottom = 82
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.pressed.connect(_resume)
	vbox.add_child(resume_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_open_save_panel)
	vbox.add_child(save_btn)

	var home_btn := Button.new()
	home_btn.text = "Home Screen"
	home_btn.pressed.connect(_go_home)
	vbox.add_child(home_btn)

func _build_save_panel() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.50)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	_save_panel = overlay

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -115
	panel.offset_bottom = 115
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Save to Slot"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_feedback_lbl = Label.new()
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.add_theme_font_size_override("font_size", 9)
	_feedback_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	_feedback_lbl.visible = false
	vbox.add_child(_feedback_lbl)

	for i in global.SAVE_SLOT_COUNT:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 26)
		btn.pressed.connect(_on_save_to_slot.bind(i + 1))
		vbox.add_child(btn)
		_save_slot_buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): _save_panel.visible = false)
	vbox.add_child(cancel_btn)

func _open_save_panel() -> void:
	_feedback_lbl.visible = false
	for i in global.SAVE_SLOT_COUNT:
		var slot := i + 1
		var preview := global.slot_preview(slot)
		if preview.get("empty", true):
			_save_slot_buttons[i].text = "Slot %d  —  Empty" % slot
		else:
			var scene_str: String = preview.get("scene", "world")
			var gold: int = preview.get("money", 0)
			var floor_no: int = preview.get("floor", 0)
			if floor_no > 0:
				_save_slot_buttons[i].text = "Slot %d  [%s  Fl.%d  %dg]" % [slot, scene_str, floor_no, gold]
			else:
				_save_slot_buttons[i].text = "Slot %d  [%s  %dg]" % [slot, scene_str, gold]
	_save_panel.visible = true

func _on_save_to_slot(slot: int) -> void:
	var player_pos := Vector2.ZERO
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_pos = players[0].position
	global.save_to_slot(slot, player_pos)
	_feedback_lbl.text = "Saved to Slot %d!" % slot
	_feedback_lbl.visible = true
	# Refresh button text to reflect new save
	var preview := global.slot_preview(slot)
	var scene_str: String = preview.get("scene", "world")
	var gold: int = preview.get("money", 0)
	var floor_no: int = preview.get("floor", 0)
	if floor_no > 0:
		_save_slot_buttons[slot - 1].text = "Slot %d  [%s  Fl.%d  %dg]" % [slot, scene_str, floor_no, gold]
	else:
		_save_slot_buttons[slot - 1].text = "Slot %d  [%s  %dg]" % [slot, scene_str, gold]

func _go_home() -> void:
	get_tree().paused = false
	_pause_panel.visible = false
	_save_panel.visible = false
	global.current_scene = "home"
	get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
