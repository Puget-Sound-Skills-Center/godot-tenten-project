---
status: partial
phase: 02-dialogue-system
source: [02-VERIFICATION.md]
started: 2026-05-13T00:00:00Z
updated: 2026-05-13T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Dialogue panel visual layout
expected: Walking up to the elder NPC and pressing E opens a dialogue panel rendered at 4x pixel-art scale. Panel shows portrait, NPC name, and dialogue text. Pressing E (or Space/click) advances to the next node.
result: [pending]

### 2. Choice button rendering on quest_offer node
expected: When the quest_offer dialogue node is reached, two choice buttons appear (e.g. "Accept" / "Decline"). Pressing E does NOT advance the text — only clicking a button progresses. Choices are visually distinct from normal text nodes.
result: [pending]

### 3. NPC memory across sessions
expected: After accepting the quest (clicking Accept), closing dialogue, then re-interacting with the elder NPC — the opening line is different (follow-up dialogue, not the initial greeting). global.npc_state["elder"] drives the start_node selection.
result: [pending]

### 4. Decline path — no state set, correct re-open
expected: If the player declines the quest offer, the NPC responds with a decline-specific line. Re-interacting with the NPC again shows the original greeting (quest_accepted flag was NOT set). No stuck state.
result: [pending]

### 5. Dungeon NPC spawn visible and interactable
expected: Entering a dungeon floor, a second NPC (merchant/lore figure) is visible somewhere in the room. Walking up and pressing E opens dialogue (merchant greeting or lore text). NPC does NOT trigger dungeon entry.
result: [pending]

### 6. Floor advance while dialogue open — no stuck pause
expected: If the player somehow reaches the floor exit while dialogue is open (e.g. via a bug or edge case), the game does NOT get permanently stuck in a paused state. The pause is released before the scene reloads.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
