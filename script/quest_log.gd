extends CanvasLayer

# Tab-toggled quest log overlay (Phase 3).
# Mirrors dialogue_manager.gd pause/process-mode pattern.
# Per UI-SPEC.md: right-side panel, 200x220 px, max 3 entries.

var _overlay: ColorRect
var _panel: ColorRect
var _vbox: VBoxContainer
var _entries_vbox: VBoxContainer
var _empty_lbl: Label
var _hint_lbl: Label

func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_log_panel()

func _pa(node: Node) -> Node:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	return node

func _build_log_panel() -> void:
	_overlay = _pa(ColorRect.new()) as ColorRect
	_overlay.color = Color(0, 0, 0, 0.75)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	_panel = _pa(ColorRect.new()) as ColorRect
	_panel.color = Color(0.12, 0.10, 0.08, 0.95)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -200
	_panel.offset_right = 0
	_panel.offset_top = 8
	_panel.offset_bottom = 228
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_panel)

	var margin: MarginContainer = _pa(MarginContainer.new()) as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	_vbox = _pa(VBoxContainer.new()) as VBoxContainer
	_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_vbox)

	var header: Label = _pa(Label.new()) as Label
	header.text = "Quests"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_vbox.add_child(header)

	var divider: ColorRect = _pa(ColorRect.new()) as ColorRect
	divider.color = Color(0.3, 0.3, 0.3, 0.5)
	divider.custom_minimum_size = Vector2(176, 1)
	_vbox.add_child(divider)

	_entries_vbox = _pa(VBoxContainer.new()) as VBoxContainer
	_entries_vbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(_entries_vbox)

	_empty_lbl = _pa(Label.new()) as Label
	_empty_lbl.text = "No active quests."
	_empty_lbl.add_theme_font_size_override("font_size", 11)
	_empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	_vbox.add_child(_empty_lbl)

	_hint_lbl = _pa(Label.new()) as Label
	_hint_lbl.text = "[Tab] Close"
	_hint_lbl.add_theme_font_size_override("font_size", 10)
	_hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	_vbox.add_child(_hint_lbl)

func _refresh() -> void:
	for c in _entries_vbox.get_children():
		c.queue_free()
	var built := 0
	for qid in global.quest_state.keys():
		if built >= 3:
			break
		var q: Dictionary = global.quest_state[qid]
		var s: String = String(q.get("status", ""))
		if s != "active" and s != "ready_to_complete":
			continue
		_build_entry(qid)
		built += 1
	_empty_lbl.visible = built == 0

func _build_entry(qid: String) -> void:
	var entry: VBoxContainer = _pa(VBoxContainer.new()) as VBoxContainer
	entry.add_theme_constant_override("separation", 4)
	_entries_vbox.add_child(entry)

	var template: Dictionary = quest_data.get_quest(qid)
	var name_text: String = String(template.get("display_name", qid))
	var name_lbl: Label = _pa(Label.new()) as Label
	name_lbl.text = name_text
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	entry.add_child(name_lbl)

	var obj_text: String = quest_manager.get_objective_string(qid)
	var status: String = String(global.quest_state[qid].get("status", ""))
	if status == "ready_to_complete":
		obj_text += " — Return to NPC"
	var obj_lbl: Label = _pa(Label.new()) as Label
	obj_lbl.text = obj_text
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	obj_lbl.add_theme_font_size_override("font_size", 11)
	obj_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	entry.add_child(obj_lbl)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.is_action_just_pressed("quest_log"):
		return
	if dialogue_manager._panel != null and dialogue_manager._panel.visible:
		return
	get_viewport().set_input_as_handled()
	_toggle()

func _toggle() -> void:
	if _overlay.visible:
		_overlay.visible = false
		get_tree().paused = false
	else:
		_refresh()
		_overlay.visible = true
		get_tree().paused = true

func force_close() -> void:
	if _overlay != null and _overlay.visible:
		_overlay.visible = false
		get_tree().paused = false
