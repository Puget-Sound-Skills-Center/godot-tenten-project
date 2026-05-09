# Phase 2: Dialogue System - Research

**Researched:** 2026-05-09
**Domain:** GDScript dialogue data, runtime UI construction, SceneTree pause, NPC state persistence
**Confidence:** HIGH (all findings verified against codebase; Godot 4.x patterns confirmed from source)

---

## Summary

Phase 2 builds a stateful, branching dialogue system entirely within the existing project
conventions: GDScript dicts as data, runtime-constructed UI (no .tscn nodes), `global.gd`
for persistence, and duck-typed NPC identity. No external libraries. No Dialogic.

The system needs two new autoloads (`dialogue_data.gd` and `dialogue_manager.gd`) and
extensions to `npc.gd`, `dungeon_npc.gd`, and `global.gd`. The pause mechanism is
already demonstrated in `pause_menu.gd` — the same `get_tree().paused = true` +
`PROCESS_MODE_ALWAYS` pattern applies to the dialogue UI.

The largest design risk is **NPC memory storage**: per-NPC state keyed by NPC ID must
integrate cleanly with the existing `ConfigFile` save/load in `global.gd`. The solution is
a single `npc_state` Dictionary in `global.gd` serialised as one `cfg.set_value` entry.

**Primary recommendation:** Two-autoload architecture — `DialogueData` (pure data, no
nodes) + `DialogueManager` (CanvasLayer UI, pause control, choice routing). NPCs call
`DialogueManager.open(npc_id, start_node)`. All state in `global.npc_state`.

---

<user_constraints>
## User Constraints (from STATE.md / locked decisions)

### Locked Decisions
- Dialogue as data: GDScript dict in a `dialogue_data.gd` autoload — NOT JSON, NOT Dialogic
- Quest state in `global.gd` (consistent with existing save pattern)
- All UI is built in GDScript at runtime (no .tscn UI nodes) — existing project pattern
- Duck-typed identity: `body.has_method("player")` / `body.has_method("npc")`
- NPCs spawned at runtime via `load().new()` then `add_child()`
- No `class_name` declarations in game scripts
- Global state polling in `_process()` is the coordination mechanism (no signals between scenes)

### Claude's Discretion
- Exact data schema for dialogue nodes (fields, naming)
- Whether DialogueData and DialogueManager are one autoload or two
- Exact UI layout (portrait placeholder vs. actual sprite, panel dimensions)
- How branching choice input is captured (keyboard 1/2 vs. mouse click)
- NPC ID scheme (string name vs. integer)

### Deferred Ideas (OUT OF SCOPE)
- DLG-V2-01: Voiced dialogue
- DLG-V2-02: Visual dialogue editor / Dialogic integration
- Quest tracking, quest log (Phase 3)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DLG-01 | Player opens dialogue panel (portrait, name, text, advance-on-input; game pauses) | Pause pattern from pause_menu.gd; UI construction from player.gd shop; "interact" action already mapped |
| DLG-02 | Branching trees with up to 2 choices per node | Dict schema with `choices` array; choice buttons built at runtime |
| DLG-03 | NPCs remember state across interactions (quest accepted, quest complete, deepest floor) | `global.npc_state` dict + ConfigFile serialisation; keyed by npc_id |
| DLG-04 | Quest offer / decline flow inline in dialogue | `choices` entry with `action: "quest_offer"` field; DialogueManager handles quest flag side-effect |
| DLG-05 | At least one dungeon NPC (merchant or lore figure) spawned inside dungeon rooms | Extend `_spawn_enemies` pattern in dungeon.gd; new `dungeon_dialogue_npc.gd` script |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dialogue data (text, tree) | `DialogueData` autoload | — | Pure data, no nodes; separates content from display |
| Dialogue UI (panel, text, choices) | `DialogueManager` autoload (CanvasLayer) | Player's existing CanvasLayer stack | Autoload owns pause lifecycle; layer 30 sits above HUD (10) and shop (20) |
| Game pause during dialogue | `DialogueManager` via `get_tree().paused` | `pause_menu.gd` already does this | Same pattern as pause menu; dialogue panel needs `PROCESS_MODE_ALWAYS` |
| NPC proximity trigger | `npc.gd` / `dungeon_dialogue_npc.gd` | — | Extends existing Area2D pattern; calls `DialogueManager.open()` |
| NPC memory / quest flags | `global.gd` (`npc_state` dict) | ConfigFile save/load | Consistent with existing save pattern |
| Dungeon NPC spawn | `dungeon.gd` `_ready()` | — | Same pattern as enemy spawn; placed after nav setup |

