# Phase 2: Dialogue System - Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 7
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `script/dialogue_data.gd` | config/data | transform | `script/global.gd` (const dicts pattern) | role-match |
| `script/dialogue_manager.gd` | service/UI | request-response | `script/pause_menu.gd` | exact |
| `script/npc.gd` | entity | request-response | `script/npc.gd` (self) | exact — modify in place |
| `script/global.gd` | store | CRUD | `script/global.gd` (self) | exact — extend save/load pattern |
| `project.godot` | config | — | `project.godot` (self) | exact — add two autoload lines |
| `script/dungeon_dialogue_npc.gd` | entity | request-response | `script/dungeon_npc.gd` | exact |
| `script/dungeon.gd` | scene | CRUD | `script/dungeon.gd` (self) | exact — extend _ready() spawn pattern |

---

## Pattern Assignments

### `script/dialogue_data.gd` (config/data, transform)

**Analog:** `script/global.gd` — const dict declarations at file top; no `class_name`; autoload accessed by bare name.

**File structure pattern** — no `extends` node needed (pure data, extend Node or omit):
```gdscript
extends Node

# All dialogue trees as nested GDScript dicts.
# Accessed globally as: DialogueData.DIALOGUES["npc_id"]["node_id"]
const DIALOGUES := {
    "elder": {
        "greeting": {
            "speaker": "Elder",
            "text": "Welcome, adventurer. The dungeon grows darker each day.",
            "choices": []
        },
        "quest_offer": {
            "speaker": "Elder",
            "text": "Will you venture to floor 10 for me?",
            "choices": [
                {"label": "Accept", "next": "quest_accepted", "action": "quest_offer", "quest_id": "reach_floor_10"},
                {"label": "Decline", "next": "quest_declined", "action": ""},
            ]
        },
        "quest_accepted": {
            "speaker": "Elder",
            "text": "Brave soul. Return when you have reached floor 10.",
            "choices": []
        },
        "quest_declined": {
            "speaker": "Elder",
            "text": "Perhaps another time. I will wait.",
            "choices": []
        },
    },
    "dungeon_merchant": {
        "greeting": {
            "speaker": "Merchant",
            "text": "Supplies, deep in the dark? You must be serious.",
            "choices": []
        },
    }
}

func get_node(npc_id: String, node_id: String) -> Dictionary:
    if DIALOGUES.has(npc_id) and DIALOGUES[npc_id].has(node_id):
        return DIALOGUES[npc_id][node_id]
    return {}
```

**Schema fields** (enforced by convention, not typing):
| Field | Type | Notes |
|-------|------|-------|
| `speaker` | String | NPC display name in panel header |
| `text` | String | Dialogue body text |
| `choices` | Array[Dict] | Empty = advance-only node |
| `choices[].label` | String | Button text |
| `choices[].next` | String | Next node ID; `""` = close |
| `choices[].action` | String | `"quest_offer"` or `""` |
| `choices[].quest_id` | String | Required when action == "quest_offer" |

---

### `script/dialogue_manager.gd` (service/UI, request-response)

**Analog:** `script/pause_menu.gd` — CanvasLayer autoload, `PROCESS_MODE_ALWAYS`, `_pa()` helper, `get_tree().paused`, runtime UI construction, Button.new() with pressed.connect().

**Imports / extends pattern** (`pause_menu.gd` line 1):
```gdscript
extends CanvasLayer
```

**_ready() setup pattern** (`pause_menu.gd` lines 8-12):
```gdscript
func _ready() -> void:
    layer = 30          # above shop (20), below pause (50)
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_dialogue_panel()
```

**PROCESS_MODE_ALWAYS helper** (`pause_menu.gd` lines 14-17) — copy verbatim:
```gdscript
func _pa(node: Node) -> Node:
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node
```

**Pause / unpause pattern** (`pause_menu.gd` lines 31-38):
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

