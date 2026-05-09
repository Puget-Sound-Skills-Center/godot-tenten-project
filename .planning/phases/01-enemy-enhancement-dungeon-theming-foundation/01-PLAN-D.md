---
phase: "01-enemy-enhancement-dungeon-theming-foundation"
plan: "01-PLAN-D"
type: execute
wave: 2
depends_on:
  - "01-PLAN-A"
files_modified:
  - script/enemy_base.gd
autonomous: true
requirements:
  - ENM-05

must_haves:
  truths:
    - "When any enemy detects the player, all other enemies in the dungeon activate within the same physics frame"
    - "Already-chasing enemies do not reset their state when the pack alert fires"
    - "Pack alert uses call_group — no per-frame polling, no O(n²) signal connections"
    - "Enemies inactive when alert fires locate the player via get_nodes_in_group and begin chasing"
  artifacts:
    - path: "script/enemy_base.gd"
      provides: "call_group pack alert in detection handler; _on_pack_alerted handler that guards against double-activation"
      contains: "call_group(\"enemies\", \"_on_pack_alerted\""
  key_links:
    - from: "script/enemy_base.gd _on_detection_area_body_entered"
      to: "all enemies in 'enemies' group"
      via: "get_tree().call_group fires _on_pack_alerted on every member"
      pattern: "call_group"
    - from: "script/enemy_base.gd _on_pack_alerted"
      to: "player node"
      via: "get_nodes_in_group('player') — requires player to have called add_to_group('player') in _ready()"
      pattern: "get_nodes_in_group"
---

<objective>
Verify and harden the pack alert system in enemy_base.gd. Plan A wrote the initial implementation; this plan confirms correctness, adds the early-return guard for already-active enemies, and verifies the "player" group membership established in Plan A's player.gd changes.

Purpose: ENM-05 — enemies alert each other without per-frame polling. Runs in parallel with Plan B (different file, no conflict).
Output: Hardened _on_pack_alerted in enemy_base.gd with is_instance_valid guard and correct group lookup.
</objective>

<execution_context>
@D:/Unity/godot-tenten-project/.claude/get-shit-done/workflows/execute-plan.md
@D:/Unity/godot-tenten-project/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-RESEARCH.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-PATTERNS.md
@.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-A-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Harden pack alert system in enemy_base.gd — verify and strengthen _on_pack_alerted and detection handler</name>

  <read_first>
    - script/enemy_base.gd (read full file — confirm _on_detection_area_body_entered contains call_group, confirm _on_pack_alerted body and guard condition)
    - script/player.gd (confirm add_to_group("player") present — required for _on_pack_alerted group lookup)
  </read_first>

  <action>
Read enemy_base.gd and verify:

**Check 1 — detection handler emits pack alert via call_group:**
`_on_detection_area_body_entered` must contain exactly:
```gdscript
func _on_detection_area_body_entered(body) -> void:
    if body.has_method("player"):
        player = body as Node2D
        player_chase = true
        get_tree().call_group("enemies", "_on_pack_alerted", global_position)
```
If call_group line is missing, add it after `player_chase = true`.

**Check 2 — _on_pack_alerted has correct guard and group lookup:**
The handler must be:
```gdscript
func _on_pack_alerted(origin_position: Vector2) -> void:
    if player_chase:
        return
    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player = players[0] as Node2D
        player_chase = true
```
The `if player_chase: return` guard is the critical piece — already-chasing enemies skip the handler entirely. Without this, a chasing enemy receiving its own call_group broadcast would reset `player` to `players[0]`, which may differ from the actual tracked body in edge cases.

If `_on_pack_alerted` exists but uses a different implementation (e.g., sets player without the guard, or uses `not player_chase` as the entry condition instead of early return), rewrite it to match the above exactly.

**Check 3 — enemy_base _ready() adds to "enemies" group:**
```gdscript
add_to_group("enemies")
```
Must appear in `_ready()`. If missing, add it immediately after `health = max_health`.

**Check 4 — player.gd "player" group:**
Confirm `add_to_group("player")` is present in player.gd `_ready()`. If missing (Plan A did not add it), add it now. This is required for `get_nodes_in_group("player")` to return the player.

If all four checks pass with no changes needed, make a cosmetic confirmation edit (e.g., add a blank line) to produce a non-empty diff, then document in the SUMMARY that all guards were verified correct.
  </action>

  <verify>
    <automated>grep -n "call_group" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "_on_pack_alerted" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "player_chase" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "add_to_group" D:/Unity/godot-tenten-project/script/enemy_base.gd</automated>
    <automated>grep -n "add_to_group" D:/Unity/godot-tenten-project/script/player.gd</automated>
  </verify>

  <acceptance_criteria>
    - script/enemy_base.gd contains `get_tree().call_group("enemies", "_on_pack_alerted", global_position)` inside `_on_detection_area_body_entered`
    - script/enemy_base.gd contains `func _on_pack_alerted(origin_position: Vector2) -> void:`
    - script/enemy_base.gd `_on_pack_alerted` contains `if player_chase:` as the first statement (early-return guard)
    - script/enemy_base.gd `_on_pack_alerted` contains `get_nodes_in_group("player")`
    - script/enemy_base.gd contains `add_to_group("enemies")` in `_ready()`
    - script/player.gd contains `add_to_group("player")` in `_ready()`
  </acceptance_criteria>

  <done>Pack alert verified and hardened: call_group in detection, early-return guard in handler, both group registrations confirmed.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| call_group → _on_pack_alerted | Godot calls _on_pack_alerted on every node in "enemies" group — including the caller itself |
| get_nodes_in_group → player ref | Returns first node in "player" group; assumes exactly 1 player |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01D-01 | Denial of Service | Pack alert causes already-chasing enemy to reset player reference unnecessarily | mitigate | `if player_chase: return` early guard — prevents any state change on active enemies |
| T-01D-02 | Denial of Service | _on_pack_alerted called but "player" group is empty (player not yet added to group) | accept | Player `_ready()` runs before any enemy can detect it (player spawns first in dungeon _ready()); group will be populated. Accept residual edge case where alert fires before player spawns — check `players.size() > 0` prevents null assignment |
| T-01D-03 | Denial of Service | call_group invoked on every enemy (30 max) triggering 30 handler calls per detection | accept | One-time event per first detection; each handler is O(1) with early-return; 30 calls is negligible. Not per-frame. |
</threat_model>

<verification>
After task complete:
1. `grep -n "call_group" script/enemy_base.gd` — returns exactly 1 match inside `_on_detection_area_body_entered`
2. `grep -n "if player_chase:" script/enemy_base.gd` — returns 1 match as first line of `_on_pack_alerted`
3. `grep -n "add_to_group" script/enemy_base.gd` — returns "enemies" group registration
4. `grep -n "add_to_group" script/player.gd` — returns "player" group registration
5. Manual verification: spawn 5+ enemies in dungeon; approach 1 enemy — all others should begin moving toward player position
</verification>

<success_criteria>
- ENM-05: When one enemy detects the player, all other enemies activate via call_group — no per-frame polling
- Already-active enemies are not disrupted by receiving the alert (player_chase early-return guard)
- Both "enemies" and "player" group registrations confirmed in respective _ready() functions
</success_criteria>

<output>
After completion, create `.planning/phases/01-enemy-enhancement-dungeon-theming-foundation/01-D-SUMMARY.md`
</output>
