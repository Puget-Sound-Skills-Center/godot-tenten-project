---
phase: 02-dialogue-system
reviewed: 2026-05-09T10:23:00-07:00
depth: standard
files_reviewed: 7
files_reviewed_list:
  - script/dialogue_data.gd
  - script/dialogue_manager.gd
  - script/dungeon_dialogue_npc.gd
  - script/global.gd
  - script/npc.gd
  - script/dungeon.gd
  - project.godot
findings:
  critical: 3
  warning: 6
  info: 4
  total: 13
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-05-09T10:23:00-07:00
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 2 ships a stateful dialogue system across 4 plans (autoload + npc_state scaffolding, DialogueData/DialogueManager engine, world NPC wiring, dungeon NPC). The architecture follows the established `pause_menu.gd` template (CanvasLayer + `_pa()` helper + `get_tree().paused`), and the documented threat-model mitigations (T-2B-01 unknown-node fail-safe, T-2B-02 force_close, T-2C-03 shop guard, T-2D-01 paused-tree leak) are all present in code.

However, the review surfaces 3 BLOCKER defects that will prevent the system from running or cause user-visible breakage:

1. **Autoload identifier case mismatch** — `project.godot` registers `dialogue_data` / `dialogue_manager` (lowercase) but every call site uses `DialogueData` / `DialogueManager` (PascalCase). Godot autoload identifiers are case-sensitive. This will fail at parse time.
2. **`get_node()` overrides `Node.get_node()`** in `dialogue_data.gd` — the autoload extends `Node`, so defining `func get_node(npc_id, node_id) -> Dictionary` shadows the built-in `Node.get_node(NodePath) -> Node`. Any engine-internal call to `get_node` on this autoload will return `Dictionary` and break.
3. **Pause-menu / dialogue interaction stomps** — `pause_menu._unhandled_input` fires on `ui_cancel` regardless of dialogue state. Pressing ESC during dialogue both opens the pause panel AND leaves the dialogue panel visible, creating a layered/inconsistent state. When the player resumes, `_resume()` unconditionally sets `paused = false`, breaking dialogue's pause invariant.

Additional warnings cover a stale-`player_ref` race in `npc.gd`, missing pause-state guards in NPC `_process()` polling (the dialogue gates input but not the trigger that opened it — pressing E during dialogue can re-open another dialogue), and the `var_to_str("{}")` round-trip producing the literal string `"{ }"` not `"{}"` so the empty-dict guard never fires after a real save.

## Critical Issues

### CR-01: Autoload identifier case mismatch — DialogueData / DialogueManager will not resolve

**File:** `project.godot:22-23`, `script/dialogue_manager.gd:138`, `script/npc.gd:51`, `script/dungeon_dialogue_npc.gd:40`, `script/dungeon.gd:114`
**Issue:** The autoloads are registered as **lowercase** identifiers:

```ini
[autoload]
dialogue_data="*res://script/dialogue_data.gd"
dialogue_manager="*res://script/dialogue_manager.gd"
```

But every consumer references them as **PascalCase**:

- `script/dialogue_manager.gd:138` — `DialogueData.get_node(_current_npc, _current_node)`
- `script/npc.gd:51` — `DialogueManager.open("elder", start)`
- `script/dungeon_dialogue_npc.gd:40` — `DialogueManager.open("dungeon_merchant", "greeting")`
- `script/dungeon.gd:114` — `DialogueManager.force_close()`

Godot autoload identifiers are case-sensitive. With this mismatch, every call site will fail at parse-time with "Identifier 'DialogueManager' not declared in the current scope." The plans (02-01, 02-02, 02-03, 02-04) repeatedly state PascalCase access should work because of "the registered name", but the actual `[autoload]` keys are lowercase. This is not theoretical — it is a hard parse error that blocks the entire phase from running.

This contradicts even the project's own existing convention: `script/global.gd` is registered as `global` (lowercase) and accessed everywhere as `global.foo` (e.g. `global.npc_state`, `global.current_floor`). The dialogue code is the only outlier reaching for PascalCase access.