func force_close() -> void:
    # Called by dungeon.gd before reload_current_scene() to prevent stuck pause
    _panel.visible = false
    get_tree().paused = false
    _current_npc = ""
    _current_node = ""
```

**Panel construction pattern** (`pause_menu.gd` lines 40-90) — use same overlay + Panel + MarginContainer + VBoxContainer stack; apply `_pa()` to every child:
```gdscript
func _build_dialogue_panel() -> void:
    var overlay := _pa(ColorRect.new()) as ColorRect
    overlay.color = Color(0, 0, 0, 0.60)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.visible = false
    add_child(overlay)
    _panel = overlay

    var panel := _pa(Panel.new()) as Panel
    # position at bottom of screen — offset_top/bottom tune height
    panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    panel.offset_top = -120
    panel.offset_bottom = -8
    panel.offset_left = 8
    panel.offset_right = -8
    overlay.add_child(panel)

    var margin := _pa(MarginContainer.new()) as MarginContainer
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var vbox := _pa(VBoxContainer.new()) as VBoxContainer
    vbox.add_theme_constant_override("separation", 6)
    margin.add_child(vbox)

    _speaker_lbl = _pa(Label.new()) as Label
    _speaker_lbl.add_theme_font_size_override("font_size", 10)
    _speaker_lbl.add_theme_color_override("font_color", Color.YELLOW)
    vbox.add_child(_speaker_lbl)

    _text_lbl = _pa(Label.new()) as Label
    _text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _text_lbl.add_theme_font_size_override("font_size", 8)
    _text_lbl.add_theme_color_override("font_color", Color.WHITE)
    vbox.add_child(_text_lbl)

    _choices_container = _pa(VBoxContainer.new()) as VBoxContainer
    vbox.add_child(_choices_container)

    _advance_lbl = _pa(Label.new()) as Label
    _advance_lbl.text = "[E] Continue"
    _advance_lbl.add_theme_font_size_override("font_size", 7)
    _advance_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    vbox.add_child(_advance_lbl)
```

**_render_node() and choice handling** — uses DialogueData.get_node(), Button.new().pressed.connect():
```gdscript
func _render_node() -> void:
    var node := DialogueData.get_node(_current_npc, _current_node)
    if node.is_empty():
        close()
        return
    _speaker_lbl.text = node.get("speaker", "")
    _text_lbl.text = node.get("text", "")
    # Clear old choice buttons
    for child in _choices_container.get_children():
        child.queue_free()
    var choices: Array = node.get("choices", [])
    if choices.is_empty():
        _advance_lbl.visible = true
        _next_node = node.get("next", "")
    else:
        _advance_lbl.visible = false
        for choice in choices:
            var btn := _pa(Button.new()) as Button
            btn.text = choice.get("label", "")
            btn.pressed.connect(_on_choice_picked.bind(choice))
            _choices_container.add_child(btn)

func _on_choice_picked(choice: Dictionary) -> void:
    var action: String = choice.get("action", "")
    if action == "quest_offer":
        var qid: String = choice.get("quest_id", "")
        if not global.npc_state.has(_current_npc):
            global.npc_state[_current_npc] = {}
        global.npc_state[_current_npc]["quest_accepted_" + qid] = true
    var next: String = choice.get("next", "")
    if next == "":
        close()
    else:
        _current_node = next
        _render_node()
```

**_unhandled_input for advance** — on PROCESS_MODE_ALWAYS node, fires while paused:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not _panel.visible:
        return
    if not (event is InputEventKey) or not event.is_action_pressed("interact"):
        return
    if _advance_lbl.visible:   # advance-only node
        if _next_node == "":
            close()
        else:
            _current_node = _next_node
            _render_node()
```

---

### `script/npc.gd` (entity, request-response) — MODIFY

**Analog:** `script/npc.gd` (self). Add dialogue trigger alongside existing shop trigger.

