# Domain Pitfalls

**Domain:** Godot 4.6 dungeon crawler RPG — dialogue, quests, enemy AI variants, dungeon theming
**Researched:** 2026-05-08
**Confidence:** HIGH (Godot 4.x engine behavior) / MEDIUM (project-specific interaction with existing tech debt)

---

## Critical Pitfalls

Mistakes that force rewrites or corrupt saves.

---

### Pitfall 1: Quest State Lives Outside `global.gd` Save Slots

**What goes wrong:** Quest progress (active quests, completed quests, kill counts, fetch item counts) is stored somewhere other than the three save slot dictionaries in `global.gd`. Floor reload via `reload_current_scene()` wipes all in-scene state. If quest progress is on a scene node or an autoload that isn't serialized, the player loses quest progress every floor.

**Why it happens:** It feels natural to put quest data on a `QuestManager` autoload without wiring it into `global.save_game()` / `global.load_game()`. The existing save system uses `ConfigFile` and manually lists every field — new fields are silently dropped if not added.

**Consequences:** Quest state resets on scene change or save/load. Quests marked complete are re-offered. Kill-count quests reset mid-dungeon. Chain quests break permanently.

**Prevention:**
- Store ALL quest state in `global.gd` under a `quest_state: Dictionary` field added to every `save_game()` / `load_game()` call.
- Use a flat, serializable dict `{ "quest_id": { "status": "active", "progress": 2, "target": 5 } }` — no nested `Resource` objects or `Object` references (ConfigFile cannot serialize those).
- Add a validation pass in `load_game()`: if a key is missing from the file, initialize it to a safe default rather than crashing.

**Warning signs:**
- Quest state survives scene load in the editor but resets when testing a save/reload cycle.
- `ConfigFile.get_value()` silently returns `null` for a missing key — trace saves at runtime to confirm every key round-trips.

**Phase:** Address in Quest System phase before any content is authored.

---

### Pitfall 2: Dialogue Data as Nested Dictionaries in Code

**What goes wrong:** Dialogue trees are written as deeply nested `Dictionary` or `Array` literals directly in GDScript files. What starts as 3 lines of test dialogue grows to 400-line GDScript files that are impossible to edit without breaking indentation or introducing syntax errors.

**Why it happens:** It's the fastest way to get dialogue showing on screen. The project already builds NPCs procedurally in code (`npc.gd`, `dungeon_npc.gd`), so dialogue-as-code feels consistent.

**Consequences:** Adding a new NPC requires a developer, not a content pass. Dialogue bugs require a full engine restart to test. Two NPCs sharing a conversation topic duplicate data across files.

**Prevention:**
- Store dialogue in `.tres` (Godot `Resource`) files or JSON files under `res://data/dialogue/`.
- Use a `DialogueEntry` custom `Resource` class with typed fields: `speaker: String`, `text: String`, `choices: Array[DialogueChoice]`. Godot 4's typed arrays on Resources work correctly and serialize cleanly.
- The `DialogueManager` (or equivalent) loads the resource by ID and drives the UI panel — no dialogue content in GDScript logic files.
- Keep the NPC-spawning-via-script pattern for positioning/collision, but give each NPC a `dialogue_id: String` exported var pointing at its data file.

**Warning signs:**
- Any GDScript file containing more than ~20 lines of string literals.
- Dialogue content changes requiring a code review.

**Phase:** Decide data format before writing a single line of NPC dialogue content.

---

### Pitfall 3: NavigationAgent2D Breaks When Multiple Enemy Types Share One NavMesh

**What goes wrong:** All enemy types are added to the same NavigationRegion2D. When fast enemies and tank enemies with different collision radii are both pathfinding, they clip through each other or get stuck because NavigationAgent2D uses a single `radius` parameter for avoidance — if types have different radii, the nav mesh baked for one is wrong for the other.

