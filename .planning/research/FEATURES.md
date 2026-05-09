# Feature Landscape: NPC / Quest / Enemy / Dungeon Systems

**Domain:** 2D pixel art dungeon crawler RPG (Godot 4.6)
**Researched:** 2026-05-08
**Milestone scope:** NPC dialogue, quest system, enemy variety, dungeon visual variety + secrets
**Reference games:** Hades, Moonlighter, Enter the Gungeon, Stardew Valley, Dead Cells

---

## Table Stakes

Features players expect from the genre. Absence makes the game feel unfinished.

### Dialogue UX

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Dialogue box with NPC portrait / name label | Every RPG since SNES — players read who is talking | Low | Panel + label + portrait sprite |
| Advance-on-input (click/button to continue) | Standard pacing contract — players feel in control | Low | Input action, not auto-advance |
| Dialogue dismisses cleanly (no input bleed) | Input bleed causes accidental actions after close | Low | Consume input event in dialogue handler |
| NPC remembers state across visits | Repeating intro dialogue on every approach feels broken | Medium | Flag in `global.gd` per NPC ID |
| Dialogue pauses game / disables player input | Player shouldn't walk away mid-sentence | Low | `set_physics_process(false)` on player |
| Quest-giving dialogue leads directly into quest accept/decline | Players expect a clear transaction — talk → get quest | Medium | Dialogue node type: "offer_quest" |

### Quest Loop

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Quest journal / active quest tracker (HUD or menu) | Players forget objectives without this — mandatory | Medium | HUD label or pause-menu list |
| Objective counter for kill/fetch quests | "Kill 5 Goblins (2/5)" — absence is a major UX gap | Low | Reactive display off global state |
| Quest completion auto-detected (not manual turn-in only) | Hades and Gungeon: objectives track passively | Medium | Signal from kill/pickup events into quest manager |
| Turn-in dialogue distinct from regular NPC chat | Players need a clear "I'm done, collect reward" beat | Low | Dialogue tree branch gated on quest state |
| Gold reward delivered on turn-in | Economic loop closure — expected for all quest types | Low | Add to `global.gd` money on completion |
| At least 4 quest types: kill, fetch, reach floor, story | Variety prevents quest fatigue — all 4 are table stakes for a dungeon crawler | High | Each type needs its own completion check logic |

### Enemy Variety

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Visually distinct enemy silhouettes per type | Players read "danger type" from sprite — required | Medium | Separate sprites per enemy type |
| Behaviorally distinct attack patterns (melee vs ranged vs fast) | Moonlighter and Gungeon teach: same behavior = no challenge scaling | High | Separate scripts extending base enemy |
| Enemies deal different damage / have different HP pools | Stats differentiate threat level at a glance | Low | Export vars on each enemy script |
| Enemies that scale (or change composition) by floor depth | Floors 1-10 feel different from 50-60 — expected | Medium | Floor-ranged spawn tables |
| Death feedback (visual + sound or screen flash) | Kill confirmation is core game feel | Low | Particle or flash + existing hit system |

### Pack / Alert Behavior

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Enemies react when nearby ally is alerted | Enter the Gungeon / Hades: rooms wake together | Medium | Alert signal propagated via area or group |
| Chase stops at room boundary (or leash radius) | Enemies chasing through walls/infinite range feels broken | Low | Max chase distance or room-scoped group |
| Brief idle-to-alert animation or state change | Visual feedback that enemy "noticed" player | Low | State machine: IDLE → ALERT → CHASE |

### Dungeon Visual Variety

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Tileset theme changes by floor range (e.g. cave → ruins → deeper hell) | Every successful dungeon crawler does this — absence reads as laziness | High | 2-3 tileset swaps tied to floor range |
| Room size / shape variety | Identical rooms are disorienting and dull | Medium | Procedural or hand-authored room templates |
| Visual signposting for floor exit | Players must know where to go — standard | Low | Distinct tile/sprite at stairs/exit |

