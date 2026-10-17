# Stage 6 — Match Replays and Duel History

Implemented local completed-duel history and a read-only replay viewer in the existing Godot 4.x project. Verified with Godot 4.7.2 and the Compatibility renderer.

## Features

- **Match History** is accessible from the main menu. Recent completed matches appear newest first, with Solo, Local/offline and grouped Gauntlet filters. Details show UTC timestamp, winner, names, difficulty, arena and turn count.
- Each completed duel receives a random 128-bit ID and an ordering sequence. Records include mode, actual turn duration, arena, both complete character/revolver snapshots and exact coat colors, winner, concrete finisher, total turns and every resolved turn.
- Turn snapshots preserve both selected and effective actions; ammunition, shield streaks and alive state before/after; fired, blocked and empty-shot flags; shootout status; terminal status and winner. Capture happens at authoritative resolution, never from inputs/animations or predicted bot choices. Bot probabilities are not stored.
- **Replay** provides Previous, Next, Play/Pause, Restart, 0.5x/1x/2x speed, a turn counter, before/after state display and Return to History. Manual stepping demonstrates the existing combat animations. Play/Pause controls automatic sequencing; recorded turn durations determine playback timing.
- Replays use separate arena, audio and finisher instances. They never call combat resolution or bot decisions, reference live participants/profile data, record another victory, or write profile/history files.
- Existing arenas and cosmetic layers are restored from snapshots. Unsupported historical IDs fall back safely. All four cinematic finishers work at replay end; Classic remains supported. Random victories save the concrete effect actually shown, so replay does not reroll it.
- Individual Gauntlet duels share a Run ID. Run summaries retain date, final streak, ending opponent/status and retained defeated opponents, with access to individual replays. Interrupted runs are labeled on startup. Abandoned partial duels and nonterminal shootouts never become completed matches.

## Storage and integration

- History uses a separate schema-1 file: `user://match_history.json`. The existing profile format, profile backups and migration code are unchanged.
- Default retention is **100 completed matches**, configurable through `[history] max_matches` in the existing settings file. Values are bounded to 1–1000. Settings saves preserve this field and unrelated settings.
- Writes use a flushed temporary file and atomic replacement, retaining the previous validated `.bak`. A hash permits reuse of validation for unchanged files; externally changed primaries are revalidated before backup. Malformed, missing and unsupported newer files fail safely, including externally introduced newer schemas.
- The application uses one background file worker and at most one coalesced latest snapshot. Serialization/scheduling happens only at completion/run boundaries; no history file I/O occurs per frame or per turn. Normal shutdown flushes and joins pending work. Failed writes retain the completed recording in memory and expose a notice on History.
- Loaded records validate field types, action/state bounds, turn sequence/continuity and terminal results. History is capped at 16 MiB; additional oldest whole matches can be evicted to satisfy that guard. Individual recordings are capped at 10,000 turns and are omitted rather than saved partially if exceeded.
- GameManager supplies observer events and the already-chosen finisher. Replay has no result-processing callback into GameManager. Gauntlet streak counting, manual Continue/Space flow, difficulty, AI, controls, audio, arenas and cosmetics remain in their existing systems.
- Custom profile paths get a separate adjacent `.history.json`, keeping tests and alternate profiles isolated from the player's normal history.

## Files changed

| File | Purpose |
| --- | --- |
| `scripts/MatchHistory.gd` and `.uid` | New snapshot observer, validation, bounded storage, atomic worker and run metadata |
| `scripts/ReplayViewer.gd` and `.uid` | New independent replay rendering, controls, speed, state display, audio and finishers |
| `scripts/GameManager.gd` | Record resolution/run boundaries, configure/load history, poll/flush writes and open replay |
| `scripts/MainMenu.gd` | History entry point, filters, list/details, run summaries and replay navigation |
| `scripts/GameSettings.gd` | Load/preserve configurable history retention |
| `tests/test_match_history_data.gd` and `.uid` | Data, retention, recovery, worker, validation, configuration and restart tests |
| `tests/test_replays.gd` and `.uid` | Production recording, native UI, replay, all arenas/finishers and isolation tests |
| `tests/test_replay_performance.gd` and `.uid` | Bounded-write stress, frame time, node counts and resize checks |
| `README.md` | Usage, architecture, persistence, limits and test commands |
| `STAGE_6_REPORT.md` | This report |

Pre-existing changes from earlier stages were preserved.

## Validation

All listed suites passed with zero failures. New test profiles, settings, histories and captures are isolated under `.godot/`; player saves/history were not modified.

| New suite | Checks | Coverage |
| --- | ---: | --- |
| `test_match_history_data.gd` | 50 | Actual action/ammo/shield snapshots; shootouts, empty shots, blocks, fatigue, unique IDs, duplicate/partial omission, copies, run grouping, retention, corruption/backup/future schemas, bounded names, write failures, configurable limits, coalesced worker and flush cleanup |
| Same data suite `--verify`, fresh process | 3 | Newest-first persistence, snapshots, turns and finisher |
| `test_replays.gd` | 64 | Production Solo/local/Gauntlet recording; concrete Random result; all arena backgrounds; cosmetics; controls and speeds; real-time playback; every cinematic; run UI; exact unchanged live state, records and profile/history file bytes |
| Same native suite `--verify`, fresh process | 3 | All modes retained, run summary survives, History UI reloads |
| `test_replay_performance.gd` | 8 | 120 completed-duel stress retaining 100 whole matches, worker flush, bounded file, three speeds, stable node counts, 16:9 resize/layout |

**128 new checks passed.** Final editor import succeeded without script/resource errors. History, combat replay and Gauntlet summary captures under `.godot/replay_*.png` were visually reviewed.

Existing regressions passed: combat rules (23,739), bot personalities (25,308), profile data (1,049), Gauntlet data (1,271), finisher persistence (276), menu (63), Gauntlet integration (52), Gauntlet edge cases (115), Local Multiplayer (57), revolvers (117), finishers (113), original elimination flow (50), fullscreen (17), manual Gauntlet Continue including a real 31-second wait (26), combat flow (21), difficulty/turn timing (86). Total: **52,360 regression checks**. The final verbose revolver rerun also completed with clean shutdown output.

### Performance sample

Native Intel UHD Graphics 630, Compatibility renderer, production 60 FPS cap:

| Replay speed | Average frame time | Average draw calls |
| --- | ---: | ---: |
| 0.5x | 16.93 ms | 158.2 |
| 1x | 16.69 ms | 157.6 |
| 2x | 16.68 ms | 156.6 |

No nodes accumulated while repeatedly seeking/rendering. With 100 retained two-turn records, completion snapshot serialization/scheduling measured **12.87 ms at the 95th percentile**. File I/O executes on the worker; the test flushed the final snapshot and verified 100 complete records on disk. Results depend on hardware and history size.

## Limitations

- History begins with completed duels recorded by this version; old console text is not retroactively converted.
- Retention is bounded. Run final streaks remain exact, while defeated-name lists and replay availability cover retained duels only. Run summaries disappear after all associated matches age out.
- Duels exceeding 10,000 turns are omitted from replay history; gameplay and run records continue normally. The 16 MiB safety cap can retain fewer than the configured maximum for unusually large histories.
- Playback reuses current procedural artwork and animations rather than recording video/frame-perfect input timing. Historical missing IDs use current safe fallbacks; font/rendering details may vary by platform.
- Performance was sampled on the available Intel UHD 630, not every low-end GPU or worst-case history size.
