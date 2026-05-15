# Phase 3: Quest System - Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 13 (4 new, 9 modified)
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `script/quest_manager.gd` | service/autoload | event-driven | `script/global.gd` (state mutations) | role-match |
| `script/quest_data.gd` | config/autoload | transform | `script/dialogue_data.gd` | exact |
| `script/quest_log.gd` | UI/autoload | request-response | `script/dialogue_manager.gd` | exact |
| `script/blacksmith_npc.gd` | entity | request-response | `script/dungeon_dialogue_npc.gd` | exact |
| `script/global.gd` | state/autoload | CRUD | `script/global.gd` (npc_state pattern) | self |
| `script/enemy_base.gd` | entity | event-driven | `script/enemy_base.gd` (death handler) | self |
| `script/dungeon.gd` | scene | event-driven | `script/dungeon.gd` (_make_tile_base) | self |
| `script/player.gd` | entity | request-response | `script/player.gd` (_setup_hud) | self |
| `script/dialogue_manager.gd` | service/autoload | event-driven | `script/dialogue_manager.gd` (_on_choice_picked) | self |
| `script/dialogue_data.gd` | config/autoload | transform | `script/dialogue_data.gd` (DIALOGUES dict) | self |
| `script/npc.gd` | entity | request-response | `script/npc.gd` (start_node selection) | self |
| `script/world.gd` | scene | request-response | `script/world.gd` (_spawn_shop_npc) | self |
| `project.godot` | config | — | `project.godot` (existing autoloads/input) | self |

---

## Pattern Assignments

### `script/quest_data.gd` (config/autoload, transform)

**Analog:** `script/dialogue_data.gd`

**Imports / file header** (lines 1-12):
```gdscript
extends Node

# All quest definitions as nested GDScript dicts.
# Accessed globally via quest_data.get_quest(quest_id).
#
# Schema fields (per-quest dict):
#   type         : String  - "kill" | "fetch" | "reach_floor" | "story_chain"
#   display_name : String  - Human-readable quest title shown in quest log
#   npc_id       : String  - NPC to return to for completion
#   reward_gold  : int     - Gold awarded on complete_quest()
#   reward_item  : String  - item_id added to global.items ("" = none)
#   reward_unlock: String  - unlock_id set in global.unlocks ("" = none)
```

**Core data-as-dict pattern** (lines 13-63 of dialogue_data.gd):
```gdscript
const QUESTS := {
    "kill_melee_10": {
        "type": "kill",
        "display_name": "Dungeon Cleanse",
        "target_type": "melee",
        "required": 10,
        "reward_gold": 500,
        "reward_item": "",
        "reward_unlock": "",
        "npc_id": "blacksmith",
    },
    # ... other quests follow same flat-dict schema
}

func get_quest(qid: String) -> Dictionary:
    return QUESTS.get(qid, {})
```

**Pattern rule:** `const` dict at file top, single accessor function returning `{}` on miss — identical to `dialogue_data.get_dialogue_node()` (line 65-68).

---

### `script/quest_log.gd` (UI/autoload, request-response)

**Analog:** `script/dialogue_manager.gd`

**File header / extends + layer** (lines 1-21 of dialogue_manager.gd):
```gdscript
extends CanvasLayer

var _panel: ColorRect   # full-rect overlay; visible == "log is open"
# ... member labels

func _ready() -> void:
    layer = 29              # below dialogue (30), above HUD (10)
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_log_panel()
```

**_pa() PROCESS_MODE_ALWAYS stamp** (lines 27-29 of dialogue_manager.gd) — copy verbatim:
```gdscript
func _pa(node: Node) -> Node:
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node
```

**Full-rect overlay construction** (lines 31-41 of dialogue_manager.gd):
```gdscript
var overlay := _pa(ColorRect.new()) as ColorRect
overlay.color = Color(0, 0, 0, 0.65)
overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
overlay.visible = false
add_child(overlay)
_panel = overlay
```

