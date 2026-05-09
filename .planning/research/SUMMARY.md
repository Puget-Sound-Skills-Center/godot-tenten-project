# Research Summary — Dungeon Explorer RPG

**Date:** 2026-05-08
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md

---

## Executive Summary

This is a Godot 4.6 GDScript-only dungeon crawler with a working game loop (movement, combat, shop, save/load, puzzles). The active milestone adds four interdependent systems: NPC dialogue, quest management, enemy type variants, and dungeon visual theming. All four must integrate without breaking the existing architecture — specifically the `global.gd`-centric state model, `reload_current_scene()` floor teardown, and duck-typed entity identity.

The recommended approach is additive: five new autoloads (`dialogue_ui`, `dialogue_data`, `quest_manager`, `quest_data`, `dungeon_themes`) slot into the existing singleton pattern without refactoring core systems. The one required refactor is extracting `enemy_base.gd` from `enemy.gd` — this unblocks quest kill tracking, enemy variants, and health bar correctness simultaneously.

---

## Stack (all HIGH confidence)

- **Dialogue data:** GDScript `Dictionary` in `dialogue_data.gd` autoload (not JSON, not Dialogic)
- **Quest state:** `active_quests` / `completed_quests` dicts in `global.gd`; definitions in `quest_data.gd`
- **Enemy variants:** `enemy_base.gd` + subclass scripts via `set_script()` on shared `enemy.tscn`
- **Theming:** `dungeon_themes.gd` autoload with color/resource dicts; `TileMapLayer` (not `TileMap`) for tile work
- **No addons** — zero external dependencies is a hard constraint for this project

---

## Features — Table Stakes

**Dialogue:**
- Portrait + name label, advance-on-input, game pause during dialogue
- NPC state memory (knows if quest accepted, player's deepest floor)
- Quest offer / decline flow

**Quests:**
- HUD tracker with objective counter
- Auto-completion detection, turn-in dialogue
- Gold reward + special item reward
- All 4 types: kill, fetch/collect, reach floor, story chain

**Enemies:**
- Distinct silhouettes + behaviors (melee / ranged / fast / tank)
- Stat scaling by floor range
- Death feedback, pack/alert behavior (signal-based, not per-frame)

**Dungeon:**
- 2–3 tileset/color theme zones across 100 floors
- Hidden rooms with meaningful rewards
- Boss floors at floors 25 / 50 / 75 / 100
- Lore objects using dialogue_ui

**Defer to post-v1:** voiced dialogue, 10+ simultaneous quests, crafting, companion NPCs.

---

## Architecture Build Order (dependency-driven)

1. `enemy_base.gd` refactor — no deps, unlocks everything
2. `dungeon_themes.gd` + color application — independent of above
3. Enemy variants (fast, tank, ranged)
4. `dialogue_data.gd` + `dialogue_ui.gd`
5. `quest_data.gd` + `quest_manager.gd`
6. NPC dialogue wiring + save/load integration
7. Boss floors, hidden rooms, lore objects

---

## Top Pitfalls

| Pitfall | Prevention |
|---------|------------|
| Quest state outside `global.gd` | Add `active_quests`/`completed_quests` to save/load/reset on Day 1 of Quest phase |
| Inline nested dialogue dicts | `dialogue_data.gd` autoload from Day 1, never inline |
| Nav mesh radius mismatch (multi-type enemies) | Bake for largest agent (tank); avoidance layers per type |
| Pack alert via per-frame `get_nodes_in_group()` | Signal-based: `player_spotted` emitted once, connected on spawn |
| Mixed TileMap + StaticBody2D walls | Pick one wall representation before theming phase |
| Scene change mid-dialogue | `call_deferred()` only; never `change_scene_to_file()` from dialogue callback |

---

## Prerequisite Bug Fixes (before new code)

These three bugs become critical the moment new systems touch them:

1. `is_instance_valid(player_ref)` guard in `npc.gd` / `dungeon_npc.gd` — freed reference crash
2. Health bar `max_value = max_health` (not hardcoded 100) — breaks all enemy variant health display
3. Enemy spawn cap: `min(5 + floor_no, 30)` — prevents O(n²) alert performance at deep floors

---

## Roadmap Implications — 4 Phases

| Phase | Focus | Dependencies |
|-------|-------|-------------|
| 1 | Enemy Base + Theming Foundation | None — prerequisite fixes + refactor |
| 2 | Dialogue System | None (parallel with Phase 1 completion) |
| 3 | Quest System | Dialogue (accept/turn-in) + EnemyBase (kill tracking) |
| 4 | Dungeon Depth (boss floors, hidden rooms, lore) | Dialogue (lore objects), themes |

---

## Open Questions for Planning

1. **Dialogue data format:** GDScript dict (recommended — matches codebase philosophy) vs JSON
2. **Art assets for enemy variants:** `art/` not fully audited; each type needs a distinct sprite
3. **Fetch quest item:** No inventory system — needs minimal item representation (string ID + count in `global.gd`)
4. **Enemy spawn cap tuning:** 30 suggested, needs in-game validation

---

## Confidence

| Area | Level |
|------|-------|
| Stack | HIGH |
| Features | HIGH |
| Architecture | HIGH |
| Engine-specific pitfalls | HIGH |
| Art/content scope | LOW |
