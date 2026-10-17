# Stage 5E — Additional Elimination Finishers

Implemented in the existing finisher, profile and post-resolution victory architecture. Godot 4.7.2 imports and launches without missing script/scene/resource errors.

## Result

- Original **WANTED: ELIMINATED** is preserved, including defeated-character appearance, stamp sound, motion and timing.
- **Dead Man's Hand** slides/fans four Western cards into view: A♠, A♣, 8♠, 8♣. The winner's name and winning-hand message appear afterward.
- **High Noon** reveals the winning character's actual customized silhouette and revolver against a stylized sunset.
- **Smoke & Mirrors** draws bounded translucent revolver smoke and reveals the winning name. Its revolver uses the winner's cosmetic configuration.
- **Random** samples one of the four cinematic finishers on each victory, using a dedicated cosmetic RNG. The saved preference stays `random`; previews do not consume bot decision RNG. Legacy Classic remains an explicit optional selection and is excluded from Random.
- Customize has a **Finisher** selector, descriptions, Preview, Equip and draft/cancel behavior. Previews cannot equip, record results, increment streaks or change statistics.
- New cinematics take approximately **1.44 seconds**, including the original 0.18-second space for gunfire/hit effects. WANTED retains approximately 1.29 seconds. A visible **Skip Finisher** button, mouse click and keyboard skip are supported; R retains immediate rematch behavior.

## Integration and persistence

`EliminationEffects.gd` centralizes stable IDs, display names, descriptions, preview availability, animation references and durations. `EliminationController.gd` retains sole playback/completion ownership and its existing `finished` signal. `FinisherVisual.gd` provides the three new native presentations, driven by one controller tween.

GameManager still resolves combat and records the result first. It passes separate winner and defeated descriptors to cosmetic playback, then opens results through the existing completion callback. No result recording or progression is duplicated in animation code.

- Solo player victories use the saved selection. Existing bot victories retain their explicit Classic behavior.
- Gauntlet increments a confirmed streak exactly once, waits for natural finisher completion or skip, then starts the existing victory transition. Existing Next Duel/Space/R shortcuts remain available.
- Local P1 and P2 use independent session finisher choices. Select the local target under Clothing & Colors, return to Look, select a finisher and Equip. P1 follows the primary saved selection until overridden; P2 defaults to WANTED. These overrides survive rematches and never overwrite primary saved equipment.
- Schema **5** retains the existing `equipped_elimination_effect` field and all names, statistics, expanded appearances, revolvers, presets, Gauntlet records, transactional writes and backup/reset recovery. Missing or invalid saved finisher IDs now fall back to WANTED as requested. Valid Classic saves remain Classic. Unsupported newer save versions remain protected from writes.
- Combat mechanics, ammo/shields, AI/personality, turn durations, controls, arena flow, statistics and result audio are unchanged.

## Files changed in this stage

| File | Change |
| --- | --- |
| `scripts/EliminationEffects.gd` | Expanded registry, durations, fallback and isolated Random selection |
| `scripts/EliminationController.gd` | Winner descriptor, new presentation dispatch, explicit skip action, shared completion/cancellation |
| `scripts/FinisherVisual.gd` + `.uid` | New lightweight card, sunset/silhouette and smoke drawing |
| `scripts/MainMenu.gd` | Finisher selector and independent local finisher drafts/equipment/previews |
| `scripts/ProfileManager.gd` | Schema 5, WANTED default/invalid-ID fallback and stable-ID validation |
| `scripts/GameManager.gd` | Pass winner context and select each local winner's equipped finisher |
| `tests/test_finishers_data.gd` + `.uid` | Registry, migration, Random, saves and restart tests |
| `tests/test_finishers.gd` + `.uid` | Native previews, animations, skips, mode integration and cancellation tests |
| `tests/test_finishers_performance.gd` + `.uid` | Compatibility renderer benchmark, repeated playback cleanup and 16:9 resize checks |
| `tests/test_elimination.gd` | Preserve explicit Classic baseline; expect expanded registry and new invalid-ID fallback |
| `tests/test_profile.gd`, `tests/test_profile_resets.gd`, `tests/test_revolvers.gd` | Update default/fallback expectations; reset fixture uses a valid saved finisher |
| `tests/test_gauntlet_edges.gd` | Explicitly equip Classic for the existing immediate-transition baseline |
| `README.md` | Selection, local targets, architecture, persistence, timings and test commands |
| `STAGE_5E_REPORT.md` | This report |

All pre-existing changes from earlier stages were retained.

## Tests performed

All final tests passed with zero failures. Profile fixtures/captures are isolated under `.godot/`; player saves were not modified.

| New suite | Checks | Coverage |
| --- | ---: | --- |
| `test_finishers_data.gd` | 276 | Legacy versions 1–4, missing/invalid IDs, all saved selections, preserved cosmetics/presets/records/backups, Random pool, registry references and durations, statistics reset |
| Same data suite with `--verify` in a fresh process | 3 | Random preference, clothing/revolver/preset and record persistence |
| `test_finishers.gd` | 113 | All previews; natural completion of all four cinematics; correct winner/defeated context; actual keyboard/mouse skip and R rematch; empty/block/shootout exclusions; duplicate-result guards; Random per victory and bot RNG isolation; independent local choices/winners; natural and skipped Gauntlet completion; one streak/transition per win; menu/rematch cancellation |
| `test_finishers_performance.gd` | 18 | Repeated playback/skip without accumulated nodes/tweens, frame budget, centering and visible skip at 960×540, 1280×720 and 1600×900 |

**410 Stage 5E checks passed.** Captured and visually reviewed Dead Man's Hand, High Noon, Smoke & Mirrors and Customize under `.godot/finisher_*.png`.

Existing regression suites passed: combat rules (23,739), bot personalities (25,308), profile data (1,049), profile UI (26), resets (51), original elimination flow (50), revolvers (117), expanded appearance data (231), expanded appearance UI (55), Gauntlet data (1,271), Gauntlet integration (48), Gauntlet edge cases (115), multiplayer (57), menu (63), arenas (242), flow (21), difficulty/timing (86), fullscreen (17), audio (67), turn tick (25), combat visuals (101). Total: **52,739 regression checks**. Final editor import also succeeded.

### Performance sample

Native GL Compatibility renderer on Intel UHD Graphics 630, production 60 FPS cap, 60 sampled frames per presentation after warmup, with the existing menu rendered beneath the overlay:

| Finisher | Average frame time | Average draw calls |
| --- | ---: | ---: |
| WANTED baseline | 16.68 ms | 256.0 |
| Dead Man's Hand | 16.65 ms | 178.6 |
| High Noon | 16.69 ms | 157.6 |
| Smoke & Mirrors | 16.69 ms | 206.6 |

Repeated playback did not accumulate scene nodes. No shaders, textures, particles, recurring timers or new audio assets were added.

## Limitations

- Visuals are stylized native 2D shapes, consistent with the existing small geometric character artwork. Smoke uses a fixed maximum of 20 soft puff groups, rather than a fluid simulation.
- New finishers reuse existing victory/defeat audio; WANTED retains its stamp sound. There are no new cinematic soundtracks or effect samples.
- Local finisher overrides are session-only. Bots retain Classic because they have no editable finisher loadout.
- System serif font appearance may vary by platform. Performance was sampled on the available Intel UHD 630 device, not every GPU/resolution.