**Existing _process() pattern** (`npc.gd` lines 38-41) — extend, do not replace:
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            player_ref.open_shop()
```

**Extended _process() with dialogue guard** (new pattern):
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            # Guard: do not open dialogue if shop is already open
            if player_ref.shop_open:
                player_ref.open_shop()
                return
            var start := "greeting"
            var state := global.npc_state.get("elder", {})
            if state.get("quest_accepted_reach_floor_10", false):
                start = "quest_follow_up"
            DialogueManager.open("elder", start)
```

**Duck-typing identity pattern** (`npc.gd` lines 43-53) — unchanged:
```gdscript
func _on_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = true
        player_ref = body
        _prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = false
        player_ref = null
        _prompt_label.visible = false
```

---

### `script/global.gd` (store, CRUD) — MODIFY

**Analog:** `script/global.gd` (self). Extend existing save/load/reset with `npc_state`.

**New var declaration** — add after existing var block (after line 32):
```gdscript
var npc_state: Dictionary = {}
```

**save_to_slot addition** (`global.gd` lines 75-88) — add one line before `cfg.save()`:
```gdscript
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))
```

**load_from_slot addition** (`global.gd` lines 90-109) — add before `return true`:
```gdscript
var raw := cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}
if npc_state == null:
    npc_state = {}
```

**reset_for_new_game addition** (`global.gd` lines 55-70) — add one line:
```gdscript
npc_state = {}
```

---

### `project.godot` (config) — MODIFY

**Analog:** `project.godot` (self). Existing `[autoload]` section (lines 17-21):

```ini
[autoload]

global="*uid://neut6i1kx728"
_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"
pause_menu="*res://script/pause_menu.gd"
```

**Add two lines** — format is `name="*res://path/to/script.gd"` (no UID needed for new scripts):
```ini
dialogue_data="*res://script/dialogue_data.gd"
dialogue_manager="*res://script/dialogue_manager.gd"
```

**Critical:** Must be added before any scene script calls `DialogueManager.open()`. These lines make the scripts available as bare global names `DialogueData` and `DialogueManager`.

---

### `script/dungeon_dialogue_npc.gd` (entity, request-response) — NEW

**Analog:** `script/dungeon_npc.gd` (lines 1-53) — exact structural copy; change action in `_process()`.

**Full file structure** (copy dungeon_npc.gd, change two things):
```gdscript
extends Node2D

var player_nearby = false
var player_ref = null
var _prompt_label: Label

func _ready():
    _build_visual()
    _build_interaction_area()

func _build_visual():
    var sprite = Sprite2D.new()
    sprite.texture = load("res://art/objects/chest_02.png")  # placeholder; swap art later
    sprite.hframes = 4
    sprite.frame = 0
    sprite.position = Vector2(0, -8)
    add_child(sprite)

    _prompt_label = Label.new()
    _prompt_label.text = "E: Talk"                   # CHANGED from "E: Enter Dungeon"
    _prompt_label.position = Vector2(-12, -22)
    _prompt_label.add_theme_font_size_override("font_size", 6)
    _prompt_label.add_theme_color_override("font_color", Color.WHITE)
    _prompt_label.visible = false
    add_child(_prompt_label)

func _build_interaction_area():
    var area = Area2D.new()
    var shape_node = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = 20.0
    shape_node.shape = circle
    area.add_child(shape_node)
    area.body_entered.connect(_on_body_entered)
    area.body_exited.connect(_on_body_exited)
    add_child(area)

func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        DialogueManager.open("dungeon_merchant", "greeting")  # CHANGED from global.enter_dungeon = true

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = true
        player_ref = body
        _prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = false
        player_ref = null
        _prompt_label.visible = false
```

---

### `script/dungeon.gd` (scene, CRUD) — MODIFY

**Analog:** `script/dungeon.gd` (self). Enemy spawn pattern to replicate for NPC spawn.

