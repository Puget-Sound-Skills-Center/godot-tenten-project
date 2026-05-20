---
phase: 04-dungeon-depth
audit_date: 2026-05-18
auditor: gsd-ui-auditor
overall_score: 16/24
---

# Phase 4 UI Review

## Overall Score: 16/24

| Pillar | Score | Grade |
|--------|-------|-------|
| 1. Visual Hierarchy | 3/4 | PASS |
| 2. Readability | 2/4 | WARN |
| 3. Affordance & Discoverability | 3/4 | PASS |
| 4. Feedback & State Communication | 3/4 | PASS |
| 5. Consistency | 2/4 | WARN |
| 6. Polish & Completeness | 3/4 | PASS |

Scoring: 4=Excellent, 3=Good, 2=Needs Work, 1=Broken/Missing

---

## Pillar Findings

### 1. Visual Hierarchy — 3/4

The boss floor warning uses red (`Color(1.0, 0.3, 0.3)`) at HUD position `Vector2(8, 56)`, sitting directly below the floor label at `Vector2(8, 24)` and puzzle label at `Vector2(8, 40)`. The stacking creates a clear severity ladder: neutral floor info > puzzle instruction > boss danger. This is correct.

The lore object uses amber (`Color(0.55, 0.40, 0.20)`) which is distinct from all floor-tile colors (PUZZLE_TILE_COLOR is purple, TRAP_RED/GREEN are obvious, EXIT is bright green/yellow). Its distinctiveness in the color palette is adequate.

The secret wall at `SECRET_WALL_COLOR = Color(0.25, 0.18, 0.28)` is a very subtle purple-grey, only 7 units darker than the CAVE theme wall color (`Color(0.18, 0.16, 0.22)`). Against the cave floor (`Color(0.07, 0.06, 0.09)`) it is visible, but against the wall tiles it would nearly disappear if ever placed adjacent. The tile is meant to be discoverable but not obvious — this is a design intent tension, not strictly a hierarchy failure, but it is the weakest element.

The boss exit locked red (`TRAP_RED_COLOR`) is identical to the "wrong" math tile red. Both appear simultaneously on boss floors that also have math puzzles (impossible by code — boss floors skip puzzles — but the semantic collision is a latent confusion risk).

Deduction: 1 point for the secret wall color being nearly indistinguishable from wall tiles in the cave theme.

---

### 2. Readability — 2/4

**BLOCKER-level concern:** The lore object's "LORE" label uses `font_size 5`. At the game's 4x logical scale this renders at 20px effective — the absolute minimum readable size for Godot's default bitmap-style font. The Phase 2 UI-SPEC establishes `font_size 9` as the project's declared minimum (pause_menu.gd feedback label). A size-5 label is below the project's own floor. At native 1:1 this is 5px — effectively unreadable without scaling.

The "LORE" label is also positioned at `Vector2(-8, -8)` — centered inside the 20x20 ColorRect tile. At font_size 5, the 4-character string "LORE" will overflow its implied bounding box, causing clipping or misalignment depending on the default font's glyph metrics. No `clip_text` or `custom_minimum_size` is set, so overflow behavior is undefined.

The `_prompt_label` (font_size 7) and secret wall prompt (font_size 7) are at the low end but within the effective 28px range — borderline but passable. The boss HUD label (`boss_hud_label`) has no explicit `font_size` override, meaning it inherits Godot's default theme size (typically 16px logical = 64px effective). This is actually the largest text in the game — larger than anything in Phase 2's typography scale — and no conscious decision to make it large is documented.

The floor label at `Vector2(8, 24)` also has no font_size override, same issue.

**Summary of size violations:**
- `font_size 5` on lore "LORE" label — below project minimum, likely unreadable
- No font_size override on `boss_hud_label` — inherits default (oversized relative to spec)
- No font_size override on `floor_label` — pre-existing but unresolved

---

### 3. Affordance & Discoverability — 3/4

All three Phase 4 interactables correctly follow the project's proximity-prompt pattern:
- Lore object: shows `[E] Inspect` on player enter, hides on exit (lore_object.gd lines 53, 59)
- Secret wall: shows `?` hint + `[E] Secret?` on player enter, hides on exit (dungeon.gd lines 441-454)
- Fetch chest (pre-existing, Phase 3 context): shows `[E] Open` on enter, hides on exit

The lore object ambient label "LORE" is always visible, acting as a passive affordance. The secret wall has NO ambient label — only the proximity hint. Given the secret wall is meant to be hidden, this is correct design.