**Why it happens:** The existing codebase bakes one navigation mesh in `dungeon.gd` `_ready()`. Adding new enemy scripts that extend the base enemy and adjusting `radius` on `NavigationAgent2D` without rebaking (or without setting per-agent avoidance layers) causes silent misbehavior.

**Consequences:** Tank enemies walk through walls on floors with wide corridors baked for small enemies. Fast enemies with smaller radii get stuck on corners because avoidance radius is too large. Pack behavior (enemies coordinating) breaks when agents block each other.

**Prevention:**
- Bake the nav mesh for the largest possible agent radius (the tank enemy). Smaller agents fit inside a mesh baked for a larger one; the reverse is false.
- In Godot 4, set `NavigationAgent2D.avoidance_layers` and `avoidance_mask` per enemy type so fast/light enemies avoid each other but don't compete with tanks for the same avoidance computation budget.
- Keep `NavigationServer2D.bake_from_source_geometry_data_async()` in mind — the existing synchronous bake in `dungeon.gd _ready()` already causes a hitch at floor load (noted in CONCERNS.md). Adding multiple enemy types makes this worse. Bake async, defer enemy spawning until bake completes.
- The existing health bar bug (hardcoded `max_value = 100`) will immediately surface when tank enemies have 300 HP — fix that in the same phase.

**Warning signs:**
- Enemies teleporting to corners on floor transitions.
- `NavigationAgent2D: target position is not on the NavMesh` errors in the Output panel.
- Pack behavior test: fast enemy and tank spawned in same room, one gets permanently stuck.

**Phase:** Enemy AI Variants phase. Do not ship multiple types without testing two types in the same room.

---

### Pitfall 4: Pack / Alert Behavior Implemented via `_process()` Polling

**What goes wrong:** The "alert nearby enemies when player is spotted" behavior is implemented by having each enemy poll `global.player_spotted` every frame, or by one enemy directly calling methods on sibling nodes it finds via `get_tree().get_nodes_in_group("enemies")` inside `_physics_process()`.

**Why it happens:** The existing codebase coordinates everything through global flag polling in `_process()`. Following this pattern for pack behavior is the path of least resistance.

**Consequences:** At 30 enemies on floor 30, every enemy calls `get_nodes_in_group("enemies")` + iterates the result every physics frame = O(n²) work. Behavior is also unpredictable: if the group walk takes more than one frame, partial alerts fire, causing some enemies to chase while others stand still mid-alert.

**Prevention:**
- Use a signal for alert propagation: the spotting enemy emits `player_spotted(position: Vector2)`, nearby enemies connect to this signal on spawn and respond once.
- Limit alert radius with a simple distance check in the signal handler, not a per-frame poll.
- Or use Godot 4 `Area2D` "alert zone" on each enemy: when the player enters the zone, the zone's `body_entered` fires once and propagates to neighboring zones via signal chain. This is O(1) per alert event rather than O(n) per frame.
- Given the existing CONCERNS.md flag on `5 + floor_no` enemies with no cap: add `min(5 + floor_no, 30)` cap before adding pack behavior — pack behavior on 105 enemies is a guaranteed freeze.

**Warning signs:**
- FPS drop when entering a room with 10+ enemies before any combat.
- Alert state fires inconsistently — sometimes 3 enemies respond, sometimes 8.

**Phase:** Enemy AI Variants phase. Requires the enemy cap fix from CONCERNS.md as a prerequisite.

---

### Pitfall 5: Dungeon Theming Breaks the Existing Tileset-Free Room Generation

**What goes wrong:** The current dungeon builds rooms procedurally via code (sprites, `StaticBody2D` walls, hardcoded pixel offsets — from CONCERNS.md). Adding themed tilesets (TileMapLayer) for floor-depth visual variety requires a different generation approach. Mixing the two — some walls as `StaticBody2D` and some as TileMap collision — produces gaps in the nav mesh and invisible collision seams.

**Why it happens:** The quickest way to add a "cave theme" is to drop a TileMap node behind the existing procedural walls. The nav mesh then sees the TileMap's physics layers AND the `StaticBody2D` walls, baking with redundant or conflicting geometry.

