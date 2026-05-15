extends CanvasLayer

# CanvasLayer-based dialogue UI built entirely in code.
# Layer 30 sits above shop (20) and HUD (10), below pause (50).
# Pause lifecycle: open() pauses tree, close()/force_close() unpauses.
# All UI children carry PROCESS_MODE_ALWAYS so input fires while paused.

var _panel: ColorRect          # full-rect overlay; visible == "dialogue is open"
var _portrait: ColorRect       # 72x72 portrait placeholder
var _speaker_lbl: Label        # NPC name (14px yellow)
var _text_lbl: Label           # dialogue body (12px white, autowrap)
var _advance_lbl: Label        # "Press E to continue" (10px grey)
var _choices_container: VBoxContainer

var _current_npc := ""
var _current_node := ""
var _next_node := ""
var _close_frame: int = -1

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_dialogue_panel()

# Stamps PROCESS_MODE_ALWAYS on a node and returns it.
# Mirror of pause_menu.gd._pa() — must be applied to every UI child or input
# silently fails while get_tree().paused == true.
func _pa(node: Node) -> Node:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	return node

func _build_dialogue_panel() -> void:
	# Full-rect overlay (kept around as the visibility flag for the dialogue).
	# mouse_filter = IGNORE so the dim does not eat clicks on the panel/buttons.
	var overlay := _pa(ColorRect.new()) as ColorRect
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	_panel = overlay

	# Bottom strip panel — 96px tall, full viewport width.
	var panel := _pa(Panel.new()) as Panel
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -96
	panel.offset_bottom = 0
	panel.offset_left = 0
	panel.offset_right = 0
	overlay.add_child(panel)

	# MarginContainer: 12px left/right, 8px top/bottom (UI-SPEC spacing scale).
	var margin := _pa(MarginContainer.new()) as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	# HBox: portrait (left) + right column (text + choices/advance).
	var hbox := _pa(HBoxContainer.new()) as HBoxContainer
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Portrait placeholder: 72x72 dark blue-grey rect (art slot).
	var portrait := _pa(ColorRect.new()) as ColorRect
	portrait.color = Color(0.25, 0.25, 0.35, 1.0)
	portrait.custom_minimum_size = Vector2(72, 72)
	hbox.add_child(portrait)
	_portrait = portrait

	# Right column VBox: speaker name + body text + (choices | advance prompt).
	var vbox := _pa(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	# NPC name label: 14px, yellow (accent reserved for speaker).
	_speaker_lbl = _pa(Label.new()) as Label
	_speaker_lbl.add_theme_font_size_override("font_size", 14)
	_speaker_lbl.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(_speaker_lbl)

	# Dialogue body label: 12px, white, word-smart autowrap.
	_text_lbl = _pa(Label.new()) as Label
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_size_override("font_size", 12)
	_text_lbl.add_theme_color_override("font_color", Color.WHITE)
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_lbl)

	# Choice buttons container — populated dynamically per node, hidden otherwise.
	_choices_container = _pa(VBoxContainer.new()) as VBoxContainer
	_choices_container.add_theme_constant_override("separation", 8)
	_choices_container.visible = false
	vbox.add_child(_choices_container)

	# Advance prompt: 10px grey, only visible on advance-only (no-choice) nodes.
	_advance_lbl = _pa(Label.new()) as Label
	_advance_lbl.text = "Press E to continue"
	_advance_lbl.add_theme_font_size_override("font_size", 10)
	_advance_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	_advance_lbl.visible = false
	vbox.add_child(_advance_lbl)

# --- Public API ---

func open(npc_id: String, start_node: String = "root") -> void:
	# Defer to pause menu if it owns the pause state (CR-03 mitigation).
	if pause_menu._pause_panel != null and pause_menu._pause_panel.visible:
		return
	# No-op if already open — re-entering from start_node would clobber state mid-flow.
	if _panel.visible:
		return
	# Block re-open on the same frame close() was called — prevents NPC _process()
	# from immediately reopening dialogue when E closes it.
	if Engine.get_process_frames() == _close_frame:
		return
	_current_npc = npc_id
	_current_node = start_node
	_panel.visible = true
	get_tree().paused = true
	_render_node()

func close() -> void:
	_panel.visible = false
	get_tree().paused = false
	_current_npc = ""
	_current_node = ""
	_next_node = ""
	_close_frame = Engine.get_process_frames()

# Same as close() but safe to call any time (including when panel already closed).
# Used by dungeon.gd before reload_current_scene() so a paused tree never carries
# across floor transitions.
func force_close() -> void:
	_panel.visible = false
	get_tree().paused = false
	_current_npc = ""
	_current_node = ""
	_next_node = ""

# --- Internals ---

func _render_node() -> void:
	var node := dialogue_data.get_dialogue_node(_current_npc, _current_node)
	if node.is_empty():
		# Unknown node id — fail-safe close (T-2B-01 mitigation).
		close()
		return
	_speaker_lbl.text = node.get("speaker", "")
	_text_lbl.text = node.get("text", "")
	# Drop stale choice buttons from any previous node.
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
			btn.text = choice.get("label", "")
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 12)
			btn.pressed.connect(_on_choice_picked.bind(choice))
			_choices_container.add_child(btn)

func _on_choice_picked(choice: Dictionary) -> void:
	var action: String = choice.get("action", "")
	if action == "quest_offer":
		var qid: String = choice.get("quest_id", "")
		if not global.npc_state.has(_current_npc):
			global.npc_state[_current_npc] = {}
		global.npc_state[_current_npc]["quest_accepted_" + qid] = true
		quest_manager.accept_quest(qid)
	elif action == "quest_complete":
		var qid2: String = choice.get("quest_id", "")
		quest_manager.complete_quest(qid2)
	elif action == "story_chain_advance":
		quest_manager.advance_story_chain()
	var next: String = choice.get("next", "")
	if next.is_empty():
		close()
	else:
		_current_node = next
		_render_node()

# Fires while paused because every node here carries PROCESS_MODE_ALWAYS.
# Guarded so it never steals input when the panel is closed; also gated to the
# advance state (advance_lbl visible) so it does not skip choice nodes.
func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if not (event is InputEventKey):
		return
	if not event.is_action_pressed("interact"):
		return
	# Consume the input so NPC pollers (npc.gd, dungeon_dialogue_npc.gd) do not
	# also see the same E press as another interact (WR-03 mitigation).
	get_viewport().set_input_as_handled()
	if _advance_lbl.visible:
		if _next_node.is_empty():
			close()
		else:
			_current_node = _next_node
			_render_node()