One concern: the secret wall's `?` hint label (font_size 8, `Color(1.0, 0.9, 0.6)`) appears at `Vector2(-3, -TILE - 4)` which is 20px above the tile center, and the prompt label appears at `Vector2(-20, -TILE - 16)` which is 32px above. With the camera at 4x scale these offsets are 80px and 128px above the tile. Both are above the tile but the stacking could cause the prompt to overlap other nearby world-space labels (e.g. exit "NEXT" label, puzzle tile numbers). No z_index is set on these labels; they render at the Area2D's z_index (default 0), below puzzle tiles (`z_index = -1` on puzzle tile Area2Ds, but labels are children of those).

Deduction: 1 point for the potential world-space label collision and for `[E] Secret?` being a weaker affordance copy than the rest of the project's pattern (discussed in Pillar 5).

---

### 4. Feedback & State Communication — 3/4

Boss floor state machine covers three states correctly:
1. **Locked** — exit tile color = `TRAP_RED_COLOR`, boss HUD = "BOSS FLOOR — Defeat all enemies to advance"
2. **Cleared** — exit tile color = `EXIT_UNLOCKED_COLOR` (yellow), exit label text = "OPEN", boss HUD = "Room cleared! Proceed."
3. **Player touches locked exit** — boss HUD text resets to the warning string (dungeon.gd line 564)

State 3 is a good defensive feedback loop: the player gets a reminder if they bump the exit before clearing. However, there is no visual flash or sound on the failed exit attempt — the label just resets to text it may already be showing. If the player never cleared the room and walks into the exit repeatedly, the label change is invisible (text is already the warning).

The lore object gives no post-interaction feedback state. After `dialogue_manager.open()` completes, the lore object remains identical — same amber tile, same "LORE" label. There is no "already read" visual state (e.g. dimmed color, checkmark). For lore fragments this is acceptable for a v1, but worth noting.

The gold reward from secret wall activation (`global.money += gold`) has no feedback text — no floating "+50g" or HUD flash. The player receives gold silently. The HUD money label will update on next `_update_hud()` frame, which is every physics frame, so the update is fast but still invisible at the moment of activation.

Deduction: 1 point for the silent gold reward on secret wall activation and the no-op boss HUD reset when the label is already showing the warning.

---

### 5. Consistency — 2/4

**WARNING: Prompt copy diverges from established pattern.**

The project's established interaction prompt pattern, confirmed across Phases 1-3:
- NPC proximity: `[E] interact` (dungeon_npc.gd pattern, world NPC pattern)
- Phase 2 dialogue spec: advance prompt is "Press E to continue"
- Fetch chest (dungeon.gd line 996): `[E] Open`

Phase 4 introduces:
- Lore object: `[E] Inspect` — new verb not used elsewhere
- Secret wall: `[E] Secret?` — not a verb, uses a question mark, inconsistent grammatical form

`[E] Inspect` is acceptable as a contextual verb. `[E] Secret?` is not — it reads as a question rather than an action label. Every other prompt in the codebase uses `[E] <Verb>` form. This breaks the pattern.

**Font size inconsistency:**

| Element | Phase 4 font_size | Nearest Phase 1-3 analog | Analog size |
|---------|-------------------|--------------------------|-------------|
| Lore "LORE" label | 5 | Save point "SAVE" label (dungeon.gd line 584) | 6 |
| Prompt labels | 7 | No direct analog | — |
| Boss HUD label | none (inherits default) | Floor label (dungeon.gd line 622) | none (inherits) |
| Secret "?" hint | 8 | Fetch chest prompt (dungeon.gd line 997) | 8 |

The fetch chest prompt (Phase 3 code, same file) uses font_size 8. Phase 4 prompts use font_size 7. Same visual role, different size — inconsistent within dungeon.gd itself.

The lore object's `[E] Inspect` prompt (lore_object.gd line 22, font_size 7) does not match the fetch chest `[E] Open` prompt (dungeon.gd line 997, font_size 8) — same interaction class, different sizes.

Deductions: prompt copy grammatical inconsistency (`[E] Secret?`) and font size drift between same-role elements (-2 points).

---

### 6. Polish & Completeness — 3/4

**Handled correctly:**
- Secret wall labels are hidden before `queue_free()` in `_on_secret_wall_activated()` (dungeon.gd lines 462-465) — fixes the frame-of-death flicker that was previously a known issue (per codebase history note IN-04 analog).
- Lore prompt correctly hides on `body_exited` (lore_object.gd line 59).
- Boss HUD label is only created when `floor_no % 25 == 0 and floor_no > 0` (dungeon.gd line 639) — correctly guarded.
- `_spawn_lore_object` guards against missing dialogue data (`if not dialogue_data.DIALOGUES.has("lore_object")`) — graceful skip.

