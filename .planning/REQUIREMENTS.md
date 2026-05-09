# Requirements: Dungeon Explorer RPG

**Defined:** 2026-05-08
**Core Value:** Every dungeon run feels different and purposeful — varied enemies, hidden secrets, and NPC quests that make players want to go back in.

## v1 Requirements

### Prerequisites (Bug Fixes — must complete before new systems)

- [ ] **PRE-01**: Fix freed `player_ref` crash — add `is_instance_valid(player_ref)` guard in `script/npc.gd` and `script/dungeon_npc.gd`
- [ ] **PRE-02**: Fix health bar — change `max_value = 100` to `max_value = max_health` in player/enemy health bar setup
- [ ] **PRE-03**: Add enemy spawn cap — `min(5 + floor_no, 30)` in `script/dungeon.gd` enemy spawner

### Dialogue

- [x] **DLG-01**: Player can interact with NPCs to open a dialogue panel (portrait, name, text, advance-on-input; game pauses during dialogue)
- [x] **DLG-02**: Dialogue supports branching trees with up to 2 choices per node
- [x] **DLG-03**: NPCs remember state across interactions (quest accepted, quest complete, deepest floor reached)
- [x] **DLG-04**: Dialogue system supports quest offer / decline flow inline (accept → quest starts; decline → NPC responds)
- [ ] **DLG-05**: At least one dungeon NPC exists (merchant or lore figure spawned inside dungeon rooms)

### Quests

- [ ] **QST-01**: Player can receive and complete kill quests (defeat N enemies of a specific type — auto-tracked)
- [ ] **QST-02**: Player can receive and complete fetch/collect quests (find item in dungeon, return to NPC)
- [ ] **QST-03**: Player can receive and complete reach-a-floor quests (reach floor N alive — uses existing floor tracker)
- [ ] **QST-04**: Player can receive and complete story chain quests (multi-step: interact with multiple NPCs in sequence)
- [ ] **QST-05**: Player can view active quests and objectives in an in-game quest log UI
- [ ] **QST-06**: Completing a quest rewards gold (added to `global.player_gold`)
- [ ] **QST-07**: Completing a quest can reward a special item not available in the shop
- [ ] **QST-08**: Completing certain quests unlocks new NPC dialogue, areas, or interactions (access unlock rewards)
- [ ] **QST-09**: Quest state (active, progress counters, completed) persists across save/load

### Enemies

- [ ] **ENM-01**: Ranged enemy type — attacks from distance with projectiles, lower HP than melee
- [ ] **ENM-02**: Fast enemy type — high movement speed, low HP, rushes directly at player
- [ ] **ENM-03**: Tank enemy type — high HP, slow movement, high damage per hit
- [ ] **ENM-04**: All enemy types scale stats (HP, speed, damage) by floor range
- [ ] **ENM-05**: Pack / alert behavior — when one enemy spots the player, it signals nearby enemies to activate (signal-based, not per-frame polling)

### Dungeon

- [ ] **DNG-01**: Dungeon has 2–3 distinct visual themes based on floor range (e.g., floors 1–33 cave, 34–66 ruins, 67–100 abyss) — color palette or tileset change
- [ ] **DNG-02**: Dungeon floors can contain hidden rooms (accessible via secret passage or inspectable trigger; contains bonus treasure or lore)
- [ ] **DNG-03**: Every 25th floor is a boss floor (tougher enemy combination; player must clear room to advance)
- [ ] **DNG-04**: Lore objects appear in dungeon rooms (inspectable → opens dialogue UI with story fragment)

## v2 Requirements

### Dialogue (Post-v1)

- **DLG-V2-01**: Voiced dialogue (audio lines per NPC)
- **DLG-V2-02**: Visual dialogue editor / Dialogic integration

### Quests (Post-v1)

- **QST-V2-01**: More than 3 simultaneous active quests
- **QST-V2-02**: Timed quests
- **QST-V2-03**: Dungeon mid-run mini-quests (assigned by dungeon NPCs per floor)

### Enemies (Post-v1)

- **ENM-V2-01**: Boss enemy with unique attack pattern (not just stat-scaled variant)
- **ENM-V2-02**: Flying enemy type (ignores ground navigation)

### Dungeon (Post-v1)

- **DNG-V2-01**: Procedural dungeon rooms with proper tileset walls (replaces ColorRect)
- **DNG-V2-02**: Shop room spawning at fixed floors

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multiplayer | Single-player focus; architecture not designed for network |
| Crafting system | Not part of v1 game loop |
| Seasons / day-night cycle | Stardew aesthetic only, not mechanics |
| Mobile port | Desktop-first |
| Companion NPCs | Post-v1 scope |
| Full inventory system | v1 fetch quests use minimal item ID + count only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PRE-01 | Phase 1 | Pending |
| PRE-02 | Phase 1 | Pending |
| PRE-03 | Phase 1 | Pending |
| DLG-01 | Phase 2 | Complete |
| DLG-02 | Phase 2 | Complete |
| DLG-03 | Phase 2 | Complete |
| DLG-04 | Phase 2 | Complete |
| DLG-05 | Phase 2 | Pending |
| QST-01 | Phase 3 | Pending |
| QST-02 | Phase 3 | Pending |
| QST-03 | Phase 3 | Pending |
| QST-04 | Phase 3 | Pending |
| QST-05 | Phase 3 | Pending |
| QST-06 | Phase 3 | Pending |
| QST-07 | Phase 3 | Pending |
| QST-08 | Phase 3 | Pending |
| QST-09 | Phase 3 | Pending |
| ENM-01 | Phase 1 | Pending |
| ENM-02 | Phase 1 | Pending |
| ENM-03 | Phase 1 | Pending |
| ENM-04 | Phase 1 | Pending |
| ENM-05 | Phase 1 | Pending |
| DNG-01 | Phase 1 | Pending |
| DNG-02 | Phase 4 | Pending |
| DNG-03 | Phase 4 | Pending |
| DNG-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 27 total
- Mapped to phases: 27
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-08*
*Last updated: 2026-05-08 after initial definition*
