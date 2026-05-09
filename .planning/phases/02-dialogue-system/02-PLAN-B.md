---
phase: 2
plan_id: "02-PLAN-B"
wave: 1
depends_on:
  - "02-PLAN-A"
files_modified:
  - script/dialogue_data.gd
  - script/dialogue_manager.gd
requirements_addressed:
  - DLG-01
  - DLG-02
autonomous: true
nyquist_compliant: false
---

# Plan B — Wave 1: Create dialogue_data.gd and dialogue_manager.gd

<objective>
Create the two new autoload scripts that are the engine of the dialogue system:

- `script/dialogue_data.gd` — pure data: all NPC dialogue trees as a nested GDScript dict
  constant. No nodes, no UI. Accessed globally as `DialogueData.get_node(npc_id, node_id)`.

- `script/dialogue_manager.gd` — CanvasLayer at layer 30. Builds the dialogue panel UI at
  runtime (portrait, name label, body label, advance prompt, choice buttons). Handles pause
  lifecycle (`get_tree().paused = true/false`). All child nodes have `PROCESS_MODE_ALWAYS`.
  Exposes `open(npc_id, start_node)`, `close()`, and `force_close()`.

Purpose: These files are the contracts that Wave 2 tasks (Plans C and D) build against.
Output: Two new GDScript files in `script/` fully implementing the core dialogue engine.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@D:/Unity/godot-tenten-project/.planning/ROADMAP.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-RESEARCH.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-PATTERNS.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-UI-SPEC.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-A-SUMMARY.md

<interfaces>
<!-- Contracts the executor needs from Plan A outputs and existing codebase -->

From script/pause_menu.gd (exact pattern to replicate):
```gdscript
extends CanvasLayer

func _ready() -> void:
    layer = 50
    process_mode = Node.PROCESS_MODE_ALWAYS

func _pa(node: Node) -> Node:
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node

func _open_pause() -> void:
    _pause_panel.visible = true
    get_tree().paused = true

func _resume() -> void:
    _pause_panel.visible = false
    get_tree().paused = false
```

From script/global.gd (state dialogue_manager reads/writes):
```gdscript
var npc_state: Dictionary = {}
```

DialogueData public API (to be created — executor defines this):
```gdscript
func get_node(npc_id: String, node_id: String) -> Dictionary
const DIALOGUES := { ... }
```

DialogueManager public API (to be created — executor defines this):
```gdscript
func open(npc_id: String, start_node: String) -> void
func close() -> void
func force_close() -> void
```
</interfaces>
</context>

<tasks>

<task id="2-B-01" type="execute">
  <title>Create script/dialogue_data.gd with full NPC dialogue trees</title>
  <read_first>
    - script/global.gd — observe the const dict style and extends Node pattern (no class_name)
    - .planning/phases/02-dialogue-system/02-PATTERNS.md — Pattern 1 (dialogue node schema,
      exact field names) and the full file structure for dialogue_data.gd
    - .planning/phases/02-dialogue-system/02-RESEARCH.md — Schema fields table (speaker, text,
      choices, choices[].label, choices[].next, choices[].action, choices[].quest_id)
  </read_first>
  <action>
Create `script/dialogue_data.gd` as a new file. It extends Node (autoload convention).
No `class_name` declaration (project convention).

The file must contain:

**1. extends + DIALOGUES constant** with two NPC trees:

```gdscript
extends Node

const DIALOGUES := {
    "elder": {
        "greeting": {
            "speaker": "Elder",
            "text": "Welcome, adventurer. The dungeon grows darker each day.",
            "next": "quest_offer",
            "choices": []
        },
        "quest_offer": {
            "speaker": "Elder",
            "text": "Will you venture to floor 10 for me? The answers I seek lie in its depths.",
            "next": "",
            "choices": [
                {"label": "Accept Quest", "next": "quest_accepted", "action": "quest_offer", "quest_id": "reach_floor_10"},
                {"label": "Decline Quest", "next": "quest_declined", "action": ""}
            ]
        },
        "quest_accepted": {
            "speaker": "Elder",
            "text": "Brave soul. Return when you have reached floor 10.",
            "next": "",
            "choices": []
        },
        "quest_declined": {
            "speaker": "Elder",
            "text": "Perhaps another time. I will wait.",
            "next": "",
            "choices": []
        },
        "quest_follow_up": {
            "speaker": "Elder",
            "text": "I remember you. How fare the depths?",
            "next": "",
            "choices": []
        }
    },
    "dungeon_merchant": {
        "greeting": {
            "speaker": "Merchant",
            "text": "Supplies, deep in the dark? You must be serious about going further.",
            "next": "merchant_offer",
            "choices": []
        },
        "merchant_offer": {
            "speaker": "Merchant",
            "text": "I have nothing to sell. But I can tell you this: the creatures below grow stronger after floor 5.",
            "next": "",
            "choices": []
        }
    }
}
```

