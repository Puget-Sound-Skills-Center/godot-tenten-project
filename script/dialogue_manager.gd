extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

# Layer 30: above shop (20) and HUD (10), below pause (50).
# All UI children carry PROCESS_MODE_ALWAYS so input fires while paused.

var _panel: ColorRect
var _portrait: ColorRect
var _speaker_lbl: Label
var _text_lbl: Label
var _advance_lbl: Label
var _choices_container: VBoxContainer

var _current_npc  := ""
var _current_node := ""
var _next_node    := ""
var _close_frame: int = -1

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_dialogue_panel()

func _pa(node: Node) -> Node:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	return node

func _build_dialogue_panel() -> void:
	var overlay := _pa(ColorRect.new()) as ColorRect
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	_panel = overlay

	# Bottom strip — 110px tall, full width
	var strip := _pa(Panel.new()) as Panel
	strip.add_theme_stylebox_override("panel", UITheme.panel_style(2))
	strip.anchor_left   = 0.0
	strip.anchor_right  = 1.0
	strip.anchor_top    = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top    = -112
	strip.offset_bottom =   -2
	strip.offset_left   =    2
	strip.offset_right  =   -2
	overlay.add_child(strip)

	# Speaker name header bar (top of strip)
	var name_bar := _pa(ColorRect.new()) as ColorRect
	name_bar.color = UITheme.C_HEADER_BG
	name_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_bar.custom_minimum_size = Vector2(0, 20)
	strip.add_child(name_bar)

	var name_bar_line := _pa(ColorRect.new()) as ColorRect
	name_bar_line.color = UITheme.C_BORDER
	name_bar_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_bar_line.custom_minimum_size = Vector2(0, 1)
	name_bar.add_child(name_bar_line)

	_speaker_lbl = _pa(Label.new()) as Label
	_speaker_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speaker_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(_speaker_lbl, 10)
	_speaker_lbl.position = Vector2(92, 0)   # offset right of portrait column
	name_bar.add_child(_speaker_lbl)

	# Body margin
	var margin := _pa(MarginContainer.new()) as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom",  8)
	strip.add_child(margin)

	var hbox := _pa(HBoxContainer.new()) as HBoxContainer
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Portrait box — 76x76 with gold border
	var portrait_frame := _pa(Panel.new()) as Panel
	portrait_frame.add_theme_stylebox_override("panel", UITheme.panel_style(1))
	portrait_frame.custom_minimum_size = Vector2(76, 76)
	hbox.add_child(portrait_frame)

	_portrait = _pa(ColorRect.new()) as ColorRect
	_portrait.color = UITheme.C_PORTRAIT_BG
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left   = 2
	_portrait.offset_right  = -2
	_portrait.offset_top    = 2
	_portrait.offset_bottom = -2
	portrait_frame.add_child(_portrait)

	# Right column
	var vbox := _pa(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)

	_text_lbl = _pa(Label.new()) as Label
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	UITheme.apply_font(_text_lbl, 7)
	vbox.add_child(_text_lbl)

	_choices_container = _pa(VBoxContainer.new()) as VBoxContainer
	_choices_container.add_theme_constant_override("separation", 5)
	_choices_container.visible = false
	vbox.add_child(_choices_container)

	_advance_lbl = _pa(Label.new()) as Label
	_advance_lbl.text = "[ E ] Continue"
	_advance_lbl.add_theme_color_override("font_color", UITheme.C_HINT)
	UITheme.apply_font(_advance_lbl, 7)
	_advance_lbl.visible = false
	vbox.add_child(_advance_lbl)

# ── Public API ──────────────────────────────────────────────────────────────

func open(npc_id: String, start_node: String = "root") -> void:
	if pause_menu._pause_panel != null and pause_menu._pause_panel.visible:
		return
	if _panel.visible:
		return
	if Engine.get_process_frames() == _close_frame:
		return
	_current_npc  = npc_id
	_current_node = start_node
	_panel.visible = true
	get_tree().paused = true
	_render_node()

func close() -> void:
	_panel.visible = false
	get_tree().paused = false
	_current_npc  = ""
	_current_node = ""
	_next_node    = ""
	_close_frame  = Engine.get_process_frames()

func force_close() -> void:
	_panel.visible = false
	get_tree().paused = false
	_current_npc  = ""
	_current_node = ""
	_next_node    = ""

# ── Internals ───────────────────────────────────────────────────────────────

func _render_node() -> void:
	var node := dialogue_data.get_dialogue_node(_current_npc, _current_node)
	if node.is_empty():
		close()
		return
	_speaker_lbl.text = node.get("speaker", "")
	_text_lbl.text    = node.get("text", "")
	for child in _choices_container.get_children():
		child.queue_free()
	var choices: Array = node.get("choices", [])
	if choices.is_empty():
		_choices_container.visible = false
		_advance_lbl.visible = true
		_next_node = node.get("next", "")
	else:
		_advance_lbl.visible = false
		_choices_container.visible = true
		_next_node = ""
		for choice in choices:
			var btn := _pa(Button.new()) as Button
			btn.text = "> " + choice.get("label", "")
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_on_choice_picked.bind(choice))
			UITheme.style_button(btn, 7)
			_choices_container.add_child(btn)

func _on_choice_picked(choice: Dictionary) -> void:
	var action: String = choice.get("action", "")
	if action == "quest_offer":
		var qid: String = choice.get("quest_id", "")
		if qid.is_empty():
			push_warning("dialogue_manager: quest_offer action missing quest_id")
		else:
			if not global.npc_state.has(_current_npc):
				global.npc_state[_current_npc] = {}
			global.npc_state[_current_npc]["quest_accepted_" + qid] = true
			quest_manager.accept_quest(qid)
	elif action == "quest_complete":
		var qid2: String = choice.get("quest_id", "")
		if qid2.is_empty():
			push_warning("dialogue_manager: quest_complete action missing quest_id")
		else:
			quest_manager.complete_quest(qid2)
	elif action == "story_chain_advance":
		quest_manager.advance_story_chain()
	var next: String = choice.get("next", "")
	if next.is_empty():
		close()
	else:
		_current_node = next
		_render_node()

func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if not (event is InputEventKey):
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _advance_lbl.visible:
		if _next_node.is_empty():
			close()
		else:
			_current_node = _next_node
			_render_node()
