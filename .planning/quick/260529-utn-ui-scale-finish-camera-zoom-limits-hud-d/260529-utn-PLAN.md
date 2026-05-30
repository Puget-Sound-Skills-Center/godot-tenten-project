---
quick_id: 260529-utn
slug: ui-scale-finish-camera-zoom-limits-hud-d
status: in-progress
date: 2026-05-30
---

# Quick Task 260529-utn — Finish UI-scale: camera zoom, limits, HUD dedupe

Finishes the unfinished tail of the SubViewport UI-scaling work (last commit
`dd20d4f "Change UI scale but Still have to working on it"`). Diagnosed live by
running the game through the Godot MCP editor: home screen + HUD autoload render
correctly; the game world renders zoomed-out with off-map gray at the edges and
inconsistent camera zoom. User approved **Option 1** (zoom in to a consistent
~2x cozy/Stardew feel) + kill gray edges + dedupe autoload.

## Key findings (live inspection)
- `project.godot` registers the HUD autoload **twice** (`hud` + `HUD` → same
  script = two CanvasLayer instances; one renders invisibly). All call sites use
  capital `HUD`; zero lowercase `hud.` singleton refs. Safe to drop `hud`.
- `player.tscn` root is `scale = Vector2(4,4)`; world/dungeon cameras are
  children of that player, so they inherit 4×. Empirically, current world view
  ≈ camera `zoom=1`; `zoom=2` ≈ 2× cozier (matches dungeon).
- World/cliffside tilemaps render at 4× (consistent with the 4× player).
- **Dungeon already correct** (`dungeon.gd:279-293`): `zoom=(2,2)`, limits
  `0..room_w/0..room_h`, smoothing + drag. Use as the template.
- **Cliffside has NO Camera2D** (`cliff_side.tscn`); player at `(1408,1441)`.
  Needs a camera added.
- `main.tscn` SubViewport `size=Vector2i(1280,720)` is dead — overridden to
  960×540 at runtime by `SubViewportContainer.stretch=true`.

## Tasks (atomic commits, verify each scene live)
1. **Dedupe HUD autoload** — remove lowercase `hud=` line from `project.godot`.
2. **main.tscn size** — `Vector2i(1280,720)` → `Vector2i(960,540)` (clarity).
3. **World camera** — `zoom=(2,2)` + runtime limits from `TileMap/Ground`
   used-rect; smoothing + drag to match dungeon. Verify world live, tune zoom.
4. **Cliffside camera** — add Camera2D under player; same zoom + runtime limits.
   Verify cliffside live.
5. **Dungeon** — verify live; minor-tune only if inconsistent. (already done)

## Out of scope (explicitly NOT doing)
- Removing `project.godot window/stretch/scale=2.0` — it gives a good chunky
  960×540 pixel-art internal resolution under the current SubViewport setup.
- Reconciling the deeper world(4×)-vs-dungeon(native) coordinate-scale mismatch
  — bigger refactor; per-scene visual tuning is sufficient for the cozy feel.

## Verify
- World: player framed, no off-map gray at edges, cozier than before.
- Cliffside: player on-screen and framed, no gray, consistent feel.
- Dungeon: still framed correctly.
- HUD still renders (one instance), HP/gold update.