**2. get_node() method** — returns the dict for a specific node, empty dict on miss:

```gdscript
func get_node(npc_id: String, node_id: String) -> Dictionary:
    if DIALOGUES.has(npc_id) and DIALOGUES[npc_id].has(node_id):
        return DIALOGUES[npc_id][node_id]
    return {}
```

Rules:
- Every node dict must have all four keys: `speaker`, `text`, `next`, `choices`
- Advance-only nodes: `choices` is `[]`, `next` is the next node_id or `""` (close)
- Choice nodes: `choices` is an Array of dicts, `next` on the parent node is `""` (irrelevant
  when choices are present — DialogueManager uses choices[N].next instead)
- No `class_name` at top of file
  </action>
  <acceptance_criteria>
    - `ls "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` succeeds (file exists)
    - `grep -n "extends Node" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      line 1 match
    - `grep -n "\"choices\"" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      at least 5 matches (one per node dict)
    - `grep -n "\"quest_offer\"" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      at least 2 matches (the node key and the action field value)
    - `grep -n "func get_node" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      1 match with signature `func get_node(npc_id: String, node_id: String) -> Dictionary:`
    - `grep -n "dungeon_merchant" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      at least 1 match (dungeon NPC tree exists)
    - `grep -n "class_name" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      0 matches (no class_name declaration — project convention)
  </acceptance_criteria>
</task>

<task id="2-B-02-04" type="execute">
  <title>Create script/dialogue_manager.gd — CanvasLayer UI, pause lifecycle, choice buttons</title>
  <read_first>
    - script/pause_menu.gd — read entire file; this is the exact analog. Replicate the
      _pa() helper, _ready() layer/process_mode setup, and get_tree().paused pattern verbatim.
    - .planning/phases/02-dialogue-system/02-UI-SPEC.md — Panel Layout Contract section
      (exact dimensions: panel offset_top=-96, portrait 72x72, HBoxContainer separation=8,
      VBoxContainer separation=4, font sizes 14/12/10px, colors)
    - .planning/phases/02-dialogue-system/02-PATTERNS.md — dialogue_manager.gd full pattern
      (Panel construction, _render_node, _on_choice_picked, _unhandled_input)
    - script/dialogue_data.gd — read after creating it in 2-B-01 to confirm get_node() signature
  </read_first>
  <action>
Create `script/dialogue_manager.gd` as a new file. It extends CanvasLayer (autoload convention).
No `class_name` declaration.

**Full file structure:**

```gdscript
extends CanvasLayer

var _panel: ColorRect        # full-rect overlay (visible = false when closed)
var _portrait: ColorRect     # 72x72 portrait placeholder
var _speaker_lbl: Label      # NPC name, 14px yellow
var _text_lbl: Label         # dialogue body, 12px white
var _advance_lbl: Label      # "Press E to continue", 10px grey
var _choices_container: VBoxContainer

var _current_npc := ""
var _current_node := ""
var _next_node := ""

func _ready() -> void:
    layer = 30
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_dialogue_panel()

func _pa(node: Node) -> Node:
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node
```

**_build_dialogue_panel()** — construct the full node tree per UI-SPEC Panel Layout Contract.
Apply `_pa()` to EVERY child node before add_child():

