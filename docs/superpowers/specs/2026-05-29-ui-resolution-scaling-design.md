# UI Resolution Scaling Design

**Date:** 2026-05-29  
**Status:** Approved  
**Topic:** Resolution-independent UI via SubViewport separation

---

## Problem

The game renders at a fixed viewport (previously 1280×720, `stretch/scale=2.0`). All UI is built procedurally in GDScript and suffers three issues:

1. **HUD too small at high res** — HP bar, money label, and lore panel use hardcoded `position` and `size` in game-world pixels with no scaling.
2. **UI breaks on resize** — absolute pixel positions don't reflow when the window size changes.
3. **Panels not centered** — modal panels (pause, shop, home menus) use `PRESET_CENTER` anchors but with fixed pixel offsets, so they can appear off-center at unexpected resolutions.

---

## Goal

- Game world renders pixel-perfect at **1920×1080** with nearest-neighbor filter.
- All UI (HUD, pause, shop, home menus, death screen) renders at **native window resolution** using anchor-based layout.
- Existing scene routing and game logic are unaffected.

---

## Architecture

```
SceneTree.root  (native window resolution)
├── global        (autoload — existing)
├── pause_menu    (autoload — existing, anchor layout fixes)
├── death_screen  (autoload — existing, anchor layout fixes)
├── ui_root       (autoload — NEW, CanvasLayer layer=10)
├── hud           (autoload — NEW, CanvasLayer layer=5)
└── main          (current_scene — NEW root scene)
    └── SubViewportContainer  (PRESET_FULL_RECT, stretch=true)
        └── SubViewport  (size=1920×1080, texture_filter=nearest)
            └── [active game scene: home_screen / world / dungeon / etc.]
```

All autoloads are children of `SceneTree.root` (the native-resolution root Viewport). The `SubViewport` is a separate rendering context at 1920×1080 — game scenes load here. UI panels attach to `UIRoot` or the HUD autoload, both at native resolution.

---

## Components

### 1. `scenes/main.tscn` + `script/main.gd` (NEW)

The new `run/main_scene`. Replaces `home_screen.tscn` as the entry point.

**Scene tree:**
```
Node  (main.gd)
└── SubViewportContainer  (anchors: full rect, stretch=true)
    └── SubViewport  (size: Vector2(1920, 1080), render_target_update_mode: always)
```

**`main.gd` responsibilities:**
- On `_ready()`: set `global.game_viewport = $SubViewportContainer/SubViewport`, load `home_screen.tscn` into SubViewport, connect to `global.scene_change_requested`.
- On `scene_change_requested(path)`: free all current children of SubViewport, instantiate and add new scene.

```gdscript
func _ready() -> void:
    global.game_viewport = $SubViewportContainer/SubViewport
    global.scene_change_requested.connect(_on_scene_change)
    _load_scene("res://scenes/home_screen.tscn")

func _on_scene_change(path: String) -> void:
    _load_scene(path)

func _load_scene(path: String) -> void:
    var vp := $SubViewportContainer/SubViewport
    for child in vp.get_children():
        child.queue_free()
    vp.add_child(load(path).instantiate())
```

---

### 2. `script/ui_root.gd` (NEW autoload `UIRoot`)

A `CanvasLayer` at layer=10. Single attach point for all overlay panels.

```gdscript
extends CanvasLayer

func add_ui(node: Node) -> void:
    add_child(node)

func remove_ui(node: Node) -> void:
    if node.get_parent() == self:
        remove_child(node)
```

All existing code that adds panels to a local CanvasLayer changes to `UIRoot.add_ui(panel)` / `UIRoot.remove_ui(panel)`.

---

### 3. `script/hud.gd` (NEW autoload `HUD`)

A `CanvasLayer` at layer=5. Owns the in-game HUD: HP bar, money label, lore panel.

**Built using anchor-based layout** — a top-left `MarginContainer` with `PRESET_TOP_LEFT` as the root, containing HP bar row and money/lore labels. No hardcoded `position` or `size`.

**Public API:**
- `show()` / `hide()` — player calls on `_ready()` / `_exit_tree()`
- `update_hp(pct: float)` — updates HP bar fill
- `update_money(amount: int)` — updates money label
- `show_lore(text: String)` / `hide_lore()` — shows/hides lore hint panel

