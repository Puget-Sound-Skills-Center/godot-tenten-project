# Death Screen — Design Spec

**Date:** 2026-05-27  
**Status:** Approved

## Goal

When the player's HP reaches 0 anywhere in the game, pause the scene and show a "YOU DIED" overlay with two options: reload the last save, or return to the home screen.

---

## Architecture

New autoload `death_screen` extending `CanvasLayer` — mirrors the existing `pause_menu` pattern exactly. Polls `global.player_dead` in `_process()`. When triggered, shows overlay; button callbacks load or reset.

No per-scene changes needed. Works in dungeon, world, and cliff_side automatically.

---

## Changes to `global.gd`

Add two variables:

```gdscript
var active_save_slot := 1      # set when a slot is loaded; used by death screen to reload
var player_dead := false       # set true by player.gd on death; cleared by death_screen on dismiss
```

---

## Changes to `player.gd`

In `_physics_process`, the block at line 57 already sets `player_alive = false`. Extend it to also set the global flag — but only once (guard with `player_alive` already false check):

```gdscript
if health <= 0:
    if player_alive:          # first frame of death only
        global.player_dead = true
    player_alive = false
    health = 0
```

No other changes to `player.gd`. Movement already stops when `player_alive` is false (player_movement is not called when dead — verify this holds).

---

## Changes to `home_screen.gd`

In `_on_load_slot`, after a successful load, record the active slot:

```gdscript
func _on_load_slot(slot: int) -> void:
    if not global.load_from_slot(slot):
        ...
        return
    global.active_save_slot = slot    # ← add this line
    ...
```

New game does not set `active_save_slot` (there is no save to reload on death during a new game run — the Load Last Save button is hidden/disabled in that case; see death_screen below).

---

## New: `script/death_screen.gd` (autoload)

Extends `CanvasLayer`. Layer = 60 (above pause_menu at 50). `process_mode = PROCESS_MODE_ALWAYS`.

### Visibility logic

- Hidden by default (`visible = false`)
- `_process()` checks `global.player_dead` — when it becomes true, calls `_show()`
- `_show()` sets `visible = true` and pauses the scene tree: `get_tree().paused = true`

### UI layout (built in `_ready()`, hidden until triggered)

Dark full-screen backdrop: `Color(0.0, 0.0, 0.0, 0.75)`.

Centered panel (400×220) containing:
- **"YOU DIED"** label — large font (32px), red `Color(0.85, 0.20, 0.25)`
- **"Load Last Save"** button — visible only when `global.active_save_slot` has a valid save file (`FileAccess.file_exists("user://save_slot_%d.cfg" % global.active_save_slot)`)
- **"Home Screen"** button — always visible

### Button callbacks

**Load Last Save:**
```
global.player_dead = false
global.load_from_slot(global.active_save_slot)
get_tree().paused = false
visible = false
# route to saved scene (same logic as home_screen._on_load_slot)
var scene_file := "res://scenes/world.tscn"
match global.current_scene:
    "cliff_side": scene_file = "res://scenes/cliff_side.tscn"
    "dungeon":    scene_file = "res://scenes/dungeon.tscn"
get_tree().change_scene_to_file(scene_file)
```

**Home Screen:**
```
global.player_dead = false
global.reset_for_new_game()
get_tree().paused = false
visible = false
get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
```

---

## Changes to `project.godot`

Register the new autoload under `[autoload]`:

```
death_screen="*res://script/death_screen.gd"
```

---

## `player_dead` flag lifecycle

| Event | `player_dead` value |
|---|---|
| Game starts / new game | `false` |
| Player HP hits 0 | set to `true` by `player.gd` |
| Scene reloads (new floor, etc.) | `player_dead` persists in `global` until cleared |
| Load Last Save clicked | cleared to `false` by `death_screen` |
| Home Screen clicked | cleared to `false` by `death_screen` |

`global.player_dead` is NOT cleared on `reset_for_new_game()` — `death_screen` always clears it explicitly before any scene transition.

---

## Out of Scope

- No animation or transition effect on death (instant overlay)
- No "respawn at checkpoint" option
- No death counter or statistics
- `dungeon_showcase.tscn` is unaffected (player can die there but no save exists — Load Last Save will be hidden)