---

## Standard Stack

### Core
| Component | Version/Source | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| GDScript dicts | Godot 4.6 built-in | Dialogue tree data | Locked decision; no external deps |
| `CanvasLayer` | Godot 4.6 | Dialogue UI root | Same as pause_menu.gd; survives scene pause |
| `get_tree().paused` | Godot 4.6 | Freeze gameplay during dialogue | Already used in pause_menu.gd |
| `PROCESS_MODE_ALWAYS` | Godot 4.6 | Keep UI responsive while paused | Same as pause_menu.gd `_pa()` helper |
| `ConfigFile` | Godot 4.6 | Persist npc_state to save slots | Already used in global.gd |

### No Alternatives to Consider
The locked decisions eliminate all external libraries. The only decision space is internal
architecture (one vs. two autoloads) — two autoloads is recommended for separation of
concerns.

---

## Architecture Patterns

### System Architecture Diagram

```
[Player presses "interact" near NPC]
        |
        v
[npc.gd _process() detects interact]
        |
        v
[DialogueManager.open(npc_id, start_node)]
        |
        +---> get_tree().paused = true
        |
        v
[DialogueData.get_node(npc_id, node_id)]
        |
        v
[DialogueManager renders panel]
   portrait | name | text
        |
        +--- no choices ---> [advance on "interact" key] ---> next_node / close
        |
        +--- choices[] present --> [render choice buttons 1/2]
                    |
                    v
              [player picks choice]
                    |
                    +--- action == "quest_offer" --> set global.npc_state quest flag
                    |
                    +--- goto next_node (or "" to close)
        |
        v
[DialogueManager.close()]
        |
        +---> get_tree().paused = false
        |
        v
[npc_state updated in global.npc_state]
```

### Recommended Project Structure

```
script/
├── dialogue_data.gd       # NEW autoload: all NPC dialogue trees as GDScript dicts
├── dialogue_manager.gd    # NEW autoload: CanvasLayer UI, pause, node traversal
├── npc.gd                 # EXTEND: call DialogueManager.open() on interact
├── dungeon_npc.gd         # UNCHANGED (dungeon entry trigger stays separate)
├── dungeon_dialogue_npc.gd  # NEW: merchant/lore NPC spawned inside dungeon rooms
└── global.gd              # EXTEND: add npc_state dict + save/load entries
```

### Pattern 1: Dialogue Node Schema

```gdscript
# Source: [ASSUMED] — standard GDScript dict pattern for dialogue trees
# In dialogue_data.gd
const DIALOGUES := {
    "elder": {
        "greeting": {
            "speaker": "Elder",
            "text": "Welcome, adventurer. The dungeon grows darker each day.",
            "choices": []   # empty = advance-only node
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
    }
}
```

**Schema fields:**
| Field | Type | Notes |
|-------|------|-------|
| `speaker` | String | NPC display name |
| `text` | String | Dialogue body |
| `choices` | Array[Dict] | Empty = advance-only; max 2 entries |
| `choices[].label` | String | Button text |
| `choices[].next` | String | Next node ID; `""` = close |
| `choices[].action` | String | `"quest_offer"` or `""` |
| `choices[].quest_id` | String | Required when `action == "quest_offer"` |

**Conditional entry points** (DLG-03 NPC memory): NPC scripts pass different `start_node`
strings based on `global.npc_state` checks before calling `DialogueManager.open()`.

```gdscript
# In npc.gd _process():
if player_nearby and Input.is_action_just_pressed("interact"):
    if is_instance_valid(player_ref):
        var start := "greeting"
        var state := global.npc_state.get("elder", {})
        if state.get("quest_accepted", false):
            start = "quest_follow_up"
        DialogueManager.open("elder", start)
```

### Pattern 2: DialogueManager Pause + UI

```gdscript
# Source: pause_menu.gd lines 33-38 — same pause pattern
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
```

**Critical:** DialogueManager's CanvasLayer and all its children must have
`process_mode = Node.PROCESS_MODE_ALWAYS`. Use the same `_pa()` helper pattern from
`pause_menu.gd` — or replicate it inline.

### Pattern 3: CanvasLayer Layer Ordering

