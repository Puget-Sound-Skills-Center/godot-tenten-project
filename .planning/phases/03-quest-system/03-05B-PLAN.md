---
phase: 03-quest-system
plan: 05B
type: execute
wave: 3
depends_on: [01, 02, 03]
files_modified:
  - script/dialogue_data.gd
autonomous: true
requirements: [QST-01, QST-02, QST-03, QST-04]
must_haves:
  truths:
    - "dialogue_data.gd contains all required quest_offer / quest_accepted / quest_declined / quest_complete / story_chain_* nodes for elder, blacksmith, dungeon_merchant"
    - "Elder greeting node has `\"next\": \"\"` — offers are reached only via npc.gd _select_start_node routing, not auto-advance"
    - "All 3 quest offer nodes (kill, fetch, story_chain) have 2-choice arrays with quest_offer action and quest_id"
    - "All quest complete nodes have a single choice with quest_complete action and quest_id"
    - "3-quest cap nodes present for both elder (quest_cap_reached) and blacksmith (kill_quest_cap_reached)"
  artifacts:
    - path: "script/dialogue_data.gd"
      provides: "All Phase 3 dialogue nodes (kill / fetch / story chain trees for 3 NPCs)"
      contains: "\"blacksmith\":"
  key_links:
    - from: "dialogue_data.DIALOGUES[\"blacksmith\"][\"kill_quest_offer\"] choice action=quest_offer"
      to: "quest_manager.accept_quest (via dialogue_manager._on_choice_picked, Plan 03)"
      via: "action dispatch wired in Plan 03"
      pattern: "\"action\": \"quest_offer\", \"quest_id\": \"kill_melee_10\""
    - from: "dialogue_data.DIALOGUES choice action=story_chain_advance"
      to: "quest_manager.advance_story_chain (via dialogue_manager._on_choice_picked)"
      via: "action dispatch from Plan 03"
      pattern: "\"action\": \"story_chain_advance\""
---

<objective>
Author all Phase 3 dialogue nodes in dialogue_data.gd: elder additions (8 new nodes + greeting fix), full blacksmith NPC tree (8 nodes), and dungeon_merchant additions (2 nodes). Runs in parallel with Plan 05 (same wave 3).

Purpose: Plan 05 wires NPC behavioral routing that references these node IDs. This plan provides the actual dialogue content. Both plans must complete before the full quest flow is testable.

