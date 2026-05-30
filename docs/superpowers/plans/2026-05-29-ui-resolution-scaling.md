# UI Resolution Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate game world (SubViewport 1920×1080, nearest-neighbor) from UI (root viewport, native resolution, anchor-based) so the UI adapts to any window size while the game world stays pixel-crisp.

**Architecture:** A new `main.tscn` root scene hosts a `SubViewportContainer → SubViewport` (1920×1080) where all game scenes live. Two new autoloads (`hud`, `ui_root`) at root level provide native-resolution UI attachment points. All scene transitions route through `global.go_to()` which signals `main.gd` to swap the SubViewport's active scene.

**Tech Stack:** GDScript 4.6, Godot 4.6, no external dependencies.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `script/global.gd` | Modify | Add `game_viewport`, `scene_change_requested` signal, `go_to()` |
| `script/hud.gd` | Create | Root-level HUD autoload: HP bar, money, lore — anchor-based |
| `script/main.gd` | Create | Root scene logic: SubViewport wiring, scene swap |
| `scenes/main.tscn` | Create | Root scene: SubViewportContainer → SubViewport |
| `project.godot` | Modify | New main_scene, 1920×1080 viewport, remove stretch scale |
| `script/player.gd` | Modify | Remove `_setup_hud()`, call `HUD.*` API instead |
| `script/world.gd` | Modify | `get_tree().change_scene_to_file` → `global.go_to()` |
| `script/cliff_side.gd` | Modify | Same |
| `script/dungeon.gd` | Modify | Same + `reload_current_scene` → `global.go_to()` |
| `script/home_screen.gd` | Modify | Same |
| `script/pause_menu.gd` | Modify | Same |
| `script/death_screen.gd` | Modify | Same |

---

## Task 1: Extend global.gd with go_to() and game_viewport

**Files:**
- Modify: `script/global.gd`

- [ ] **Step 1: Add three lines after the existing `var player_dead` declaration**

Open `script/global.gd`. After the line `var player_dead := false` (around line 34), add:

```gdscript
var game_viewport: SubViewport = null
signal scene_change_requested(path: String)

func go_to(path: String) -> void:
	scene_change_requested.emit(path)
```

- [ ] **Step 2: Verify the file parses**

Open Godot editor (or use `! godot --headless --quit` if editor is closed). Godot will print a parse error to Output if GDScript is invalid. No error = pass.

- [ ] **Step 3: Commit**

```bash
git add script/global.gd
git commit -m "feat(ui-scale): add go_to() and game_viewport to global"
```

---

## Task 2: Create HUD autoload (script/hud.gd)

**Files:**
- Create: `script/hud.gd`
- Modify: `project.godot`

- [ ] **Step 1: Create `script/hud.gd`**

```gdscript
extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

var _hp_bar: ProgressBar
var _hp_label: Label
var _money_label: Label
var _lore_panel: Panel
var _lore_label: Label

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── HP bar ─────────────────────────────────────────────────────────────
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_row)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(160, 18)
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.show_percentage = false
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.add_theme_color_override("font_color", UITheme.C_TEXT)
	UITheme.apply_font(_hp_label, 12)
	hp_row.add_child(_hp_label)

	# ── Gold counter ────────────────────────────────────────────────────────
	_money_label = Label.new()
	_money_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	UITheme.apply_font(_money_label, 13)
	vbox.add_child(_money_label)

	# ── Lore / item hint ────────────────────────────────────────────────────
	_lore_panel = Panel.new()
	_lore_panel.add_theme_stylebox_override("panel", UITheme.panel_style(1))
	_lore_panel.custom_minimum_size = Vector2(200, 24)
	_lore_panel.visible = false
	vbox.add_child(_lore_panel)

	_lore_label = Label.new()
	_lore_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lore_label.clip_text = true
	_lore_label.add_theme_constant_override("margin_left", 6)
	_lore_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	UITheme.apply_font(_lore_label, 11)
	_lore_panel.add_child(_lore_label)

func show() -> void:
	visible = true

func hide() -> void:
	visible = false

func update_hp(pct: float, current: int, maximum: int) -> void:
	_hp_bar.value = clampf(pct, 0.0, 1.0)
	_hp_label.text = "%d/%d" % [current, maximum]

func update_money(amount: int) -> void:
	_money_label.text = "G: %d" % amount

func show_lore(text: String) -> void:
	_lore_label.text = text
	_lore_panel.visible = true

func hide_lore() -> void:
	_lore_panel.visible = false
```