**Pause open/close lifecycle** (lines 111-139 of dialogue_manager.gd):
```gdscript
func open(...) -> void:
    if pause_menu._pause_panel != null and pause_menu._pause_panel.visible:
        return
    if _panel.visible:
        return
    _panel.visible = true
    get_tree().paused = true

func close() -> void:
    _panel.visible = false
    get_tree().paused = false
```

**_unhandled_input guard pattern** (lines 188-203 of dialogue_manager.gd):
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not _panel.visible:
        return
    if not (event is InputEventKey):
        return
    if not event.is_action_just_pressed("interact"):
        return
    get_viewport().set_input_as_handled()
```

**quest_log adaptation:** Replace `"interact"` check with `"quest_log"` action. Add guard: `if dialogue_manager._panel != null and dialogue_manager._panel.visible: return`. Toggle `_panel.visible` (not a one-way open/close). Call `_refresh()` on open. Use `VBoxContainer` for up to 3 quest entry labels inside panel.

---

### `script/blacksmith_npc.gd` (entity, request-response)

**Analog:** `script/dungeon_dialogue_npc.gd` (exact structural match — same Node2D + Area2D + prompt pattern)

**Full file structure** (lines 1-56 of dungeon_dialogue_npc.gd) — copy verbatim, then modify:
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
    sprite.texture = load("res://art/objects/chest_01.png")  # or chest_02.png
    sprite.hframes = 4
    sprite.frame = 0
    sprite.position = Vector2(0, -8)
    add_child(sprite)

    _prompt_label = Label.new()
    _prompt_label.text = "E: Talk"
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
        if dialogue_manager._panel != null and dialogue_manager._panel.visible:
            return
        dialogue_manager.open("dungeon_merchant", "greeting")  # ← change npc_id + start_node

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

**blacksmith_npc.gd modifications from analog:**
- Change `dialogue_manager.open("dungeon_merchant", "greeting")` → dynamic start_node selection checking `global.quest_state` (kill quest state, story chain step)
- Change npc_id to `"blacksmith"`
- No `open_shop()` call (unlike npc.gd)

**Additional reference for start_node selection** — `script/npc.gd` lines 52-57:
```gdscript
var start := "greeting"
var state: Dictionary = global.npc_state.get("elder", {})
if state.get("quest_accepted_reach_floor_10", false):
    start = "quest_follow_up"
dialogue_manager.open("elder", start)
```

---

### `script/quest_manager.gd` (service/autoload, event-driven)

**Analog:** `script/global.gd` (autoload singleton pattern) + `script/dialogue_manager.gd` (method-based API)

**Autoload structure** (from global.gd lines 1-34):
```gdscript
extends Node

# No _ready() setup required — all state lives in global.quest_state.
# quest_manager is a stateless service that mutates global dicts.
```

**Kill event handler pattern** — modeled on global.gd's mutation style:
```gdscript
func on_enemy_killed(enemy_type: String) -> void:
    for qid in global.quest_state:
        var q: Dictionary = global.quest_state[qid]
        if q.get("type") == "kill" and q.get("status") == "active":
            if q.get("target_type") == enemy_type:
                q["progress"] += 1
                if q["progress"] >= q["required"]:
                    q["status"] = "ready_to_complete"
```

**Bool query pattern** — modeled on global.gd `get_max_health()` / `get_attack_damage()` (lines 36-41):
```gdscript
func has_active_fetch_quest() -> bool:
    for qid in global.quest_state:
        var q: Dictionary = global.quest_state[qid]
        if q.get("type") == "fetch" and q.get("status") == "active":
            if global.items.get(q.get("item_id", ""), 0) == 0:
                return true
    return false

func active_quest_count() -> int:
    var count := 0
    for qid in global.quest_state:
        var s: String = global.quest_state[qid].get("status", "")
        if s == "active" or s == "ready_to_complete":
            count += 1
    return count
