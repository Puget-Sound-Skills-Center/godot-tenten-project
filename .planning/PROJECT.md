# Dungeon Explorer RPG

## What This Is

A 2D pixel art dungeon exploration RPG built in Godot 4.6, inspired by Stardew Valley's aesthetic and warmth but focused on deep dungeon crawling. Players explore procedurally generated dungeon floors, interact with a cast of NPCs who give quests and tell stories, and fight varied enemies that challenge them to adapt their approach. The game lives in the tension between the safety of the overworld town and the danger of going deeper.

## Core Value

Every dungeon run feels different and purposeful — varied enemies, hidden secrets, and NPC quests that make players *want* to go back in.

## Requirements

### Validated

- ✓ World hub → Cliff Side → Dungeon (floors 1–100) loop — existing
- ✓ Player movement, combat, HUD — existing
- ✓ Shop NPC with upgrade system — existing
- ✓ Enemy with NavigationAgent2D pathfinding — existing
- ✓ 5 puzzle types in dungeon — existing
- ✓ Save/load system (3 slots) — existing
- ✓ Money system — existing
- ✓ Pause menu with in-game save — existing

### Active

- [ ] NPC dialogue system (branching dialogue trees, UI panel)
- [ ] Quest system (kill, fetch, reach floor, story chain quests)
- [ ] Quest rewards (gold, special items, access unlocks, deeper story)
- [ ] 2–3 named NPC characters in overworld + dungeon
- [ ] Multiple enemy types (ranged, melee, tank, fast)
- [ ] Pack/alert behavior (enemies coordinate when player is spotted)
- [ ] Dungeon visual variety by floor depth (tileset themes)
- [ ] Hidden rooms and secrets in dungeons
- [ ] Lore objects and story fragments in dungeon
- [ ] Boss floors with distinct tension and goal
- [ ] Enemy variety combinations per floor range

### Out of Scope

- Multiplayer — single-player focus
- Crafting system — not part of v1
- Seasons / time cycle (Stardew feature) — aesthetic inspiration only, not mechanics
- Mobile port — desktop first

## Context

**Existing codebase:** Godot 4.6 game with a working game loop. The architecture uses:
- `global.gd` autoload for all game state and save/load
- `pause_menu.gd` autoload for ESC overlay
- Scene routing via `get_tree().change_scene_to_file()` with global flag polling
- NPCs built at runtime via script (no .tscn needed — see `npc.gd`, `dungeon_npc.gd`)
- Enemy identity via duck-typed method tags (`has_method("enemy")`, `has_method("player")`)
- Dungeon floors regenerated via `reload_current_scene()` — clean slate each floor

**Known tech debt to be aware of:**
- Flag polling in `_process()` is the coordination mechanism — new systems should follow this pattern or introduce signals carefully
- Duplicate puzzle logic between `dungeon.gd` and `puzzle_test.gd`
- No shared utility file yet (add `script/utils.gd` as autoload if needed)

## Constraints

- **Tech stack**: Godot 4.6 / GDScript — no external dependencies
- **Art style**: Pixel art, consistent with existing `art/` assets
- **Architecture**: Follow existing patterns (global flag polling, duck-typed identity, runtime NPC spawn)
- **Save system**: Any new persistent state must be added to `global.gd` save/load slots

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Dialogue as data (JSON/resource files) | Separates content from code, easier to author and expand | — Pending |
| Quest state stored in `global.gd` | Consistent with existing save pattern | — Pending |
| NPC scenes built at runtime (no .tscn) | Matches existing `npc.gd` / `dungeon_npc.gd` pattern | — Pending |
| Enemy types as separate scripts extending base enemy | Matches codebase guidance in STRUCTURE.md | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-08 after initialization*