- [ ] **Step 2: Register `hud` autoload in `project.godot`**

Open `project.godot`. Find the `[autoload]` section. Add `hud` directly after the `death_screen` line:

```ini
hud="*res://script/hud.gd"
```

So the autoload section becomes:

```ini
[autoload]

global="*uid://neut6i1kx728"
pause_menu="*res://script/pause_menu.gd"
death_screen="*res://script/death_screen.gd"
hud="*res://script/hud.gd"
dialogue_data="*res://script/dialogue_data.gd"
dialogue_manager="*res://script/dialogue_manager.gd"
quest_data="*res://script/quest_data.gd"
quest_manager="*res://script/quest_manager.gd"
quest_log="*res://script/quest_log.gd"
_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"
```

- [ ] **Step 3: Commit**

```bash
git add script/hud.gd project.godot
git commit -m "feat(ui-scale): add HUD autoload with anchor-based layout"
```

---

## Task 3: Create main.gd, main.tscn, update project.godot

**Files:**
- Create: `script/main.gd`
- Create: `scenes/main.tscn`
- Modify: `project.godot`

- [ ] **Step 1: Create `script/main.gd`**

```gdscript
extends Node

func _ready() -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	global.game_viewport = vp
	$SubViewportContainer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global.scene_change_requested.connect(_on_scene_change)
	_load_scene("res://scenes/home_screen.tscn")

func _on_scene_change(path: String) -> void:
	_load_scene(path)

func _load_scene(path: String) -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	for child in vp.get_children():
		child.queue_free()
	var packed = load(path)
	if packed == null:
		push_error("main.gd: cannot load scene: " + path)
		return
	vp.add_child(packed.instantiate())
```

- [ ] **Step 2: Create `scenes/main.tscn`**

```
[gd_scene load_steps=2 format=3 uid="uid://bmain00tscn1"]

[ext_resource type="Script" uid="uid://bmaingd00001" path="res://script/main.gd" id="1_maingd"]

[node name="Main" type="Node"]
script = ExtResource("1_maingd")

[node name="SubViewportContainer" type="SubViewportContainer" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
stretch = true

[node name="SubViewport" type="SubViewport" parent="SubViewportContainer"]
size = Vector2i(1920, 1080)
render_target_update_mode = 4
```

- [ ] **Step 3: Update `project.godot` — change main scene and viewport size**

In `project.godot`, find the `[application]` section and change `run/main_scene`:

```ini
run/main_scene="res://scenes/main.tscn"
```

Find the `[display]` section and replace the three lines:

```ini
window/size/viewport_width=1920
window/size/viewport_height=1080
```

Remove (delete) this line entirely — it is no longer needed:

```ini
window/stretch/scale=2.0
```

- [ ] **Step 4: Verify in Godot editor**

Open Godot. The editor should show `Main` as the main scene with a `SubViewportContainer` child. No parse errors in Output. Close.

- [ ] **Step 5: Commit**

```bash
git add script/main.gd scenes/main.tscn project.godot
git commit -m "feat(ui-scale): add main.tscn root scene with SubViewport 1920x1080"
```

---

## Task 4: Update player.gd — remove HUD, call HUD autoload

**Files:**
- Modify: `script/player.gd`

