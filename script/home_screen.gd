extends Node2D

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

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var title := Label.new()
	title.text = "TENTEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 48
	title.offset_bottom = 84
	title.offset_left = -100
	title.offset_right = 100
	canvas.add_child(title)

	var sub := Label.new()
	sub.text = "An Adventure Awaits"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.50, 0.45, 0.70))
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 90
	sub.offset_bottom = 108
	sub.offset_left = -100
	sub.offset_right = 100
	canvas.add_child(sub)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -65
	vbox.offset_right = 65
	vbox.offset_top = -38
	vbox.offset_bottom = 52
	vbox.add_theme_constant_override("separation", 10)
	canvas.add_child(vbox)

	var new_btn := _make_btn("New Game")
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var load_btn := _make_btn("Load Save")
	load_btn.pressed.connect(_on_open_load)
	vbox.add_child(load_btn)

	var exit_btn := _make_btn("Exit")
	exit_btn.pressed.connect(_on_exit)
	vbox.add_child(exit_btn)

	_build_load_panel(canvas)

func _make_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(130, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn

func _build_load_panel(canvas: CanvasLayer) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	canvas.add_child(overlay)
	_load_panel = overlay

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -110
	panel.offset_bottom = 110
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

	var lbl := Label.new()
	lbl.text = "Load Save"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())

	_feedback_lbl = Label.new()
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.add_theme_font_size_override("font_size", 9)
	_feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_feedback_lbl.visible = false
	vbox.add_child(_feedback_lbl)

	for i in global.SAVE_SLOT_COUNT:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 26)
		btn.pressed.connect(_on_load_slot.bind(i + 1))
		vbox.add_child(btn)
		_load_slot_buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): _load_panel.visible = false)
	vbox.add_child(cancel_btn)

func _refresh_load_slots() -> void:
	for i in global.SAVE_SLOT_COUNT:
		var slot := i + 1
		var preview := global.slot_preview(slot)
		if preview.get("empty", true):
			_load_slot_buttons[i].text = "Slot %d  —  Empty" % slot
		else:
			var scene_str: String = preview.get("scene", "world")
			var gold: int = preview.get("money", 0)
			var floor_no: int = preview.get("floor", 0)
			var when: String = preview.get("saved_at", "")
			if floor_no > 0:
				_load_slot_buttons[i].text = "Slot %d  [%s  Fl.%d  %dg]  %s" % [slot, scene_str, floor_no, gold, when]
			else:
				_load_slot_buttons[i].text = "Slot %d  [%s  %dg]  %s" % [slot, scene_str, gold, when]

func _on_new_game() -> void:
	global.reset_for_new_game()
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_open_load() -> void:
	_refresh_load_slots()
	_feedback_lbl.visible = false
	_load_panel.visible = true

func _on_load_slot(slot: int) -> void:
	if not global.load_from_slot(slot):
		_feedback_lbl.text = "Slot %d is empty." % slot
		_feedback_lbl.visible = true
		return
	_load_panel.visible = false
	var scene_file := "res://scenes/world.tscn"
	match global.current_scene:
		"cliff_side": scene_file = "res://scenes/cliff_side.tscn"
		"dungeon": scene_file = "res://scenes/dungeon.tscn"
	get_tree().change_scene_to_file(scene_file)

func _on_exit() -> void:
	get_tree().quit()