**Consequences:** Players walk through visual walls. Nav mesh has holes where tile edges don't align with procedural wall `CollisionShape2D` offsets. Room sizes that grow `8px per floor` (CONCERNS.md) cause tile seams at every floor boundary.

**Prevention:**
- Commit to one wall representation: either TileMapLayer (preferred for theming) OR procedural `StaticBody2D`. Do not mix.
- If switching to TileMapLayer: the nav mesh bakes from TileMap physics layers automatically in Godot 4 — remove the manual `StaticBody2D` walls. Procedural room layout logic writes tile IDs instead of spawning nodes.
- Theme variation via `TileSet` atlas source swapping: same tile IDs, different visual atlas per theme. The dungeon generator picks a `theme_id` based on floor range (floors 1–25: cave, 26–50: ruins, etc.), sets the TileSet atlas source index on load. No geometry changes, only texture swap.
- The `8px per floor` room growth must have a hard cap before theming — a 1280px room with tiles baked at 16px grid will have alignment issues at non-multiple sizes.

**Warning signs:**
- Player clips through a wall visually present as a tile but missing collision.
- Nav mesh debug view (Scene > Tools > NavigationServer2D > Enable Visible Navigation) shows holes at room edges.
- Tile seams visible at floor-to-floor transitions in the same theme.

**Phase:** Dungeon Theming phase. Prerequisite: decide wall representation (TileMap vs procedural) in Phase planning, not mid-implementation.

---

### Pitfall 6: Quest Completion Triggers a Scene Change Mid-Dialogue

**What goes wrong:** A quest's completion condition fires (e.g., kill count reached) during combat, setting a global flag. The player then talks to the NPC to turn in the quest. The dialogue system reads the flag, awards the reward, and calls `global.save_game()`. If the reward includes a floor unlock or scene route change, `get_tree().change_scene_to_file()` is called while the dialogue UI is still open, leaving the Control nodes in an indeterminate state — or crashing on `queue_free()` of a node that is mid-tween.

**Why it happens:** The existing scene transition mechanism fires immediately when a flag is set (polled in `_process()`). The dialogue system doesn't know a scene change is pending.

**Consequences:** Dialogue panel remains visible on the next scene. `queue_free()` on a Control node that owns a tween crashes the next scene's `_ready()`. Scene transition fires before the reward sound/animation completes.

**Prevention:**
- Dialogue system owns scene transitions that originate from dialogue. It emits a `dialogue_finished` signal; scene changes happen in the signal handler after the panel closes.
- Quest rewards that unlock areas should set a flag only — scene transition is deferred to the overworld `_process()` loop, which is already the pattern for `global.enter_dungeon`.
- Never call `change_scene_to_file()` from inside a dialogue callback. Use `call_deferred("change_scene_to_file", path)` if unavoidable.

**Warning signs:**
- Any dialogue branch that has a consequence (reward, unlock, transition) called synchronously in the dialogue step handler.
- `queue_free` errors in the Godot Output panel immediately after a quest reward dialogue.

**Phase:** Quest System phase, specifically quest reward integration.

---

## Moderate Pitfalls

---

### Pitfall 7: NPC Count Scope Creep

**What goes wrong:** The milestone specifies "2–3 named NPC characters." Each NPC needs: dialogue data, at least one quest chain, an overworld position, a sprite, a collision shape, and a `player_ref` guard fix (noted in CONCERNS.md). The instinct is to add a fourth NPC "just for lore" and a fifth "for the dungeon merchant." By the time scope stabilizes, each NPC has grown to include faction logic, relationship tracking, and conditional dialogue that references other NPCs' quest states.

**Prevention:**
- Hard cap: implement exactly 2 NPCs end-to-end (dialogue + quest + save/load) before adding a third. Validate the pattern scales before multiplying content.
- "Lore NPC" is valid only if it reuses the same dialogue system with zero new code — new code means it belongs in a later milestone.
- Dungeon NPCs (dungeon_npc.gd already exists) should share the same dialogue system as overworld NPCs, not have a separate one.