The goal: remove the seven HUD-related variable declarations and the entire `_setup_hud()` function. Replace the inline HUD update calls in `_update_hud()` with calls to the `HUD` autoload. The shop overlay (`_shop_layer`) is unchanged — it stays as a CanvasLayer child of player.

- [ ] **Step 1: Remove HUD variable declarations at the top of player.gd**

Find these six lines (around lines 20–33) and delete them:

```gdscript
var _hud_layer: CanvasLayer
var _hud_money_label: Label
var _hud_hp_bar_fg: ColorRect
var _hud_hp_label: Label
var _lore_panel: Panel
var _lore_label: Label
```

Leave these in place (shop variables — untouched):

```gdscript
var _shop_layer: CanvasLayer
var _shop_money_label: Label
var _dmg_level_label: Label
var _hp_level_label: Label
var _def_level_label: Label
var _dmg_btn: Button
var _hp_btn: Button
var _def_btn: Button
```

- [ ] **Step 2: Update `_ready()` — remove `_setup_hud()`, add HUD autoload calls**

Replace:

```gdscript
func _ready():
	add_to_group("player")
	$AnimatedSprite2D.play("front_idle")
	if global.player_current_health > 0:
		health = global.player_current_health
	else:
		health = global.get_max_health()
	global.player_current_attack = false
	_setup_hud()
	_setup_shop()
```

With:

```gdscript
func _ready():
	add_to_group("player")
	$AnimatedSprite2D.play("front_idle")
	if global.player_current_health > 0:
		health = global.player_current_health
	else:
		health = global.get_max_health()
	global.player_current_attack = false
	HUD.show()
	HUD.update_money(global.money)
	HUD.update_hp(health / float(global.get_max_health()), health, global.get_max_health())
	_setup_shop()
```

- [ ] **Step 3: Update `_exit_tree()` — add HUD.hide()**

Replace:

```gdscript
func _exit_tree():
	global.player_current_health = health
	global.player_current_attack = false
```

With:

```gdscript
func _exit_tree():
	global.player_current_health = health
	global.player_current_attack = false
	HUD.hide()
```

- [ ] **Step 4: Replace `_update_hud()` body with HUD autoload calls**

Find the `_update_hud()` function (called from `_physics_process`). Replace its entire body with:

```gdscript
func _update_hud() -> void:
	var max_hp := global.get_max_health()
	var pct := health / float(max_hp)
	HUD.update_hp(pct, health, max_hp)
	HUD.update_money(global.money)

	var lore_text := ""
	for key in global.items:
		if global.items[key]:
			lore_text = String(key).replace("_", " ").capitalize()
			break
	if lore_text.is_empty():
		HUD.hide_lore()
	else:
		HUD.show_lore(lore_text)
```

- [ ] **Step 5: Delete the entire `_setup_hud()` function**

Find and delete this entire function (approximately lines 214–266 in the original):

```gdscript
func _setup_hud():
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	# ... (all lines through the end of _lore_label setup)
```

The function ends just before `func _setup_shop():`. Delete everything from `func _setup_hud():` up to but not including `func _setup_shop():`.

- [ ] **Step 6: Verify no remaining references to removed variables**

Run this in a terminal to confirm no stragglers:

```bash
grep -n "_hud_layer\|_hud_hp_bar_fg\|_hud_hp_label\|_hud_money_label\|_lore_panel\|_lore_label" script/player.gd
```

Expected output: no lines found (empty).

- [ ] **Step 7: Commit**

```bash
git add script/player.gd
git commit -m "feat(ui-scale): player.gd delegates HUD to HUD autoload"
```

---

## Task 5: Replace all change_scene_to_file() calls with global.go_to()

**Files:**
- Modify: `script/world.gd`
- Modify: `script/cliff_side.gd`
- Modify: `script/dungeon.gd`
- Modify: `script/home_screen.gd`
- Modify: `script/pause_menu.gd`
- Modify: `script/death_screen.gd`

- [ ] **Step 1: Update `script/world.gd`**

Find (line ~45 in world.gd):