```

---

### `script/global.gd` (MODIFY — state/autoload, CRUD)

**Analog:** Self — existing npc_state dict pattern

**New var declarations** — insert after line 34 (`var npc_state: Dictionary = {}`):
```gdscript
var quest_state: Dictionary = {}
var items: Dictionary = {}
var unlocks: Dictionary = {}
```

**reset_for_new_game() additions** — insert after line 72 (`npc_state = {}`):
```gdscript
quest_state = {}
items = {}
unlocks = {}
```

**save_to_slot() additions** — insert after line 91 (`cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))`):
```gdscript
cfg.set_value("quests", "quest_state", var_to_str(quest_state))
cfg.set_value("quests", "items", var_to_str(items))
cfg.set_value("quests", "unlocks", var_to_str(unlocks))
```

**load_from_slot() additions** — insert after line 113 (`if npc_state == null: npc_state = {}`). Copy npc_state pattern exactly:
```gdscript
var raw_qs := cfg.get_value("quests", "quest_state", "{}")
quest_state = str_to_var(raw_qs) if raw_qs != "{}" else {}
if quest_state == null: quest_state = {}

var raw_items := cfg.get_value("quests", "items", "{}")
items = str_to_var(raw_items) if raw_items != "{}" else {}
if items == null: items = {}

var raw_unlocks := cfg.get_value("quests", "unlocks", "{}")
unlocks = str_to_var(raw_unlocks) if raw_unlocks != "{}" else {}
if unlocks == null: unlocks = {}
```

**var_to_str / str_to_var serialization pattern** (lines 91 and 110-113 of global.gd):
```gdscript
# SAVE:
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))

# LOAD:
var raw := cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}
if npc_state == null:
    npc_state = {}
```

---

### `script/enemy_base.gd` (MODIFY — entity, event-driven)

**Analog:** Self — death handler

**Integration point** — lines 92-94 of enemy_base.gd:
```gdscript
# CURRENT:
if health <= 0:
    global.money += money_drop
    queue_free()

# MODIFIED — insert quest hook before queue_free():
if health <= 0:
    global.money += money_drop
    quest_manager.on_enemy_killed(enemy_type)  # NEW
    queue_free()
```

**enemy_type declaration** (line 9 of enemy_base.gd) — already present, no change:
```gdscript
var enemy_type: String = "melee"
```

**Critical ordering note:** `quest_manager.on_enemy_killed(enemy_type)` MUST be called before `queue_free()`. After `queue_free()` the node is gone and `enemy_type` is inaccessible.

---

### `script/dungeon.gd` (MODIFY — scene, event-driven)

**Analog:** Self — two integration points

**Integration point 1: fetch chest spawn** — insert after line 99 (`_build_hud(floor_no)`) in `_ready()`:
```gdscript
_spawn_fetch_chest_if_needed(obstacles)
```

**New function pattern** — follows `_spawn_dungeon_dialogue_npc` structure (lines 275-279):
```gdscript
func _spawn_fetch_chest_if_needed(obstacles: Array) -> void:
    if not quest_manager.has_active_fetch_quest():
        return
    var item_id := quest_manager.get_active_fetch_item_id()
    var pos := _pick_save_position(obstacles)
    # Build Area2D chest — see _make_tile_base pattern below
```

**_make_tile_base Area2D construction** (lines 485-507 of dungeon.gd) — use as chest template:
```gdscript
func _make_tile_base(pos: Vector2, color: Color, label_text: String) -> Area2D:
    var area := Area2D.new()
    area.position = pos
    area.z_index = -1
    var shape_node := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(TILE, TILE)
    shape_node.shape = shape
    area.add_child(shape_node)
    var visual := ColorRect.new()
    visual.color = color                              # use Color(0.55, 0.40, 0.15) for golden-brown chest
    visual.position = Vector2(-TILE / 2.0, -TILE / 2.0)
    visual.size = Vector2(TILE, TILE)
    area.add_child(visual)
    var lbl := Label.new()
    lbl.text = label_text                             # "E: Open"
    lbl.position = Vector2(-3, -8) if label_text.length() <= 1 else Vector2(-6, -8)
    lbl.add_theme_font_size_override("font_size", 10)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    area.add_child(lbl)
    area.body_entered.connect(_on_puzzle_tile_entered.bind(area))  # ← swap for chest handler
    return area
