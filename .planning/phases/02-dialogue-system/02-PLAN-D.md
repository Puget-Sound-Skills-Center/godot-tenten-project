---
phase: 2
plan_id: "02-PLAN-D"
wave: 2
depends_on:
  - "02-PLAN-B"
files_modified:
  - script/dungeon_dialogue_npc.gd
  - script/dungeon.gd
requirements_addressed:
  - DLG-05
autonomous: true
nyquist_compliant: false
---

# Plan D — Wave 2: Dungeon Dialogue NPC (parallel with Plan C)

<objective>
Create `script/dungeon_dialogue_npc.gd` — a near-clone of `dungeon_npc.gd` that opens
dialogue instead of triggering dungeon entry — and modify `script/dungeon.gd` to spawn
one instance per floor.

Also add a `force_close()` guard in `dungeon.gd` before `reload_current_scene()` to prevent
permanently frozen game state if the player advances floors while dialogue is open.

Purpose: DLG-05 requires at least one dialogue-capable NPC spawned inside dungeon rooms.
Output: New `script/dungeon_dialogue_npc.gd` + two changes to `script/dungeon.gd`.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@D:/Unity/godot-tenten-project/.planning/ROADMAP.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-RESEARCH.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-PATTERNS.md
@D:/Unity/godot-tenten-project/.planning/phases/02-dialogue-system/02-B-SUMMARY.md

<interfaces>
<!-- Contracts from Plan B outputs and existing codebase -->

From script/dialogue_manager.gd (Plan B):
```gdscript
func open(npc_id: String, start_node: String) -> void
func force_close() -> void
```

From script/dungeon_npc.gd (exact analog — full structure to copy):
```gdscript
extends Node2D
var player_nearby = false
var player_ref = null
var _prompt_label: Label

func _ready():
    _build_visual()
    _build_interaction_area()

func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        global.enter_dungeon = true   # <-- THIS LINE changes to DialogueManager.open(...)

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = true
        player_ref = body
        _prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = false
        player_ref = null
        _prompt_label.visible = false
```

From script/dungeon.gd — spawn pattern to replicate (world.gd lines 17-20):
```gdscript
var npc = load("res://script/npc.gd").new()
npc.position = Vector2(167, 110)
add_child(npc)
```

From script/dungeon.gd — _pick_save_position or _is_position_clear (to reuse for NPC placement).
Read dungeon.gd to find the exact function name used for safe position selection.
</interfaces>
</context>

<tasks>

<task id="2-D-01" type="execute">
  <title>Create script/dungeon_dialogue_npc.gd — proximity NPC calling DialogueManager.open()</title>
  <read_first>
    - script/dungeon_npc.gd — read entire file; this is the structural template to copy.
      Identify exact _build_visual(), _build_interaction_area(), _process(), and body
      signal handler implementations.
    - script/npc.gd — observe the art/objects/chest_01.png sprite used; dungeon NPC uses
      chest_02.png as a visual distinction (per 02-PATTERNS.md)
    - .planning/phases/02-dialogue-system/02-PATTERNS.md — dungeon_dialogue_npc.gd full
      file structure section
  </read_first>
  <action>
Create `script/dungeon_dialogue_npc.gd` as a new file. It is a structural copy of
`script/dungeon_npc.gd` with exactly two changes:
1. The prompt label text changes from "E: Enter Dungeon" to "E: Talk"
2. The `_process()` action changes from `global.enter_dungeon = true` to
   `DialogueManager.open("dungeon_merchant", "greeting")`

Full file:

