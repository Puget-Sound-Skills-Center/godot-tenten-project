---
phase: 2
plan_id: "02-PLAN-C"
wave: 2
depends_on:
  - "02-PLAN-B"
files_modified:
  - script/npc.gd
requirements_addressed:
  - DLG-01
  - DLG-02
  - DLG-03
  - DLG-04
autonomous: true
nyquist_compliant: false
---

# Plan C — Wave 2: Wire NPC Interaction (npc.gd → DialogueManager)

<objective>
Modify `script/npc.gd` to trigger dialogue on interact, implement NPC memory (different
start_node on repeat visit), and confirm the quest offer/decline flow is reachable from the
world shop NPC.

The shop NPC (`npc.gd`) currently only opens the shop. After this plan it will:
1. Open dialogue (`DialogueManager.open("elder", start_node)`) on interact — guarded so it
   does NOT trigger when the shop is already open.
2. Select the correct `start_node` based on `global.npc_state["elder"]` — showing follow-up
   dialogue after the quest has been accepted.
3. The dialogue tree in `dialogue_data.gd` already has the quest_offer node with 2 choices
   (Accept / Decline) created in Plan B. This plan verifies the wiring is complete end-to-end.

Purpose: DLG-01, DLG-02, DLG-03, DLG-04 all require the world NPC to be fully wired.
Output: Modified `script/npc.gd` with dialogue trigger + npc_state state check.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@D:/Unity/godot-tenten-project/.planning/ROADMAP.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-RESEARCH.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-PATTERNS.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-B-SUMMARY.md

<interfaces>
<!-- Contracts from Plan B outputs -->

From script/dialogue_manager.gd (created in Plan B):
```gdscript
func open(npc_id: String, start_node: String) -> void
func close() -> void
func force_close() -> void
```

From script/global.gd (Plan A):
```gdscript
var npc_state: Dictionary = {}
# runtime structure: { "elder": {"quest_accepted_reach_floor_10": true} }
```

From script/dialogue_data.gd (Plan B) — node IDs for "elder" NPC:
  "greeting"       — first visit
  "quest_offer"    — leads to 2-choice branch (Accept / Decline)
  "quest_accepted" — after accepting
  "quest_declined" — after declining
  "quest_follow_up"— shown on repeat visit after quest accepted

From script/npc.gd (current, lines 38-41) — existing _process() to extend:
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            player_ref.open_shop()
```
</interfaces>
</context>

<tasks>

<task id="2-C-01-03" type="execute">
  <title>Replace npc.gd _process() to open dialogue with npc_state start_node selection</title>
  <read_first>
    - script/npc.gd — read entire file (54 lines) to see current _process() at lines 38-41
      and confirm player_ref.shop_open is the flag name used in player.gd
    - script/player.gd — search for "shop_open" to confirm the exact flag name and that it
      is a public var (not underscore-prefixed)
    - .planning/phases/02-dialogue-system/02-PATTERNS.md — "script/npc.gd MODIFY" section,
      specifically the "Extended _process() with dialogue guard" pattern
  </read_first>
  <action>
Replace the existing `_process()` function in `script/npc.gd` (lines 38-41) with the
extended version below. Do not touch any other function.

**Current code to replace** (lines 38-41):
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if is_instance_valid(player_ref) and player_ref.has_method("open_shop"):
            player_ref.open_shop()
```

**Replacement** — preserves shop behavior, adds dialogue trigger with guard:
```gdscript
func _process(_delta):
    if player_nearby and Input.is_action_just_pressed("interact"):
        if not is_instance_valid(player_ref):
            return
        # Guard: if shop is already open, pressing E closes it (existing behavior)
        if player_ref.shop_open:
            player_ref.open_shop()
            return
        # Dialogue trigger — select start_node based on quest state (DLG-03)
        var start := "greeting"
        var state: Dictionary = global.npc_state.get("elder", {})
        if state.get("quest_accepted_reach_floor_10", false):
            start = "quest_follow_up"
        DialogueManager.open("elder", start)
```

