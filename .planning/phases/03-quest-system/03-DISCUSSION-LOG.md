# Phase 3: Quest System - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 3-quest-system
**Areas discussed:** Quest log UI, Fetch items, Special & unlock rewards, Story chain structure

---

## Quest Log UI

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated key (Q or Tab) | Press key to toggle overlay. Game may pause. | ✓ |
| From pause menu | Quest log lives inside ESC pause menu. | |
| Always-visible HUD element | Current objective as persistent HUD label. | |

**User's choice:** Dedicated key (Q or Tab)
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — pause (like dialogue) | get_tree().paused = true. Matches dialogue system. | ✓ |
| No — game keeps running | Player can check log mid-combat. PROCESS_MODE_ALWAYS needed. | |

**User's choice:** Yes — pause (like dialogue)
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Name + current objective only | Minimal: 'Kill 10 Melee Enemies (6/10)'. | ✓ |
| Name + objective + reward preview | Adds gold/item reward below objective. | |
| Name + full description + objective + reward | Full RPG quest log detail. | |

**User's choice:** Name + current objective only
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Up to 3 simultaneous | Small enough for one screen. One of each type max. | ✓ |
| Unlimited | No cap. Log may scroll. | |

**User's choice:** Up to 3 simultaneous
**Notes:** —

---

## Fetch Items

| Option | Description | Selected |
|--------|-------------|----------|
| Floor drop | Item spawns in room, player auto-picks up on contact. | |
| Chest — interactable object | Player presses E to open. More satisfying discovery. | ✓ |
| Dungeon NPC gift | Merchant gives item through dialogue. | |

**User's choice:** Chest — interactable object in a room
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Only when player has active fetch quest | Targeted — no chest clutter otherwise. | ✓ |
| Every floor, always | Simpler spawn logic. | |
| Random chance each floor | ~40% chance, exploration incentive. | |

**User's choice:** Only when player has an active fetch quest
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Simple bool flag (global.has_item["id"] = true) | Matches npc_state dict pattern. | |
| Item count dict (global.items["id"] = N) | Supports stackable items in future. | ✓ |

**User's choice:** Item count dict (global.items["item_id"] = N)
**Notes:** —

---

## Special & Unlock Rewards

| Option | Description | Selected |
|--------|-------------|----------|
| Permanent stat buffs | Stored as global flag/counter. No UI item needed. | |
| Unique consumables | Stored in global.items; player activates via key. Needs usage UI. | |
| Story keys / lore artifacts | No mechanical effect. Unlock dialogue/areas when held. | ✓ |

**User's choice:** Story keys / lore artifacts
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| New dialogue branch at NPC | NPC checks npc_state for quest_complete flag. | |
| New NPC spawns in overworld | Completing quest adds runtime NPC to world.gd. | |
| Door or area becomes passable | global.unlocks flag → blocked tile removed. | ✓ |

**User's choice:** A door or area becomes passable
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Quest log only — shown as reward received | No separate inventory screen needed. | |
| Persistent HUD slot (key icon) | Small icon in corner visible when holding lore item. | ✓ |
| Dialogue only — NPCs reference what you found | No UI representation. | |

**User's choice:** Persistent HUD slot (like a key icon)
**Notes:** —

---

## Story Chain Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Quest log shows next NPC name | 'Talk to: Blacksmith' as current objective. | |
| Dialogue hints — NPC tells you | Closing line of dialogue says who to visit next. | |
| Both — quest log + dialogue hint | Quest log records objective; dialogue gives story beat. | ✓ |

**User's choice:** Both — quest log + dialogue hint
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed 3 steps (A → B → C) | One chain, 3 NPCs, step index as counter. Simple. | ✓ |
| Variable — defined by quest data | Steps as array in quest_data.gd. Any length. | |

**User's choice:** Fixed 3 steps — step index as counter in global.quest_state
**Notes:** —

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — counts toward 3-quest cap | Chain occupies one quest slot. | ✓ |
| No — separate from cap | Chain runs as background thread; kill/fetch/floor fill 3 slots. | |

**User's choice:** Yes — story chain counts toward the 3-quest cap
**Notes:** —

---

## Claude's Discretion

- Specific toggle key (Q or Tab) — planner chooses based on existing input map
- Quest log panel visual layout and position
- Exact dialogue node IDs for quest offer/accept/complete flows
- Which NPCs are assigned to which quest types
- Specific lore artifact names and story chain NPC sequence

## Deferred Ideas

- Dungeon mid-run mini-quests (QST-V2-03) — post-v1
- Timed quests (QST-V2-02) — post-v1
- More than 3 simultaneous quests (QST-V2-01) — post-v1
- New NPC spawning as access unlock — considered, chose door/area passable instead