```gdscript
extends Node2D

var player_nearby = false
var player_ref = null
var _prompt_label: Label

func _ready():
    _build_visual()
    _build_interaction_area()

func _build_visual():
    var sprite = Sprite2D.new()
    sprite.texture = load("res://art/objects/chest_02.png")
    sprite.hframes = 4
    sprite.frame = 0
    sprite.position = Vector2(0, -8)
    add_child(sprite)

    _prompt_label = Label.new()
    _prompt_label.text = "E: Talk"
    _prompt_label.position = Vector2(-12, -22)
    _prompt_label.add_theme_font_size_override("font_size", 6)
    _prompt_label.add_theme_color_override("font_color", Color.WHITE)
    _prompt_label.visible = false
    add_child(_prompt_label)

func _build_interaction_area():
    var area = Area2D.new()
    var shape_node = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = 20.0
    shape_node.shape = circle
    area.add_child(shape_node)
    area.body_entered.connect(_on_body_entered)
    area.body_exited.connect(_on_body_exited)
    add_child(area)

func _process(_delta):
    if player_nearby and is_instance_valid(player_ref) and Input.is_action_just_pressed("interact"):
        DialogueManager.open("dungeon_merchant", "greeting")

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = true
        player_ref = body
        _prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("player"):
        player_nearby = false
        player_ref = null
        _prompt_label.visible = false
```

Note on chest_02.png: if `art/objects/chest_02.png` does not exist, fall back to
`res://art/objects/chest_01.png` (same as npc.gd) to prevent a load error. The visual
distinction is cosmetic; do not block the task on missing art.
  </action>
  <acceptance_criteria>
    - `ls "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` succeeds (file exists)
    - `grep -n "DialogueManager.open" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` returns
      1 match containing `DialogueManager.open("dungeon_merchant", "greeting")`
    - `grep -n "_build_interaction_area\|body_entered\|Area2D" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` returns
      at least 2 matches (proximity area exists)
    - `grep -n "has_method.*player" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` returns
      at least 1 match (duck-typed identity check preserved)
    - `grep -n "E: Talk" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` returns
      1 match (prompt label text)
    - `grep -n "class_name" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` returns
      0 matches
    - `grep -n "global.enter_dungeon" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"` returns
      0 matches (original dungeon_npc action NOT present in this file)
  </acceptance_criteria>
</task>

<task id="2-D-02" type="execute">
  <title>Modify dungeon.gd to spawn dungeon_dialogue_npc per floor + add force_close guard</title>
  <read_first>
    - script/dungeon.gd — read lines 80-130 (_ready() body and _check_next_floor function)
      to find: exact call site after _spawn_enemies(), and the reload_current_scene() call
      that needs the force_close guard. Also identify the clear-position helper function name
      (may be _pick_save_position, _pick_clear_position, or _is_position_clear-based loop).
    - .planning/phases/02-dialogue-system/02-PATTERNS.md — dungeon.gd MODIFY section,
      specifically _spawn_dungeon_dialogue_npc() pattern and _check_next_floor() guard pattern
  </read_first>
  <action>
Make two targeted changes to `script/dungeon.gd`:

**Change 1 — Spawn call in _ready():**
After the `_spawn_enemies(floor_no, obstacles)` call in `_ready()`, add one line:

```gdscript
_spawn_dungeon_dialogue_npc(floor_no, obstacles)
```

Find the exact context by reading dungeon.gd lines 80-100. The call goes immediately after
the existing `_spawn_enemies(...)` call, on its own line, before whatever follows.

**Change 2 — Add _spawn_dungeon_dialogue_npc() method:**
Add this new method to the end of the file (or near the other _spawn_* methods for grouping):

```gdscript
func _spawn_dungeon_dialogue_npc(floor_no: int, obstacles: Array) -> void:
    var pos := _pick_save_position(obstacles)
    var npc := load("res://script/dungeon_dialogue_npc.gd").new()
    npc.position = pos
    add_child(npc)
```

If the clear-position function is named differently (e.g., `_is_position_clear` is a check
rather than a picker), use the same helper that `_spawn_enemies` uses to find valid positions.
Read dungeon.gd to determine the exact function name — do not assume `_pick_save_position`.

**Change 3 — force_close guard in _check_next_floor():**
Inside `_check_next_floor()`, add `DialogueManager.force_close()` immediately before
`get_tree().reload_current_scene()`. Read the function to find the exact line. The result:

```gdscript
# Before (existing):
get_tree().reload_current_scene()

# After:
DialogueManager.force_close()
get_tree().reload_current_scene()
```

