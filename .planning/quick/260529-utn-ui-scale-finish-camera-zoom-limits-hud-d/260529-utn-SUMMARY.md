---
quick_id: 260529-utn
slug: ui-scale-finish-camera-zoom-limits-hud-d
status: complete
date: 2026-05-30
commits:
  - "c3d7a6f fix(ui-scale): remove duplicate hud autoload, correct dead SubViewport size"
  - "b76bb32 feat(ui-scale): world camera zoom 2x + tilemap-bounds limits"
  - "52303d9 feat(ui-scale): add cliffside camera with zoom 2x + tilemap-bounds limits"
---

# Quick Task 260529-utn — Summary

Finished the unfinished tail of the SubViewport UI-scaling work. User approved
**Option 1** (cozy ~2× zoom-in) + kill off-map gray + dedupe the HUD autoload.
Diagnosed and verified entirely live through the Godot MCP editor (run + screenshot).

## What changed
1. **HUD autoload dedupe** (`project.godot`) — removed the duplicate lowercase
   `hud` autoload; kept `HUD` (all call sites use it). Was spawning a second,
   invisible HUD CanvasLayer. `c3d7a6f`
2. **Dead SubViewport size** (`scenes/main.tscn`) — `Vector2i(1280,720)` →
   `Vector2i(960,540)` to match the runtime size forced by
   `SubViewportContainer.stretch=true`. `c3d7a6f`
3. **World camera** (`script/world.gd`) — new `_setup_camera()`: `zoom=(2,2)`,
   position + limit smoothing, and limits clamped to the `TileMap/Ground`
   used-rect (via global transform, so the 4× layer scale is handled). `b76bb32`
4. **Cliffside camera** (`script/cliff_side.gd`) — the scene had **no Camera2D**;
   added one under the player at runtime with the same zoom + limits +
   `reset_smoothing()`. `52303d9`
5. **Dungeon** — already correct (`dungeon.gd:279-293`: zoom 2 + limits). No
   change; used as the reference and confirmed visually consistent.

## Verification (live, per scene + end-to-end)
- World (standalone): map fills viewport, player cozy-framed, no off-map gray.
- Cliffside (standalone): player now framed (was unframed), no gray.
- Dungeon (standalone): floor fills viewport, player same size — consistent.
- Boot (`main.tscn`): home screen renders, no errors.
- **End-to-end**: New Game → world through the real SubViewport pipeline renders
  cozy + full-screen with HUD and NPC prompts. No parse/runtime errors in game logs.

## Notes / deliberately out of scope
- Kept `project.godot window/stretch/scale=2.0` — it yields a good chunky
  960×540 pixel-art internal resolution under the current SubViewport setup.
- Did **not** reconcile the deeper coordinate-scale mismatch (world/cliffside
  tilemaps render at 4× while the dungeon is built at native scale, with a 4×
  player in all scenes). Because the camera sits under the 4× player in every
  scene, the player is the same on-screen size everywhere, so per-scene visual
  tuning gives a consistent cozy feel without that larger refactor. Flag for
  later if pixel-for-pixel world/dungeon consistency is ever wanted.