Existing layers in the project:
| Layer | Owner | Purpose |
|-------|-------|---------|
| 5 | dungeon.gd | Floor HUD (floor number, puzzle label) |
| 10 | player.gd `_hud_layer` | Money HUD |
| 20 | player.gd `_shop_layer` | Upgrade shop |
| 50 | pause_menu.gd | Pause overlay |

**Dialogue panel: layer 30** — above shop (20), below pause (50). Dialogue and pause
cannot be open simultaneously (pause closes dialogue; dialogue prevents pause input).

[VERIFIED: project codebase — pause_menu.gd line 8 `layer = 50`, player.gd line 204 `layer = 10`, player.gd line 213 `layer = 20`]

### Pattern 4: NPC State in global.gd

```gdscript
# Add to global.gd:
var npc_state: Dictionary = {}
# Example structure at runtime:
# { "elder": {"quest_accepted": true}, "merchant": {"met": true} }

# Save (add to save_to_slot):
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))

# Load (add to load_from_slot):
var raw := cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}

# Reset (add to reset_for_new_game):
npc_state = {}
```

`var_to_str()` / `str_to_var()` are Godot built-ins that serialise arbitrary GDScript
values (Dictionaries, Arrays, booleans) to string for ConfigFile storage.
[VERIFIED: Godot 4.x built-in functions — used for ConfigFile Dict round-trip]

### Pattern 5: Dungeon NPC Spawn (DLG-05)

```gdscript
# In dungeon.gd _ready(), after _spawn_enemies():
_spawn_dungeon_dialogue_npc(floor_no, obstacles)

func _spawn_dungeon_dialogue_npc(floor_no: int, obstacles: Array) -> void:
    var npc := load("res://script/dungeon_dialogue_npc.gd").new()
    var pos := _find_clear_position(obstacles)  # reuse _is_position_clear logic
    npc.position = pos
    add_child(npc)
```

`dungeon_dialogue_npc.gd` mirrors `dungeon_npc.gd` structure (Area2D, proximity label,
`_process` interact) but calls `DialogueManager.open("dungeon_merchant", "greeting")`
instead of setting `global.enter_dungeon`.

### Anti-Patterns to Avoid

- **Signals between scenes for dialogue open/close:** Project uses flag polling, not signals. Dialogue open/close is a direct call, not a signal.
- **Storing dialogue tree in .tscn or JSON:** Locked decision. GDScript dict only.
- **Giving the dialogue panel a lower layer than the shop (20):** The shop must be closed before dialogue opens, OR dialogue must be at layer 30+.
- **Forgetting `PROCESS_MODE_ALWAYS`:** If the dialogue CanvasLayer does not set this on every child node, button presses and `_unhandled_input` will not fire while `get_tree().paused = true`. This is the #1 source of "dialogue is open but nothing responds" bugs.
- **Opening dialogue while shop is open:** NPC `_process()` must guard: if `player_ref.shop_open` is true, do not call `DialogueManager.open()`.
- **Using `class_name`:** Project convention prohibits it. DialogueManager is accessed as autoload by node path name only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pause during dialogue | Custom freeze flag + disabling all enemy scripts | `get_tree().paused = true` | Engine-native; pause_menu.gd already does it |
| Dict → String serialisation | Custom JSON encoder | `var_to_str()` / `str_to_var()` | Godot built-in; handles nested Dicts and booleans |
| Advance-on-input while paused | Custom input buffer | `_unhandled_input` on PROCESS_MODE_ALWAYS node | Engine input system works during pause if process_mode is set |

---

## Common Pitfalls

### Pitfall 1: PROCESS_MODE_ALWAYS missing on child nodes
**What goes wrong:** Dialogue panel appears but all input (advance text, choose option) is silently consumed or ignored because the node tree is paused.
**Why it happens:** `get_tree().paused = true` suspends all nodes with default `PROCESS_MODE_INHERIT`. The CanvasLayer itself is set to ALWAYS, but children inherit PAUSABLE unless overridden.
**How to avoid:** Apply `PROCESS_MODE_ALWAYS` to every child node in the dialogue panel (overlay ColorRect, Panel, Labels, Buttons). Use a helper like pause_menu.gd's `_pa()`.
**Warning signs:** Dialogue opens visually, but "interact" key does nothing; choice buttons are unresponsive.

