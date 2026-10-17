# Stage 5A — cosmetic revolvers

Implemented Peacemaker, Schofield, Python and Cobra silhouettes, with four metal finishes and four grips (64 combinations). All use the same lightweight procedural drawing in the enlarged preview, character rendering, gameplay and WANTED portraits.

## Usage and persistence

- Open **Customize → Revolver**. Choose model, metal and grip; the preview updates on the next rendered frame.
- **Equip** confirms the saved-profile draft, including existing character and elimination choices. **Cancel** discards pending changes. **Look** switches back to character customization without losing a saved-profile draft.
- The target selector also offers independent **Local Player 1** and **Local Player 2** session loadouts. Equipping either changes no primary-profile data. They survive rematch/menu navigation and reset on process restart. Player 1 follows the saved gun until explicitly overridden for the session.
- Profile schema **2** stores `revolver_model`, `revolver_finish`, and `revolver_grip` as explicit root fields. Defaults: `peacemaker`, `iron`, `walnut`. Version-1 profiles, missing fields and malformed IDs load safely. Identity, statistics, appearance, elimination choice, reset revisions, temporary replacement and backup recovery remain intact.
- Legacy character-only equip calls retain the current revolver. Save failures roll back the entire attempted appearance/effect change.

## Files changed in this stage

| File | Purpose |
| --- | --- |
| `scripts/RevolverAppearance.gd` (new) | Stable model/finish/grip catalogs, validation, procedural gun geometry and muzzle offsets. |
| `scripts/RevolverPreview.gd` (new) | Enlarged lightweight preview using the same renderer. |
| `scripts/CharacterAppearance.gd` | Include validated revolver IDs in shared runtime appearance. |
| `scripts/Arena.gd` | Draw equipped models and align flashes/trails using their muzzle offsets, existing recoil/reload transforms and mirrored facing. |
| `scripts/ProfileManager.gd` | Schema-2 serialization, safe defaults/migration, cross-version reset backup recovery and legacy equip preservation. |
| `scripts/MainMenu.gd` | Revolver page, live selectors, equipped state, apply/cancel and independent session targets. |
| `scripts/GameManager.gd` | Bind session-only revolvers to local fighter appearances; Solo continues to use the saved gun and default bot gun. |
| `tests/test_revolvers.gd` (new) | Render all combinations; check migration, recovery, cancellation, persistence, muzzle pixels, local isolation and finishers. |
| `tests/test_profile_ui.gd` | Compare complete sanitized appearances while preserving original character-only test inputs. |
| `tests/test_profile_resets.gd` | Compare complete sanitized appearances, including during backup recovery. |
| `tests/test_flow.gd`, `tests/test_difficulty.gd`, `tests/test_turn_tick.gd` | Advance the synthetic debounce clock before rapid pause/resume calls. These tests predated the existing multiplayer pause-key debounce; gameplay debounce/timing code was not changed. |
| `README.md` | Revolver usage, schema, local session behavior, architecture and test commands. |
| `STAGE_5A_REPORT.md` (new) | This report. |

Godot generated `.gd.uid` companions for the two new scripts and new test. Existing multiplayer/difficulty work already present in the workspace was preserved.

## Validation

Final checks passed on **Godot 4.7.2 / Windows / GL Compatibility / Intel UHD 630**:

| Suite | Checks passed |
| --- | ---: |
| New revolver integration | 117 |
| Revolver persistence in a separate process | 4 |
| Combat rules | 23,739 |
| Bot personality / restrictions | 25,308 |
| Profile data / statistics | 1,049 |
| Existing local multiplayer / input / session statistics | 57 |
| Difficulty / real turn durations | 86 |
| Turn flow / deadlines | 21 |
| Menu navigation / settings | 61 |
| Character customization / gameplay appearance | 26 |
| Character profile restart | 3 |
| Combat visuals | 101 |
| WANTED elimination integration | 50 |
| Wanted profile / confirmed resets | 51 |
| Statistics-reset restart / recovery | 16 |
| Full-reset restart / recovery | 7 |
| Audio | 67 |
| Developer console / input | 24 |
| Turn tick | 25 |
| Fullscreen / scaling | 17 |

The new suite verified 64 distinct rendered combinations, immediate preview updates, no writes while trying/canceling, confirmed equip, preserved character/effect fields, version-1 migration, corrupted-primary backup recovery, confirmed reset safety, invalid-ID defaults and failed-save rollback. It also verified independent local finishes/grips, no primary-profile writes from guest slots, rematch retention, unchanged reload/clash outcomes and deadlines, both local winners' WANTED portraits, Solo victory and exactly-once result recording. Pixel samples verified muzzle flashes on all four models facing both directions; trails start at the same model offsets.

Final editor import and a normal standalone project launch completed without script or missing-resource errors. Rendered previews were visually inspected. Optional captures are `.godot/revolver_models.png`, `.godot/revolver_combinations.png`, and `.godot/revolver_customize.png`; tests use isolated saves under `.godot/`.

Reproduce the stage-specific checks in order:

```text
godot --path . --script tests/test_revolvers.gd -- --capture
godot --path . --script tests/test_revolvers.gd -- --verify
```

No combat rules, reload/ammo quantities, shield restrictions, shoot costs, damage/victory conditions, AI, difficulty durations, player control mappings, statistics definitions, sound assets or finisher logic were changed. Cosmetic data is used only by appearance, persistence and rendering paths.

## Known limitations

- These are stylized geometric representations, not detailed firearm replicas. Fine engraving and grip detail are clearest in the enlarged preview because combat weapons are small.
- Local-player revolver overrides are intentionally session-only; only the primary saved configuration survives restart.
- Tested on Windows with Godot 4.7.2; other platforms and older Godot 4.x releases were not exercised. No sustained performance benchmark was run; the implementation adds no textures, shaders, particles or per-frame nodes.
