# Wild Wild Cards — Stage 7D Report: Gunslinger Registry, Searchable Profiles & Tournament Leaderboard

**Date:** 2026-10-17  
**Engine:** Godot Engine v4.7.2.stable.official.ed1daf0bf (x86_64 Windows)  
**Status:** COMPLETED & VERIFIED (16/16 Test Suites Passing, 0 Failures, 0 Timeouts)

---

## 1. Executive Summary

Stage 7D introduces a dedicated, high-performance **Gunslinger Registry & Tournament Leaderboard** to the offline Tournament Circuit in *Wild Wild Cards*. Duelists can now instantly search, filter, sort, and inspect every participant across active and archived tournaments without navigating through bracket branches.

### Core Deliverables
- **Unified Tournament Navigation Bar:** Consistent top tab bar (`BRACKET`, `GUNSLINGERS`, `MATCH RESULTS`, `ARCHIVES`) accessible from active lobbies, bracket views, match catch-up/simulation screens, and historical archives.
- **Dedicated Gunslinger Registry:** Clean, scrollable leaderboard table showing all participants (8, 16, or 32 gunslingers), with rank/placement, highlighted human entry, W/L records, win percentage, live status, and one-click dossier inspection.
- **Instant Search:** Case-insensitive, real-time partial-name matching with instantaneous results, clear button (`✕`), and friendly empty-state feedback (`"No gunslingers match '[query]'"`).
- **Multi-Criteria Sorting:** Six sorting modes with deterministic tie-breaking:
  1. *Placement / Rank* (Active contenders first, followed by confirmed ranks: Champion #1, Runner-Up #2, Tied #3, Tied #5, etc.)
  2. *Most Wins* (Descending wins, stable slot order)
  3. *Fewest Losses* (Ascending losses, stable slot order)
  4. *Highest Win Percentage* (Calculated `(W / (W+L)) * 100%`)
  5. *Alphabetical (A–Z)*
  6. *Reverse Alphabetical (Z–A)*
- **Status & Type Filters:** Filters for *All Participants*, *Still Competing*, *Eliminated*, *Human Duelist*, and *AI Gunslingers*, functioning concurrently with active search queries.
- **Enhanced Participant Dossiers:** Reusable modal window showing:
  - Duelist name, classification tag, and cosmetic equipment summary (hat, attire, revolver metal & grip)
  - Bot shooting temperaments (Aggression, Caution, Greed)
  - Tournament record (Overall W/L, formatted win rate %, breakdown vs. Human and vs. Bots)
  - Live status vs. confirmed rank
  - **Tournament Match History:** Chronological ledger of all completed duels in that tournament (round name, opponent name, VICTORY/DEFEAT, turns, arena), equipped with a direct `[WATCH REPLAY]` button when a human replay exists in match history.
- **Strict Tournament Isolation:** Registry views are scoped exclusively to either the active circuit or the selected archive record; zero data leaks from Solo, Gauntlet, Local PvP, or other tournaments.

---

## 2. Architecture & Technical Implementation

### 2.1 Static Query & Sorting Engine (`scripts/TournamentCircuit.gd`)

To maintain clean separation of concerns and enable ultra-fast in-memory operations with zero disk writes during user interaction, authoritative helper routines were implemented as static methods on `TournamentCircuit`:

- `win_percentage(wins: int, losses: int) -> float`: Returns `0.0` when unplayed or `(wins / total) * 100.0`.
- `format_win_percentage(wins: int, losses: int) -> String`: Formats percentages cleanly as integers when exact (e.g., `"100%"`, `"50%"`, `"0%"`) or to one decimal place (e.g., `"33.3%"`).
- `get_matches_for_participant(part_id: String, match_list: Array) -> Array[Dictionary]`: Scans match lists for completed duels involving the participant as Slot A or Slot B.
- `get_participant_status_info(p, tourn_status, cur_round, tot_rounds, champ_slot) -> Dictionary`:
  - When still competing: assigns `rank_text = "—"`, `is_competing = true`, and `status_text = "Still competing — [Stage]"` (e.g. `Still competing — Round of 16`, `Still competing — Finals`).
  - When eliminated or tournament completed: assigns confirmed rank (Champion `#1`, `Runner-Up #2`, `Tied #3`, `Tied #5`, etc.).
- `filter_and_sort_participants(...) -> Array[Dictionary]`:
  - In-memory case-insensitive substring search (`p.name.to_lower().contains(q)`).
  - Multi-type filtering (`all`, `competing`, `eliminated`, `human`, `bot`).
  - Deterministic sort comparator maintaining stable bracket positions for ties.

### 2.2 UI Navigation & Registry Presentation (`scripts/MainMenu.gd`)

- **State Management:** Added `tournament_registry_source` (holds archive dictionary or empty for active circuit), `registry_search_query`, `registry_filter_type`, and `registry_sort_type`.
- **Page Routing:** Updated `show_page()` to integrate `"tournament_registry"` as a first-class view alongside `"tournament"`, `"tournament_catchup"`, and `"tournament_history"`.
- **Navigation Bar:** Implemented `_build_tournament_nav_bar(parent, active_tab)` creating styled tabs with active-state highlights and context-aware disabling (e.g. `MATCH RESULTS` disabled when no active tournament is running).
- **Dashboard Shortcuts:** Embedded `GUNSLINGERS` shortcut buttons in:
  - Bracket bottom dashboard (Active duels, eliminated spectating, and completed champion screen)
  - Tournament entry card
  - Completed tournament history archive viewer (`[VIEW ARCHIVE GUNSLINGERS & LEADERBOARD  ›]`)
- **Dossier Replay Integration:** Clicking `[WATCH REPLAY]` in the participant match history sets `replay_return_page = page` and emits `replay_requested(rep_match)`, smoothly transitioning into the replay viewer and returning to the registry upon completion.

---

## 3. Verification & Automated Test Suite

A dedicated test suite [`tests/test_tournament_registry.gd`](file:///d:/Godot/Gunslinger/tests/test_tournament_registry.gd) was created, covering all 15 Stage 7D requirements plus UI component integration:

| Requirement | Test Routine | Status | Description |
|---|---|---|---|
| **Req 1** | `test_registry_view_loads_all_participants` | **PASS** | 8, 16, and 32 participant circuits load complete participant lists. |
| **Req 2** | `test_search_exact_match` | **PASS** | Exact full-name query returns single matching duelist. |
| **Req 3** | `test_search_case_insensitive` | **PASS** | Lower, upper, and mixed-case queries return identical matches. |
| **Req 4** | `test_search_partial_name` | **PASS** | Substring queries match expected human and bot gunslingers. |
| **Req 5** | `test_search_empty_clears_filter` | **PASS** | Empty or whitespace queries restore full participant list. |
| **Req 6** | `test_search_no_matches_message` | **PASS** | Non-matching query cleanly returns empty array with friendly message. |
| **Req 7** | `test_filter_still_competing` | **PASS** | Returns only active contenders; ensures rank is `"—"` without false ranks. |
| **Req 8** | `test_filter_eliminated` | **PASS** | Returns eliminated duelists with tied placement ranks (e.g. `Tied #17`). |
| **Req 9** | `test_filter_human_only` | **PASS** | Returns exactly 1 participant matching the human player. |
| **Req 10** | `test_filter_bots_only` | **PASS** | Returns all 31 AI gunslingers; verifies no human contamination. |
| **Req 11** | `test_concurrent_search_and_filter` | **PASS** | Filtering while searching correctly intersects both criteria. |
| **Req 12** | `test_sort_by_rank` | **PASS** | Champion #1 first, Runner-Up #2 second, followed by tied rounds in order. |
| **Req 13** | `test_sort_by_wins_losses_and_percentage` | **PASS** | Sorts correctly by most wins, fewest losses, win %, and A-Z/Z-A names. |
| **Req 14** | `test_participant_dossier_contains_match_history` | **PASS** | Validates chronological duel ledger, opponent names, turns, and W/L consistency. |
| **Req 15** | `test_tournament_isolation` | **PASS** | Active and archived registries remain 100% isolated without cross-leakage. |
| **UI** | `test_ui_controls_and_modal` | **PASS** | Instantiates menu and validates search, clear, filter, sort, and modal elements. |

### Complete Test Runner Results (`run_all_tests.ps1`)

```
===========================================================
 Wild Wild Cards Test Runner
 Godot:        D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
 Mode:         Windowed
 Timeout:      60s per test
 StopOnFail:   False
 Total Tests:  16
===========================================================

-----------------------------------------------------------
>>> Running: test_rules.gd (23739 checks) -> PASS (0.98s)
>>> Running: test_profile.gd (1049 checks) -> PASS (1.00s)
>>> Running: test_profile_resets.gd (51 checks) -> PASS (3.43s)
>>> Running: test_bot_personality.gd (25308 checks) -> PASS (2.09s)
>>> Running: test_difficulty.gd (86 checks) -> PASS (6.86s)
>>> Running: test_match_history_data.gd (50 checks) -> PASS (1.03s)
>>> Running: test_gauntlet_data.gd (1271 checks) -> PASS (0.89s)
>>> Running: test_arenas.gd (247 checks) -> PASS (5.95s)
>>> Running: test_revolvers.gd (117 checks) -> PASS (5.30s)
>>> Running: test_finishers_data.gd (276 checks) -> PASS (1.14s)
>>> Running: test_replays.gd (64 checks) -> PASS (5.38s)
>>> Running: test_tournament_data.gd (463 checks) -> PASS (1.05s)
>>> Running: test_tournament.gd (48 checks) -> PASS (2.91s)
>>> Running: test_tournament_registry.gd (542 checks) -> PASS (1.46s)
>>> Running: test_multiplayer.gd (57 checks) -> PASS (2.34s)
>>> Running: test_gauntlet.gd (53 checks) -> PASS (4.81s)

===========================================================
 TEST RUN SUMMARY
 Overall Time: 46.82s
 Passed:       16
 Failed:       0
 Timed Out:    0
 All tests passed successfully!
===========================================================
```

---

## 4. Modified & Created Files

1. [`scripts/TournamentCircuit.gd`](file:///d:/Godot/Gunslinger/scripts/TournamentCircuit.gd)
   - Added `win_percentage()`, `format_win_percentage()`, `get_matches_for_participant()`, `get_participant_status_info()`, and `filter_and_sort_participants()`.
   - Included `"human_slot"` in `save_to_history()` payload for reliable archive lookups.
2. [`scripts/MainMenu.gd`](file:///d:/Godot/Gunslinger/scripts/MainMenu.gd)
   - Added registry view routing (`"tournament_registry"`), state variables, and `_build_tournament_nav_bar()`.
   - Implemented `_build_tournament_registry()` with search input, clear button, filter dropdown, sort dropdown, and scrollable leaderboard table.
   - Enhanced `_show_participant_profile_modal()` with live status, win rates, and scrollable **Tournament Match History** with `[WATCH REPLAY]` support.
   - Added `[GUNSLINGERS]` dashboard buttons to bracket, catch-up, and archive screens.
   - Added guard for `get_window() != null` in `_ready()` for robust headless/testing execution.
3. [`run_all_tests.ps1`](file:///d:/Godot/Gunslinger/run_all_tests.ps1)
   - Integrated `test_tournament_registry.gd` into the primary automated test suite (16 suites total).
4. [`tests/test_tournament_registry.gd`](file:///d:/Godot/Gunslinger/tests/test_tournament_registry.gd)
   - Comprehensive test suite covering all 15 functional requirements and UI integration (542 checks, 0 failures).