### Hidden Rooms / Secrets

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| At least one secret room type (hidden wall, locked door) | Secrets are table stakes in dungeon crawlers — Binding of Isaac proved this | Medium | Tile flag or collision layer trick |
| Secret contains meaningful reward (not filler) | Secrets that reward junk teach players to stop looking | Low | Design: gold pile, item, or lore fragment |
| Player agency to find it (breakable wall, lever, or pattern) | Random secrets feel random; interactable secrets feel earned | Medium | Interactable node type with visual hint |

---

## Differentiators

Features that make this game distinct — not expected by genre, but valued.

### Dialogue UX

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| NPC dialogue changes based on dungeon depth reached | Stardew: NPCs react to player progress. Rare in dungeon crawlers | Medium | Dialogue condition checks `global.deepest_floor` |
| NPCs have idle ambient lines (short, non-blocking) | Warmth — world feels alive without player interaction | Low | Proximity trigger → 1-line floating text |
| Story-chain quests that unlock new NPC dialogue arcs | Moonlighter does this — quests that evolve NPC relationships | High | Ordered quest chains, NPC "friendship" flag |
| Dungeon NPC (found mid-run) gives one-time hint or mini-quest | Surprise discovery — rare in dungeon crawlers | Medium | Dungeon NPC with disposable quest state per run |

### Quest Loop

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Story quests that reveal world lore gradually | Players invest in characters — rare in pure dungeon crawlers | High | Scripted dialogue sequences, not just objectives |
| Quest failure state with graceful handling (item lost, enemy escaped) | Most dungeon crawlers never fail quests — doing so adds stakes | Medium | Timeout or condition-fail path in quest manager |
| Quest rewards beyond gold: access unlocks, new areas | Moonlighter: quests open the shop. Non-gold rewards feel meaningful | Medium | Gate scene access on quest completion flag |

### Enemy Variety

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Enemy combo difficulty (tank + ranged = hard) | Enter the Gungeon: room compositions as difficulty knobs | Medium | Spawn table: weighted enemy group templates |
| Mini-boss enemy (stronger variant, not full boss) | Surprise spike — mid-floor encounter that demands attention | Medium | Scaled stats + distinct color/FX on normal enemy type |
| Enemy lore fragment on first kill | Hades: codex entries. Adds depth without mandatory reading | Low | First-kill flag per enemy type → lore popup or journal |

### Dungeon Design

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Lore objects in dungeon (readable signs, bones, murals) | Environmental storytelling — differentiates from pure combat crawlers | Medium | Interactable node type: LoreObject |
| Boss floors with distinct pre-boss atmosphere (lighting, music) | Tension spike before bosses — rare in procedural crawlers | Medium | Floor-range flag triggers ambience change |
| Secret lore rooms (not just reward rooms) | Secrets that tell story reward exploration intrinsically | Medium | LoreObject placed in secret rooms |
| Floor-specific ambient detail (different torch colors, crumbling walls) | Depth feeling without full tileset swap — quick visual variety | Low | Modulate color on tilemap per floor range |

---

## Anti-Features

Deliberate exclusions for v1. Build these and regret it.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Voiced dialogue / audio for NPC lines | Scope trap — localization, recording, sync complexity | Text only; sfx on dialogue open/advance is sufficient |
| Full dialogue editor / visual node graph tool | Over-engineering for a small NPC cast | JSON/Resource files authored by hand — PROJECT.md already decided this |
| Branching dialogue with 3+ player choices per node | Choice-heavy dialogue is a different game (Disco Elysium) | 2-option max: accept/decline quests, yes/no lore prompts |
| Quest board with 10+ simultaneous quests | Hades has ~3-5 active "boons" — more = decision paralysis | 2-3 active quests max, clear turn-in flow |
| Procedurally generated quest objectives | Complexity explosion — edge cases multiply | Hand-authored quest list, data-driven parameters (kill count, item ID) |
| Crafting integration in v1 | PROJECT.md: explicitly out of scope | Shop upgrade system already handles economy |
| Enemy AI pathfinding beyond NavigationAgent2D | Custom steering behavior is a rabbit hole | Tune NavAgent2D parameters; add aggro radius |
| Physics-based traps / environment hazards | Fun but expensive to tune in pixel art dungeon | Puzzle types already cover environmental challenge |
| Full skill tree / build system | Balancing multiplies by every enemy type added | Upgrade shop covers progression in v1 |
| Companion NPCs that follow player | AI coordination with player + enemies in tight rooms = nightmare | Dungeon NPC as stationary encounter only |

