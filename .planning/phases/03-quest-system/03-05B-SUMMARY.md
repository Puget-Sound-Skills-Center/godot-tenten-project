---
phase: "03"
plan: "05B"
subsystem: dialogue_data
tags: [dialogue, quest, npc, content]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [dialogue-nodes-phase3]
  affects: [quest_manager, npc_dialogue_ui]
tech_stack:
  added: []
  patterns: [nested-dict-dialogue-tree, choice-action-dispatch]
key_files:
  modified:
    - script/dialogue_data.gd
decisions:
  - "elder greeting next set to empty string to prevent auto-advance orphan bug"
  - "blacksmith added as new top-level NPC key alongside elder and dungeon_merchant"
  - "story_chain_advance action used as a two-point signal: elder story_chain_accepted and blacksmith story_chain_step1"
metrics:
  duration: "< 5 min"
  completed: "2026-05-14"
---

# Phase 03 Plan 05B: Phase 3 Dialogue Nodes Summary

All Phase 3 dialogue content authored in `script/dialogue_data.gd`.

## New Node IDs by NPC

### elder (9 new nodes)

| Node ID | Purpose |
|---|---|
| `fetch_quest_offer` | Offer fetch_ancient_relic quest with accept/decline choices |
| `fetch_quest_accepted` | Confirms player accepted relic fetch |
| `fetch_quest_declined` | Graceful decline response |
| `fetch_quest_complete` | Hands over gold when relic returned; triggers quest_complete action |
| `story_chain_offer` | Offer story_chain quest with accept/decline choices |
| `story_chain_accepted` | Directs player to Blacksmith; triggers story_chain_advance action |
| `story_chain_declined` | Graceful decline response |
| `reach_floor_complete` | Reward node when floor 10 reached; triggers quest_complete for reach_floor_10 |
| `quest_cap_reached` | Shown when player has no eligible elder quests |

### blacksmith (9 nodes — new NPC)

| Node ID | Purpose |
|---|---|
| `greeting` | Default greeting when no quest context applies |
| `kill_quest_offer` | Offer kill_melee_10 quest with accept/decline choices |
| `kill_quest_accepted` | Confirms player accepted kill quest |
| `kill_quest_declined` | Graceful decline response |
| `kill_quest_complete` | Reward node when 10 melee enemies killed; triggers quest_complete |
| `kill_quest_followup` | Reminder while quest is active |
| `kill_quest_cap_reached` | Shown when player has no eligible blacksmith quests |
| `story_chain_step1` | Story chain link: blacksmith reveals merchant has the map; triggers story_chain_advance |
| `story_chain_step1_done` | Shown on revisit after player has noted the merchant |

### dungeon_merchant (2 new nodes)

| Node ID | Purpose |
|---|---|
| `story_chain_step2` | Merchant hands over Map Fragment; triggers quest_complete for story_chain |
| `story_chain_complete` | Shown on revisit after story chain completed |

## Elder Greeting Fix

**Before:** `"next": "quest_offer"` — greeting auto-advanced into the reach_floor offer, making `fetch_quest_offer` and `story_chain_offer` unreachable orphans regardless of quest state.

**After:** `"next": ""` — greeting closes after one line. The npc.gd selector (Plan 05A) reads quest state and picks the correct `start_node` before opening the panel. Each offer node is now independently reachable.

## Story Chain Advance Sequence

`story_chain_advance` is a two-point action signal used to advance quest stage tracking:

1. **elder / story_chain_accepted** — player accepts quest; action fires to move stage from 0 → 1 (go see Blacksmith)
2. **blacksmith / story_chain_step1** — player learns about merchant; action fires to move stage from 1 → 2 (go find merchant in dungeon)
3. **dungeon_merchant / story_chain_step2** — player retrieves fragment; `quest_complete` action fires to finish quest

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `script/dialogue_data.gd` exists and contains all new nodes
- Elder greeting `"next": ""` confirmed at line 18
- `"blacksmith":` top-level key present (count = 1)
- `story_chain_advance` action appears at 2 locations (lines 91 and 168)