```

**Chest body_entered handler** — use duck-typing pattern from lines 59-61 of npc.gd:
```gdscript
# In chest body_entered callback:
if body.has_method("player"):
    global.items[item_id] = global.items.get(item_id, 0) + 1
    area.queue_free()
```

**_pick_save_position** (lines 398-409 of dungeon.gd) — reuse as-is for chest placement:
```gdscript
func _pick_save_position(obstacles: Array) -> Vector2:
    for i in 80:
        var x := rng.randi_range(min_tx, max_tx) * TILE + TILE / 2
        var y := rng.randi_range(min_ty, max_ty) * TILE + TILE / 2
        var p := Vector2(x, y)
        if _is_position_clear(p, obstacles, 10):
            return p
    return Vector2(room_w / 2, room_h / 2)
```

**Integration point 2: reach-floor check** — insert at top of `_check_next_floor()` (line 107):
```gdscript
func _check_next_floor() -> void:
    if not global.next_floor:
        return
    quest_manager.on_floor_reached(global.current_floor)  # NEW — before incrementing floor
    global.next_floor = false
    # ... rest unchanged
```

Also insert same call in `_save_and_exit()` (line 117-119) before `_exit_to_cliffside()`:
```gdscript
func _save_and_exit() -> void:
    quest_manager.on_floor_reached(global.current_floor)  # NEW
    var resume := mini(global.current_floor + 1, global.DUNGEON_MAX_FLOOR)
    _exit_to_cliffside(resume)
```

---

### `script/player.gd` (MODIFY — entity, request-response)

**Analog:** Self — `_setup_hud()` and `_update_hud()`

**_setup_hud() construction pattern** (lines 205-213 of player.gd):
```gdscript
func _setup_hud():
    _hud_layer = CanvasLayer.new()
    _hud_layer.layer = 10
    add_child(_hud_layer)

    _hud_money_label = Label.new()
    _hud_money_label.position = Vector2(8, 8)
    _hud_money_label.add_theme_color_override("font_color", Color.YELLOW)
    _hud_layer.add_child(_hud_money_label)
```

**Lore artifact slot addition** — append to _setup_hud() after money label:
```gdscript
    _lore_panel = ColorRect.new()
    _lore_panel.color = Color(0.25, 0.20, 0.10, 0.9)
    _lore_panel.size = Vector2(80, 16)
    _lore_panel.position = Vector2(8, 24)   # directly below money label at (8,8)
    _hud_layer.add_child(_lore_panel)

    _lore_label = Label.new()
    _lore_label.position = Vector2(2, 0)
    _lore_label.add_theme_font_size_override("font_size", 8)
    _lore_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    _lore_panel.add_child(_lore_label)
```

**_update_hud() update pattern** (lines 305-306 of player.gd) — follow same poll style:
```gdscript
func _update_hud():
    _hud_money_label.text = "Gold: %d" % global.money
    # Lore artifact slot — add after money update:
    var has_lore := false
    for key in global.items:
        if global.items[key] > 0:
            has_lore = true
            _lore_label.text = key.replace("_", " ").capitalize()
            break
    _lore_panel.visible = has_lore
```

**New member var declarations** — add alongside `_hud_money_label` at top of player.gd:
```gdscript
var _lore_panel: ColorRect
var _lore_label: Label
```

---

### `script/dialogue_manager.gd` (MODIFY — service/autoload, event-driven)

**Analog:** Self — `_on_choice_picked()`

**Current _on_choice_picked pattern** (lines 171-183 of dialogue_manager.gd):
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

**Extension — add new action branches before `var next` line**:
```gdscript
    if action == "quest_offer":
        # ... existing npc_state code stays ...
        quest_manager.accept_quest(choice.get("quest_id", ""))  # NEW — also register with quest_manager
    elif action == "quest_complete":                             # NEW
        quest_manager.complete_quest(choice.get("quest_id", ""))
    elif action == "story_chain_advance":                        # NEW
        quest_manager.advance_story_chain()