```gdscript
func _build_dialogue_panel() -> void:
    # Full-rect overlay (hidden by default; showing it = dialogue open)
    var overlay := _pa(ColorRect.new()) as ColorRect
    overlay.color = Color(0, 0, 0, 0.65)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.visible = false
    add_child(overlay)
    _panel = overlay

    # Bottom strip panel — height 96px logical
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

    # MarginContainer: 12px left/right, 8px top/bottom
    var margin := _pa(MarginContainer.new()) as MarginContainer
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)

    # HBox: portrait + right column
    var hbox := _pa(HBoxContainer.new()) as HBoxContainer
    hbox.add_theme_constant_override("separation", 8)
    margin.add_child(hbox)

    # Portrait placeholder: 72x72 dark blue-grey
    var portrait := _pa(ColorRect.new()) as ColorRect
    portrait.color = Color(0.25, 0.25, 0.35, 1.0)
    portrait.custom_minimum_size = Vector2(72, 72)
    hbox.add_child(portrait)
    _portrait = portrait

    # Right column VBox: name + text + choices/advance
    var vbox := _pa(VBoxContainer.new()) as VBoxContainer
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_theme_constant_override("separation", 4)
    hbox.add_child(vbox)

    # NPC name label: 14px, yellow
    _speaker_lbl = _pa(Label.new()) as Label
    _speaker_lbl.add_theme_font_size_override("font_size", 14)
    _speaker_lbl.add_theme_color_override("font_color", Color.YELLOW)
    vbox.add_child(_speaker_lbl)

    # Dialogue body label: 12px, white, word wrap
    _text_lbl = _pa(Label.new()) as Label
    _text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _text_lbl.add_theme_font_size_override("font_size", 12)
    _text_lbl.add_theme_color_override("font_color", Color.WHITE)
    _text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(_text_lbl)

    # Choice buttons container (hidden when no choices)
    _choices_container = _pa(VBoxContainer.new()) as VBoxContainer
    _choices_container.add_theme_constant_override("separation", 8)
    _choices_container.visible = false
    vbox.add_child(_choices_container)

    # Advance prompt: 10px, grey
    _advance_lbl = _pa(Label.new()) as Label
    _advance_lbl.text = "Press E to continue"
    _advance_lbl.add_theme_font_size_override("font_size", 10)
    _advance_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
    _advance_lbl.visible = false
    vbox.add_child(_advance_lbl)
```

**open(), close(), force_close():**

```gdscript
func open(npc_id: String, start_node: String) -> void:
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

func force_close() -> void:
    # Called by dungeon.gd before reload_current_scene() — no side effects
    _panel.visible = false
    get_tree().paused = false
    _current_npc = ""
    _current_node = ""
    _next_node = ""
```

**_render_node()** — reads from DialogueData, populates labels, builds or clears choice buttons:

```gdscript
func _render_node() -> void:
    var node := DialogueData.get_node(_current_npc, _current_node)
    if node.is_empty():
        close()
        return
    _speaker_lbl.text = node.get("speaker", "")
    _text_lbl.text = node.get("text", "")
    # Clear previous choice buttons
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
        for choice in choices:
            var btn := _pa(Button.new()) as Button
            btn.text = choice.get("label", "")
            btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            btn.add_theme_font_size_override("font_size", 12)
            btn.pressed.connect(_on_choice_picked.bind(choice))
            _choices_container.add_child(btn)
```

**_on_choice_picked()** — handles quest_offer action, advances to next node:

```gdscript
func _on_choice_picked(choice: Dictionary) -> void:
    var action: String = choice.get("action", "")
    if action == "quest_offer":
        var qid: String = choice.get("quest_id", "")
        if not global.npc_state.has(_current_npc):
            global.npc_state[_current_npc] = {}
        global.npc_state[_current_npc]["quest_accepted_" + qid] = true
    var next: String = choice.get("next", "")
    if next.is_empty():
        close()
    else:
        _current_node = next
        _render_node()
```

**_unhandled_input()** — advance on "interact" key while panel visible (fires because PROCESS_MODE_ALWAYS):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not _panel.visible:
        return
    if not (event is InputEventKey):
        return
    if not event.is_action_pressed("interact"):
        return
    if _advance_lbl.visible:
        if _next_node.is_empty():
            close()
        else:
            _current_node = _next_node
            _render_node()
```

Critical implementation rules:
- `_pa()` MUST be called on every node before `add_child()` — this is the #1 failure mode.
  The overlay ColorRect, Panel, MarginContainer, HBoxContainer, portrait ColorRect,
  right VBoxContainer, _speaker_lbl, _text_lbl, _choices_container, _advance_lbl,
  and each dynamically-created Button — ALL must go through `_pa()`.
- `process_mode = Node.PROCESS_MODE_ALWAYS` on the CanvasLayer itself is set in `_ready()`.
- layer = 30 (above shop layer 20, below pause layer 50).
- Do NOT add `class_name`.
  </action>
  <acceptance_criteria>
    - `ls "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` succeeds (file exists)
    - `grep -n "get_tree().paused = true" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns 1 match inside `open()`
    - `grep -n "get_tree().paused = false" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns at least 2 matches (close and force_close)
    - `grep -n "PROCESS_MODE_ALWAYS" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns at least 2 matches (one on the CanvasLayer in _ready, one in _pa body)
    - `grep -n "func _pa" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns 1 match
    - `grep -n "Button.new" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns 1 match inside _render_node
    - `grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns at least 1 match inside _on_choice_picked
    - `grep -n "npc_state" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns at least 1 match (quest flag write)
    - `grep -n "layer = 30" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns 1 match
    - `grep -n "force_close" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns at least 1 match (function definition)
    - `grep -n "class_name" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns 0 matches
  </acceptance_criteria>