**Issues:**

The lore object calls `dialogue_manager.open("lore_object", lore_id)` directly from `_process()` in `lore_object.gd` line 47 — with no guard against the dialogue panel already being open. If a dungeon_dialogue_npc dialogue is active while the player is near a lore object, pressing E will call `open()` on top of an active session. Whether `dialogue_manager.open()` handles re-entrant calls is not visible in this file, but the absence of a guard here is a completeness gap (the fetch chest in dungeon.gd line 127 guards: `if dialogue_manager._panel != null and dialogue_manager._panel.visible: continue`).

The `_lore_panel` in player.gd (lines 217-229) shows the last collected lore item key as a HUD badge. The `_update_hud()` method (line 324-330) iterates `global.items` and shows the first item with count > 0. This has no relationship to lore_object.gd — the badge shows collected items generically, not specifically lore fragments. The lore badge label is clipped (`clip_text = true`, size 80x16) but no `custom_minimum_size` is set on the badge itself, so at very long item keys the label truncates silently with no ellipsis indicator.

Deduction: 1 point for the missing dialogue re-entrancy guard in lore_object.gd.

---

## Issues

| ID | Pillar | Severity | Description | Recommended Fix |
|----|--------|----------|-------------|-----------------|
| UI-04-01 | Readability | BLOCKER | `font_size 5` on lore "LORE" label (lore_object.gd:30) is below project minimum (9px per Phase 2 spec) and will be illegible at any resolution | Change to `font_size 7` minimum; prefer 8 to match fetch chest prompt |
| UI-04-02 | Consistency | WARNING | `[E] Secret?` (dungeon.gd:402) breaks `[E] <Verb>` prompt pattern used by all other interactables | Change to `[E] Search` or `[E] Inspect` |
| UI-04-03 | Consistency | WARNING | Prompt labels font_size 7 in Phase 4 vs font_size 8 in Phase 3 fetch chest (dungeon.gd:997) — same visual role, different size | Normalize all `[E] *` world-space prompts to font_size 8 |
| UI-04-04 | Polish & Completeness | WARNING | lore_object.gd:46 calls `dialogue_manager.open()` with no guard against an already-open panel; dungeon.gd fetch chest has this guard (line 127) | Add `if dialogue_manager._panel != null and dialogue_manager._panel.visible: return` before calling open() |
| UI-04-05 | Readability | WARNING | `boss_hud_label` and `floor_label` have no `font_size` override (dungeon.gd:621, 641) — inherits Godot default (16px logical = 64px effective), making these the largest text in the game with no design intent | Add explicit `add_theme_font_size_override("font_size", 10)` or document the intentional size |
| UI-04-06 | Feedback & State Communication | WARNING | Secret wall gold reward is silent — `global.money += gold` with no visual feedback at moment of activation | Add a short-lived Label child to the area before queue_free, or update a HUD flash label |
| UI-04-07 | Visual Hierarchy | WARNING | `SECRET_WALL_COLOR = Color(0.25, 0.18, 0.28)` is only marginally distinct from `WALL_COLOR = Color(0.18, 0.16, 0.22)` in the CAVE theme — players may not register it as a separate tile type at a glance | Increase lightness or saturation: e.g. `Color(0.30, 0.20, 0.38)` |
| UI-04-08 | Feedback & State Communication | WARNING | Boss HUD warning text resets to itself (dungeon.gd:564) when the label already shows the warning — provides no new feedback on repeated exit-bump | Add a brief color flash (tween alpha) on the label to signal the failed attempt |

---

## Verdict

Phase 4 delivers functional UI for all three features — lore objects, boss floors, and hidden rooms — with correct state transitions and proper proximity-prompt show/hide behavior. The most damaging issue is the `font_size 5` "LORE" label, which falls below the project's own documented minimum and is likely illegible in practice; this is a one-line fix. Two consistency failures compound into a 2/4 score on Pillar 5: the `[E] Secret?` prompt breaks the project's `[E] <Verb>` grammar contract, and font_size drift between same-role prompts (7 vs 8) indicates Phase 4 was not cross-referenced against Phase 3 dungeon.gd during implementation. The missing re-entrancy guard in lore_object.gd is the most impactful completeness gap — the fetch chest in the same file has this guard, so the fix is a copy-paste. Top three action items: (1) fix `font_size 5` to 8 on lore label, (2) change `[E] Secret?` to `[E] Search`, (3) add the dialogue open guard to lore_object.gd.