```

**Pattern note:** The `elif` chain is ordered — `quest_offer` retains its existing npc_state mutation and gains the quest_manager call; new actions are purely quest_manager delegates.

---

### `script/dialogue_data.gd` (MODIFY — config/autoload, transform)

**Analog:** Self — existing DIALOGUES dict structure

**Schema for new choice nodes with quest actions** (from lines 21-28 of dialogue_data.gd):
```gdscript
"quest_offer": {
    "speaker": "Elder",
    "text": "Will you venture to floor 10 for me?",
    "next": "",
    "choices": [
        {"label": "Accept Quest", "next": "quest_accepted", "action": "quest_offer", "quest_id": "reach_floor_10"},
        {"label": "Decline Quest", "next": "quest_declined", "action": ""}
    ]
},
```

**New action types for Phase 3 choices:**
- `"action": "quest_offer", "quest_id": "<qid>"` — triggers `quest_manager.accept_quest(qid)`
- `"action": "quest_complete", "quest_id": "<qid>"` — triggers `quest_manager.complete_quest(qid)`
- `"action": "story_chain_advance"` — triggers `quest_manager.advance_story_chain()`
- `"action": ""` — no action (decline / advance only)

**New "blacksmith" top-level key** — follows same structure as "elder" and "dungeon_merchant":
```gdscript
"blacksmith": {
    "greeting": { "speaker": "Blacksmith", "text": "...", "next": "...", "choices": [] },
    "kill_quest_offer": { ..., "choices": [{"label": "Accept", "action": "quest_offer", "quest_id": "kill_melee_10", ...}, ...] },
    # ... all blacksmith nodes
}
```

---

### `script/npc.gd` (MODIFY — entity, request-response)

**Analog:** Self — start_node selection in `_process()`

**Current start_node selection** (lines 52-57 of npc.gd):
```gdscript
var start := "greeting"
var state: Dictionary = global.npc_state.get("elder", {})
if state.get("quest_accepted_reach_floor_10", false):
    start = "quest_follow_up"
dialogue_manager.open("elder", start)
```

**Extended pattern for Phase 3** — insert additional checks before `dialogue_manager.open()`:
```gdscript
var start := "greeting"
var state: Dictionary = global.npc_state.get("elder", {})
# Reach-floor quest completion check
if state.get("quest_accepted_reach_floor_10", false) and quest_manager.quest_ready("reach_floor_10"):
    start = "reach_floor_complete"
elif state.get("quest_accepted_reach_floor_10", false):
    start = "quest_follow_up"
# Fetch quest completion check (add similarly)
# Story chain offer check (add similarly)
dialogue_manager.open("elder", start)
```

**3-quest cap guard** — add before any `dialogue_manager.open()` for quest-offering nodes:
```gdscript
# In npc.gd and blacksmith_npc.gd, when offering a new quest:
if quest_manager.active_quest_count() >= 3:
    start = "quest_cap_reached"   # a node that says "I have no quests for you now"
```

---

### `script/world.gd` (MODIFY — scene, request-response)

**Analog:** Self — `_spawn_shop_npc()` (lines 16-19 of world.gd)

**Existing spawn pattern** (lines 16-19 of world.gd):
```gdscript
func _spawn_shop_npc():
    var npc = load("res://script/npc.gd").new()
    npc.position = Vector2(167, 110)
    add_child(npc)
```

**New blacksmith spawn** — copy pattern exactly:
```gdscript
func _spawn_blacksmith_npc():
    var npc = load("res://script/blacksmith_npc.gd").new()
    npc.position = Vector2(220, 110)
    add_child(npc)