**Existing _spawn_enemies() pattern** (`dungeon.gd` lines 247-270) — model for NPC spawn:
```gdscript
func _spawn_enemies(floor_no: int, obstacles: Array) -> void:
    var packed: PackedScene = load(ENEMY_SCENE)
    # ... position finding loop using _is_position_clear() ...
    var enemy: Node2D = packed.instantiate()
    enemy.set_script(load(_pick_enemy_script(floor_no)))
    enemy.position = pos
    add_child(enemy)
```

**Runtime script-only spawn pattern** (`world.gd` lines 17-20) — no PackedScene needed for Node2D script:
```gdscript
var npc = load("res://script/npc.gd").new()
npc.position = Vector2(167, 110)
add_child(npc)
```

**New _ready() call** — add after `_spawn_enemies(floor_no, obstacles)` at line 91:
```gdscript
_spawn_dungeon_dialogue_npc(floor_no, obstacles)
```

**New method to add** — uses `_is_position_clear()` and `_pick_save_position()` pattern (`dungeon.gd` lines 388-399):
```gdscript
func _spawn_dungeon_dialogue_npc(floor_no: int, obstacles: Array) -> void:
    var pos := _pick_save_position(obstacles)   # reuse same random-clear-position logic
    var npc := load("res://script/dungeon_dialogue_npc.gd").new()
    npc.position = pos
    add_child(npc)
```

**_check_next_floor() guard** — add before `get_tree().reload_current_scene()` at line 113:
```gdscript
func _check_next_floor() -> void:
    if not global.next_floor:
        return
    global.next_floor = false
    if global.current_floor >= global.DUNGEON_MAX_FLOOR:
        _exit_to_cliffside(1)
        return
    DialogueManager.force_close()   # ADD: prevent stuck pause if dialogue was open
    global.current_floor += 1
    get_tree().reload_current_scene()
```

---

## Shared Patterns

### PROCESS_MODE_ALWAYS helper
**Source:** `script/pause_menu.gd` lines 14-17
**Apply to:** `dialogue_manager.gd` — every node added to the CanvasLayer
```gdscript
func _pa(node: Node) -> Node:
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node
```

### get_tree().paused lifecycle
**Source:** `script/pause_menu.gd` lines 31-38
**Apply to:** `dialogue_manager.gd` open() and close()
```gdscript
# open:  get_tree().paused = true   (after making panel visible)
# close: get_tree().paused = false  (before hiding panel)
# ALWAYS paired — never set one without the other
```

### Duck-typed identity check
**Source:** `script/npc.gd` lines 43-45, `script/dungeon_npc.gd` lines 42-44
**Apply to:** `dungeon_dialogue_npc.gd` — identical pattern
```gdscript
func _on_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = true
```

### ConfigFile var_to_str / str_to_var round-trip
**Source:** `script/global.gd` lines 75-109 (pattern; new keys follow same structure)
**Apply to:** `global.gd` npc_state save/load additions
```gdscript
# save:
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))
# load (with null guard per Pitfall 5):
var raw := cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}
if npc_state == null:
    npc_state = {}
```

### Runtime load().new() NPC spawn
**Source:** `script/world.gd` lines 17-20
**Apply to:** `dungeon.gd` _spawn_dungeon_dialogue_npc()
```gdscript
var npc = load("res://script/dungeon_dialogue_npc.gd").new()
npc.position = pos
add_child(npc)
```

---

## No Analog Found

All 7 files have direct analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

| File | Notes |
|------|-------|
| `script/dialogue_data.gd` | Closest analog is global.gd const dict style; schema is net-new but trivial GDScript dicts |

---

## Metadata

**Analog search scope:** `script/` directory — all .gd files
**Files scanned:** pause_menu.gd, npc.gd, dungeon_npc.gd, global.gd, dungeon.gd, project.godot
**Pattern extraction date:** 2026-05-09
**Layer ordering confirmed:** HUD=5, money HUD=10, shop=20, dialogue=30 (new), pause=50
**"interact" action confirmed mapped:** dungeon_npc.gd line 39 uses it without error
