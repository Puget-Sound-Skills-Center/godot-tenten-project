# Phase 4: Dungeon Depth — Context

**Phase goal:** Dungeon runs contain hidden rooms, boss floors, and lore objects that reward exploration and make each run feel purposeful.

**Requirements:**

| ID | Description |
|----|-------------|
| DNG-02 | Hidden rooms accessible via inspectable trigger; contains bonus treasure |
| DNG-03 | Every 25th floor is a boss floor; player must clear all enemies to advance |
| DNG-04 | Lore objects appear in dungeon rooms; inspectable → dialogue UI with story fragment |

**Key architectural decisions:**

1. All three features live in `script/dungeon.gd` (+ `script/lore_object.gd` for DNG-04 + `script/dialogue_data.gd` for lore content). No new autoloads.
2. Boss exit gate: poll `get_tree().get_nodes_in_group("boss_enemies").size() == 0` in `_check_boss_clear()` called from `_process()`. Boss enemies added to `"boss_enemies"` group at spawn; Godot removes them on `queue_free()` automatically.
3. Boss floors MUST suppress puzzle spawn (`if not boss_floor_active`) — both systems gate the exit and would deadlock if active simultaneously.
4. Lore objects: new `script/lore_object.gd` (analog of `dungeon_dialogue_npc.gd`). Sets `lore_id` before `add_child()`. Calls `dialogue_manager.open("lore_object", lore_id)`. Six fragments in `dialogue_data.DIALOGUES["lore_object"]` selected by floor range via `_pick_lore_node()`.
5. Hidden room trigger: Area2D with `secret_wall` + `player_near` meta, polled via `elif` branch in existing `_process()` child loop. One-shot: `queue_free()` on activation. Gold reward: `50 + floor_no * 5`. Never spawns on boss floors.
6. Hidden room placement: custom `_pick_hidden_room_position()` that extends `_is_position_clear()` with an additional `_exit_zone()` check. Returns `Vector2.ZERO` as sentinel; `_spawn_hidden_room()` returns early if no valid position.

**Wave structure and dependency order:**

```
Wave 1 — Plan 01 (DNG-04):  lore data + lore_object.gd + dungeon.gd spawn wiring
Wave 2 — Plan 02 (DNG-03):  boss floors (depends on plan 01 for _spawn_lore_object in context)
Wave 2 — Plan 03 (DNG-02):  hidden rooms (depends on plan 01; parallel with plan 02)
```

Plans 02 and 03 both modify `script/dungeon.gd` but touch non-overlapping functions and lines. Execute sequentially (02 then 03) if running manually, or ensure no concurrent writes.