Explanation of logic:
- `player_ref.shop_open` check: if true, the player pressed E to toggle the shop — let the
  shop handle it and return. If false, open dialogue instead.
- `global.npc_state.get("elder", {})` returns an empty dict (not null) if the elder key
  doesn't exist yet, so `.get("quest_accepted_reach_floor_10", false)` is safe.
- `start = "quest_follow_up"` only when the quest has been accepted (flag set by
  DialogueManager._on_choice_picked when player chose "Accept Quest").
- `DialogueManager.open("elder", start)` is the only line that needs to change to add more
  dialogue state branches — the dialogue data handles the rest.

Do NOT modify `_build_visual()`, `_build_interaction_area()`, `_on_body_entered()`, or
`_on_body_exited()`. Only `_process()` changes.
  </action>
  <acceptance_criteria>
    - `grep -n "DialogueManager.open" "D:/Unity/godot-tenten-project/script/npc.gd"` returns
      1 match containing `DialogueManager.open("elder", start)`
    - `grep -n "interact" "D:/Unity/godot-tenten-project/script/npc.gd"` returns at least
      1 match (the is_action_just_pressed line)
    - `grep -n "npc_state" "D:/Unity/godot-tenten-project/script/npc.gd"` returns at least
      1 match (the state variable assignment from global.npc_state)
    - `grep -n "shop_open" "D:/Unity/godot-tenten-project/script/npc.gd"` returns 1 match
      (the guard that prevents opening dialogue while shop is open)
    - `grep -n "quest_follow_up" "D:/Unity/godot-tenten-project/script/npc.gd"` returns
      1 match (the repeat-visit branch)
    - `grep -n "open_shop" "D:/Unity/godot-tenten-project/script/npc.gd"` returns 1 match
      (shop behavior preserved in the guard branch)
  </acceptance_criteria>
</task>

<task id="2-C-04-verify" type="execute">
  <title>Verify quest offer/decline paths in dialogue_data.gd are complete and reachable</title>
  <read_first>
    - script/dialogue_data.gd — read the full "elder" dialogue tree to confirm:
        (a) "quest_offer" node has choices array with exactly 2 entries
        (b) first choice has action="quest_offer" and quest_id="reach_floor_10"
        (c) second choice has a non-empty "next" pointing to "quest_declined"
        (d) "quest_declined" node exists with non-empty text
    - script/dialogue_manager.gd — read _on_choice_picked to confirm quest_offer action
      handling writes the correct key to global.npc_state
  </read_first>
  <action>
This task verifies the DLG-04 flow is complete. No new code should be needed if Plan B was
implemented correctly. Run the grep checks below. If any are missing, make targeted edits
to `script/dialogue_data.gd` only.

**Required state of dialogue_data.gd "elder" tree:**

The "quest_offer" node must have exactly this structure:
```gdscript
"quest_offer": {
    "speaker": "Elder",
    "text": "Will you venture to floor 10 for me? The answers I seek lie in its depths.",
    "next": "",
    "choices": [
        {"label": "Accept Quest", "next": "quest_accepted", "action": "quest_offer", "quest_id": "reach_floor_10"},
        {"label": "Decline Quest", "next": "quest_declined", "action": ""}
    ]
},
```

The "quest_declined" node must exist with non-empty text so declining leads to a valid node:
```gdscript
"quest_declined": {
    "speaker": "Elder",
    "text": "Perhaps another time. I will wait.",
    "next": "",
    "choices": []
},
```

**Required state of dialogue_manager.gd _on_choice_picked:**
```gdscript
if action == "quest_offer":
    var qid: String = choice.get("quest_id", "")
    if not global.npc_state.has(_current_npc):
        global.npc_state[_current_npc] = {}
    global.npc_state[_current_npc]["quest_accepted_" + qid] = true
```

