---
phase: "03"
plan: "05"
subsystem: quest-npc-routing
tags: [npc, quest, dialogue, blacksmith, elder, story-chain]
dependency_graph:
  requires: [03-01, 03-02, 03-03, 03-04]
  provides: [blacksmith-npc, elder-priority-cascade, dungeon-merchant-story-routing]
  affects: [world.gd, npc.gd, dungeon_dialogue_npc.gd]
tech_stack:
  added: []
  patterns: [runtime-npc-spawn, duck-typed-identity, start-node-routing]
key_files:
  created:
    - script/blacksmith_npc.gd
  modified:
    - script/world.gd
    - script/npc.gd
    - script/dungeon_dialogue_npc.gd
decisions:
  - Used chest_01.png for blacksmith sprite (exists at res://art/objects/chest_01.png)
  - Blacksmith spawned at (220, 110) — offset from shop NPC at (167, 110)
  - _quest_unaccepted() returns true when qid absent OR status=="" (covers first-time offer)
metrics:
  duration: "15 minutes"
  completed: "2026-05-14"
  tasks_completed: 4
  files_changed: 4
---

# Phase 3 Plan 05: NPC Behavioral Routing Summary

Stand up Blacksmith NPC, spawn in world.gd, extend elder priority cascade, add story chain routing to dungeon_merchant.

## What Was Built

### Task 1 — blacksmith_npc.gd (NEW)

Spawnable Node2D NPC mirroring dungeon_dialogue_npc.gd structure. Uses `chest_01.png` sprite, 20px interaction radius, "E: Talk" prompt.

**_select_start_node() — 6-priority cascade:**
1. `kill_quest_complete` — kill_melee_10 ready_to_complete
2. `kill_quest_followup` — quest previously accepted
3. `story_chain_step1` — story_chain active at step 1
4. `story_chain_step1_done` — step 1 already seen
5. `kill_quest_cap_reached` — 3 active quests, no room
6. `kill_quest_offer` — default (offer the kill quest)

### Task 2 — world.gd spawn

`_spawn_blacksmith_npc()` added, called from `_ready()` after `_spawn_shop_npc()`. Blacksmith spawned at **Vector2(220, 110)**.

### Task 3 — npc.gd elder priority cascade

Replaced 2-branch `start_node` block with **9-branch priority cascade**:
1. `reach_floor_complete` — reach_floor_10 ready
2. `fetch_quest_complete` — fetch_ancient_relic ready
3. `story_chain_accepted` — story_chain active step 0
4. `quest_follow_up` — reach_floor_10 previously accepted
5. `story_chain_offer` — story_chain unaccepted + cap open
6. `fetch_quest_offer` — fetch_ancient_relic unaccepted + cap open
7. `quest_offer` — reach_floor_10 unaccepted + cap open
8. `quest_cap_reached` — 3 active quests
9. `greeting` — fallback

Added helper: `_quest_unaccepted(qid)` returns true if qid absent OR status=="".

### Task 4 — dungeon_dialogue_npc.gd story routing

Replaced `dialogue_manager.open("dungeon_merchant", "greeting")` with a 3-branch selector:
- `story_chain_step2` — story_chain active at step 2
- `story_chain_complete` — story_chain complete
- `greeting` — default

## Deviations from Plan

None — plan executed exactly as written.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

- script/blacksmith_npc.gd: FOUND
- script/world.gd _spawn_blacksmith_npc: FOUND
- script/npc.gd _quest_unaccepted: FOUND
- script/dungeon_dialogue_npc.gd story_chain_step2: FOUND
- Commit a49d676: FOUND