### Pitfall 2: DialogueManager autoload not yet registered in project.godot
**What goes wrong:** `DialogueManager.open()` call in npc.gd causes "Identifier not found" error.
**Why it happens:** New autoloads must be added to `[autoload]` section in project.godot manually (or via Godot editor Project Settings).
**How to avoid:** Wave 0 task — add `dialogue_data` and `dialogue_manager` entries to project.godot before any scene calls them.
**Warning signs:** Script parse error on first play; "DialogueManager: identifier not found in current scope."

### Pitfall 3: npc_state dict not reset on new game
**What goes wrong:** Starting a new game, NPC shows "quest accepted" dialogue from a previous session.
**Why it happens:** `reset_for_new_game()` in global.gd only resets vars explicitly listed.
**How to avoid:** Add `npc_state = {}` to `reset_for_new_game()`.
**Warning signs:** Fresh new game has NPCs behave as if quest already accepted.

### Pitfall 4: Dialogue opened while shop is open
**What goes wrong:** Both shop and dialogue panels are visible simultaneously; `get_tree().paused` state becomes inconsistent (shop does not use pause; dialogue does).
**Why it happens:** npc.gd `_process()` checks proximity and interact, but not whether shop is already open.
**How to avoid:** Guard in npc.gd: `if is_instance_valid(player_ref) and not player_ref.shop_open`.
**Warning signs:** Pressing E near the shop NPC triggers both open_shop() and DialogueManager.open().

### Pitfall 5: var_to_str() round-trip on empty dict
**What goes wrong:** `str_to_var("{}")` returns `null` in some Godot versions, causing npc_state to be null instead of an empty Dictionary, crashing `.get()` calls.
**Why it happens:** `str_to_var` returns null for certain string inputs.
**How to avoid:** Guard: `npc_state = str_to_var(raw) if raw != "{}" else {}` — or always check `npc_state != null` after load.
**Warning signs:** Crash on `global.npc_state.get(...)` immediately after loading a save.

### Pitfall 6: Dungeon NPC destroyed on scene reload (floor advance)
**What goes wrong:** Dungeon NPC does not persist across floors (expected) but dialogue state IS expected to persist. No problem with the NPC dying — problem is if its in-progress dialogue was open when floor advances.
**Why it happens:** `get_tree().reload_current_scene()` tears down the entire dungeon scene including the NPC, but `get_tree().paused` may still be true.
**How to avoid:** In dungeon.gd `_check_next_floor()`, call `DialogueManager.force_close()` before `reload_current_scene()`. DialogueManager.force_close() sets `get_tree().paused = false` and hides the panel without side effects.
**Warning signs:** After floor advance, game is permanently paused (no player movement possible).

---

## Code Examples

### Verified: pause + PROCESS_MODE_ALWAYS pattern
```gdscript
# Source: script/pause_menu.gd lines 8, 14-16, 33-38
# CanvasLayer with process_mode = ALWAYS; _pa() helper stamps children

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

### Verified: runtime NPC spawn pattern
```gdscript
# Source: script/world.gd lines 17-20
func _spawn_shop_npc():
    var npc = load("res://script/npc.gd").new()
    npc.position = Vector2(167, 110)
    add_child(npc)
