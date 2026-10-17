# Stage 5B — additional duel arenas

Added **Dusty Main Street**, **The Last Call Saloon**, **Iron Horse Station** and **Ghost Town**, while preserving the original scene as **Desert Ridge**. Both Solo and Local use the same shared combat renderer and arena catalog.

## Selection and behavior

- Play now shows the selected arena name, a matching thumbnail and a description before either launch button.
- The preference saves through the existing settings manager as `[cosmetics] arena`. Old/missing/invalid preferences use Desert Ridge. Unrelated settings and profile data are preserved.
- Random includes all five locations. A dedicated arena RNG chooses once at a new duel's start without consuming bot RNG.
- Rematches retain the actual location, including a resolved Random choice. Returning to Play and starting a new duel rolls Random again.
- Arena changes never affect an active match. Difficulty, turn deadlines, combat state, controls, statistics, saved appearances and session revolver loadouts retain their existing behavior.

## Modified files

| File | Change |
| --- | --- |
| `scripts/ArenaDefinitions.gd` (new) | Stable IDs, display names, visual feature/palette configurations, ambient data and preview metadata for five locations. |
| `scripts/ArenaBackdrop.gd` (new) | Cached procedural scenery painter with reusable buildings, signs, bar, saloon doors, lanterns and locomotive features; preserves original desert geometry. |
| `scripts/ArenaAmbient.gd` (new) | Bounded analytic dust, lantern glow, steam and mist, drawn behind actors without particles or per-frame nodes. |
| `scripts/ArenaPreview.gd` (new) | Matching scenery thumbnails using the shared painter; Random collage. |
| `scripts/Arena.gd` | Add background/ambient layers behind the existing fighters/effects; move original scenery into the reusable painter. |
| `scripts/GameManager.gd` | Resolve the cosmetic location at match entry, keep it on rematch, and use a separate arena RNG. |
| `scripts/GameSettings.gd` | Validate, load and save the arena preference without changing difficulty/audio/display behavior. |
| `scripts/MainMenu.gd` | Add selector, preview and description to the existing Play page; compact its controls to fit the existing panel. |
| `tests/test_arenas.gd` (new) | Integration, preview comparison, gameplay/effect visibility, random isolation, restart persistence and fullscreen checks. |
| `tests/test_arena_performance.gd` (new) | Short rendered comparison, static draw caching and node-count stability. |
| `README.md` | Selection, persistence, architecture, Random/rematch semantics and test instructions. |
| `STAGE_5B_REPORT.md` (new) | This report. |

Godot generated `.gd.uid` companions for the four new implementation scripts and two new tests. No existing regression test scripts were changed during this stage. Earlier uncommitted multiplayer, difficulty and revolver work was preserved.

## Tests performed

Final runs passed on **Godot 4.7.2 / Windows / GL Compatibility / Intel UHD 630**:

| Suite | Checks passed |
| --- | ---: |
| New arena integration | 242 |
| Fixed arena preference across a process restart | 6 |
| Random preference across another process restart | 6 |
| New short arena performance comparison | 20 |
| Existing combat rules | 23,739 |
| Existing bot personality/restrictions | 25,308 |
| Existing turn flow/deadlines | 21 |
| Existing local multiplayer/controls | 57 |
| Existing difficulty/real turn durations | 86 |
| Existing profile data/statistics | 1,049 |
| Existing menu navigation/settings | 63 |
| Existing revolver integration | 117 |
| Existing WANTED elimination integration | 50 |
| Existing character customization/gameplay appearance | 26 |
| Existing combat visuals | 101 |
| Existing audio | 67 |
| Existing developer console/input | 24 |
| Existing turn tick | 25 |

Arena integration checks compare preview pixels to the actual static scenery, exercise both modes in every location, verify revolver loadouts, sample actual flash/shield pixels on both sides, resolve reload/block/lethal turns, check Solo statistics and local isolation, run WANTED effects, rematch, and return to menu. Random checks verify all locations are reachable, exactly one isolated RNG choice occurs at entry, rematches do not reroll, bot RNG is untouched, and changing a preference does not swap the current scene. Fullscreen checks verify the actual window mode, visible/clickable controls, selected Local launch, uniform arena scaling and return to windowed mode.

Editor import and a normal standalone launch completed without script or missing-resource errors. Scene composition and the Play page were visually reviewed. The saloon sign and Ghost Town moon sit below the primary HUD region.

## Short performance results

Measured 90 rendered frames per location after 12 warm-up frames, with the production 60 FPS cap, actors, HUD, combat effects and ambient layers active:

| Location | Mean frame time | 95th-percentile frame time | Mean total draw calls |
| --- | ---: | ---: | ---: |
| Desert Ridge | 16.71 ms | 18.18 ms | 77.5 |
| Dusty Main Street | 16.71 ms | 18.45 ms | 108.5 |
| The Last Call Saloon | 16.67 ms | 17.83 ms | 87.5 |
| Iron Horse Station | 16.68 ms | 17.29 ms | 107.5 |
| Ghost Town | 16.68 ms | 17.31 ms | 132.5 |

All locations averaged approximately 60 FPS in this sample. Static scenery was not redrawn during the sampled frames; node counts stayed constant. Ambient shape counts are bounded at 16 (current maximum is 12). No textures, shaders, particle systems, physics or audio assets were added.

This is a short, capped smoke comparison on one integrated GPU, not an uncapped GPU/headroom benchmark or a long-session performance guarantee. Other operating systems and Godot versions were not exercised.

## Reproduction and artifacts

Run these in order with the Godot executable:

```text
godot --path . --script tests/test_arenas.gd -- --capture
godot --path . --script tests/test_arenas.gd -- --verify
godot --path . --script tests/test_arenas.gd -- --verify-random
godot --path . --script tests/test_arena_performance.gd
```

Tests use isolated profile/settings fixtures under `.godot/`. Captures include `arena_selection.png`, `arena_contact_sheet.png` and one `arena_<id>.png` per location; performance data is in `arena_performance.json` there. Contact-sheet order: Main Street / Saloon; Station / Ghost Town; original Desert Ridge.

The arenas are stylized procedural illustrations. Ambient effects are deliberately restrained, and thumbnails show static scenery rather than animated weather. Existing combat rules, bot probabilities, durations, controls, statistics definitions, cosmetics and finisher logic were not changed.
