---
quick_id: 260529-utn
slug: ui-scale-finish-camera-zoom-limits-hud-d
status: complete
date: 2026-05-30
commits:
  - "c3d7a6f fix(ui-scale): remove duplicate hud autoload, correct dead SubViewport size"
  - "b76bb32 feat(ui-scale): world camera zoom 2x + tilemap-bounds limits"
  - "52303d9 feat(ui-scale): add cliffside camera with zoom 2x + tilemap-bounds limits"
  - "15733ad fix(ui-scale): force nearest texture filter on SubViewport canvas"
  - "f76d41a feat(world): scale NPCs to 4x and respread spawns to match world scale"
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

## Follow-up (same session, from user feedback)
6. **Blur fix** (`script/main.gd`) — pixel art was blurry at native window
   resolution (my earlier MCP shots were downscaled to 960, which hid it). Root
   cause: **SubViewports do NOT inherit the project `default_texture_filter`;
   they default to linear**, so the 8×-magnified art (4× tilemap × 2× camera)
   smeared. Added `RenderingServer.viewport_set_default_canvas_item_texture_filter(
   vp.get_viewport_rid(), CANVAS_ITEM_TEXTURE_FILTER_NEAREST)`. Crisp at full
   1920×1080. `15733ad`
7. **World NPC scale/position** (`npc.gd`, `shop_npc.gd`, `blacksmith_npc.gd`,
   `world.gd`) — NPCs built at scale 1 (tiny vs the 4× world); elder spawned on
   the player's exact spawn `(167,110)`. Scaled visuals to 4×, raised labels,
   interaction radius 20→36, respread spawns (shop `105,125` / elder `210,125` /
   smith `285,125`). `f76d41a`

## OPEN — paused for user decision (RE-ASK on resume)
User answered "pause this session and ask me again" to both of these:
- **SMITH appearance**: blacksmith is still a plain amber `ColorRect` placeholder
  (`blacksmith_npc.gd._build_visual`). Decide: give it a `chest_01.png` sprite
  like SHOP/elder (e.g. a different frame), or keep the distinct square.
- **NPC exact layout / scale**: current spread + 4× scale is a reasonable default;
  the elder currently sits fairly close to the player. Re-ask for precise x,y per
  NPC (and/or a different scale) if the user wants a specific town layout.