```gdscript
get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")
```

Replace with:

```gdscript
global.go_to("res://scenes/cliff_side.tscn")
```

- [ ] **Step 2: Update `script/cliff_side.gd`**

Find and replace both calls:

```gdscript
get_tree().change_scene_to_file("res://scenes/world.tscn")
```
→
```gdscript
global.go_to("res://scenes/world.tscn")
```

```gdscript
get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
```
→
```gdscript
global.go_to("res://scenes/dungeon.tscn")
```

- [ ] **Step 3: Update `script/dungeon.gd`**

Find and replace the cliff-side exit call (line ~171):

```gdscript
get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")
```
→
```gdscript
global.go_to("res://scenes/cliff_side.tscn")
```

Also find any `get_tree().reload_current_scene()` call (used for next-floor advancement). Replace it with:

```gdscript
global.go_to("res://scenes/dungeon.tscn")
```

Verify all replacements by running:

```bash
grep -n "change_scene_to_file\|reload_current_scene" script/dungeon.gd
```

Expected: no output.

- [ ] **Step 4: Update `script/home_screen.gd`**

Find `_on_new_game()` (line ~234):

```gdscript
get_tree().change_scene_to_file("res://scenes/world.tscn")
```
→
```gdscript
global.go_to("res://scenes/world.tscn")
```

Find `_on_load_slot()` (line ~254):

```gdscript
get_tree().change_scene_to_file(scene_file)
```
→
```gdscript
global.go_to(scene_file)
```

- [ ] **Step 5: Update `script/pause_menu.gd`**

Find `_go_home()` (line ~221):

```gdscript
get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
```
→
```gdscript
global.go_to("res://scenes/home_screen.tscn")
```

- [ ] **Step 6: Update `script/death_screen.gd`**

Find `_on_load_last_save()` (line ~71):

```gdscript
get_tree().change_scene_to_file(scene_file)
```
→
```gdscript
global.go_to(scene_file)
```

Find `_on_home_screen()` (line ~78):

```gdscript
get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
```
→
```gdscript
global.go_to("res://scenes/home_screen.tscn")
```

- [ ] **Step 7: Verify no remaining change_scene_to_file calls in game scripts**

```bash
grep -rn "change_scene_to_file\|reload_current_scene" script/
```

Expected: no output (addons/ is separate and not our concern).

- [ ] **Step 8: Commit**

```bash
git add script/world.gd script/cliff_side.gd script/dungeon.gd script/home_screen.gd script/pause_menu.gd script/death_screen.gd
git commit -m "feat(ui-scale): route all scene transitions through global.go_to()"
```

---

## Verification Checklist

After all tasks complete, test these flows in the Godot editor (Play):

- [ ] **Home screen loads** — game launches, home screen background and menu appear
- [ ] **New game starts** — click "New Game", world scene loads inside SubViewport
- [ ] **Player HUD visible** — HP bar and gold label appear anchored to top-left at native resolution
- [ ] **HUD updates** — take damage, watch HP bar shrink; earn gold, watch counter update
- [ ] **HUD hides on scene change** — return to home screen via pause menu, HUD disappears
- [ ] **Pause menu works** — ESC pauses the game, overlay appears centered
- [ ] **Save works from pause** — save to a slot, verify file exists
- [ ] **Load from home screen works** — click "Load Save", choose slot, loads correct scene
- [ ] **World → Cliffside transition** — walk to transition point, scene swaps cleanly
- [ ] **Cliffside → Dungeon** — talk to NPC, dungeon scene loads
- [ ] **Dungeon next floor** — reach exit, dungeon reloads for next floor
- [ ] **Dungeon → exit** — exit dungeon, cliff_side scene loads
- [ ] **Death screen** — let player die, YOU DIED overlay appears; Load Last Save works; Home Screen works
- [ ] **Window resize** — resize the game window (if windowed), UI stays proportionally anchored; game world scales to fill window