---

## Feature Dependencies

```
Dialogue system (data + UI)
  → Quest offer / accept dialogue (quest system requires dialogue)
  → NPC state memory (requires global.gd flags)
  → Story quest chains (requires dialogue + quest system both working)

Kill quest
  → Enemy death signal wired to quest manager

Fetch quest
  → Item pickup signal wired to quest manager
  → Item type exists in inventory/global state

Reach-floor quest
  → Floor number tracked in global.gd (already exists)
  → Floor arrival signal or flag-poll check

Pack/alert behavior
  → Base enemy exists (already exists)
  → Group or area-based alert propagation

Enemy type variety
  → Base enemy script exists (already exists)
  → Each type: separate script + sprite

Dungeon visual variety (tileset themes)
  → Floor range detection (already exists)
  → 2-3 art asset sets exist or are created

Hidden rooms
  → Dungeon generation supports additional room types
  → Interactable node type (also needed for lore objects)

Boss floors
  → Floor range detection
  → Boss enemy type (distinct from regular enemy variety)
```

---

## MVP Recommendation

Build in this order — each layer unblocks the next.

**Layer 1 — Foundation (required before anything else)**
1. Dialogue system (data format + UI panel + input handling) — everything else blocks on this
2. NPC state flags in `global.gd`

**Layer 2 — Quest Core**
3. Quest manager autoload (state machine: inactive → active → complete)
4. Kill quest type + HUD objective counter
5. Reach-floor quest type (simplest — already have floor number)
6. Turn-in dialogue flow + gold reward

**Layer 3 — Enemy Variety**
7. 2 additional enemy types (ranged + fast) as scripts extending base
8. Pack/alert behavior (group-based aggro)
9. Floor-ranged spawn tables

**Layer 4 — Dungeon Depth**
10. Fetch quest type + basic item type
11. Dungeon visual variety (tileset swap by floor range)
12. Hidden room type (one variant)
13. Lore objects (interactable node)

**Defer to post-v1:**
- Story quest chains (high complexity, needs content)
- Boss floors with distinct atmosphere (needs art + audio)
- Enemy lore fragments (needs journal UI)
- Dungeon NPC mid-run mini-quests (needs run-scoped state design)

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Dialogue UX table stakes | HIGH | Consistent across Stardew, Hades, Moonlighter — well-established genre pattern |
| Quest loop table stakes | HIGH | All 4 types (kill/fetch/floor/story) present in Moonlighter and Hades |
| Enemy variety | HIGH | Enter the Gungeon / Dead Cells design is well-documented |
| Pack behavior design | MEDIUM | Hades uses room-scope alerting — implementation details vary by engine |
| Dungeon secret patterns | HIGH | Binding of Isaac / Gungeon patterns are genre-defining |
| Differentiators | MEDIUM | Based on what's rare-but-valued in the genre, not measured player research |

---

## Sources

- Hades (Supergiant Games) — NPC relationship/dialogue progression model, room-scope enemy behavior
- Moonlighter (Digital Sun) — quest→shop-unlock loop, dungeon NPC encounters, tileset depth theming
- Enter the Gungeon (Dodge Roll) — room composition as difficulty, secret room patterns, enemy silhouette design
- Stardew Valley (ConcernedApe) — NPC state memory, progress-reactive dialogue, warmth-through-ambient-lines
- Dead Cells (Motion Twin) — enemy type behavioral differentiation (melee/ranged/elite), visual floor theming
- The Binding of Isaac (Edmund McMillen) — secret room conventions, hidden wall discovery pattern
