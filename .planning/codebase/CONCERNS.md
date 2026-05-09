# Codebase Concerns

**Analysis Date:** 2026-05-08

---

## Tech Debt

**God-object: `global.gd` carries all mutable game state**
- Issue: Single autoload holds player stats, scene routing flags, dungeon floor, money, save/load logic, and position data. Any script can mutate any field at any time with no encapsulation.
- Files: `script/global.gd`
- Impact: Bugs from unexpected cross-scene state mutation are invisible until runtime. State reset in `reset_for_new_game()` must manually list every field — easy to forget new ones.
- Fix approach: Split into typed resource objects (`PlayerData`, `DungeonState`) passed by reference. Keep `global` as a thin router only.

**Player script is a god-object (combines movement, combat, HUD, shop UI)**
- Issue: `player.gd` extends `CharacterBody2D` but also owns HUD construction (`_setup_hud`), the entire upgrade shop UI (`_setup_shop`, 100+ lines of node creation), upgrade purchase logic, health regen, and animation. All built procedurally in code — no scene file for shop/HUD.
- Files: `script/player.gd`
- Impact: Impossible to iterate on shop UI without touching the physics character. Any scene that needs the player drags in the shop whether it needs it or not.
- Fix approach: Extract shop to a separate `ShopUI` scene/node. Extract HUD to `PlayerHUD` scene. Player script owns only movement, combat, and health.

**Entire shop UI built procedurally at runtime**
- Issue: `_setup_shop()` and `_setup_hud()` in `player.gd` create ~40 nodes with hardcoded sizes, offsets, and colors via `Node.new()` chains. Same pattern repeated in `home_screen.gd`, `pause_menu.gd`.
- Files: `script/player.gd` (lines 199–284), `script/home_screen.gd`, `script/pause_menu.gd`
- Impact: UI is invisible in the Godot editor — no visual layout preview. Pixel offsets hardcoded will break on non-1x viewport scales.
- Fix approach: Convert to `.tscn` scenes edited in the Godot editor. Use anchors/containers for responsive layout.

**Massive duplication between `dungeon.gd` and `puzzle_test.gd`**
- Issue: All five puzzle types (Order, Math, Trap, Echo, Switches) are implemented twice — once in `script/dungeon.gd` and again in `script/puzzle_test.gd` with near-identical code.
- Files: `script/dungeon.gd` (lines 385–706), `script/puzzle_test.gd` (lines 229–515)
- Impact: Bug fixes and balance changes must be applied in two places. Already diverged: `puzzle_test.gd` adds `_set_solved_label` and per-puzzle `solved` booleans that `dungeon.gd` lacks.
- Fix approach: Extract puzzle logic into a `PuzzleManager` autoload or reusable `Puzzle` node.

**Scene transition via global boolean flags (fragile state machine)**
- Issue: Scene changes are driven by polling `global.transition_scene`, `global.enter_dungeon`, `global.exit_dungeon`, `global.next_floor` in `_process()` every frame.
- Files: `script/world.gd` (lines 29–35), `script/cliff_side.gd` (lines 27–36), `script/dungeon.gd` (lines 79–87)
- Impact: Race condition possible if two flags become true in the same frame. Any new scene must know and clear every relevant flag.
- Fix approach: Replace with a `SceneManager` singleton that takes an explicit destination enum. Eliminate polling flags.

**`finish_changescenes()` does not handle dungeon scene**
- Issue: `global.finish_changescenes()` assumes only two scenes ("world" / "cliff_side") and blindly toggles between them.
- Files: `script/global.gd` (lines 40–46), `script/world.gd` (line 34)
- Impact: If ever called after entering the dungeon, `current_scene` will be set incorrectly.
- Fix approach: Remove the function; replace with explicit `SceneManager` routing.

**NPC spawned by loading a `.gd` script directly as a scene**
- Issue: `world.gd` and `cliff_side.gd` instantiate NPCs with `load("res://script/npc.gd").new()` instead of `load("res://scenes/npc.tscn").instantiate()`.
- Files: `script/world.gd` (line 17), `script/cliff_side.gd` (line 15)
- Impact: NPC visual/collision configuration is fully hardcoded in GDScript. Cannot be configured in the editor. Bypasses Godot's scene system and resource caching.
- Fix approach: Create `scenes/npc.tscn` and `scenes/dungeon_npc.tscn`.

**Player position stored as separate x/y integers in `global.gd`**
- Issue: `player_start_posx = 155`, `player_start_posy = 108`, etc. stored as separate integer vars instead of `Vector2` constants.
- Files: `script/global.gd` (lines 8–15)
- Fix approach: Replace with `const PLAYER_START_POS := Vector2(155, 108)` etc.

---

## Known Bugs

**Enemy health bar hardcoded to max=100; does not reflect scaled stats**
- Symptoms: `enemy.gd` calls `healthbar.value = health` but never sets `healthbar.max_value`. The `update_health()` function compares `health >= 100` to hide the bar — breaks if max health is ever changed from 100.
- Files: `script/enemy.gd` (lines 80–86)
- Trigger: Introduce any enemy with more than 100 max HP.

**`change_scene()` in `world.gd` runs every frame during transition**
- Symptoms: `change_scene()` is called inside `_process()` with no guard after `change_scene_to_file` is called. Between the frame the flag is set and the scene unloads, the call is issued repeatedly.
- Files: `script/world.gd` (lines 21–35)
- Workaround: Godot discards duplicate `change_scene_to_file` calls so it does not crash, but it is wasteful.