**Fix:** Either (a) rename the autoload registrations to PascalCase to match the code, OR (b) rewrite all five call sites to use lowercase, matching the existing `global.` convention. Option (b) is consistent with the rest of the codebase and the research recommendations (RESEARCH.md says NPCs call `DialogueManager.open()` but the conventions section shows `global` access pattern is lowercase).

Option B (recommended — matches `global` autoload convention):

```gdscript
# project.godot — leave as-is (already lowercase)

# script/dialogue_manager.gd:138
var node := dialogue_data.get_node(_current_npc, _current_node)

# script/npc.gd:51
dialogue_manager.open("elder", start)

# script/dungeon_dialogue_npc.gd:40
dialogue_manager.open("dungeon_merchant", "greeting")

# script/dungeon.gd:114
dialogue_manager.force_close()
```

(If renaming the autoload keys to PascalCase instead, also update the references in plan summary docs that grep for the literal strings.)

---

### CR-02: `dialogue_data.gd` overrides `Node.get_node()` with an incompatible signature

**File:** `script/dialogue_data.gd:1, 65-68`
**Issue:** `dialogue_data.gd` declares `extends Node`, and then defines:

```gdscript
func get_node(npc_id: String, node_id: String) -> Dictionary:
    if DIALOGUES.has(npc_id) and DIALOGUES[npc_id].has(node_id):
        return DIALOGUES[npc_id][node_id]
    return {}
```

This **shadows** the engine-provided `Node.get_node(path: NodePath) -> Node`. Two failure modes:

1. **Editor warning / crash on autoload init.** Godot's parser will at minimum warn ("function 'get_node' is shadowing a virtual function from base class"), and on some Godot 4.x point releases will refuse to load the autoload entirely.
2. **Any internal engine call** that does `dialogue_data_singleton.get_node(...)` (the engine, plugin, or even tooling like `editor_screenshot` paths that walk autoload nodes) will now receive a `Dictionary` instead of a `Node` and crash on `.queue_free()` / `.get_path()` etc.

Even if Godot 4.6 currently allows the override, the call signature mismatch (`String, String` vs `NodePath`) is fragile — any caller passing a single argument like `dialogue_data.get_node("foo")` raises an arg-count error at runtime.

**Fix:** Rename the lookup function so it does not collide with `Node.get_node`:

```gdscript
# script/dialogue_data.gd
func get_dialogue_node(npc_id: String, node_id: String) -> Dictionary:
    if DIALOGUES.has(npc_id) and DIALOGUES[npc_id].has(node_id):
        return DIALOGUES[npc_id][node_id]
    return {}
```

Then update the only caller:

```gdscript
# script/dialogue_manager.gd:138
var node := dialogue_data.get_dialogue_node(_current_npc, _current_node)
```

Alternatively, change `extends Node` to `extends Object` if the autoload truly does not need to be a node — but autoload nodes are added to the SceneTree, so `Object` will not work as a registered autoload. Renaming the function is the only correct fix.

---

### CR-03: `pause_menu` and `dialogue_manager` clobber each other's `get_tree().paused` state

**File:** `script/pause_menu.gd:19-29, 35-38`, `script/dialogue_manager.gd:111-133`
**Issue:** Both autoloads write `get_tree().paused` directly with no coordination, and `pause_menu._unhandled_input` is gated only on `global.current_scene == "home"`, not on whether the dialogue is currently open. Two concrete failure scenarios:

**Scenario A — Pause stomps dialogue:**
1. Player opens dialogue. `dialogue_manager.open()` sets `_panel.visible = true` and `paused = true`.
2. Player presses ESC. `pause_menu._unhandled_input` fires (its CanvasLayer is also `PROCESS_MODE_ALWAYS`), sees neither save nor pause panel visible, calls `_open_pause()`.
3. Now BOTH the dialogue panel (layer 30) and pause panel (layer 50) are visible. Pause panel renders on top, dialogue panel still consumes input space and remains paused.
4. Player clicks "Resume" → `_resume()` runs `get_tree().paused = false` while dialogue is still open. Dialogue panel is now visible but the world is unpaused — enemies move, the player can move and walk away from the NPC, but the dialogue overlay is still drawn forever.