**Warning signs:** A third NPC is added before the first NPC's quest round-trips through save/load correctly.

**Phase:** NPC Dialogue phase. Enforce the 2-NPC limit in planning.

---

### Pitfall 8: `is_instance_valid()` Not Used on `player_ref` in NPC Scripts

**What goes wrong:** CONCERNS.md already flags this: `player_ref` in `npc.gd` and `dungeon_npc.gd` is null-initialized and checked only with `has_method()`. When dialogue is active and the player takes lethal damage (health bug in CONCERNS.md — no death screen), `player_ref` becomes a freed object. Calling any method on it crashes the game.

**Prevention:**
- Before the dialogue system is wired to NPC scripts, fix the `player_ref` guard: `if not is_instance_valid(player_ref): return`.
- Also guard the death path: player death should disable NPC interaction areas (emit a signal or set a global flag) so no NPC callback fires on a dead player.

**Warning signs:** Crash logs showing `Invalid call. Nonexistent function 'open_shop' on base Nil`.

**Phase:** NPC Dialogue phase, day 1. Fix before any dialogue code is written.

---

### Pitfall 9: Dialogue UI Built Procedurally (Following Existing Pattern)

**What goes wrong:** Following the existing `_setup_hud()` / `_setup_shop()` pattern (CONCERNS.md: "UI invisible in Godot editor, pixel offsets hardcoded"), the dialogue panel is constructed in code. Text wrapping, portrait sizing, and choice button layout are hardcoded pixel offsets that break at any viewport scale other than 1x.

**Prevention:**
- Dialogue UI is the one place to break from the procedural-UI pattern. Create `scenes/dialogue_panel.tscn` with a `PanelContainer > VBoxContainer` layout using `Control` anchors.
- This is explicitly the right moment to introduce `.tscn` for UI — it's a net-new system, not a refactor of existing procedural UI.
- Use `RichTextLabel` for dialogue text (supports `[wave]`, `[color]` BBCode for emphasis without additional code).

**Warning signs:** Dialogue text clips at resolution changes. Choice buttons overlap on strings longer than ~30 characters.

**Phase:** NPC Dialogue phase. Treat dialogue panel as a scene, not a procedural node chain.

---

### Pitfall 10: Enemy Type Identity Uses Duck Typing Inconsistently

**What goes wrong:** The existing codebase identifies enemies via `has_method("enemy")` (duck typing, per PROJECT.md). New enemy subtypes (ranged, tank, fast) extend the base `enemy.gd` and override some methods. If the combat system identifies enemies by `has_method("enemy")` but the pack behavior system identifies them by `is_instance_of(RangedEnemy)` or a type string, two parallel identity systems diverge. The third developer who adds a boss extends `Node2D` directly to avoid the base class and breaks both systems.

**Prevention:**
- Stick to one identity mechanism: the duck-typed `has_method("enemy")` pattern already in the codebase. All enemy subtypes must expose this method (inherited from base class, not re-declared).
- Add one more duck-typed tag for subtype behavior: `has_method("is_ranged")`, `has_method("is_tank")` etc. — consistent with existing pattern, no imports needed.
- Document this convention in CONVENTIONS.md before enemy subtype work begins.

**Warning signs:** `if enemy is RangedEnemy` appears anywhere in `dungeon.gd` or `player.gd`.

**Phase:** Enemy AI Variants phase, architecture decision before first subtype.

---

## Minor Pitfalls

---

### Pitfall 11: Dialogue Text Encoding Issues in ConfigFile Save Round-Trip

**What goes wrong:** NPC names or dialogue strings with non-ASCII characters (accents, em-dashes, ellipsis `…`) are stored in `global.gd` (e.g., last-seen dialogue state) and saved via `ConfigFile`. Godot 4's `ConfigFile` writes UTF-8 but Windows file systems sometimes introduce BOM markers on `user://` paths on certain configurations, causing load-time parse failures.