</task>

</tasks>

<verification>
  <grep_checks>
    <!-- AC from VALIDATION.md task map — 2-B-01 through 2-B-04 -->
    <!-- Task 2-B-01: files exist -->
    ls "D:/Unity/godot-tenten-project/script/dialogue_data.gd"
    ls "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

    <!-- Task 2-B-02: pause wired -->
    grep -n "get_tree().paused = true" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

    <!-- Task 2-B-03: PROCESS_MODE_ALWAYS applied -->
    grep -n "PROCESS_MODE_ALWAYS" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

    <!-- Task 2-B-04: choice buttons rendered -->
    grep -n "Button.new" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

    <!-- DLG-02: at least one node has 2 choices -->
    grep -A5 "\"choices\"" "D:/Unity/godot-tenten-project/script/dialogue_data.gd" | grep -c "label"
  </grep_checks>
  <must_haves>
    <truths>
      - `DialogueData.get_node("elder", "greeting")` returns a non-empty Dictionary with
        keys speaker, text, next, choices
      - `DialogueData.get_node("elder", "quest_offer")` returns a node with choices array
        of length 2; first choice has action == "quest_offer" and quest_id == "reach_floor_10"
      - `DialogueData.get_node("dungeon_merchant", "greeting")` returns a non-empty Dictionary
      - `DialogueManager.open("elder", "greeting")` sets `get_tree().paused = true` and
        makes the overlay ColorRect visible
      - `DialogueManager.close()` sets `get_tree().paused = false` and hides the overlay
      - `DialogueManager.force_close()` resets pause state without advancing nodes (safe to
        call at any time, including when panel is already closed)
      - All nodes inside the DialogueManager CanvasLayer have PROCESS_MODE_ALWAYS — "interact"
        key advances dialogue while game is paused
      - Choice buttons are rendered with Button.new() and removed with queue_free() on each
        node render (no stale buttons from previous node)
    </truths>
  </must_haves>
</verification>

<threat_model>
  <!-- ASVS L1 — local single-player Godot game -->

  | Threat ID | Category | Component | Disposition | Mitigation |
  |-----------|----------|-----------|-------------|------------|
  | T-2B-01 | Denial of Service | _render_node() (dialogue_manager.gd) | mitigate | `if node.is_empty(): close()` guard prevents infinite loop when DialogueData returns empty dict for unknown node_id |
  | T-2B-02 | Denial of Service | get_tree().paused lifecycle | mitigate | `force_close()` function ensures pause is always clearable; dungeon.gd must call it before reload_current_scene() to prevent permanently frozen game state |
  | T-2B-03 | Tampering | quest flag write in _on_choice_picked | accept | Flag written to global.npc_state in-memory only; persisted via save system. No exploit path — quest flags only route dialogue, no economy or unlock gating. |
  | T-2B-04 | Information Disclosure | dialogue_data.gd DIALOGUES const | accept | All text is visible in source; single-player game with no server. No secrets in dialogue content. |
</threat_model>

<success_criteria>
- `script/dialogue_data.gd` exists with DIALOGUES const containing "elder" and "dungeon_merchant" trees
- "elder" tree has nodes: greeting, quest_offer (2 choices), quest_accepted, quest_declined, quest_follow_up
- "dungeon_merchant" tree has nodes: greeting, merchant_offer
- `script/dialogue_manager.gd` exists extending CanvasLayer, layer=30
- DialogueManager has open(), close(), force_close(), _render_node(), _on_choice_picked(), _unhandled_input()
- _pa() helper applied to every UI child node
- get_tree().paused = true in open(), false in close() and force_close()
- Button.new() used in _render_node() for choice nodes
- quest_offer action handled in _on_choice_picked() writing to global.npc_state
</success_criteria>

<output>
After completion, create `.planning/phases/02-dialogue-system/02-B-SUMMARY.md`
</output>