```

### Verified: existing interact trigger pattern
```gdscript
# Source: script/npc.gd lines 38-41
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            player_ref.open_shop()
```

### Verified: save/load pattern for new state
```gdscript
# Source: script/global.gd lines 75-109 — pattern to replicate for npc_state
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))
# load:
var raw := cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}
```

### Verified: existing "interact" action
```gdscript
# Source: script/dungeon_npc.gd line 39 — "interact" action already mapped in InputMap
if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
```
[VERIFIED: dungeon_npc.gd uses "interact" — InputMap entry confirmed to exist]

---

## Runtime State Inventory

> Not a rename/refactor phase. This section is not applicable.

None — no rename/refactor scope in this phase.

---

## Environment Availability

> Phase is pure GDScript code change — no external CLIs, databases, or services required.

Step 2.6: SKIPPED — no external dependencies. All work is Godot 4.6 GDScript edits and
additions. Godot 4.6 editor is the runtime; it is present (project.godot confirmed).

---

## Validation Architecture

> nyquist_validation: enabled (no explicit false in config).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual grep + Godot editor play-test (no automated test runner in project) |
| Config file | None — no pytest/vitest/jest config detected |
| Quick run command | `grep` checks (see below) — structural correctness |
| Full suite command | Manual play-test in Godot editor |

No automated test runner exists in this project. Validation uses:
1. **Grep acceptance criteria** — verify code patterns are present (structural)
2. **Play-test checklist** — verify runtime behaviour (manual)

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Grep Command | Manual Test |
|--------|----------|-----------|--------------|-------------|
| DLG-01 | Dialogue panel opens on interact, game pauses | structural + manual | See AC-01 below | Walk to NPC, press E, verify panel appears and player cannot move |
| DLG-02 | Choice buttons render for branching nodes | structural + manual | See AC-02 below | Reach a choice node; verify 2 buttons appear; pick each, verify different NPC text |
| DLG-03 | NPC shows different text on repeat visit after quest accept | structural + manual | See AC-03 below | Accept quest, close, re-open dialogue; verify different start node text |
| DLG-04 | Quest offer choice sets quest flag in global | structural + manual | See AC-04 below | Accept quest; open global.npc_state in debugger or reload save; flag present |
| DLG-05 | Dungeon NPC spawns inside dungeon room | structural + manual | See AC-05 below | Enter dungeon; NPC visible and interactable |

### Grep Acceptance Criteria

**AC-01 — DLG-01: Dialogue panel opens and game pauses**

```bash
# 1. DialogueManager sets get_tree().paused = true on open
grep -n "get_tree().paused = true" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

# 2. DialogueManager CanvasLayer has PROCESS_MODE_ALWAYS
grep -n "PROCESS_MODE_ALWAYS" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

# 3. npc.gd calls DialogueManager.open()
grep -n "DialogueManager.open" "D:/Unity/godot-tenten-project/script/npc.gd"

# 4. "interact" action used as trigger (not a new action)
grep -n "interact" "D:/Unity/godot-tenten-project/script/npc.gd"
```

**AC-02 — DLG-02: Branching with up to 2 choices per node**

```bash
# 1. dialogue_data.gd contains "choices" field in at least one node
grep -n "\"choices\"" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"

# 2. DialogueManager renders choice buttons (Button.new() inside choices branch)
grep -n "Button.new" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

# 3. At least one node has 2 choices (array of length 2)
grep -A5 "\"choices\"" "D:/Unity/godot-tenten-project/script/dialogue_data.gd" | grep -c "label"
```

**AC-03 — DLG-03: NPC remembers state (different start_node on repeat visit)**

```bash
# 1. global.gd declares npc_state dict
grep -n "npc_state" "D:/Unity/godot-tenten-project/script/global.gd"

# 2. global.gd saves npc_state to ConfigFile
grep -n "npc_state" "D:/Unity/godot-tenten-project/script/global.gd" | grep "set_value\|var_to_str"

# 3. global.gd loads npc_state from ConfigFile
grep -n "npc_state" "D:/Unity/godot-tenten-project/script/global.gd" | grep "get_value\|str_to_var"

# 4. npc.gd checks npc_state to select start_node
grep -n "npc_state" "D:/Unity/godot-tenten-project/script/npc.gd"

# 5. npc_state reset in reset_for_new_game
grep -n "npc_state" "D:/Unity/godot-tenten-project/script/global.gd" | grep "= {}"
```

**AC-04 — DLG-04: Quest offer / decline inline in dialogue**

```bash
# 1. dialogue_data.gd has at least one choice with action == "quest_offer"
grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"

# 2. DialogueManager handles "quest_offer" action
grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

# 3. Quest accept sets a flag in global.npc_state
grep -n "npc_state" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"

# 4. Decline path leads to a different next_node (not quest_accepted)
grep -n "quest_declined\|Decline" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"
```

**AC-05 — DLG-05: Dungeon NPC spawned inside dungeon rooms**

```bash
# 1. dungeon_dialogue_npc.gd exists
ls "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"

# 2. dungeon.gd calls a spawn function for the dialogue NPC
grep -n "dungeon_dialogue_npc\|_spawn_dungeon" "D:/Unity/godot-tenten-project/script/dungeon.gd"

# 3. dungeon_dialogue_npc.gd calls DialogueManager.open()
grep -n "DialogueManager.open" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"

