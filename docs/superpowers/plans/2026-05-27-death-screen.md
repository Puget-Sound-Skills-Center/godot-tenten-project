# Death Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a "YOU DIED" overlay with Load Last Save / Home Screen buttons whenever player HP hits 0, in any scene.

**Architecture:** New `death_screen` autoload (CanvasLayer, layer=60) polls `global.player_dead`. `player.gd` sets the flag on first death frame. `home_screen.gd` tracks the active save slot. Mirrors the existing `pause_menu` autoload pattern exactly.

**Tech Stack:** Godot 4.6 / GDScript

---

## Files

| File | Action |
|---|---|
| `script/global.gd` | Add `active_save_slot` and `player_dead` vars |
| `script/player.gd` | Set `global.player_dead = true` on first death frame |
| `script/home_screen.gd` | Set `global.active_save_slot = slot` on successful load |
| `script/death_screen.gd` | Create — new autoload overlay |
| `project.godot` | Register `death_screen` autoload |

---

## Task 1: Add vars to global.gd

**Files:**
- Modify: `script/global.gd`

- [ ] **Add two vars after `var player_current_health = -1` (line 32)**

Current line 32:
```gdscript
var player_current_health = -1
```

Add directly after it:
```gdscript
var active_save_slot := 1
var player_dead := false
```

- [ ] **Verify by reading back lines 32-35** — confirm both vars are present with correct types.

- [ ] **Commit**

```bash
git add script/global.gd
git commit -m "feat(death): add active_save_slot and player_dead to global"
```

---

## Task 2: Set death flag in player.gd

**Files:**
- Modify: `script/player.gd`

- [ ] **Replace the death block in `_physics_process` (lines 57-59)**

Current:
```gdscript
	if health <= 0:
		player_alive = false
		health = 0
```

Replace with:
```gdscript
	if health <= 0:
		if player_alive:
			global.player_dead = true
		player_alive = false
		health = 0
```

The `if player_alive` guard ensures `global.player_dead = true` fires only once (the first frame health hits 0), not every frame thereafter.

- [ ] **Verify:** Run the game, enter dungeon, let enemies kill the player. Confirm `global.player_dead` becomes true (death_screen not yet built — just confirm no crash).

- [ ] **Commit**

```bash
git add script/player.gd
git commit -m "feat(death): set global.player_dead on first death frame"
```

---

## Task 3: Track active slot in home_screen.gd

**Files:**
- Modify: `script/home_screen.gd`

- [ ] **Add `global.active_save_slot = slot` in `_on_load_slot` after the early return**

Current `_on_load_slot` (line 243):
```gdscript
func _on_load_slot(slot: int) -> void:
	if not global.load_from_slot(slot):
		_feedback_lbl.text = "Slot %d is empty." % slot
		_feedback_lbl.visible = true
		return
	_load_panel.visible = false
	var scene_file := "res://scenes/world.tscn"
	match global.current_scene:
		"cliff_side": scene_file = "res://scenes/cliff_side.tscn"
		"dungeon":    scene_file = "res://scenes/dungeon.tscn"
	get_tree().change_scene_to_file(scene_file)
```

Replace with:
```gdscript
func _on_load_slot(slot: int) -> void:
	if not global.load_from_slot(slot):
		_feedback_lbl.text = "Slot %d is empty." % slot
		_feedback_lbl.visible = true
		return
	global.active_save_slot = slot
	_load_panel.visible = false
	var scene_file := "res://scenes/world.tscn"
	match global.current_scene:
		"cliff_side": scene_file = "res://scenes/cliff_side.tscn"
		"dungeon":    scene_file = "res://scenes/dungeon.tscn"
	get_tree().change_scene_to_file(scene_file)
```

- [ ] **Commit**

```bash
git add script/home_screen.gd
git commit -m "feat(death): record active_save_slot on slot load"
```

---

## Task 4: Create death_screen.gd

**Files:**
- Create: `script/death_screen.gd`

- [ ] **Create the file with the full implementation**

```gdscript
extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

var _load_btn: Button

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if global.player_dead and not visible:
		_show()

func _show() -> void:
	var save_path := "user://save_slot_%d.cfg" % global.active_save_slot
	_load_btn.visible = FileAccess.file_exists(save_path)
	visible = true
	get_tree().paused = true

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 220)
	panel.offset_left = -200
	panel.offset_top = -110
	panel.offset_right = 200
	panel.offset_bottom = 110
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.20, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_load_btn = Button.new()
	_load_btn.text = "Load Last Save"
	_load_btn.pressed.connect(_on_load_last_save)
	vbox.add_child(_load_btn)

	var home_btn := Button.new()
	home_btn.text = "Home Screen"
	home_btn.pressed.connect(_on_home_screen)
	vbox.add_child(home_btn)

func _on_load_last_save() -> void:
	global.player_dead = false
	global.load_from_slot(global.active_save_slot)
	get_tree().paused = false
	visible = false
	var scene_file := "res://scenes/world.tscn"
	match global.current_scene:
		"cliff_side": scene_file = "res://scenes/cliff_side.tscn"
		"dungeon":    scene_file = "res://scenes/dungeon.tscn"
	get_tree().change_scene_to_file(scene_file)

func _on_home_screen() -> void:
	global.player_dead = false
	global.reset_for_new_game()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
```

- [ ] **Commit**

```bash
git add script/death_screen.gd
git commit -m "feat(death): add death_screen autoload overlay"
```

---

## Task 5: Register autoload in project.godot

**Files:**
- Modify: `project.godot`

- [ ] **Add `death_screen` to the `[autoload]` section**

Find the `[autoload]` block (currently contains `global`, `pause_menu`, `dialogue_data`, etc.). Add one line:

```
death_screen="*res://script/death_screen.gd"
```

Place it after `pause_menu`:
```
[autoload]

global="*uid://neut6i1kx728"
pause_menu="*res://script/pause_menu.gd"
death_screen="*res://script/death_screen.gd"
dialogue_data="*res://script/dialogue_data.gd"
```

- [ ] **Run the game and verify the full flow**

  1. Load a save slot from the home screen
  2. Enter the dungeon and let enemies kill the player
  3. Expected: game pauses, "YOU DIED" overlay appears, "Load Last Save" button is visible
  4. Click "Load Last Save" → game reloads the saved scene, player is alive again
  5. Repeat step 2-3, click "Home Screen" → returns to home screen, no crash

- [ ] **Test with no save (new game)**

  1. Start a new game (no slot loaded → `active_save_slot = 1` default, no file exists)
  2. Die in the dungeon
  3. Expected: overlay appears, "Load Last Save" button is **hidden**, only "Home Screen" is visible
  4. Click "Home Screen" → returns to home screen cleanly

- [ ] **Commit**

```bash
git add project.godot
git commit -m "feat(death): register death_screen autoload"
```

---

## Self-Review

- [x] **Spec coverage**
  - `global.player_dead` flag: Task 1 + Task 2
  - `global.active_save_slot` tracking: Task 1 + Task 3
  - Death screen autoload (layer=60, PROCESS_MODE_ALWAYS): Task 4
  - "Load Last Save" hidden when no save file: Task 4 (`_show()` checks FileAccess)
  - Scene routing on load (world/cliff_side/dungeon): Task 4 `_on_load_last_save`
  - `reset_for_new_game()` on home screen: Task 4 `_on_home_screen`
  - `get_tree().paused` on show/hide: Task 4
  - project.godot autoload registration: Task 5

- [x] **No placeholders** — all code blocks complete

- [x] **Type consistency** — `global.player_dead` (bool), `global.active_save_slot` (int) consistent across Tasks 1-5
