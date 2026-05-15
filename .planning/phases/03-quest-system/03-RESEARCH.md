# Phase 3: Quest System - Research

**Researched:** 2026-05-13
**Domain:** GDScript quest system — kill/fetch/reach-floor/story-chain quests, in-game log UI, save/load persistence
**Confidence:** HIGH (all findings from direct codebase inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Quest log opens/closes with a dedicated key (Q or Tab). Planner chooses based on input map; if neither mapped, Tab preferred.
- **D-02:** Game pauses when quest log is open — `get_tree().paused = true/false`, identical to dialogue system. All log UI nodes must use `PROCESS_MODE_ALWAYS`.
- **D-03:** Each quest entry shows only: quest name + current objective (e.g. "Kill Melee Enemies (6/10)"). No reward preview, no description.
- **D-04:** Maximum 3 active quests at any time. Story chain counts toward cap. NPCs must not offer a quest when player is already at 3 active.
- **D-05:** Fetch items appear in dungeon as interactable chests — Area2D + CollisionShape2D + ColorRect + Label. Player presses E to open. NOT auto-pickup.
- **D-06:** Chest spawns in `dungeon.gd _ready()` **only when player has an active fetch quest** (`global.quest_state` has active fetch entry). No chest otherwise.
- **D-07:** Items tracked as `global.items: Dictionary` with item_id → count. Must be saved/loaded per slot in `global.gd`.
- **D-08:** Special items = story keys / lore artifacts — no mechanical effect. Gate NPC dialogue or locked areas. Stored in `global.items`.
- **D-09:** Lore artifacts displayed as persistent HUD icon slot — visible when player holds at least one lore item. Built at runtime in `player.gd`. Shows item name and colored rect.
- **D-10:** Access unlock reward = `global.unlocks: Dictionary` (e.g. `global.unlocks["cliff_secret_door"] = true`); relevant scene checks flag in `_ready()` / `_process()` and removes/disables blocking collision.
- **D-11:** Story chain player guidance = BOTH: quest log shows next step objective AND NPC closing dialogue hints at next NPC. Both required.
- **D-12:** v1 story chain is fixed 3 steps. Step index tracked as integer in `global.quest_state["story_chain"]["step"]` (0, 1, 2 → complete).
- **D-13:** Story chain counts toward the 3-quest cap (occupies one of 3 quest slots).

### Claude's Discretion
- Which toggle key for quest log (Q or Tab — determined below based on input map)
- Quest log panel visual layout (position, size, colors)
- Exact dialogue tree node IDs for quest offer/completion flows
- Which NPCs associated with which quest types
- Specific lore artifact names and story chain NPC sequence

### Deferred Ideas (OUT OF SCOPE)
- Dungeon mid-run mini-quests from dungeon NPCs (QST-V2-03)
- Timed quests (QST-V2-02)
- More than 3 simultaneous active quests (QST-V2-01)
- New NPC spawning as access unlock
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QST-01 | Kill quests: defeat N enemies of specific type, auto-tracked | enemy_base.gd death handler at line 92; hook at `global.money += money_drop` line |
| QST-02 | Fetch quests: find item in dungeon, return to NPC | D-05/D-06 chest spawn in dungeon._ready(); D-07 global.items dict |
| QST-03 | Reach-floor quests: reach floor N alive | global.current_floor already tracked; check on floor advance in dungeon._check_next_floor() |
| QST-04 | Story chain quests: multi-step, interact multiple NPCs in sequence | D-11/D-12/D-13; fixed 3-step; step counter in quest_state |
| QST-05 | Quest log UI: view active quests and objectives | CanvasLayer pattern from dialogue_manager.gd; D-02 pause; D-03 minimal display |
| QST-06 | Quest rewards: gold added to global.player_gold (actually global.money) | global.money is the existing gold var; reward on complete |
| QST-07 | Quest rewards: special item not available in shop | global.items dict; D-08 lore artifacts |
| QST-08 | Quest rewards: unlock new dialogue/areas | global.unlocks dict; D-10 pattern |
| QST-09 | Quest state persists across save/load | Extend global.gd save_to_slot/load_from_slot/reset_for_new_game |
</phase_requirements>

---

## Summary

Phase 3 adds a complete quest system on top of Phase 2's dialogue infrastructure. All integration points are confirmed in the codebase: enemy death tracking hooks into `enemy_base.gd` line 92-94, fetch chests follow the existing `_make_tile_base()` Area2D pattern in `dungeon.gd`, quest log UI replicates the `dialogue_manager.gd` CanvasLayer/pause lifecycle, and save/load extends `global.gd`'s `ConfigFile` slot pattern with three new dicts.

The project has two existing NPC identities exposed to the dialogue system: `"elder"` (world NPC, `npc.gd` at world position 167,110) and `"dungeon_merchant"` (dungeon NPC, `dungeon_dialogue_npc.gd` spawned per floor). A third NPC — `"blacksmith"` — must be created and spawned in `world.gd` to complete the story chain. The `dungeon_npc.gd` (cliff_side) is a gateway-only NPC with no dialogue identity; it is not used for quests.

**Primary recommendation:** Implement a `quest_manager.gd` autoload that owns `global.quest_state`, `global.items`, `global.unlocks` mutations, and provides the kill-event API. All other scripts call `quest_manager` methods rather than mutating global dicts directly.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Quest state storage | global autoload | — | All cross-scene mutable state lives in global per architecture |
| Kill tracking | enemy_base.gd (death site) | quest_manager autoload | Death event fires in enemy script; quest_manager updates state |
| Fetch item pickup | dungeon.gd (chest spawn + handler) | quest_manager autoload | Chest is a dungeon-level object; completion calls quest_manager |
| Reach-floor detection | dungeon.gd _check_next_floor() | quest_manager autoload | Floor advance is already handled here |
| Story chain step advance | npc.gd / blacksmith_npc.gd | quest_manager autoload | Interaction happens in NPC scripts |
| Quest log UI | quest_log.gd (new CanvasLayer autoload) | player.gd (lore artifact HUD slot) | Log is game-wide overlay; artifact slot is player-local HUD |
| Save/load | global.gd | — | Existing pattern; add 3 new dict keys per slot |
| Access unlock checks | cliff_side.gd / world.gd _ready() | — | Scenes check global.unlocks flag and remove collision |

---

## Standard Stack

No external libraries. Pure GDScript 4.x / Godot 4.6 engine APIs only. [VERIFIED: codebase — no dependencies beyond engine]

### Core Patterns Used
| Pattern | Source | Used For |
|---------|--------|----------|
| CanvasLayer autoload UI | `dialogue_manager.gd` layer=30 | Quest log overlay (use layer=29 or 31) |
| ConfigFile slot save/load | `global.gd` save_to_slot/load_from_slot | quest_state / items / unlocks persistence |
| Area2D + CollisionShape2D + ColorRect + Label | `dungeon.gd _make_tile_base()` | Fetch item chest |
| E-key interact polling | `npc.gd _process()` | Chest interaction, new NPC interactions |
| `has_method("player")` duck-typing | `enemy_base.gd`, `npc.gd` | Chest body_entered filter |
| `global.npc_state` dict pattern | `global.gd` | Model for quest_state, items, unlocks |
| `var_to_str` / `str_to_var` | `global.gd` line 91/110 | Serialise quest_state dict to ConfigFile |
| PROCESS_MODE_ALWAYS on UI nodes | `dialogue_manager.gd _pa()` | Quest log nodes (required for pause input) |

---

## Input Map Finding

**Verified from `project.godot` [input] section:** [VERIFIED: project.godot]

| Action | Physical Key |
|--------|-------------|
| move_up | W / Arrow Up (keycode 87 / 4194320) |
| move_down | S / Arrow Down (keycode 83 / 4194322) |
| move_left | A / Arrow Left (keycode 65 / 4194319) |
| move_right | D / Arrow Right (keycode 68 / 4194321) |
| left_click | Mouse Button 1 |
| interact | E (keycode 69) |

**Neither Q nor Tab is mapped.** Per D-01, Tab is preferred when neither is mapped.

**Recommendation (Claude's Discretion):** Use **Tab** for quest log toggle. Add `quest_log` action to `project.godot` [input] section mapping to physical_keycode 4194305 (Tab). The `quest_log.gd` autoload checks `Input.is_action_just_pressed("quest_log")` in `_unhandled_input`.

---

## NPC Assignment

### Existing NPC Identities [VERIFIED: codebase]

| NPC ID | Script | Location | Spawned By | Current Role |
|--------|--------|----------|------------|--------------|
| `"elder"` | `script/npc.gd` | world.gd position (167, 110) | `world.gd _spawn_shop_npc()` | Shop + elder dialogue |
| `"dungeon_merchant"` | `script/dungeon_dialogue_npc.gd` | dungeon (per floor) | `dungeon.gd _spawn_dungeon_dialogue_npc()` | Lore/warning dialogue |
| (unnamed gateway) | `script/dungeon_npc.gd` | cliff_side position (352, 315) | `cliff_side.gd _spawn_dungeon_npc()` | `global.enter_dungeon = true` only — no dialogue |

### Quest NPC Assignment (Claude's Discretion)

| Quest Type | NPC ID | NPC Name | Location | Rationale |
|------------|--------|----------|----------|-----------|
| Reach-floor | `"elder"` | Elder | World (167,110) | Already has reach_floor_10 quest offer node in dialogue_data.gd; natural fit |
| Kill | `"blacksmith"` (NEW) | Blacksmith | World — new position e.g. (220, 110) | Warrior/combat flavor; world hub is appropriate for combat quests |
| Fetch | `"elder"` OR `"blacksmith"` | — | World | Either works; recommend Elder for fetch (ancient relic narrative) |
| Story chain | Elder → Blacksmith → dungeon_merchant | 3-step sequence | World → World → Dungeon | Natural progression: elder sends player to blacksmith who sends player into dungeon |

**Story chain NPC sequence (Claude's Discretion):**
1. **Step 0 — Elder** (world): "I've lost my Ancient Map Fragment. The Blacksmith may know where it went."
2. **Step 1 — Blacksmith** (world): "The merchant who wanders the dungeon — he took it for safekeeping. Find him."
3. **Step 2 — dungeon_merchant** (dungeon): Completes chain, rewards lore artifact "Ancient Map Fragment" + gold + access unlock.

**New file required:** `script/blacksmith_npc.gd` — copy structure of `npc.gd`, change npc_id to `"blacksmith"`, position to (220, 110). Spawned by `world.gd _spawn_blacksmith_npc()`.

---

## Dialogue Node IDs — Existing and Required

### Existing nodes in `dialogue_data.gd` [VERIFIED]

**"elder":** `greeting`, `quest_offer`, `quest_accepted`, `quest_declined`, `quest_follow_up`
- `quest_offer` already has `action: "quest_offer"`, `quest_id: "reach_floor_10"` — reach-floor quest already wired
- `_on_choice_picked` in `dialogue_manager.gd` handles `action == "quest_offer"` → sets `global.npc_state[npc_id]["quest_accepted_" + qid] = true`

**"dungeon_merchant":** `greeting`, `merchant_offer`
- No quest nodes yet; needs story chain step-2 completion node

### Required New Dialogue Nodes

**"elder"** additions:
```
"fetch_quest_offer"      — offer fetch quest (Ancient Relic)
"fetch_quest_accepted"   — "Bring me the Ancient Relic Fragment from the dungeon depths."
"fetch_quest_declined"   — decline response
"fetch_quest_complete"   — player returns with item; awards gold
"story_chain_offer"      — offer story chain quest
"story_chain_accepted"   — "Go speak with the Blacksmith — he knows of an ancient secret."
"story_chain_declined"   — decline response
"story_chain_step0_done" — state: elder already talked, now in progress
"reach_floor_complete"   — player returns after reaching floor 10; awards gold + unlock
```

**"blacksmith"** (new NPC):
```
"greeting"               — intro
"kill_quest_offer"       — offer kill quest (Kill 10 Melee Enemies)
"kill_quest_accepted"    — "Clear those melee brutes from the dungeon."
"kill_quest_declined"    — decline response
"kill_quest_complete"    — player returns; awards gold
"kill_quest_followup"    — already accepted; shows progress
"story_chain_step1"      — story chain step 1 dialogue; hints at dungeon merchant
"story_chain_step1_done" — already talked in chain
```

**"dungeon_merchant"** additions:
```
"story_chain_step2"      — story chain step 2; completes chain; awards artifact + gold
"story_chain_complete"   — already completed chain
```

### dialogue_manager.gd `_on_choice_picked` — Current Behavior
```gdscript
# line 173-183 (VERIFIED)
if action == "quest_offer":
    var qid: String = choice.get("quest_id", "")
    if not global.npc_state.has(_current_npc):
        global.npc_state[_current_npc] = {}
    global.npc_state[_current_npc]["quest_accepted_" + qid] = true
```
**Phase 3 must extend this** to also call `quest_manager.accept_quest(qid)` when action == "quest_offer". Add `action == "quest_complete"` handling to trigger `quest_manager.complete_quest(qid)` and award rewards.

---

## quest_state Schema

Full proposed dict structure for `global.quest_state`:

```gdscript
# global.quest_state: Dictionary
# Stored as var_to_str / str_to_var in ConfigFile (same pattern as npc_state)

global.quest_state = {
    # Kill quest
    "kill_melee_10": {
        "type": "kill",
        "status": "active",       # "inactive" | "active" | "complete"
        "target_type": "melee",   # matches enemy_base.gd enemy_type string
        "required": 10,
        "progress": 0,            # auto-incremented on enemy death
        "reward_gold": 500,
        "reward_item": "",        # "" = no item reward
        "reward_unlock": "",      # "" = no unlock reward
        "npc_id": "blacksmith",   # NPC to return to for completion
    },

    # Fetch quest
    "fetch_ancient_relic": {
        "type": "fetch",
        "status": "active",
        "item_id": "ancient_relic_fragment",  # key in global.items
        "reward_gold": 300,
        "reward_item": "",
        "reward_unlock": "",
        "npc_id": "elder",
    },

    # Reach-floor quest
    "reach_floor_10": {
        "type": "reach_floor",
        "status": "active",
        "target_floor": 10,
        "reached": false,         # set true when current_floor >= target while alive
        "reward_gold": 400,
        "reward_item": "",
        "reward_unlock": "cliff_secret_door",  # example unlock
        "npc_id": "elder",
    },

    # Story chain quest (one entry, step tracks progress)
    "story_chain": {
        "type": "story_chain",
        "status": "active",
        "step": 0,                # 0=talk elder, 1=talk blacksmith, 2=talk dungeon_merchant
        "npc_sequence": ["elder", "blacksmith", "dungeon_merchant"],
        "reward_gold": 1000,
        "reward_item": "ancient_map_fragment",  # lore artifact
        "reward_unlock": "cliff_secret_door",
        "npc_id": "dungeon_merchant",  # final completer
    },
}

# global.items: Dictionary  (item_id -> count)
global.items = {
    "ancient_relic_fragment": 1,
    "ancient_map_fragment": 1,
    # future items stacked here
}

# global.unlocks: Dictionary  (unlock_id -> bool)
global.unlocks = {
    "cliff_secret_door": true,
    # future unlock flags
}
```

**Quest log display string logic:**
```gdscript
func get_objective_string(qid: String) -> String:
    var q = global.quest_state[qid]
    match q["type"]:
        "kill":
            return "%s: Kill %s Enemies (%d/%d)" % [qid, q["target_type"], q["progress"], q["required"]]
        "fetch":
            var have = global.items.get(q["item_id"], 0)
            return "%s: Find %s (%s)" % [qid, q["item_id"], "Got it!" if have > 0 else "not found"]
        "reach_floor":
            return "%s: Reach Floor %d (%s)" % [qid, q["target_floor"], "Done" if q["reached"] else "in progress"]
        "story_chain":
            var next_npc = q["npc_sequence"][mini(q["step"], q["npc_sequence"].size()-1)]
            return "Story Chain: Talk to %s (step %d/3)" % [next_npc.capitalize(), q["step"]+1]
    return qid
```

---

## Save/Load Changes (global.gd)

### Additions to `save_to_slot()` (after line 91)
```gdscript
cfg.set_value("quests", "quest_state", var_to_str(quest_state))
cfg.set_value("quests", "items", var_to_str(items))
cfg.set_value("quests", "unlocks", var_to_str(unlocks))
```

### Additions to `load_from_slot()` (after line 111 npc_state block)
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

### Additions to `reset_for_new_game()` (after line 72 `npc_state = {}`)
```gdscript
quest_state = {}
items = {}
unlocks = {}
```

### New var declarations in global.gd (top of file, after line 34 `var npc_state`)
```gdscript
var quest_state: Dictionary = {}
var items: Dictionary = {}
var unlocks: Dictionary = {}
```

---

## Integration Points — File + Line Range

### 1. Kill Quest Hook — `script/enemy_base.gd` lines 92-94

**Current:**
```gdscript
if health <= 0:
    global.money += money_drop
    queue_free()
```

**Add before `queue_free()`:**
```gdscript
if health <= 0:
    global.money += money_drop
    quest_manager.on_enemy_killed(enemy_type)  # NEW — quest_manager is autoload
    queue_free()
```

`quest_manager.on_enemy_killed(type)` iterates `global.quest_state`, finds kill quests with matching `target_type` and `status == "active"`, increments `progress`. If `progress >= required`, marks `status = "ready_to_complete"` (not auto-complete — player must return to NPC).

### 2. Fetch Chest Spawn — `script/dungeon.gd` `_ready()` after line 99

**Current _ready() call sequence (lines 88-99):**
```gdscript
_spawn_player()
_spawn_enemies(floor_no, obstacles)
_spawn_dungeon_dialogue_npc(floor_no, obstacles)
var exit_pos := _build_floor_exit(...)
_add_exit_barrier(exit_pos, obstacles)
if floor_no % 10 == 0:
    _build_save_point(obstacles)
_build_hud(floor_no)
if rng.randf() < PUZZLE_PROBABILITY:
    _setup_puzzle(...)
```

**Add after `_build_hud(floor_no)` (after line 98):**
```gdscript
_spawn_fetch_chest_if_needed(obstacles)
```

New function guards on `quest_manager.has_active_fetch_quest()` before spawning.

### 3. Reach-Floor Check — `script/dungeon.gd` `_check_next_floor()` lines 106-115

**Add at top of `_check_next_floor()`:**
```gdscript
quest_manager.on_floor_reached(global.current_floor)
```

Called every time `global.next_floor` is true (i.e., player steps on exit). Updates reach_floor quests with `reached = true` if `current_floor >= target_floor`.

### 4. Story Chain Step Advance — `script/dialogue_manager.gd` `_on_choice_picked()` lines 171-183

Extend `_on_choice_picked` to handle two new actions:
- `action == "quest_offer"` → already handled; extend to call `quest_manager.accept_quest(qid)` in addition to setting npc_state
- `action == "quest_complete"` → new: call `quest_manager.complete_quest(qid)`
- `action == "story_chain_advance"` → new: call `quest_manager.advance_story_chain()`

### 5. NPC Interaction — `script/npc.gd` `_process()` lines 38-57

NPC start_node selection must check quest states:
```gdscript
var start := "greeting"
var state := global.npc_state.get("elder", {})
# Reach-floor: offered, player reached floor, ready to complete
if state.get("quest_accepted_reach_floor_10", false) and quest_manager.quest_ready("reach_floor_10"):
    start = "reach_floor_complete"
elif state.get("quest_accepted_reach_floor_10", false):
    start = "quest_follow_up"
# Fetch quest similar pattern...
dialogue_manager.open("elder", start)
```

### 6. Lore Artifact HUD Slot — `script/player.gd` `_setup_hud()` lines 205-213

Add after `_hud_money_label` setup:
```gdscript
# Lore artifact slot — visible only when global.items is non-empty
_lore_panel = ColorRect.new()
_lore_panel.color = Color(0.25, 0.20, 0.10, 0.9)
_lore_panel.size = Vector2(80, 16)
_lore_panel.position = Vector2(8, 24)   # below money label
_hud_layer.add_child(_lore_panel)

_lore_label = Label.new()
_lore_label.position = Vector2(2, 0)
_lore_label.add_theme_font_size_override("font_size", 8)
_lore_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
_lore_panel.add_child(_lore_label)
```

Updated in `_update_hud()`:
```gdscript
var has_lore := false
for key in global.items:
    if global.items[key] > 0:
        has_lore = true
        _lore_label.text = key.replace("_", " ").capitalize()
        break
_lore_panel.visible = has_lore
```

---

## New Files Needed

### `script/quest_manager.gd` — Autoload

Registered in `project.godot` as `quest_manager="*res://script/quest_manager.gd"`.

Responsibilities:
- `accept_quest(qid: String)` — validate cap (< 3 active), add to `global.quest_state`, set status = "active"
- `on_enemy_killed(enemy_type: String)` — update kill quest progress counters
- `on_floor_reached(floor_no: int)` — update reach-floor quest reached flag
- `advance_story_chain()` — increment `global.quest_state["story_chain"]["step"]`
- `complete_quest(qid: String)` — award gold, items, unlocks; set status = "complete"
- `quest_ready(qid: String) -> bool` — returns true if status is "ready_to_complete"
- `has_active_fetch_quest() -> bool` — returns true if any fetch quest is active
- `get_active_fetch_item_id() -> String` — returns item_id of active fetch quest
- `active_quest_count() -> int` — count of quests with status == "active" or "ready_to_complete"

### `script/quest_log.gd` — Autoload (CanvasLayer)

Registered in `project.godot` as `quest_log="*res://script/quest_log.gd"`.

Structure mirrors `dialogue_manager.gd`:
- `layer = 29` (below dialogue layer 30, above HUD layer 10)
- `_pa()` helper stamps PROCESS_MODE_ALWAYS on all children
- `_build_log_panel()` in `_ready()` — creates overlay + panel + VBoxContainer for up to 3 entries
- `_unhandled_input()` — checks `Input.is_action_just_pressed("quest_log")`, toggles `_panel.visible` and `get_tree().paused`
- `_refresh()` — rebuilds entry labels from `global.quest_state` on open
- Panel spec: right side of screen (anchor_right=1, offset_left=-200), full height or centered ~180px tall; dark bg Color(0,0,0,0.75); white text 11px; yellow quest name 12px

### `script/blacksmith_npc.gd` — Runtime NPC (no autoload)

Copy of `npc.gd` structure. Key differences:
- Dialogue ID: `"blacksmith"`
- No shop logic (`open_shop()` call removed)
- Start node selection checks kill quest state and story chain state
- Spawned by `world.gd _spawn_blacksmith_npc()` at position (220, 110)

### `script/quest_data.gd` — Autoload (data only)

Registered in `project.godot` as `quest_data="*res://script/quest_data.gd"`.

Mirrors `dialogue_data.gd` pattern — GDScript dict constant:

```gdscript
extends Node

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
    "fetch_ancient_relic": {
        "type": "fetch",
        "display_name": "Lost Relic",
        "item_id": "ancient_relic_fragment",
        "reward_gold": 300,
        "reward_item": "",
        "reward_unlock": "",
        "npc_id": "elder",
    },
    "reach_floor_10": {
        "type": "reach_floor",
        "display_name": "Into the Deep",
        "target_floor": 10,
        "reward_gold": 400,
        "reward_item": "",
        "reward_unlock": "cliff_secret_door",
        "npc_id": "elder",
    },
    "story_chain": {
        "type": "story_chain",
        "display_name": "The Lost Fragment",
        "npc_sequence": ["elder", "blacksmith", "dungeon_merchant"],
        "reward_gold": 1000,
        "reward_item": "ancient_map_fragment",
        "reward_unlock": "cliff_secret_door",
        "npc_id": "dungeon_merchant",
    },
}

func get_quest(qid: String) -> Dictionary:
    return QUESTS.get(qid, {})
```

---

## Story Chain NPC Sequence (Claude's Discretion)

**Quest name:** "The Lost Fragment"

**Narrative:**
- The Elder once possessed an Ancient Map Fragment that charted the dungeon's deepest secrets. It was entrusted to the Blacksmith for safekeeping during a time of danger, but the Blacksmith gave it to a wandering dungeon merchant before losing track of him.

**Step 0 — Elder (world):**
- Dialogue node `"story_chain_offer"`: "I've lost something precious — an Ancient Map Fragment. The Blacksmith near the forge may know who took it. Will you help me find it?"
- Accept → sets step=0, quest active. Closing text: "Start with the Blacksmith. He knows more than he lets on."
- Quest log shows: "The Lost Fragment: Talk to Blacksmith (step 1/3)"

**Step 1 — Blacksmith (world):**
- NPC checks `global.quest_state["story_chain"]["step"] == 1` on interact
- Dialogue node `"story_chain_step1"`: "The Elder's map? Yes, I held it once. But a merchant who wanders the dungeon — he asked to borrow it. You'll find him somewhere in the depths."
- Calls `quest_manager.advance_story_chain()` → step becomes 2
- Quest log shows: "The Lost Fragment: Find Dungeon Merchant (step 2/3)"

**Step 2 — dungeon_merchant (dungeon):**
- NPC checks `global.quest_state["story_chain"]["step"] == 2` on interact
- Dialogue node `"story_chain_step2"`: "The Elder sent you? I've kept this safe. Here — take it back to him. And tell him the map shows a passage near the cliffside... if one knows where to look."
- Calls `quest_manager.complete_quest("story_chain")` → awards 1000g + "ancient_map_fragment" item + "cliff_secret_door" unlock
- Quest log shows: "The Lost Fragment: COMPLETE"

---

## Architecture Patterns

### Recommended Project Structure (new files only)
```
script/
├── quest_manager.gd    # Autoload — quest logic, state mutations, reward dispatch
├── quest_data.gd       # Autoload — static quest definitions dict
├── quest_log.gd        # Autoload — CanvasLayer quest log UI (Tab toggle)
└── blacksmith_npc.gd   # Runtime NPC — spawned by world.gd
```

### Quest Offer Flow
```
Player presses E near NPC
  → npc._process() detects interact
  → dialogue_manager.open(npc_id, start_node)
  → Player selects "Accept Quest"
  → dialogue_manager._on_choice_picked(choice)
  → action == "quest_offer"
  → quest_manager.accept_quest(quest_id)
    → validate cap < 3
    → copy quest_data.QUESTS[qid] into global.quest_state[qid]
    → set status = "active"
  → dialogue continues to "quest_accepted" node → closes
```

### Kill Quest Auto-Track Flow
```
Enemy health <= 0 (enemy_base.gd line 92)
  → global.money += money_drop
  → quest_manager.on_enemy_killed(enemy_type)
    → for qid in global.quest_state:
        if q.type == "kill" and q.status == "active" and q.target_type == enemy_type:
            q.progress += 1
            if q.progress >= q.required: q.status = "ready_to_complete"
  → queue_free()
```

### Reach-Floor Check Flow
```
Player steps on exit (dungeon._on_exit_body_entered)
  → global.next_floor = true
  → dungeon._check_next_floor() fires
  → quest_manager.on_floor_reached(global.current_floor)  ← ADD HERE
    → for qid in global.quest_state:
        if q.type == "reach_floor" and q.status == "active":
            if current_floor >= q.target_floor: q.reached = true; q.status = "ready_to_complete"
  → global.current_floor += 1
  → get_tree().reload_current_scene()
```

### Fetch Quest Chest Spawn Guard
```gdscript
func _spawn_fetch_chest_if_needed(obstacles: Array) -> void:
    if not quest_manager.has_active_fetch_quest():
        return
    var item_id := quest_manager.get_active_fetch_item_id()
    var pos := _pick_save_position(obstacles)   # reuse existing position picker
    # Build Area2D + CollisionShape2D + ColorRect(golden_brown) + Label("E: Open")
    # body_entered → if body.has_method("player") → global.items[item_id] += 1 → queue_free self
```

### Anti-Patterns to Avoid
- **Auto-complete on reach:** Reach-floor quests mark "ready_to_complete" but player must return to NPC. Same pattern as kill quests.
- **Chest spawning without guard:** Always check `has_active_fetch_quest()` first — no orphan chest on non-quest runs (D-06).
- **Mutating global.quest_state directly in scene scripts:** Route all mutations through `quest_manager` — keeps save consistency.
- **Forgetting PROCESS_MODE_ALWAYS:** Quest log nodes must all carry PROCESS_MODE_ALWAYS or Tab input silently fails while paused. Use same `_pa()` helper pattern from dialogue_manager.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Dict serialization | Custom binary format | `var_to_str` / `str_to_var` (already used for npc_state) |
| UI pause lifecycle | Custom pause flag | `get_tree().paused = true/false` (same as dialogue_manager) |
| Position picking for chest | New algorithm | `_pick_save_position()` already in dungeon.gd |
| NPC interaction area | New physics setup | Copy Area2D + CircleShape2D pattern from npc.gd |

---

## Common Pitfalls

### Pitfall 1: Quest log Tab key fires while dialogue is open
**What goes wrong:** Both dialogue_manager and quest_log use `_unhandled_input`. Tab pressed during dialogue could toggle quest log while dialogue is also open.
**How to avoid:** In `quest_log._unhandled_input()`, guard: `if dialogue_manager._panel != null and dialogue_manager._panel.visible: return`. Identical to NPC guards already in codebase.

### Pitfall 2: Kill count persists across saves but enemy_type is lost on queue_free
**What goes wrong:** `enemy_type` must be read BEFORE `queue_free()` is called.
**How to avoid:** `quest_manager.on_enemy_killed(enemy_type)` is called before `queue_free()` in enemy_base.gd — order matters.

### Pitfall 3: Fetch chest spawns every floor during a fetch quest
**What goes wrong:** `dungeon.gd _ready()` runs on every floor reload. Chest spawns every floor, player can pick up item multiple times.
**How to avoid:** After player picks up item (`global.items[item_id] > 0`), the `has_active_fetch_quest()` guard should check that the item is NOT already held. Alternatively, check `global.items.get(item_id, 0) == 0` before spawning.

### Pitfall 4: Pause state conflict between quest log and dialogue
**What goes wrong:** If dialogue closes while quest log is open, dialogue's `close()` calls `get_tree().paused = false` — unpausing while quest log still expects pause.
**How to avoid:** `dialogue_manager.close()` should check `if quest_log._panel.visible: return` before unpausing. OR quest log always re-pauses in its `_process()`. Simpler: don't allow quest log to open while dialogue is open (same guard as pitfall 1).

### Pitfall 5: story_chain step advances even when quest not active
**What goes wrong:** Blacksmith NPC interacts normally. If story chain isn't active, the step-advance dialogue fires anyway.
**How to avoid:** Blacksmith `_process()` checks `global.quest_state.get("story_chain", {}).get("status", "") == "active"` and `global.quest_state["story_chain"]["step"] == 1` before serving story chain dialogue.

### Pitfall 6: Reach-floor "reached" flag not set when player saves and exits mid-dungeon
**What goes wrong:** Player saves at save point on floor 10, exits to cliff, reloads — quest not marked reached.
**How to avoid:** `quest_manager.on_floor_reached()` must also be called in `dungeon._save_and_exit()` before `_exit_to_cliffside()`, using `global.current_floor`.

### Pitfall 7: `var_to_str` on nested dict with non-string keys fails silently
**What goes wrong:** If `global.quest_state` accidentally gets integer keys, `str_to_var(var_to_str(...))` may not round-trip cleanly.
**How to avoid:** All quest_state keys are String type. Enforce in `quest_manager.accept_quest()` with explicit String cast.

---

## Validation Architecture

### Test Framework
No automated test runner detected in project. Testing is manual in-editor via Godot Play. [VERIFIED: no pytest/jest/vitest config; addons/godot_ai contains test_handler.gd for MCP-based editor tests]

| Property | Value |
|----------|-------|
| Framework | Manual in-editor play + Godot AI MCP test_handler |
| Quick run | F5 in Godot editor |
| Full suite | Manual walkthrough of all QST criteria |

### Phase Requirements → Verification Map

| Req ID | Behavior | Test Method | Verifiable Condition |
|--------|----------|-------------|----------------------|
| QST-01 | Kill quest auto-tracks enemy kills | Accept kill quest, kill 10 melee enemies, check quest log counter | `global.quest_state["kill_melee_10"]["progress"] == 10`, status = "ready_to_complete" |
| QST-02 | Fetch quest: pick up item, return to NPC | Accept fetch quest, enter dungeon, open chest, return to elder | `global.items["ancient_relic_fragment"] == 1`; NPC offers complete dialogue |
| QST-03 | Reach-floor quest: arrive at target floor alive | Accept reach quest, reach floor 10, return to elder | `global.quest_state["reach_floor_10"]["reached"] == true` after floor advance |
| QST-04 | Story chain: 3-step multi-NPC sequence | Accept story chain from elder, talk to blacksmith, find dungeon merchant | `global.quest_state["story_chain"]["step"]` advances 0→1→2→complete |
| QST-05 | Quest log shows active quests | Press Tab, verify panel opens with quest entries | Panel visible, up to 3 entries shown, each with name + objective |
| QST-06 | Quest completion rewards gold | Complete any quest, check gold | `global.money` increased by reward_gold amount |
| QST-07 | Quest can reward special item | Complete story chain | `global.items["ancient_map_fragment"] == 1`; lore HUD slot visible |
| QST-08 | Quest can unlock dialogue/areas | Complete reach-floor or story chain | `global.unlocks["cliff_secret_door"] == true`; blocking collision removed |
| QST-09 | Quest state persists across save/load | Save mid-quest, load, verify state intact | `global.quest_state` keys and progress values identical after load |

### Wave 0 Gaps
- [ ] Add `quest_log` input action to `project.godot` [input] section (Tab key, physical_keycode 4194305)
- [ ] Register `quest_manager`, `quest_data`, `quest_log` as autoloads in `project.godot`
- [ ] Create `script/quest_manager.gd`, `script/quest_data.gd`, `script/quest_log.gd`, `script/blacksmith_npc.gd`

---

## Environment Availability

Step 2.6: SKIPPED — phase is pure GDScript code changes; no external CLI tools, databases, or services required beyond Godot 4.6 editor (already confirmed present via project.godot).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Blacksmith NPC position (220, 110) in world scene does not overlap existing collision or objects | NPC Assignment | Visual overlap; adjust position in plan |
| A2 | `quest_log` Tab key (physical_keycode 4194305) is correct Godot 4 keycode for Tab | Input Map | Wrong key registered; verify in Godot docs or editor |
| A3 | `dialogue_manager._on_choice_picked` is the correct extension point for quest_offer/quest_complete actions | Integration Points | If dialogue system expanded, hook location may change |
| A4 | `dungeon_dialogue_npc.gd` spawns in every dungeon floor (confirmed in `_spawn_dungeon_dialogue_npc`) — story chain step 2 can always be reached | Story Chain | If NPC is floor-gated, step 2 may be unreachable on some floors |

---

## Open Questions (RESOLVED)

1. **Blacksmith NPC world position** — RESOLVED: Plan 05 Task 2 spawns blacksmith at Vector2(220, 110) in world.gd. Implementer to adjust position in editor if collision is detected at runtime; planner assumption A1 documents this risk.

2. **quest_log Tab keycode** — RESOLVED: Plan 04 (HUD/quest log UI) uses Godot 4 `KEY_TAB` constant (4194305) as the physical_keycode in the project.godot InputMap entry. Implementer verifies via the Godot editor InputMap panel after the bind is added.

3. **Cliff secret door — which scene, which node** — RESOLVED: Plan 06 Task 2 adds the secret door procedurally in `cliff_side.gd._ready()` as a blocking StaticBody2D, and conditionally hides/removes it based on `global.unlocks["cliff_secret_door"]` (D-10).

---

## Sources

### Primary (HIGH confidence)
- `script/enemy_base.gd` — death handler lines 86-94 (direct read)
- `script/global.gd` — full save/load/reset pattern (direct read)
- `script/dialogue_manager.gd` — full CanvasLayer/pause lifecycle and `_on_choice_picked` (direct read)
- `script/dialogue_data.gd` — all existing dialogue nodes and schema (direct read)
- `script/npc.gd` — interaction pattern, start_node selection (direct read)
- `script/dungeon_dialogue_npc.gd` — dungeon merchant NPC (direct read)
- `script/dungeon_npc.gd` — cliff_side gateway NPC (direct read)
- `script/dungeon.gd` — `_ready()` spawn sequence, `_make_tile_base()`, `_check_next_floor()` (direct read)
- `script/player.gd` — `_setup_hud()`, `_update_hud()`, `_hud_layer` layer=10 (direct read)
- `script/world.gd` — NPC spawning pattern (direct read)
- `script/cliff_side.gd` — scene routing (direct read)
- `project.godot` — full input map, autoloads, layer structure (direct read)

### Tertiary (LOW confidence — assumed)
- Tab physical_keycode = 4194305 [ASSUMED — training knowledge, verify in Godot editor]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — GDScript only, no external deps confirmed
- Architecture: HIGH — all integration points verified from source
- NPC assignment: HIGH (existing) / MEDIUM (blacksmith position)
- Pitfalls: HIGH — derived from direct code reading of edge cases
- Dialogue node IDs: HIGH — existing nodes verified; new nodes are prescribed design

**Research date:** 2026-05-13
**Valid until:** 2026-06-13 (stable Godot project — no moving dependencies)
