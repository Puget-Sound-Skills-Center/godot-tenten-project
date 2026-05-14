# Roadmap: Dungeon Explorer RPG

## Overview

Four phases that build the game's active systems on top of the existing working loop. Phase 1 fixes critical bugs and builds the enemy variety + dungeon theming foundation. Phase 2 adds the full dialogue system. Phase 3 builds the quest system on top of dialogue and enemy tracking. Phase 4 delivers dungeon depth: hidden rooms, boss floors, and lore objects.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Enemy Enhancement + Dungeon Theming Foundation** - Bug fixes, enemy_base refactor, 3 new enemy types, pack alert, stat scaling, visual themes (completed 2026-05-13)
- [x] **Phase 2: Dialogue System** - Dialogue data/UI autoloads, NPC wiring, branching trees, quest offer/decline flow (completed 2026-05-09)
- [ ] **Phase 3: Quest System** - Quest data/manager autoloads, all 4 quest types, quest log UI, all reward types, save/load integration
- [ ] **Phase 4: Dungeon Depth** - Hidden rooms, boss floors, lore objects

## Phase Details

### Phase 1: Enemy Enhancement + Dungeon Theming Foundation
**Goal**: Players encounter meaningfully different enemies per floor range in a visually distinct dungeon — and the game no longer crashes or misreports health
**Depends on**: Nothing (first phase)
**Requirements**: PRE-01, PRE-02, PRE-03, ENM-01, ENM-02, ENM-03, ENM-04, ENM-05, DNG-01
**Success Criteria** (what must be TRUE):
  1. Player can fight ranged, fast, and tank enemies — each with distinct movement and attack behavior
  2. Enemies on floor 50+ are visibly tougher than floor 1 enemies (higher HP, speed, damage)
  3. When one enemy spots the player, nearby enemies activate — without per-frame polling
  4. The dungeon's color palette or tileset visibly changes at floor 34 and floor 67
  5. Health bars show correct max health for every enemy type; no freed-reference crashes occur
**Plans**: 4 plans
Plans:
- [x] 01-PLAN-A.md — PRE fixes (freed-ref crash, health bar max, spawn cap) + enemy_base.gd + player.gd take_damage
- [x] 01-PLAN-B.md — Enemy variant scripts: enemy_ranged.gd, enemy_fast.gd, enemy_tank.gd
- [x] 01-PLAN-C.md — dungeon.gd: variant spawning, stat scaling, dungeon themes (cave/ruins/abyss)
- [x] 01-PLAN-D.md — Pack alert system verification and hardening in enemy_base.gd

### Phase 2: Dialogue System
**Goal**: Players can have stateful, branching conversations with NPCs — including quest offer/decline — with the game pausing during dialogue
**Depends on**: Phase 1
**Requirements**: DLG-01, DLG-02, DLG-03, DLG-04, DLG-05
**Success Criteria** (what must be TRUE):
  1. Player can walk up to any NPC and open a dialogue panel showing portrait, name, and text — advancing on input
  2. Dialogue can present 2-choice branches and the NPC responds differently based on player choice
  3. An NPC remembers if the player already accepted a quest and shows different dialogue on repeat visits
  4. Player can accept or decline a quest offer inline in dialogue; declining causes the NPC to respond accordingly
  5. A dungeon NPC (merchant or lore figure) appears inside dungeon rooms and is interactable
**Plans**: TBD
**UI hint**: yes

### Phase 3: Quest System
**Goal**: Players can receive, track, and complete all four quest types — with rewards that persist across save/load
**Depends on**: Phase 2
**Requirements**: QST-01, QST-02, QST-03, QST-04, QST-05, QST-06, QST-07, QST-08, QST-09
**Success Criteria** (what must be TRUE):
  1. Player can accept a kill quest and see enemy kill count auto-increment in the quest log
  2. Player can pick up a fetch item in the dungeon, return to an NPC, and complete the quest
  3. Player can complete a reach-floor quest by arriving at the target floor alive
  4. Player can follow a story chain quest across multiple NPCs in sequence to completion
  5. Quest log UI shows all active quests and current objectives at any time
  6. Completing quests awards gold, can grant special items, and can unlock new NPC dialogue or areas — all persisting after save/load
**Plans**: 7 plans
Plans:
- [ ] 03-01-PLAN.md — Wave 0: global.gd dicts (quest_state / items / unlocks) + quest_data.gd autoload + project.godot registration (autoloads + Tab input)
- [ ] 03-02-PLAN.md — Wave 1: quest_manager.gd autoload (accept / complete / kill / floor / chain logic + query helpers)
- [ ] 03-03-PLAN.md — Wave 2: integration hooks — enemy_base kill hook, dungeon fetch chest + reach-floor hook, dialogue_manager action dispatch
- [ ] 03-04-PLAN.md — Wave 2: quest_log.gd CanvasLayer overlay (Tab toggle, pause, max-3 entry display)
- [ ] 03-05-PLAN.md — Wave 3: blacksmith_npc.gd + world.gd spawn + npc.gd / dungeon_dialogue_npc.gd start_node selectors (NPC behavioral wiring)
- [ ] 03-05B-PLAN.md — Wave 3: dialogue_data.gd nodes — all Phase 3 quest dialogue trees for elder, blacksmith, dungeon_merchant (parallel with 03-05)
- [ ] 03-06-PLAN.md — Wave 4: lore artifact HUD slot in player.gd + cliff_side secret door (access unlock reward)
**UI hint**: yes

### Phase 4: Dungeon Depth
**Goal**: Dungeon runs contain hidden rooms, boss floors, and lore objects that reward exploration and make each run feel purposeful
**Depends on**: Phase 2
**Requirements**: DNG-02, DNG-03, DNG-04
**Success Criteria** (what must be TRUE):
  1. Player can find and enter a hidden room via a secret passage or inspectable trigger — and find bonus treasure or lore inside
  2. Every 25th floor is a boss floor with a tougher enemy combination; player must clear the room to advance
  3. Player can inspect a lore object in a dungeon room and read a story fragment via the dialogue UI
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Enemy Enhancement + Dungeon Theming Foundation | 4/4 | Complete | 2026-05-13 |
| 2. Dialogue System | 4/4 | Complete   | 2026-05-09 |
| 3. Quest System | 0/6 | Not started | - |
| 4. Dungeon Depth | 0/TBD | Not started | - |
