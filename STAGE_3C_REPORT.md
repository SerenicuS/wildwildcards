# Stage 3C implementation report

Implemented equippable Classic and WANTED: ELIMINATED cosmetics. The latter uses shared parchment styling, the defeated fighter's actual appearance, a diagonal distressed red stamp, a 190 ms original PCM impact, and subtle poster motion. The complete transition takes approximately 1.3 seconds and supports click/key skip. R can immediately rematch. Classic and bot victories retain the original result presentation.

Combat resolution, statistics and victory/defeat audio run once before cosmetic presentation. No combat rules, AI, turn deadlines, controls, display configuration, existing audio samples, or scene references were changed. Repeated terminal callbacks are ignored. Preview never starts a match or records a result. Rematch/menu transitions cancel the tween, portrait animation and stamp audio.

## Files changed

| File | Change |
| --- | --- |
| `scripts/EliminationEffects.gd` (new) | Stable IDs, names, descriptions, safe unknown-ID fallback. |
| `scripts/EliminationController.gd` (new) | Reusable defeated-character descriptor, poster/Classic preview, tween sequencing, skip and cancellation. |
| `scripts/EliminationStamp.gd` (new) | Procedural distressed stamp; retained font resource. |
| `scripts/GameManager.gd` | Connect confirmed lethal results and cosmetic completion; choose winner's effect; cancel on navigation; guard duplicate terminal processing. |
| `scripts/MainMenu.gd` | Effect picker, descriptions, preview, shared Equip action, selected/equipped state. |
| `scripts/ProfileManager.gd` | Transactional appearance/effect equip through existing save/backup architecture; roll back both on save failure. |
| `scripts/CharacterPreview.gd` | Optional exact coat override for the original bot appearance. |
| `scripts/AudioManager.gd` | Stamp resource and selective sound cancellation using the existing voice pool. |
| `assets/audio/stamp.wav` and `.import` (new) | Mono 22,050 Hz, 16-bit PCM; same uncompressed import format as existing effects. |
| `tools/generate_audio.py` | Reproducible stamp generation; `--stamp-only` preserves all existing samples. |
| `tests/test_elimination.gd` (new) | Cosmetic integration, preview, persistence, skip, cleanup, audio routing and save rollback tests. |
| `tests/test_audio_samples.py` | Validate the stamp alongside existing PCM assets. |
| `README.md` | Usage, architecture, compatibility, testing and limitations. |
| `STAGE_3C_REPORT.md` (new) | This report. |

Godot also generated `.gd.uid` companions for the three new scripts and the new test script. Rendered test screenshots and isolated save fixtures are under `.godot/`.

## Tests performed

All final runs passed using Godot 4.7.2 on Windows, with rendered tests using GL Compatibility on Intel UHD 630:

| Suite | Passed checks |
| --- | ---: |
| New elimination integration | 50 |
| Elimination persistence in a separate process | 3 |
| Combat rules | 23,739 |
| Turn flow / timing | 21 |
| Bot personality / restrictions | 25,308 |
| Profile data / resolved statistics | 1,049 |
| Menu navigation / settings | 58 |
| Profile UI / actual equipped character rendering | 26 |
| Combat visuals | 101 |
| Debug console / gameplay input | 24 |
| Audio / branding | 67 |
| Turn tick | 25 |
| Wanted profile / confirmed resets | 51 |
| Statistics-reset restart / recovery | 16 |
| Full-profile-reset restart / recovery | 7 |
| Fullscreen / UI scaling | 17 |

The elimination suite covers both winners, Classic compatibility, shootout draws, blocks, empty shots, actual bot portrait colors, atomic equip failures, effect selection persistence, preview isolation, stamp audio routing/volume, automatic completion, click/key skip, repeated terminal callbacks, R rematch and menu cancellation. All tests use isolated profile/settings files, preserving the real player profile.

PCM checks passed for all ten assets (duration, headroom, RMS, fades and stereo routing). The new stamp peaks at 0.55 before the existing audio mix gain. Editor import and a standalone normal project launch completed without script or missing-resource errors. Rendered screenshots were inspected for Customize layout, portrait appearance and stamp legibility.

## Known limitations

- Portraits reuse the existing geometric character artwork; no new character art was introduced. Solo's bot retains its existing fixed appearance and Classic loadout.
- System serif font fallback can change letter shapes slightly across platforms.
- Validation was performed on Windows/Godot 4.7.2; other operating systems were not exercised.
- The existing `equipped_elimination_effect` save key and schema version are preserved. Unknown future IDs are retained in saves and rendered as Classic until a supported effect is explicitly equipped.