Hidden by default. Only visible when a player scene is active.

---

### 4. `script/global.gd` (MODIFIED — additions only)

Add to the existing singleton:

```gdscript
var game_viewport: SubViewport = null
signal scene_change_requested(path: String)

func go_to(path: String) -> void:
    scene_change_requested.emit(path)
```

`go_to()` is the new scene-change entry point. All scripts call `global.go_to(path)` instead of `get_tree().change_scene_to_file(path)`.

---

### 5. `script/player.gd` (MODIFIED)

- Remove `_build_hud()` function and all HUD node references (`_hud_hp_bar_fg`, `_hud_hp_label`, `_hud_money_label`, `_lore_panel`, `_lore_label`, `_hud_layer`).
- On `_ready()`: call `HUD.show()`, `HUD.update_hp(...)`, `HUD.update_money(...)`.
- On `_exit_tree()`: call `HUD.hide()`.
- On HP change: call `HUD.update_hp(pct)`.
- On money change: call `HUD.update_money(global.player_money)`.
- On lore pickup: call `HUD.show_lore(text)` / `HUD.hide_lore()`.
- Shop overlay panel: add to `UIRoot` instead of own CanvasLayer.

---

### 6. `script/home_screen.gd` (MODIFIED)

- Background color rect / art stays in the scene (renders inside SubViewport — pixel-perfect).
- All `CanvasLayer` + panel building moves to attach to `UIRoot` instead of `self`.
- On `_exit_tree()`: remove panels from `UIRoot` (so they don't persist when scene changes).

---

### 7. `script/pause_menu.gd` (MODIFIED — minor)

Already an autoload at root level. Its CanvasLayer is already native-resolution. Changes:
- Add overlays to `UIRoot` instead of own CanvasLayer for consistent layering.
- Ensure all panels use `PRESET_FULL_RECT` overlays and `PRESET_CENTER` modal panels (already mostly done).

---

### 8. `script/death_screen.gd` (MODIFIED — minor)

Same pattern as `pause_menu.gd` — already at root level, minor anchor/UIRoot wiring.

---

### 9. `script/world.gd`, `cliff_side.gd`, `dungeon.gd` (MODIFIED — search/replace)

Every `get_tree().change_scene_to_file(path)` → `global.go_to(path)`.

Approximately 8–10 call sites across these three files.

---

## Project Settings (`project.godot`)

| Setting | Old | New |
|---|---|---|
| `application/run/main_scene` | `res://scenes/home_screen.tscn` | `res://scenes/main.tscn` |
| `display/window/size/viewport_width` | `1280` | `1920` |
| `display/window/size/viewport_height` | `720` | `1080` |
| `display/window/stretch/mode` | (unset / scale=2.0) | `disabled` |
| `display/window/stretch/scale` | `2.0` | (remove) |

The SubViewport handles its own 1920×1080 rendering. No engine-level stretch needed.

---

## Data Flow

**Scene change:**
```
world.gd: global.go_to("res://scenes/dungeon.tscn")
  → global emits scene_change_requested
  → main.gd._on_scene_change() frees old children, loads dungeon.tscn into SubViewport
```

**HUD update:**
```
player.gd takes damage → calls HUD.update_hp(pct)
  → HUD (native-res CanvasLayer) updates Control nodes
  → renders at native window resolution, always correct size
```

**Pause overlay:**
```
ESC pressed → pause_menu._on_esc()
  → builds panel, UIRoot.add_ui(overlay)
  → overlay renders at native resolution, centered by anchors
```

---

## Error Handling

- `_load_scene()` in `main.gd`: if `load(path)` returns null (missing scene), print error and do not crash — current scene stays.
- `UIRoot.remove_ui()`: guards against double-free with `get_parent() == self` check.
- `global.go_to()`: no-op guard if `scene_change_requested` has no connections (edge case during boot).

---

## Out of Scope

- Changing game art resolution or tile sizes — game world logic is untouched.
- Font/theme changes — existing `UITheme` carries over as-is.
- Any new gameplay features.