Output: One modified file (dialogue_data.gd) — +19 dialogue nodes across 3 NPCs.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project-main/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project-main/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/03-quest-system/03-CONTEXT.md
@.planning/phases/03-quest-system/03-RESEARCH.md
@.planning/phases/03-quest-system/03-PATTERNS.md
@.planning/phases/03-quest-system/03-UI-SPEC.md
@CLAUDE.md
@script/dialogue_data.gd
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Add all Phase 3 dialogue nodes to dialogue_data.gd (elder additions, full blacksmith, dungeon_merchant additions)</name>
  <files>script/dialogue_data.gd</files>
  <read_first>
    - script/dialogue_data.gd (full file — existing schema for "elder", "dungeon_merchant"; choice schema at lines 21-28)
    - .planning/phases/03-quest-system/03-RESEARCH.md (lines 149-202 — required dialogue nodes per NPC; lines 537-559 — story chain narrative copy)
    - .planning/phases/03-quest-system/03-PATTERNS.md (lines 519-550 — schema for new choice nodes with quest actions)
    - .planning/phases/03-quest-system/03-UI-SPEC.md (Copywriting Contract for any visible quest text)
  </read_first>
  <behavior>
    - For NPC "elder": MODIFY the existing "greeting" node so `"next": ""` (currently `"next": "quest_offer"` — auto-advance is removed so offers are reached only via npc.gd's _select_start_node routing, preventing orphan-offer nodes)
    - For NPC "elder": add 8 new nodes — fetch_quest_offer, fetch_quest_accepted, fetch_quest_declined, fetch_quest_complete, story_chain_offer, story_chain_accepted, story_chain_declined, reach_floor_complete
    - For NPC "elder": also add a new "quest_cap_reached" node (text: "I have no new quests for you right now.") used when active_quest_count() >= 3
    - For NPC "blacksmith" (entirely new top-level key): add 8 nodes — kill_quest_offer, kill_quest_accepted, kill_quest_declined, kill_quest_complete, kill_quest_followup, kill_quest_cap_reached, story_chain_step1, story_chain_step1_done
    - For NPC "dungeon_merchant": add 2 new nodes — story_chain_step2, story_chain_complete
    - All offer nodes contain a 2-choice array: Accept (action=quest_offer with quest_id) / Decline
    - kill_quest_complete and fetch_quest_complete contain a single advance choice (action=quest_complete with quest_id)
    - story_chain_step1 contains a single advance choice (action=story_chain_advance, no quest_id needed)
    - story_chain_step2 contains a single advance choice (action=quest_complete, quest_id=story_chain) — the dungeon_merchant is the final NPC
    - kill_quest_cap_reached AND elder quest_cap_reached have no choices (`"choices": []`) and "next": "" — dialogue closes after one line
    - quest_cap_reached text per UI-SPEC: "I have no new quests for you right now."
  </behavior>
  <action>
Open script/dialogue_data.gd. The file currently contains:
```gdscript
extends Node
const DIALOGUES := {
    "elder": { ... existing nodes ... },
    "dungeon_merchant": { ... existing nodes ... },
}
```

### Modify "elder" — (a) change "greeting" node, (b) add 9 new nodes

#### (a) MODIFY existing "greeting" node
Locate the existing elder "greeting" entry. It currently reads:
```gdscript
"greeting": {
    "speaker": "Elder",
    "text": "Welcome, adventurer. The dungeon grows darker each day.",
    "next": "quest_offer",
    "choices": []
},
```
Change the `"next"` field from `"quest_offer"` to `""` (empty string). Result:
```gdscript
"greeting": {
    "speaker": "Elder",
    "text": "Welcome, adventurer. The dungeon grows darker each day.",
    "next": "",
    "choices": []
},
```
WHY: The npc.gd _select_start_node (Plan 05 Task 3) routes the player directly to fetch_quest_offer / story_chain_offer / quest_offer based on quest state. If greeting keeps next="quest_offer", it always auto-advances to the reach_floor offer — making fetch and story_chain offer nodes unreachable (orphans). With next="" the greeting closes after one line; offers are reached only when the selector picks them.

#### (b) Append 9 new entries (each terminated with a comma) inside the elder dict:

```gdscript
		"fetch_quest_offer": {
			"speaker": "Elder",
			"text": "I lost an Ancient Relic Fragment deep in the dungeon. Will you bring it back?",
			"next": "",
			"choices": [
				{"label": "Accept", "next": "fetch_quest_accepted", "action": "quest_offer", "quest_id": "fetch_ancient_relic"},
				{"label": "Decline", "next": "fetch_quest_declined", "action": ""}
			]
		},
		"fetch_quest_accepted": {
			"speaker": "Elder",
			"text": "Search the dungeon depths. The Fragment will glow faintly when nearby.",
			"next": "",
			"choices": []
		},
		"fetch_quest_declined": {
			"speaker": "Elder",
			"text": "Very well. The Fragment will wait.",
			"next": "",
			"choices": []
		},
		"fetch_quest_complete": {
			"speaker": "Elder",
			"text": "You found it! Take this gold — it's the least I can offer.",
			"next": "",
			"choices": [
				{"label": "(Hand over the Fragment)", "next": "", "action": "quest_complete", "quest_id": "fetch_ancient_relic"}
			]
		},
		"story_chain_offer": {
			"speaker": "Elder",
			"text": "I've lost something precious — an Ancient Map Fragment. The Blacksmith near the forge may know who took it. Will you help me find it?",
			"next": "",
			"choices": [
				{"label": "Accept", "next": "story_chain_accepted", "action": "quest_offer", "quest_id": "story_chain"},
				{"label": "Decline", "next": "story_chain_declined", "action": ""}
			]
		},
		"story_chain_accepted": {
			"speaker": "Elder",
			"text": "Start with the Blacksmith. He knows more than he lets on.",
			"next": "",
			"choices": [
				{"label": "(Set out)", "next": "", "action": "story_chain_advance"}
			]
		},
		"story_chain_declined": {
			"speaker": "Elder",
			"text": "The Fragment will wait. Return when you are ready.",
			"next": "",
			"choices": []
		},
		"reach_floor_complete": {
			"speaker": "Elder",
			"text": "Floor ten! Few return from there. Here is your reward — and a path opens by the cliffside.",
			"next": "",
			"choices": [
				{"label": "(Accept reward)", "next": "", "action": "quest_complete", "quest_id": "reach_floor_10"}
			]
		},
		"quest_cap_reached": {
			"speaker": "Elder",
			"text": "I have no new quests for you right now.",
			"next": "",
			"choices": []
		},
```

### Add new top-level "blacksmith" key

Insert this entire block as a sibling of "elder" inside the DIALOGUES const (immediately after the closing brace of "elder" and before "dungeon_merchant"):

```gdscript
	"blacksmith": {
		"greeting": {
			"speaker": "Blacksmith",
			"text": "What is it, traveler?",
			"next": "",
			"choices": []
		},
		"kill_quest_offer": {
			"speaker": "Blacksmith",
			"text": "Those melee brutes in the dungeon — clear ten of them and there's gold in it for you.",
			"next": "",
			"choices": [
				{"label": "Accept", "next": "kill_quest_accepted", "action": "quest_offer", "quest_id": "kill_melee_10"},
				{"label": "Decline", "next": "kill_quest_declined", "action": ""}
			]
		},
		"kill_quest_accepted": {
			"speaker": "Blacksmith",
			"text": "Good. Ten melee enemies. Return when it's done.",
			"next": "",
			"choices": []
		},
		"kill_quest_declined": {
			"speaker": "Blacksmith",
			"text": "Suit yourself. The job will be here.",
			"next": "",
			"choices": []
		},
		"kill_quest_complete": {
			"speaker": "Blacksmith",
			"text": "Ten melee down! Here — earned every coin.",
			"next": "",
			"choices": [
				{"label": "(Take the reward)", "next": "", "action": "quest_complete", "quest_id": "kill_melee_10"}
			]
		},
		"kill_quest_followup": {
			"speaker": "Blacksmith",
			"text": "Keep at it. Those brutes won't clear themselves.",
			"next": "",
			"choices": []
		},
		"kill_quest_cap_reached": {
			"speaker": "Blacksmith",
			"text": "I have no new quests for you right now.",
			"next": "",
			"choices": []
		},
		"story_chain_step1": {
			"speaker": "Blacksmith",
			"text": "The Elder's map? Yes, I held it once. But a merchant who wanders the dungeon — he asked to borrow it. You'll find him somewhere in the depths.",
			"next": "",
			"choices": [
				{"label": "(Note the merchant)", "next": "", "action": "story_chain_advance"}
			]
		},
		"story_chain_step1_done": {
			"speaker": "Blacksmith",
			"text": "Find that wandering merchant in the dungeon. He has what the Elder seeks.",
			"next": "",
			"choices": []
		},
	},
```

After the blacksmith block, ensure the existing "dungeon_merchant" key follows. The trailing comma after the closing brace of "blacksmith" is intentional and required for the dict syntax.

### Modify "dungeon_merchant" — add 2 nodes

Inside the existing "dungeon_merchant" dict (between the last existing node and the closing brace), append:

```gdscript
		"story_chain_step2": {
			"speaker": "Dungeon Merchant",
			"text": "The Elder sent you? I've kept this safe. Here — take the Map Fragment back to him. And tell him the map shows a passage near the cliffside... if one knows where to look.",
			"next": "",
			"choices": [
				{"label": "(Take the Fragment)", "next": "", "action": "quest_complete", "quest_id": "story_chain"}
			]
		},
		"story_chain_complete": {
			"speaker": "Dungeon Merchant",
			"text": "Safe travels, friend.",
			"next": "",
			"choices": []
		},
```

Use tab indentation matching existing entries. Verify each comma placement carefully — Godot 4 allows trailing commas, but match the existing style.

Do NOT modify or remove any existing dialogue node ("greeting", "quest_offer", "quest_accepted", "quest_declined", "quest_follow_up" for elder; "greeting", "merchant_offer" for dungeon_merchant). Do NOT remove the get_dialogue_node accessor.
  </action>
  <acceptance_criteria>
    - grep `"fetch_quest_offer":` script/dialogue_data.gd returns 1 match
    - grep `"fetch_quest_accepted":\|"fetch_quest_declined":\|"fetch_quest_complete":` script/dialogue_data.gd returns 3 matches
    - grep `"story_chain_offer":\|"story_chain_accepted":\|"story_chain_declined":` script/dialogue_data.gd returns 3 matches
    - grep `"reach_floor_complete":` script/dialogue_data.gd returns 1 match
    - Elder "greeting" node MUST have `"next": ""` (not "quest_offer"). Verify: grep -A3 '"greeting": {' script/dialogue_data.gd shows first occurrence (under elder) with `"next": ""`
    - grep `"quest_cap_reached":` script/dialogue_data.gd returns 1 match (elder)
    - grep `^\s*"blacksmith":` script/dialogue_data.gd returns 1 match
    - grep `"kill_quest_offer":\|"kill_quest_accepted":\|"kill_quest_declined":\|"kill_quest_complete":\|"kill_quest_followup":\|"kill_quest_cap_reached":` script/dialogue_data.gd returns 6 matches
    - grep `"story_chain_step1":\|"story_chain_step1_done":` script/dialogue_data.gd returns 2 matches
    - grep `"story_chain_step2":\|"story_chain_complete":` script/dialogue_data.gd returns 2 matches
    - grep `"action": "quest_offer", "quest_id": "kill_melee_10"` script/dialogue_data.gd returns 1 match
    - grep `"action": "quest_offer", "quest_id": "fetch_ancient_relic"` script/dialogue_data.gd returns 1 match
    - grep `"action": "quest_offer", "quest_id": "story_chain"` script/dialogue_data.gd returns 1 match
    - grep `"action": "quest_complete", "quest_id": "kill_melee_10"` script/dialogue_data.gd returns 1 match
    - grep `"action": "quest_complete", "quest_id": "fetch_ancient_relic"` script/dialogue_data.gd returns 1 match
    - grep `"action": "quest_complete", "quest_id": "reach_floor_10"` script/dialogue_data.gd returns 1 match
    - grep `"action": "quest_complete", "quest_id": "story_chain"` script/dialogue_data.gd returns 1 match
    - grep `"action": "story_chain_advance"` script/dialogue_data.gd returns 2 matches (elder story_chain_accepted + blacksmith story_chain_step1)
    - grep `"I have no new quests for you right now."` script/dialogue_data.gd returns 1 match
    - Existing nodes preserved: grep `"quest_offer":\|"quest_accepted":\|"quest_declined":\|"quest_follow_up":` script/dialogue_data.gd returns 4 matches (original elder reach-floor nodes from Phase 2)
  </acceptance_criteria>
  <verify>
    <automated>grep -c "\"action\": \"quest_offer\"\|\"action\": \"quest_complete\"\|\"action\": \"story_chain_advance\"" script/dialogue_data.gd returns >= 8 (3 offers + 4 completes + 2 advances); grep -c "\"blacksmith\"\|\"elder\"\|\"dungeon_merchant\"" script/dialogue_data.gd returns >= 3 (all three NPCs present as top-level keys)</automated>
  </verify>
  <done>dialogue_data.gd contains complete dialogue trees for all 4 quest types across all 3 NPCs. Every offer routes to quest_manager.accept_quest; every complete routes to quest_manager.complete_quest; story_chain_advance fires at the right step transitions.</done>
</task>

</tasks>

<verification>
After this plan completes (combined with Plan 05 NPC routing):
- Talking to Blacksmith with no kill quest active → kill_quest_offer text appears
- Talking to Elder for first time → story_chain_offer text appears — verifies QST-04 is reachable
- All quest complete nodes trigger reward dispatch via action=quest_complete
- story_chain_advance fires from both elder story_chain_accepted and blacksmith story_chain_step1
- 3-quest cap nodes show "I have no new quests for you right now."
- No existing Phase 2 dialogue nodes removed
</verification>

<success_criteria>
- All Phase 3 dialogue content authored in dialogue_data.gd
- No existing Phase 2 nodes modified or removed (except elder greeting next= fix)
- All quest action strings match Plan 03's dispatch handler expectations
</success_criteria>

<output>
After completion, create `.planning/phases/03-quest-system/03-05B-SUMMARY.md` listing: all new node IDs grouped by NPC, the elder greeting fix rationale, and the story chain advance node sequence.
</output>