This prevents permanently frozen game state if the player somehow reaches the floor exit
while the dialogue panel is open (Pitfall 6 from 02-RESEARCH.md).

Do not modify any other part of dungeon.gd.
  </action>
  <acceptance_criteria>
    - `grep -n "dungeon_dialogue_npc\|_spawn_dungeon" "D:/Unity/godot-tenten-project/script/dungeon.gd"` returns
      at least 2 matches (the spawn call in _ready() + the function definition)
    - `grep -n "force_close" "D:/Unity/godot-tenten-project/script/dungeon.gd"` returns
      1 match (the guard before reload_current_scene)
    - `grep -n "reload_current_scene" "D:/Unity/godot-tenten-project/script/dungeon.gd"` still
      returns at least 1 match (reload call preserved, not deleted)
    - `grep -n "load.*dungeon_dialogue_npc" "D:/Unity/godot-tenten-project/script/dungeon.gd"` returns
      1 match (the load().new() spawn inside _spawn_dungeon_dialogue_npc)
  </acceptance_criteria>
</task>

</tasks>

<verification>
  <grep_checks>
    <!-- AC from VALIDATION.md task map — 2-D-01 and 2-D-02 -->
    <!-- Task 2-D-01 -->
    ls "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"
    grep -n "dungeon_dialogue_npc" "D:/Unity/godot-tenten-project/script/dungeon.gd"
    grep -n "DialogueManager.open" "D:/Unity/godot-tenten-project/script/dungeon_dialogue_npc.gd"

    <!-- Task 2-D-02 -->
    grep -n "force_close" "D:/Unity/godot-tenten-project/script/dungeon.gd"
    grep -n "_spawn_dungeon" "D:/Unity/godot-tenten-project/script/dungeon.gd"
  </grep_checks>
  <must_haves>
    <truths>
      - Entering any dungeon floor spawns exactly one dungeon_dialogue_npc instance in the room
      - Walking near the dungeon NPC shows the "E: Talk" prompt label
      - Pressing E near the dungeon NPC opens the dialogue panel with "Merchant" name and
        greeting text (game pauses, enemies freeze)
      - Advancing the dungeon NPC dialogue to the final node closes the panel and unpauses
      - Advancing floors while dialogue is open does NOT leave the game in a permanently
        paused state (force_close called before reload_current_scene)
    </truths>
  </must_haves>
</verification>

<threat_model>
  <!-- ASVS L1 — local single-player Godot game -->

  | Threat ID | Category | Component | Disposition | Mitigation |
  |-----------|----------|-----------|-------------|------------|
  | T-2D-01 | Denial of Service | floor advance while dialogue open (dungeon.gd) | mitigate | `DialogueManager.force_close()` called before `reload_current_scene()` clears paused state unconditionally; even if panel was already closed, force_close is a no-op (safe to call) |
  | T-2D-02 | Denial of Service | missing chest_02.png texture (dungeon_dialogue_npc.gd) | mitigate | Acceptance criteria instruct executor to fall back to chest_01.png if chest_02.png is absent; load() does not crash on missing texture but logs an error — fallback prevents visual regression |
  | T-2D-03 | Denial of Service | NPC spawned inside wall/obstacle | mitigate | _spawn_dungeon_dialogue_npc reuses the same clear-position helper as _spawn_enemies; if no clear position is found within retry limit, the function falls back to room center (existing dungeon.gd behavior) |
</threat_model>

<success_criteria>
- script/dungeon_dialogue_npc.gd exists, extends Node2D
- _process() calls DialogueManager.open("dungeon_merchant", "greeting") on interact
- Duck-typed identity check (has_method("player")) used in body signal handlers
- No class_name declaration
- script/dungeon.gd _ready() calls _spawn_dungeon_dialogue_npc() after _spawn_enemies()
- _spawn_dungeon_dialogue_npc() creates npc via load().new() and add_child()
- force_close() called in _check_next_floor() before reload_current_scene()
- Manual play-test: dungeon NPC visible per floor, dialogue opens on E, game pauses
</success_criteria>

<output>
After completion, create `.planning/phases/02-dialogue-system/02-D-SUMMARY.md`
</output>
