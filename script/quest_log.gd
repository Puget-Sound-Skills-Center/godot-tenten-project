extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

var _overlay: ColorRect
var _panel: Panel
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
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)   # transparent — panel is self-contained
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# Right-side floating panel (210px wide, anchored to top-right)
	_panel = _pa(Panel.new()) as Panel
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	_panel.anchor_left   = 1.0
	_panel.anchor_right  = 1.0
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -212
	_panel.offset_right  =  -2
	_panel.offset_top    =  8
	_panel.offset_bottom =  238
	_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_panel)

	# Header bar
	var header_bar := _pa(ColorRect.new()) as ColorRect
	header_bar.color = UITheme.C_HEADER_BG
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.custom_minimum_size = Vector2(0, 22)
	_panel.add_child(header_bar)

	var header_lbl := _pa(Label.new()) as Label
	header_lbl.text = "Quest Log"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(header_lbl, 10)
	header_bar.add_child(header_lbl)

	var hdr_line := _pa(ColorRect.new()) as ColorRect
	hdr_line.color = UITheme.C_BORDER
	hdr_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hdr_line.custom_minimum_size = Vector2(0, 1)
	header_bar.add_child(hdr_line)

	# Body margin
	var margin := _pa(MarginContainer.new()) as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom",  8)
	_panel.add_child(margin)

	var vbox := _pa(VBoxContainer.new()) as VBoxContainer
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_entries_vbox = _pa(VBoxContainer.new()) as VBoxContainer
	_entries_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_entries_vbox)

	_empty_lbl = _pa(Label.new()) as Label
	_empty_lbl.text = "No active quests."
	_empty_lbl.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(_empty_lbl, 9)
	vbox.add_child(_empty_lbl)

	vbox.add_child(UITheme.divider(188))

	_hint_lbl = _pa(Label.new()) as Label
	_hint_lbl.text = "[L] Close"
	_hint_lbl.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(_hint_lbl, 7)
	vbox.add_child(_hint_lbl)

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
	var entry := _pa(VBoxContainer.new()) as VBoxContainer
	entry.add_theme_constant_override("separation", 3)
	_entries_vbox.add_child(entry)

	var template: Dictionary = quest_data.get_quest(qid)
	var name_text: String = String(template.get("display_name", qid))

	var name_lbl := _pa(Label.new()) as Label
	name_lbl.text = "* " + name_text
	name_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(name_lbl, 9)
	entry.add_child(name_lbl)

	var obj_text: String = quest_manager.get_objective_string(qid)
	var status: String = String(global.quest_state[qid].get("status", ""))
	if status == "ready_to_complete":
		obj_text += " (Return!)"
	var obj_lbl := _pa(Label.new()) as Label
	obj_lbl.text = "  " + obj_text
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	obj_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	UITheme.apply_font(obj_lbl, 8)
	entry.add_child(obj_lbl)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.is_action_pressed("quest_log"):
		return
	if dialogue_manager._panel != null and dialogue_manager._panel.visible:
		return
	get_viewport().set_input_as_handled()
	_toggle()

func _toggle() -> void:
	if _overlay.visible:
		_overlay.visible = false
		var dlg_open := dialogue_manager._panel != null and dialogue_manager._panel.visible
		var pause_open := pause_menu._pause_panel != null and pause_menu._pause_panel.visible
		if not dlg_open and not pause_open:
			get_tree().paused = false
	else:
		_refresh()
		_overlay.visible = true
		get_tree().paused = true

func force_close() -> void:
	if _overlay != null and _overlay.visible:
		_overlay.visible = false
		get_tree().paused = false
