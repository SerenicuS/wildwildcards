# Stage 5C — Endless Gauntlet

Implemented a separate Endless Gauntlet mode while retaining Solo Duel and Local Multiplayer. No previous consecutive-victory mode existed to migrate.

## Behavior

- Start from **Play → Endless Gauntlet**. A fresh run begins at streak 0 / duel 1 and locks in the currently selected difficulty.
- Each opponent uses the existing fair bot decision system with a fresh personality. Display names, hats, outfit colors, accessories and revolver combinations use existing cosmetic catalogs and a separate cosmetic RNG.
- All five existing arenas are reused. Consecutive arena repeats are excluded whenever more than one is available. The saved Solo/Local arena preference remains unchanged.
- Confirmed lethal wins increment the current streak and persistent victory count exactly once. Blocks, empty shots and simultaneous shootout draws do not advance the run.
- The existing WANTED finisher completes first. A one-second victory transition then names the next opponent and previews its arena. Next Duel / Space / R can shorten that transition; R during WANTED skips the cosmetic and continues. Each next duel reuses the existing countdown, with both duelists' ammo, shield streaks, selections and timer reset.
- Losing ends the entire run and shows final/best streak, Restart Gauntlet and Main Menu. Restart begins at zero.
- Pause Restart Run, leaving for the menu/another mode, and native-window closing require confirmation during active runs. Confirmation freezes the current phase; cancel restores it and adjusts the appropriate deadlines. Already-expired turns resolve before an exit request is accepted.

## Records and compatibility

Profile schema **3** adds a separate `gauntlet` object:

```json
{"best_streak": 0, "total_runs": 0, "duel_victories": 0}
```

Runs count once when started, including later-abandoned runs. Achieved wins and personal bests save immediately using the existing temporary-file/backup architecture. Loss and exit never count another run or award an unfinished victory. Schema 1/2 saves receive safe defaults and retain identity, cosmetics, Solo statistics, elimination choices and reset revisions. Newer unsupported saves stay protected.

Gauntlet does not add to Solo lifetime match/action counters or Local session scores. Developer statistics/profile resets include the new records, use the existing confirmation/backup protections, and remain independently blocked by ProfileManager throughout an active run, including between duels.

## Files modified in this stage

| File | Change |
| --- | --- |
| `scripts/GauntletRun.gd` (new) | Guarded run progression, non-repeating arena/name selection and existing cosmetic generation. No combat resolver or AI implementation. |
| `scripts/GameManager.gd` | New mode/transition/exit states; reuse duel setup, resolver, bot reset and finisher completion; guard progression and deadline-safe confirmations; native close handling. |
| `scripts/ProfileManager.gd` | Schema-3 records, safe migration, independently guarded run/win writes, immediate persistence and reset integration. |
| `scripts/HUD.gd` | Compact current/best/duel label, shared next-arena preview, new transition/end/confirmation presentations. Existing Solo/Local layouts remain in use. |
| `scripts/MainMenu.gd` | Separate Endless Gauntlet entry; compact the existing Play preview to keep all modes and controls in the existing panel. |
| `tests/test_gauntlet_data.gd` (new) | Generation/progression, profile migration, duplicate protection and backup/reset recovery. |
| `tests/test_gauntlet.gd` (new) | Rendered end-to-end mode, UI, persistence, loss/restart, WANTED and exit checks. |
| `tests/test_gauntlet_edges.gd` (new) | Real automatic timing, rapid finisher skips, expired-deadline exits, paused/countdown confirmations and 50 continued duels. |
| `tests/test_revolvers.gd` | Check the current profile schema constant rather than hardcoding schema 2; revolver serialization assertions remain intact. |
| `README.md` | Mode controls, progression, record semantics, migration, architecture and test commands. |
| `STAGE_5C_REPORT.md` (new) | This report. |

Godot generated `.gd.uid` files for GauntletRun and the three new tests. Existing arena, revolver, local multiplayer and difficulty implementation work in the workspace was preserved. No new arenas, cosmetics, finishers, audio assets, weapons, AI weights, networking or online titles were introduced.

## Tests performed

Final checks passed on **Godot 4.7.2 / Windows / Compatibility renderer / Intel UHD 630**:

| Suite | Checks passed |
| --- | ---: |
| New Gauntlet data/progression | 1,271 |
| New rendered Gauntlet integration | 48 |
| Gauntlet records in a fresh process | 3 |
| New Gauntlet edge/stress cases | 115 |
| Existing combat rules | 23,739 |
| Existing Solo turn flow/deadlines | 21 |
| Existing bot personality/restrictions | 25,308 |
| Existing Local Multiplayer/controls | 57 |
| Existing difficulty/real durations | 86 |
| Existing profile data/statistics | 1,049 |
| Existing menu navigation/settings | 63 |
| Existing revolver integration | 117 |
| Existing WANTED elimination integration | 50 |
| Existing arena integration/fullscreen | 242 |
| Existing wanted profile/confirmed resets | 51 |
| Existing statistics-reset restart/recovery | 16 |
| Existing full-profile-reset restart/recovery | 7 |
| Existing character customization/gameplay appearance | 26 |
| Existing audio | 67 |
| Existing turn tick | 25 |
| Existing developer console/input | 24 |

The new data suite generates 250 opponents, checks valid existing cosmetics, visits every arena, prevents immediate arena/name repetition and duplicate progression, and exercises old-profile defaults, corrupt-primary recovery and reset-safe backups. Integration covers zero-streak start, draws/blocks, actual streak recording, WANTED's defeated portrait, transition preview, automatic/manual continuation, clean combat resources, fresh personalities, difficulty locking, loss/end/restart, cancellation in gameplay/pause/countdown/transition, native-window close cancellation, and separate-process records.

Edge tests use the real monotonic process loop for automatic transition, test R through WANTED, wait for stale callbacks, resolve expired lethal turns before leaving, preserve legitimate expired-turn wins, and run 50 fast consecutive duels. Those 50 continuations had constant node counts, correct cumulative records and clean ammunition/shield resets. No recurring Timer nodes or per-frame generated opponent objects are used.

Editor import and a normal standalone launch completed without script or resource errors. Menu, HUD, next-arena transition, confirmation and final-screen screenshots were visually inspected. All new tests use isolated `.godot/` profiles/settings rather than the player's saved data.

Reproduce stage-specific checks:

```text
godot --headless --path . --script tests/test_gauntlet_data.gd
godot --path . --script tests/test_gauntlet.gd -- --capture
godot --path . --script tests/test_gauntlet.gd -- --verify
godot --path . --script tests/test_gauntlet_edges.gd
```

Optional captures are `.godot/gauntlet_menu.png`, `gauntlet_hud.png`, `gauntlet_transition.png`, `gauntlet_exit.png` and `gauntlet_ended.png`.

## Known limitations

- Active runs are session-only and are not resumed after application restart. Already-achieved records persist; a fresh run starts at zero.
- Opponent names come from a small display-name pool and can recur later; immediate repeats are excluded. Cosmetic combinations can naturally recur. Neither affects AI difficulty.
- Each continued duel retains the existing introduction/countdown after the short, skippable victory transition.
- Validation used Windows/Godot 4.7.2 on one integrated GPU. No sustained Gauntlet FPS benchmark or other-platform validation was performed.
