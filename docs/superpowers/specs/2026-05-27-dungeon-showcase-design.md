# Dungeon Theme Showcase Scene — Design Spec

**Date:** 2026-05-27  
**Status:** Approved

## Goal

A standalone test scene (`dungeon_showcase.tscn`) that lets a developer walk through all three dungeon themes — CAVE, RUINS, and ABYSS — with live enemies in each room, without touching any save state.

Mirrors `puzzle_test.tscn` in purpose (developer sandbox) but showcases environment themes instead of puzzle types.

---

## Layout

Three rooms connected by two hallways, arranged left-to-right on a 1600×320 canvas.

```
[CAVE 0..480] [hall 480..560] [RUINS 560..1040] [hall 1040..1120] [ABYSS 1120..1600]
```

**Constants:**
- `ROOM_W = 480`, `ROOM_H = 320`, `TILE = 16`
- `HALL_W = 80`, `HALL_H = 96`
- `HALL_WALL_H = (ROOM_H - HALL_H) / 2 = 112`  (solid wall above/below the opening)
- Hallway opening: `y = 112..208` (centered vertically)

---

## Rooms

### Walls

Each room has TILE-thick walls. Where a hallway connects, the shared wall is split into two segments (above and below the 96px gap):

| Wall segment | CAVE | RUINS | ABYSS |
|---|---|---|---|
| Top | full width | full width | full width |
| Bottom | full width | full width | full width |
| Left | full height | split (gap y=112..208) | split (gap y=112..208) |
| Right | split (gap y=112..208) | split (gap y=112..208) | full height |

Hallway floor uses the left room's `floor` color. Hallway wall blocks (above/below opening) use the left room's `wall` color.

### Labels

Each room has a label in the top-left corner (inside walls, offset 20px from top-left):
- CAVE: `"CAVE  ·  Floors 1–33"`
- RUINS: `"RUINS  ·  Floors 34–66"`
- ABYSS: `"ABYSS  ·  Floors 67–100"`

Font size 14, color white.

### Theme colors (copied from dungeon.gd)

```
THEME_CAVE:  floor=(0.07,0.06,0.09)  wall=(0.18,0.16,0.22)  accent=(0.35,0.30,0.55)
THEME_RUINS: floor=(0.10,0.08,0.05)  wall=(0.30,0.22,0.14)  accent=(0.55,0.40,0.20)
THEME_ABYSS: floor=(0.02,0.02,0.08)  wall=(0.08,0.06,0.20)  accent=(0.30,0.10,0.60)
```

---

## Enemies

Spawned with `load(ENEMY_SCENE).instantiate()` + `set_script()`, same pattern as `dungeon.gd`. No stat scaling (floor multiplier = 1.0).

| Room | Count | Scripts |
|------|-------|---------|
| CAVE | 2 | base, base |
| RUINS | 2 | base, fast |
| ABYSS | 3 | ranged, fast, tank |

Spawn positions are fixed (not random) so the scene is reproducible on each open. Placed in the inner half of each room, away from walls and the hallway opening.

---

## Navigation

Single `NavigationRegion2D` baked in `_ready()` covering all walkable area:
- Three room interiors (TILE-inset from walls)
- Two hallway passages (the 80×96 openings)

Enemies use `NavigationAgent2D` (created by their own `_ready()`). With a valid nav mesh they will chase the player normally.

---

## Player

- Spawned from `res://scenes/player.tscn`
- Start position: CAVE room center `(240, 160)`
- `Camera2D` attached to player with limits `(0, 0, 1600, 320)` and smoothing enabled

---

## Files

| File | Action |
|------|--------|
| `scenes/dungeon_showcase.tscn` | Create new (empty Node2D + script attached) |
| `script/dungeon_showcase.gd` | Create new |

No changes to any existing file. No `global` reads or writes.

---

## Out of Scope

- No puzzles, exits, save points, or HUD
- No quest or dialogue integration
- No procedural obstacle generation
- Enemies do not drop money (they do by default but that's fine — no shop to spend it in)