The key written is `"quest_accepted_reach_floor_10"` (concatenation of "quest_accepted_" + qid).
This is the EXACT key that npc.gd checks: `state.get("quest_accepted_reach_floor_10", false)`.
If there is a mismatch between the key written here and the key checked in npc.gd, the NPC
memory feature (DLG-03) will silently fail. Verify they match.

If any of the above is missing or mismatched, make the minimal edit to fix it. Do not
restructure the file.
  </action>
  <acceptance_criteria>
    - `grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      at least 2 matches (node key + action field value)
    - `grep -n "quest_declined" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      at least 2 matches (the "Decline Quest" next field + the node key itself)
    - `grep -n "Decline Quest" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"` returns
      1 match (the decline button label)
    - `grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns
      at least 1 match inside _on_choice_picked
    - `grep -n "quest_accepted_" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"` returns
      1 match (the concatenation that writes the flag key)
    - `grep -n "quest_accepted_reach_floor_10" "D:/Unity/godot-tenten-project/script/npc.gd"` returns
      1 match (npc.gd checks this exact key for DLG-03)
  </acceptance_criteria>
</task>

</tasks>

<verification>
  <grep_checks>
    <!-- AC from VALIDATION.md task map — 2-C-01 through 2-C-04 -->
    grep -n "DialogueManager.open" "D:/Unity/godot-tenten-project/script/npc.gd"
    grep -n "npc_state" "D:/Unity/godot-tenten-project/script/npc.gd"
    grep -n "\"choices\"" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"
    grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_data.gd"
    grep -n "quest_offer" "D:/Unity/godot-tenten-project/script/dialogue_manager.gd"
  </grep_checks>
  <must_haves>
    <truths>
      - Player walks up to the world NPC, presses E — dialogue panel opens (game pauses,
        panel appears with "Elder" name and greeting text)
      - Player walks up while shop is already open, presses E — shop closes, NOT dialogue
        (shop_open guard fires)
      - Dialogue reaches "quest_offer" node showing 2 buttons: "Accept Quest" / "Decline Quest"
      - Clicking "Accept Quest" writes `global.npc_state["elder"]["quest_accepted_reach_floor_10"] = true`
        and advances to "quest_accepted" node
      - Clicking "Decline Quest" advances to "quest_declined" node (different text from accept)
      - After accepting quest and closing dialogue, pressing E again opens dialogue at
        "quest_follow_up" node (not "greeting") — DLG-03 NPC memory working
    </truths>
  </must_haves>
</verification>

<threat_model>
  <!-- ASVS L1 — local single-player Godot game -->

  | Threat ID | Category | Component | Disposition | Mitigation |
  |-----------|----------|-----------|-------------|------------|
  | T-2C-01 | Denial of Service | npc.gd _process() guard | mitigate | `not is_instance_valid(player_ref)` early return prevents null-ref crash if player_ref becomes stale |
  | T-2C-02 | Tampering | npc_state key mismatch (npc.gd vs dialogue_manager.gd) | mitigate | Acceptance criteria 2-C-04 explicitly grep-checks that npc.gd checks "quest_accepted_reach_floor_10" and dialogue_manager.gd writes the same key |
  | T-2C-03 | Tampering | shop_open + dialogue both active | mitigate | `if player_ref.shop_open: ... return` guard prevents dual-open state; shop does not call get_tree().paused so there is no pause conflict from shop side |
</threat_model>

<success_criteria>
- script/npc.gd _process() calls DialogueManager.open("elder", start) on interact
- shop_open guard present: shop_open == true routes to open_shop(), returns before dialogue
- npc_state check selects "quest_follow_up" after quest accepted, "greeting" otherwise
- "quest_offer" node in dialogue_data.gd has 2 choices with correct action/quest_id fields
- "quest_declined" node exists and has non-empty text
- Key written by dialogue_manager._on_choice_picked ("quest_accepted_reach_floor_10") matches
  key read by npc.gd state check — DLG-03 memory loop is closed
</success_criteria>

<output>
After completion, create `.planning/phases/02-dialogue-system/02-C-SUMMARY.md`
</output>
