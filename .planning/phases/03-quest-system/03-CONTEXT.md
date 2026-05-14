# Phase 3: Quest System - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a complete quest system: players receive quests from NPCs via the existing dialogue system, track progress in an in-game quest log, and complete 4 quest types (kill, fetch, reach-floor, story chain) with gold, lore artifact, and access-unlock rewards — all persisting across save/load.

</domain>

<decisions>
## Implementation Decisions

### Quest Log UI
- **D-01:** Quest log opens/closes with a dedicated key (Q or Tab). The planner chooses which key based on existing input map; if neither is mapped, Tab is preferred.
- **D-02:** Game pauses when the quest log is open — `get_tree().paused = true` / `false`, identical to the dialogue system. All log UI nodes must use `PROCESS_MODE_ALWAYS`.
- **D-03:** Each quest entry shows only: quest name + current objective (e.g. "Kill Melee Enemies (6/10)"). No reward preview, no description. Minimal, pixel-art consistent.
- **D-04:** Maximum 3 active quests at any time. The story chain quest counts toward this cap (occupies one slot). NPCs must not offer a quest when the player is already at 3 active.

### Fetch Items
- **D-05:** Fetch items appear in the dungeon as interactable chests — Area2D with CollisionShape2D + ColorRect visual + Label. Player presses E to open (same interaction key as NPCs). NOT a floor auto-pickup.
- **D-06:** The chest spawns in `dungeon.gd _ready()` **only when the player has an active fetch quest** (`global.quest_state` has an active fetch quest entry). No chest otherwise — no clutter on non-quest runs.
- **D-07:** Items are tracked as `global.items: Dictionary` with item_id → count (e.g. `global.items["ancient_key"] = 1`). Supports future stacking. Must be saved/loaded per slot in `global.gd`.

### Special Items (Lore Artifacts)
- **D-08:** "Special items" = **story keys / lore artifacts** — no mechanical effect. They exist to gate NPC dialogue or open locked areas. Examples: "Ancient Map Fragment", "Rusted Key". Stored in `global.items`.
- **D-09:** Lore artifacts are displayed as a **persistent HUD icon slot** in the corner of the screen — visible when the player holds at least one lore item. Built at runtime in `player.gd` (or a separate autoload). Shows the item name and a small colored rect representing it.
- **D-10:** **Access unlock reward** = a door, passage, or Area2D in a scene becomes passable after a global flag is set. Implementation: `global.unlocks: Dictionary` (e.g. `global.unlocks["cliff_secret_door"] = true`); the relevant scene checks this flag in `_ready()` / `_process()` and removes/disables the blocking collision.

### Story Chain Quest
- **D-11:** Player guidance = **both**: the quest log shows the next step objective ("Talk to: Blacksmith") AND the current NPC's closing dialogue line contains a hint ("Go find the Blacksmith near the forge"). Both are required — quest log for reference, dialogue for story feel.
- **D-12:** v1 story chain is **fixed 3 steps**: interact NPC A → interact NPC B → interact NPC C. Step index tracked as an integer counter in `global.quest_state["story_chain"]["step"]` (0, 1, 2 → complete).
- **D-13:** Story chain **counts toward the 3-quest cap** (occupies one of the 3 quest slots).

### Claude's Discretion
- Which specific toggle key to use for quest log (Q or Tab — planner/researcher chooses based on input map)
- Quest log panel visual layout (position, size, colors — follow dialogue_manager.gd aesthetic)
- Exact dialogue tree node IDs for quest offer/completion flows in dialogue_data.gd
- Which NPCs are associated with which quest types (researcher scopes with existing NPC identities)
- Specific lore artifact names and story chain NPC sequence

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Quests — QST-01 through QST-09 (all 9 quest requirements for this phase)

### Dialogue System (Phase 2 — quest delivery mechanism)
- `script/dialogue_manager.gd` — open/close/force_close interface; pause lifecycle pattern to replicate for quest log
- `script/dialogue_data.gd` — GDScript dict-as-data pattern; quest_data.gd should follow the same structure
- `script/npc.gd` — interaction pattern (npc_state check → start_node selection → DialogueManager.open()); quest NPCs extend this

### Save System
- `script/global.gd` — save/load/reset pattern for new dicts: `quest_state`, `items`, `unlocks` must all be added to slot save/load and new-game reset

### Enemy System (kill quest hook)
- `script/enemy_base.gd` — `enemy_type: String = "melee"` declared at line 9; death handler at lines 92–94 (where `global.money += money_drop`) — kill quest tracking hooks here

### Architecture Constraints
- `.planning/PROJECT.md` §Constraints — "Any new persistent state must be added to global.gd save/load slots"; "Follow existing patterns (global flag polling, duck-typed identity, runtime NPC spawn)"
- `CLAUDE.md` §Architecture — UI built entirely in GDScript at runtime; no Control nodes in .tscn files

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dialogue_manager.gd` CanvasLayer + pause lifecycle: replicate for quest log (CanvasLayer layer=29 or 31 to avoid conflict with layer 30)
- Puzzle tile / exit pattern (`Area2D` + `CollisionShape2D` + `ColorRect` + `Label`): use for fetch item chest
- `npc.gd` interaction pattern (Area2D, E-key detect via `_on_body_entered` + input poll): reuse for chest interaction
- `npc_state` dict pattern in `global.gd`: replicate as `quest_state`, `items`, `unlocks` dicts

### Established Patterns
- Runtime UI construction in GDScript (no .tscn UI): quest log panel and HUD artifact slot must be built procedurally
- Global flag polling in `_process()`: quest completion checks follow this pattern (not signals)
- Duck-typed identity via `has_method()`: no changes needed — enemy/player identity already resolved
- `set_script()` for enemy variants: quest kill tracking reads `enemy.enemy_type` after death, before queue_free

### Integration Points
- `enemy_base.gd` death handler (line 92): add `quest_manager.on_enemy_killed(enemy_type)` call (or inline `global.quest_state` update) before or after `queue_free()`
- `npc.gd` interact: after `DialogueManager.open()`, quest state is updated via dialogue choice callbacks (accept/decline already handled in Phase 2)
- `dungeon.gd _ready()`: add fetch chest spawn after enemy spawn — guarded by `global.quest_state` check
- `global.gd` save/load: add `quest_state`, `items`, `unlocks` to all 4 save slots and `_reset_new_game()`
- `player.gd` HUD: add lore artifact icon slot (shown when `global.items` is non-empty)

</code_context>

<specifics>
## Specific Ideas

- Story chain v1: 3-step fixed sequence. Researcher to propose which 3 existing NPCs (elder, blacksmith, dungeon merchant?) make narrative sense.
- Fetch chest: same pixel-art aesthetic as existing tiles — ColorRect with a distinct color (e.g. golden brown) and "E: Open" label. No sprite asset needed.
- Quest log panel: similar visual to dialogue panel (dark background, white text, border). Shows up to 3 quest entries stacked vertically.
- Lore artifact HUD slot: small panel in top-right or bottom-left corner, outside of existing HUD elements. Shows item name in a colored box. Disappears when `global.items` is empty.

</specifics>

<deferred>
## Deferred Ideas

- Dungeon mid-run mini-quests from dungeon NPCs (QST-V2-03 — post-v1)
- Timed quests (QST-V2-02 — post-v1)
- More than 3 simultaneous active quests (QST-V2-01 — post-v1)
- New NPC spawning as access unlock (considered, deferred in favor of door/area passable approach)

</deferred>

---

*Phase: 3-Quest System*
*Context gathered: 2026-05-13*