**Player health can fall to 0 but death has no game-over handling**
- Symptoms: When `health <= 0`, `player_alive = false` is set and health is clamped to 0, but no death animation plays, no game-over screen appears, and the player continues to receive input and move.
- Files: `script/player.gd` (lines 48–51)
- Trigger: Health reaches 0 from enemy attacks.

**Dungeon save only available every 10 floors**
- Symptoms: Players on floors 1–9, 11–19, etc. have no in-dungeon save point.
- Files: `script/dungeon.gd` (line 68)
- Workaround: Pause menu save works if the player manually pauses.

**`_update_hud()` runs every physics frame even when shop is closed**
- Symptoms: The full shop label update block executes every physics frame including string formatting and button state checks.
- Files: `script/player.gd` (line 46, lines 289–327)

---

## Security Considerations

**Save files use `ConfigFile` with no integrity check**
- Risk: Save files at `user://save_slot_N.cfg` are plain text. Values like `money`, `damage_level`, and `health_level` can be edited directly by the player.
- Files: `script/global.gd` (lines 75–121)
- Current mitigation: None. Acceptable for a single-player game; add HMAC if leaderboards/multiplayer added.

---

## Performance Bottlenecks

**Full dungeon room built procedurally on every floor load**
- Problem: Each dungeon floor triggers `get_tree().reload_current_scene()` which re-runs the entire `_ready()` — rebuilding background, walls, obstacles, navigation mesh, enemies, exit, puzzle, and HUD from scratch. Room size grows 8px per floor in both dimensions (floor 100 = 1280×1120px room).
- Files: `script/dungeon.gd` (lines 51–72, 87–88)
- Improvement path: Bake nav mesh asynchronously. Cap room growth or use a fixed max size.

**Enemy `deal_with_damge()` polls global attack flag every physics frame**
- Problem: Every enemy reads `global.player_current_attack` every frame.
- Files: `script/enemy.gd` (lines 27–29, 67–75)
- Improvement path: Emit a signal from player on attack start/end; enemies connect to it.

---

## Fragile Areas

**Puzzle state in `dungeon.gd` is flat variables on the scene node**
- Files: `script/dungeon.gd` (lines 36–50)
- Why fragile: All five puzzle types share the same variable namespace (`puzzle_tiles`, `puzzle_next_index`, `math_answer`, `trap_greens_total`, etc.). Only one puzzle type is active at a time, enforced only by `puzzle_type` string — if the string ever mismatches, wrong handler runs on shared data.
- Safe modification: Only change puzzle logic inside its own `_build_puzzle_*` / `_handle_*_tile` pair.

**`player_ref` in NPC scripts is an untyped `null`-initialized variable**
- Files: `script/npc.gd` (line 4), `script/dungeon_npc.gd` (line 4)
- Why fragile: If player is freed before `body_exited` fires, `player_ref` becomes a dangling reference. The `has_method("open_shop")` check will crash on a freed object.
- Safe modification: Use `is_instance_valid(player_ref)` before calling methods on it.

**`_on_exit_body_entered` allows exit while enemies might be alive**
- Files: `script/dungeon.gd` (lines 304–309)
- Why fragile: The exit is blocked only while `puzzle_active` is true. No check that all enemies are dead.
- Safe modification: Add an `enemies_alive` counter incremented on enemy spawn, decremented before `queue_free`.

---

## Scaling Limits

**Enemy count: `5 + floor_no` with no hard upper limit**
- Current capacity: Floor 1 = 1–6 enemies; Floor 100 = 1–105 enemies attempted.
- Limit: At high floors, all enemies run `_physics_process` + NavigationAgent pathfinding every frame. No culling or LOD.
- Scaling path: Cap enemy count (e.g., `mini(5 + floor_no, 30)`). Disable `_physics_process` on enemies outside camera view.

**Upgrade levels cap at 50 (MAX_UPGRADE_LEVEL) with `* 0.01` stat formulas**
- Current capacity: Max defense = 50% damage reduction. Math is bounded and safe at current cap.
- Concern: 1% per level scaling makes early levels feel negligible.

---

## Dependencies at Risk

**`puzzle_test.gd` / `puzzle_test.tscn` is dead code in production**
- Risk: The puzzle test scene exists as a developer debug tool but has no guard preventing it from shipping. It duplicates ~280 lines from `dungeon.gd`.
- Migration plan: Delete it or gate it behind a `ProjectSettings` debug flag. Extract shared puzzle logic to eliminate duplication first.

---

## Missing Critical Features

**No game-over / death screen**
- Problem: `player_alive = false` is set when health reaches 0 but nothing handles it — no UI, no respawn, no scene transition. The game silently continues in a broken state.

**No enemy variety or scaling beyond count**
- Problem: All enemies share one scene (`enemy.tscn`) with fixed `speed = 40`, `health = 100`, `money_drop = 1000`. Floor number only changes enemy count, not stats.

**Money economy is broken — `money_drop = 1000` per kill at cost 50g base**
- Problem: `enemy.gd` drops 1000 gold per kill. `_upgrade_cost` starts at 50g. A player can fully upgrade all three stats (50 levels each) after roughly 8–10 enemy kills on floor 1.
- Files: `script/enemy.gd` (line 11), `script/player.gd` (line 287)

---

## Test Coverage Gaps

**No automated tests exist**
- What's not tested: All game logic — player movement, combat hit detection, enemy pathfinding, puzzle state machines, save/load round-trip, scene transitions, upgrade math.
- Files: All of `script/`
- Risk: Any refactor breaks silently. The only "test" is the `puzzle_test` scene which requires manual play.
- Priority: High for save/load (`global.gd` lines 75–121) and puzzle state machines (`dungeon.gd` lines 385–706).

---

*Concerns audit: 2026-05-08*