**Prevention:** Use only ASCII-safe characters in any string that round-trips through `ConfigFile`. Keep NPC names and dialogue IDs as ASCII slugs (`"npc_elara"`, `"quest_fetch_herbs"`). Display strings live only in the `.tres`/JSON data files, never in save files.

**Phase:** Quest System phase, save format design.

---

### Pitfall 12: `reload_current_scene()` Loses Enemy State Mid-Quest

**What goes wrong:** A kill quest requires 10 rats. The player kills 7, exits the dungeon, re-enters. `reload_current_scene()` respawns all enemies. Kill count is only preserved if the quest progress is in `global.gd` (Pitfall 1). If even partially correct — kill count saved but enemy group not reset — the player can re-enter a cleared floor and no enemies spawn, softlocking a kill quest.

**Prevention:** Kill quests track a global kill counter in `global.gd`, not "enemies remaining in this room." The counter increments on `enemy_died` signal/callback regardless of floor state. Floor enemy spawning is always fresh — no dependency on "how many were killed last visit."

**Phase:** Quest System phase.

---

### Pitfall 13: Dungeon Theme Atlas Swap Causes One-Frame Visual Glitch

**What goes wrong:** If the TileSet atlas source is swapped in `_ready()` after the first rendered frame, the player sees one frame of the wrong theme on floor load.

**Prevention:** Set theme before `add_child()` of the TileMapLayer node, or swap atlas in a deferred call paired with a loading screen / fade that already covers the floor-transition frame. The existing `reload_current_scene()` pattern has no loading screen — add a black fade-in on dungeon entry before theming work begins.

**Phase:** Dungeon Theming phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| NPC Dialogue — data format | Inline dict dialogue explodes in size | Use Resource/JSON files from day 1 |
| NPC Dialogue — UI | Procedural UI panel breaks at scale | Create `dialogue_panel.tscn`, use anchors |
| NPC Dialogue — NPC scripts | Freed `player_ref` crash | `is_instance_valid()` guard before any dialogue code |
| Quest System — save/load | Quest state not in save slots | Add `quest_state` dict to `global.gd` save, day 1 |
| Quest System — rewards | Scene change mid-dialogue crash | Defer transitions via signal, not inline callbacks |
| Quest System — kill quests | Kill count wiped by `reload_current_scene()` | Global counter in `global.gd`, not scene-local |
| Enemy AI — nav mesh | Multi-type radius mismatch breaks pathfinding | Bake for largest agent, set avoidance layers per type |
| Enemy AI — pack behavior | O(n²) per-frame group poll | Signal-based alert, not `get_nodes_in_group()` in `_process()` |
| Enemy AI — health bars | Hardcoded `max_value=100` breaks tank enemies | Fix health bar bug before first non-standard HP enemy |
| Enemy AI — identity | Mixed `is` / `has_method` checks diverge | Duck-typed tags only, document in CONVENTIONS.md |
| Dungeon Theming — walls | Mixed TileMap + StaticBody2D breaks nav | Choose one wall representation before theming starts |
| Dungeon Theming — room growth | `8px * floor` growth misaligns tiles | Cap room size before theming phase |
| All phases — scope | NPC/quest count expands past plan | 2-NPC hard limit; full save/load test before adding more |

---

## Sources

- Godot 4.6 official docs: NavigationAgent2D avoidance layers, NavigationServer2D bake_from_source_geometry_data_async, TileMapLayer, ConfigFile, Resource serialization — HIGH confidence from engine documentation patterns.
- Codebase analysis: `.planning/codebase/CONCERNS.md` (2026-05-08) — all pitfall interactions with existing tech debt are drawn directly from documented bugs and fragile areas.
- Godot 4 known behavior: `reload_current_scene()` clears all scene-local state — HIGH confidence, fundamental engine behavior.
- Duck-typed identity pattern: `.planning/PROJECT.md` — architectural decision, HIGH confidence.