**Scenario B — Dialogue close after pause:**
1. Player opens pause menu first. `paused = true`, pause overlay visible.
2. (Hypothetically — if the timing aligns with an NPC interact already in flight, or via a future entry point) dialogue opens, `paused = true` (no-op).
3. Player advances and closes dialogue. `dialogue_manager.close()` runs `paused = false`.
4. Pause panel still visible but world is unpaused — same broken state.

The research file (`02-RESEARCH.md` line 247–248) anticipates this: *"Dialogue and pause cannot be open simultaneously (pause closes dialogue; dialogue prevents pause input)."* — but neither rule is enforced in code. There is no check in `pause_menu._unhandled_input` for `dialogue_manager._panel.visible`, and there is no check in `dialogue_manager.open()` for `pause_menu._pause_panel.visible`.

**Fix:** Make the two systems mutually aware. Cheapest correct fix: gate `pause_menu._unhandled_input` on dialogue not being open, and accept the input there.

```gdscript
# script/pause_menu.gd — _unhandled_input
func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.is_action_pressed("ui_cancel"):
        return
    if global.current_scene == "home":
        return
    # Defer to dialogue if it owns the pause state.
    if dialogue_manager._panel != null and dialogue_manager._panel.visible:
        return
    if _save_panel.visible:
        _save_panel.visible = false
    elif _pause_panel.visible:
        _resume()
    else:
        _open_pause()
```

And symmetric defense in dialogue:

```gdscript
# script/dialogue_manager.gd — open()
func open(npc_id: String, start_node: String = "root") -> void:
    if pause_menu._pause_panel != null and pause_menu._pause_panel.visible:
        return
    _current_npc = npc_id
    ...
```

(Both checks rely on the case-fix from CR-01.)

## Warnings

### WR-01: NPC `_process()` polling does not guard against dialogue already being open

**File:** `script/npc.gd:38-51`, `script/dungeon_dialogue_npc.gd:38-40`
**Issue:** Both NPCs poll `Input.is_action_just_pressed("interact")` in `_process()`. The NPCs are nodes in the regular scene tree (default `PROCESS_MODE_INHERIT`), so their `_process` does NOT run while `get_tree().paused == true`. That part is fine.

But there is still a 1-frame race: `dialogue_manager.close()` runs `paused = false` first, then clears state. The frame *after* close, the NPC's `_process` resumes — and if the player is still inside the Area2D, `player_nearby` is still `true`, and if the player is still holding E... `Input.is_action_just_pressed` only fires on the press edge so this specific case is safe.

**However**, the dungeon merchant case has another problem: `dungeon_dialogue_npc.gd:38-40` lacks the `is_instance_valid(player_ref)` check that `npc.gd:39` has via `_process(_delta)`. Wait — actually `dungeon_dialogue_npc.gd:39` does have `is_instance_valid(player_ref)`. But it has no `shop_open` guard either way (no shop in the dungeon, so this is fine for now), and crucially:

The real issue: pressing E twice rapidly (once to open dialogue, then dialogue advances on the next E press, then if the player walks out of the area2D mid-dialogue, comes back, and presses E again, `dialogue_manager._panel.visible` is true but `npc._process` will still call `dialogue_manager.open(...)` again — re-entering the conversation from `start_node` and overwriting `_current_node`/`_next_node` mid-flight.

**Fix:** Guard NPC trigger against an already-open dialogue:

```gdscript
# script/npc.gd:38
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if not is_instance_valid(player_ref):
            return
        # Don't re-open dialogue if one is already up
        if dialogue_manager._panel != null and dialogue_manager._panel.visible:
            return
        if player_ref.shop_open:
            player_ref.open_shop()
            return
        ...

# script/dungeon_dialogue_npc.gd:38
func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        if dialogue_manager._panel != null and dialogue_manager._panel.visible:
            return
        dialogue_manager.open("dungeon_merchant", "greeting")
```

A cleaner version exposes a public `is_open() -> bool` on `dialogue_manager` instead of poking `_panel.visible`.

---

### WR-02: `var_to_str(npc_state)` save/load round-trip — empty-dict guard does not match real serialized output

**File:** `script/global.gd:91, 110-113`
**Issue:** Save:

```gdscript
cfg.set_value("dialogue", "npc_state", var_to_str(npc_state))
```

For `npc_state = {}`, `var_to_str({})` returns the literal string `"{ }"` (with a space) — not `"{}"`. Then on load:

```gdscript
var raw := cfg.get_value("dialogue", "npc_state", "{}")
npc_state = str_to_var(raw) if raw != "{}" else {}
```

The default `"{}"` (used when the key is missing on disk, e.g. old saves) compares fine. But after a real `save_to_slot()` writes `"{ }"` (or any populated dict text), `raw != "{}"` is true and `str_to_var(raw)` runs. Pitfall 5 in RESEARCH.md (line 339-343) explicitly warns about `str_to_var("{}")` returning null — but that pitfall is about the literal `"{}"` reaching `str_to_var`, which **never happens** here because the literal `"{}"` triggers the early return. The actual risk is the inverse:

`str_to_var(var_to_str({}))` → may return `{}` correctly, OR may return `null` depending on Godot 4.6 build. The follow-up null-guard `if npc_state == null: npc_state = {}` (line 112-113) does catch this — so this specific bug is actually defended against, but **only** by the redundant null-guard, not by the `raw != "{}"` early return as the comment implies.

The real defect: the early-return comparison is dead code in practice (real saves never produce `"{}"`), so it gives a false sense of safety. More importantly, **arrays vs strings**: if a future schema change adds an array to a value, `var_to_str` includes type-prefixes that may bite later. The current code works only because of the trailing null-guard.

**Fix:** Drop the brittle string comparison and rely on the null-guard, which is the actual defense:

```gdscript
# script/global.gd:110-113
var raw := cfg.get_value("dialogue", "npc_state", "")
var parsed = str_to_var(raw) if raw != "" else null
npc_state = parsed if (parsed is Dictionary) else {}
```

This handles three failure modes uniformly: missing key (default `""`), empty/whitespace string, and `str_to_var` returning a non-Dictionary.

---

### WR-03: `dialogue_manager._unhandled_input` does not call `accept_event()` — input bleeds to player

**File:** `script/dialogue_manager.gd:182-194`
**Issue:** `_unhandled_input` reacts to the `interact` action while the dialogue panel is visible, but does not call `get_viewport().set_input_as_handled()` (or `accept_event()` for older Godot). On the same frame the dialogue advances, that same `interact` press also reaches:

- `npc.gd:39` (if still in the Area2D — which the player IS, since dialogue just opened from this NPC)
- `dungeon_dialogue_npc.gd:39` (in dungeon)
- Any other `Input.is_action_just_pressed("interact")` poll

`Input.is_action_just_pressed` reads the global input state, NOT the consumed-event state — so it fires regardless. Combined with WR-01, this means: each E press during dialogue advances the dialogue AND also tries to re-trigger the NPC. Currently masked because `_process` runs after `_unhandled_input` and by then `_panel.visible` is still true → with WR-01's fix that is fine; without it, every advance press re-opens the dialogue from `start_node`, resetting the conversation.

The masking is fragile. Even with WR-01 applied, accepting the event is the canonical fix.

**Fix:**

```gdscript
# script/dialogue_manager.gd:182
func _unhandled_input(event: InputEvent) -> void:
    if not _panel.visible:
        return
    if not (event is InputEventKey):
        return
    if not event.is_action_pressed("interact"):
        return
    if _advance_lbl.visible:
        get_viewport().set_input_as_handled()
        if _next_node.is_empty():
            close()
        else:
            _current_node = _next_node
            _render_node()
```

(Also good to consume the event on `ui_cancel` if the dialogue ever supports cancel, to prevent ESC reaching pause_menu.)

---

### WR-04: `npc.gd._process` calls `player_ref.shop_open` before `is_instance_valid(player_ref)` check

**File:** `script/npc.gd:38-44`
**Issue:**

```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if not is_instance_valid(player_ref):
            return
        # Guard: if shop is already open, pressing E closes it
        if player_ref.shop_open:
            ...
```

The `is_instance_valid` check is placed correctly. But on line 49, `start := "greeting"` followed by `var state: Dictionary = global.npc_state.get("elder", {})` — the `state` variable is fine. The deeper issue is that `_on_body_exited` clears `player_ref = null` (line 62), but if the player frees / queue_frees mid-dialogue (via death, scene reload, etc.), `_on_body_exited` may not fire on the freed body, leaving `player_ref` as a stale reference until the next exit event. `is_instance_valid` catches this — that part is fine.

The ACTUAL latent bug: in `dungeon_dialogue_npc.gd:39`, the NPC and player are both in the dungeon scene. When the floor advances (`reload_current_scene`), the NPC's signal handlers may not fire `_on_body_exited` cleanly during teardown. Combined with `force_close()` (which already runs), the next floor's NPC instance has fresh state, so this is currently safe. But the asymmetry — `npc.gd` has the shop guard, `dungeon_dialogue_npc.gd` does not check anything — is a maintenance trap.

**Fix:** None strictly required for correctness. Recommend extracting a small helper or convention so all NPCs follow the same guard pattern:

```gdscript
# Standard NPC dispatch guard
if not is_instance_valid(player_ref):
    return
if dialogue_manager._panel != null and dialogue_manager._panel.visible:
    return  # WR-01 fix
```

---

### WR-05: `DIALOGUES.elder.quest_offer.next` is `""` while choices array is non-empty — schema ambiguity

**File:** `script/dialogue_data.gd:21-29`
**Issue:**

```gdscript
"quest_offer": {
    "speaker": "Elder",
    "text": "Will you venture to floor 10 for me? ...",
    "next": "",
    "choices": [
        {"label": "Accept Quest", "next": "quest_accepted", ...},
        {"label": "Decline Quest", "next": "quest_declined", ...}
    ]
},
```

The schema (per RESEARCH.md "Schema fields") says `next` is the advance-only target; `choices[]` is the multi-button branching. When `choices` is non-empty, `_render_node` (line 153-163) ignores `next` and uses choice buttons. So `"next": ""` here is dead data, but harmless.

However, `_render_node:152` reads `_next_node = node.get("next", "")` only on the advance-only branch (line 149). On the choices branch (line 156) it sets `_next_node = ""`. So the current code is internally consistent. The risk is that a future contributor adds a "next" handler thinking it is meaningful for choice nodes.

**Fix:** Either omit the `"next"` field entirely on choice nodes, or document that it is ignored:

```gdscript
"quest_offer": {
    "speaker": "Elder",
    "text": "...",
    # "next" omitted: choice nodes use only the choices[] array.
    "choices": [...]
},
```

---

### WR-06: `dialogue_manager._render_node` uses untyped `for choice in choices:` over `Array` — silent type drift

**File:** `script/dialogue_manager.gd:148, 157-163`
**Issue:**

```gdscript
var choices: Array = node.get("choices", [])
...
for choice in choices:
    var btn := _pa(Button.new()) as Button
    btn.text = choice.get("label", "")
    ...
    btn.pressed.connect(_on_choice_picked.bind(choice))
```

`choices` is typed `Array` (untyped element), `choice` falls back to `Variant`. If a malformed dialogue node has `"choices": "not-an-array"` (e.g. typo), `node.get("choices", [])` returns the string and the for-loop iterates per character, calling `.get("label")` on a String which raises at runtime. Similarly `choice.get("label", "")` on a non-Dictionary raises.

The data is currently authored by hand in `dialogue_data.gd`, so this is theoretical — but the dialogue tree is documented as "user-extensible" in the research, and DLG-V2-01 (visual editor) plus future quest content will add nodes by less-careful contributors.

**Fix:** Defensive type checks:

```gdscript
var choices_raw = node.get("choices", [])
var choices: Array = choices_raw if choices_raw is Array else []
...
for choice in choices:
    if not (choice is Dictionary):
        continue
    ...
```

## Info

### IN-01: `dialogue_data.gd` is registered as `dialogue_data` autoload but file pattern matches `class_name`-style

**File:** `script/dialogue_data.gd:1-12`
**Issue:** The file is documented as accessed via `DialogueData.get_node(...)` but is registered as lowercase. Not a defect on its own, just an example of the same naming inconsistency from CR-01 leaking into source comments. Update the doc-comment after CR-01 fix.

**Fix:** After CR-01 is resolved, line 4 comment should match the actual identifier in use.

---

### IN-02: `_on_choice_picked` has no validation on `_current_npc` being non-empty before mutating `global.npc_state`

**File:** `script/dialogue_manager.gd:165-177`
**Issue:**

```gdscript
func _on_choice_picked(choice: Dictionary) -> void:
    var action: String = choice.get("action", "")
    if action == "quest_offer":
        var qid: String = choice.get("quest_id", "")
        if not global.npc_state.has(_current_npc):
            global.npc_state[_current_npc] = {}
        global.npc_state[_current_npc]["quest_accepted_" + qid] = true
```

If `_current_npc` is `""` (e.g. someone calls `open("", "node")` or a race after `close()`), the empty-string key gets a quest entry. If `qid == ""`, the key becomes `"quest_accepted_"` which is meaningless but persists across saves.

**Fix:** Validate before writing:

```gdscript
if action == "quest_offer":
    var qid: String = choice.get("quest_id", "")
    if _current_npc.is_empty() or qid.is_empty():
        push_warning("dialogue_manager: quest_offer action with empty npc/quest_id; skipping")
    else:
        if not global.npc_state.has(_current_npc):
            global.npc_state[_current_npc] = {}
        global.npc_state[_current_npc]["quest_accepted_" + qid] = true
```

---

### IN-03: Magic number `layer = 30` lacks named constant

**File:** `script/dialogue_manager.gd:20`
**Issue:** `layer = 30` is an important architectural decision (between shop=20 and pause=50) but is a bare integer literal. The other CanvasLayers in the project (`layer = 5`, `10`, `20`, `50`) have the same problem. Phase 2 introduces another. RESEARCH.md table (line 240-245) is the only place documenting this.

**Fix (optional polish):** Either accept the project convention (bare integers everywhere) or introduce constants in `global.gd`:

```gdscript
# script/global.gd
const LAYER_HUD := 10
const LAYER_SHOP := 20
const LAYER_DIALOGUE := 30
const LAYER_PAUSE := 50
```

Low priority; do not block on this.

---

### IN-04: `dungeon.gd:114` calls `force_close()` but the code path also unpauses on scene reload

**File:** `script/dungeon.gd:106-115`
**Issue:**

```gdscript
func _check_next_floor() -> void:
    if not global.next_floor:
        return
    global.next_floor = false
    if global.current_floor >= global.DUNGEON_MAX_FLOOR:
        _exit_to_cliffside(1)
        return
    global.current_floor += 1
    DialogueManager.force_close()
    get_tree().reload_current_scene()
```

The `force_close()` call mitigates the documented threat T-2D-01 (paused-tree leak). However, `_exit_to_cliffside(1)` on line 111 (the FINAL floor branch) takes a different path that does NOT call `force_close()`. Per SUMMARY 02-04 "Implementation Notes", this is intentional because `change_scene_to_file` rebuilds the tree. But:

- If dialogue is open when `_exit_to_cliffside` is called from the FINAL-floor branch, `dialogue_manager` (autoload, persists across scenes) still holds `_panel.visible = true`, `_current_npc`, `_current_node` — not state-clearing.
- More importantly, `change_scene_to_file` does NOT reset `get_tree().paused`. If the dialogue paused the tree, the new scene will boot paused.

The plan summary claims "the fresh scene starts unpaused" which is **incorrect** for `change_scene_to_file`. `paused` is on the SceneTree itself, not the root scene — it persists across `change_scene_to_file`.

**Fix:** Add the same `force_close()` guard to `_exit_to_cliffside` to be safe:

```gdscript
func _exit_to_cliffside(resume_floor: int) -> void:
    DialogueManager.force_close()  # NEW: defense against paused-tree leak
    global.dungeon_resume_floor = clampi(resume_floor, 1, global.DUNGEON_MAX_FLOOR)
    ...
```

(After CR-01 fix this becomes `dialogue_manager.force_close()`.)

---

_Reviewed: 2026-05-09T10:23:00-07:00_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