```

**Call site addition** — in `_ready()` after `_spawn_shop_npc()` (line 14):
```gdscript
func _ready() -> void:
    # ... existing position setup ...
    _spawn_shop_npc()
    _spawn_blacksmith_npc()   # NEW
```

---

### `project.godot` (MODIFY — config)

**Analog:** Self — existing autoload and input section patterns

**Existing autoload format** (from project.godot — read during research):
```ini
[autoload]
global="*res://script/global.gd"
pause_menu="*res://script/pause_menu.gd"
dialogue_manager="*res://script/dialogue_manager.gd"
dialogue_data="*res://script/dialogue_data.gd"
```

**New autoload entries** — append to [autoload] section:
```ini
quest_data="*res://script/quest_data.gd"
quest_manager="*res://script/quest_manager.gd"
quest_log="*res://script/quest_log.gd"
```

**Existing input action format** — from project.godot [input] section:
```ini
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,...,"physical_keycode":69,...)]
}
```

**New input action** — add to [input] section:
```ini
quest_log={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,...,"physical_keycode":4194305,...)]
}
```
Note: 4194305 is KEY_TAB in Godot 4. Verify in Godot editor InputMap if behavior is wrong (see Research A2).

---

## Shared Patterns

### PROCESS_MODE_ALWAYS Stamp
**Source:** `script/dialogue_manager.gd` lines 27-29
**Apply to:** `quest_log.gd` — every UI node created in `_build_log_panel()`
```gdscript
func _pa(node: Node) -> Node:
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node
```
Usage: `var lbl := _pa(Label.new()) as Label`

### Duck-Typed Player Identity Check
**Source:** `script/npc.gd` lines 59-62, `script/enemy_base.gd` lines 59-61
**Apply to:** fetch chest `body_entered` handler in `dungeon.gd`
```gdscript
func _on_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        # ... handle player interaction
```

### Dialogue Open Guard (WR-01 mitigation)
**Source:** `script/npc.gd` lines 46-47, `script/dungeon_dialogue_npc.gd` lines 41-42
**Apply to:** `blacksmith_npc.gd` _process(), `quest_log.gd` _unhandled_input()
```gdscript
if dialogue_manager._panel != null and dialogue_manager._panel.visible:
    return
```

### Runtime UI Node Construction (no .tscn)
**Source:** `script/player.gd` `_setup_hud()` (lines 205-213), `script/dialogue_manager.gd` `_build_dialogue_panel()` (lines 31-107)
**Apply to:** `quest_log.gd` `_build_log_panel()`, `player.gd` lore artifact slot
- All UI nodes instantiated with `.new()` and `add_child()`
- Anchors set via `set_anchors_preset()` or explicit `anchor_*` properties
- Fonts via `add_theme_font_size_override("font_size", N)`
- Colors via `add_theme_color_override("font_color", Color(...))`

### var_to_str / str_to_var Dict Serialization
**Source:** `script/global.gd` lines 91 and 110-113
**Apply to:** `global.gd` — quest_state, items, unlocks in save_to_slot / load_from_slot
```gdscript
# Save: cfg.set_value(section, key, var_to_str(dict))
# Load:
var raw := cfg.get_value(section, key, "{}")
dict = str_to_var(raw) if raw != "{}" else {}
if dict == null: dict = {}
```

### Runtime NPC Spawn
**Source:** `script/world.gd` lines 16-19
**Apply to:** `world.gd` `_spawn_blacksmith_npc()`
```gdscript
var npc = load("res://script/<npc_script>.gd").new()
npc.position = Vector2(x, y)
add_child(npc)
```

---

## No Analog Found

All files have close analogs in the codebase. No files require falling back to RESEARCH.md patterns only.

---

## Metadata

**Analog search scope:** `script/` directory (all .gd files read directly)
**Files scanned:** 8 source files read in full or targeted sections
**Pattern extraction date:** 2026-05-13