# 4. dungeon_dialogue_npc.gd has proximity interaction area (same pattern as dungeon_npc.gd)
grep -n "_build_interaction_area\|Area2D\|body_entered" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"
```

### Wave 0 Gaps

The following files must be created or modified before implementation waves:

- [ ] `script/dialogue_data.gd` — new file (does not exist)
- [ ] `script/dialogue_manager.gd` — new file (does not exist)
- [ ] `script/dungeon_dialogue_npc.gd` — new file (does not exist)
- [ ] `project.godot` — add `dialogue_data` and `dialogue_manager` to `[autoload]` section
- [ ] `script/global.gd` — add `npc_state` var + save/load + reset entries

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `var_to_str` / `str_to_var` correctly round-trips nested Dictionaries in Godot 4.6 | Pattern 4 | npc_state save/load corrupted; need to use JSON.stringify instead |
| A2 | The "interact" action is already mapped in the Godot InputMap (inferred from dungeon_npc.gd usage) | Code Examples | If not mapped, pressing E does nothing; need to add InputMap entry |
| A3 | CanvasLayer at layer 30 renders above shop (layer 20) and below pause (layer 50) without z-fighting | Architecture Patterns | Visual overlap; adjust layer value |
| A4 | Portrait area can use a colored placeholder rect (no NPC portrait sprites exist in art/characters/) | Standard Stack | If portraits are required, a new art asset pipeline is needed |

**Note on A2:** `dungeon_npc.gd` line 39 uses `Input.is_action_just_pressed("interact")` and the game runs without error, so "interact" IS mapped. Confidence is HIGH.
**Note on A4:** `art/characters/` contains player.png, skeleton.png, slime.png — no NPC portraits. Dialogue UI should use a placeholder ColorRect or the NPC's sprite texture.

---

## Open Questions

1. **Portrait art for NPCs**
   - What we know: `art/characters/` has no NPC portrait sprites
   - What's unclear: Should DLG-01 use a placeholder (colored box) or defer portrait art?
   - Recommendation: Use placeholder ColorRect for v1; portrait art is v2 scope

2. **How many NPC dialogue trees for v1?**
   - What we know: DLG-01 through DLG-04 require at least one fully-featured NPC; DLG-05 requires one dungeon NPC
   - What's unclear: Should both the world shop NPC and the cliff_side NPC get dialogue, or just one?
   - Recommendation: Implement elder/guide NPC in world (full branching, quest offer) + minimal dungeon merchant. Shop NPC (npc.gd) stays shop-only — do not replace shop with dialogue.

3. **Input for choice selection: keyboard (1/2) vs. mouse click**
   - What we know: All existing interaction is keyboard ("interact" = E). Shop uses Button.pressed (mouse).
   - What's unclear: Should choices be keyboard (1 = option 1, 2 = option 2) or mouse click on buttons?
   - Recommendation: Mouse click on Buttons (same as shop) — simpler to implement, consistent with existing shop UI pattern.

---

## Sources

### Primary (HIGH confidence)
- `script/pause_menu.gd` (codebase) — pause pattern, PROCESS_MODE_ALWAYS, layer 50
- `script/npc.gd` (codebase) — NPC spawn, proximity, interact, prompt label
- `script/dungeon_npc.gd` (codebase) — dungeon NPC pattern
- `script/global.gd` (codebase) — save/load ConfigFile pattern, reset_for_new_game
- `script/player.gd` (codebase) — CanvasLayer layers (10, 20), shop_open flag
- `script/dungeon.gd` (codebase) — enemy spawn pattern, _is_position_clear, _ready() structure
- `script/world.gd` (codebase) — runtime NPC spawn via load().new()
- `project.godot` (codebase) — confirmed autoloads: global, pause_menu; confirmed "interact" action used

### Secondary (MEDIUM confidence)
- Godot 4.x documentation (training knowledge) — `var_to_str`, `str_to_var`, `get_tree().paused`, `PROCESS_MODE_ALWAYS` [ASSUMED — not live-verified against docs.godotengine.org this session]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all patterns verified in codebase
- Architecture: HIGH — derived from existing pause_menu.gd and npc.gd patterns
- Dialogue data schema: HIGH — GDScript dict; no external deps to break
- NPC state persistence: HIGH — ConfigFile pattern verified in global.gd; var_to_str risk flagged as A1
- Pitfalls: HIGH — all pitfalls derived from direct code inspection

**Research date:** 2026-05-09
**Valid until:** 2026-08-09 (stable Godot 4.x APIs; no fast-moving dependencies)
