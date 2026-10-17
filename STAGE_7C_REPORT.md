# Wild Wild Cards — Stage 7C Verification & Architecture Report
**32-Participant Tournament Circuit Expansion & Accelerated Bot Simulation**

---

## 1. Overview & Architecture

Stage 7C expands the Tournament Circuit in *Wild Wild Cards* (`D:\Godot\Gunslinger`) from the initial 8-participant circuit to a full **32-participant offline single-elimination championship**. The underlying architecture is dynamically configurable ($N \in \{8, 16, 32\}$) with **32 gunslingers set as the default size**.

### Core Architecture Highlights

```
                                [32-Participant Single Elimination Tree]
Round of 32 (16 Matches) ──> Round of 16 (8 Matches) ──> Quarterfinals (4 Matches) ──> Semifinals (2 Matches) ──> Championship (1 Match)
        16 Losers                    8 Losers                   4 Losers                   2 Losers                   1 Runner-Up
       (Rank #17)                   (Rank #9)                  (Rank #5)                  (Rank #3)                   (Rank #2)
                                                                                                                  1 Champion (#1)
```

1. **Universal Mathematical Tree Linkage:**
   - For any tournament size $N \in \{8, 16, 32\}$, the number of rounds is $R = \log_2(N)$ ($R=5$ for $N=32$, $R=4$ for $N=16$, $R=3$ for $N=8$).
   - Match indexing across rounds:
     $$\text{round\_start}(r) = N - \frac{N}{2^r}$$
     $$\text{next\_match\_idx} = \text{round\_start}(r+1) + \left\lfloor \frac{k}{2} \right\rfloor$$
     $$\text{slot} = \begin{cases} \text{slot\_a}, & k \equiv 0 \pmod 2 \\ \text{slot\_b}, & k \equiv 1 \pmod 2 \end{cases}$$
   - When $r = R-1$ (Championship match), the winner is crowned Champion without further advancement.

2. **Expanded Character Identity Pool:**
   - Western outlaw name roster expanded from 24 to **56 unique names**, guaranteeing that all 31 generated AI bots receive distinct names without duplicates.
   - Each bot retains consistent cosmetic snapshots (hat, outfit, accessory), revolver snapshots (grip, metal, cylinder, frame), personality modifiers (aggression, caution, greed), and statistics throughout the entire circuit.

3. **Authoritative Accelerated Bot Simulation:**
   - Bot vs. bot match resolution executes headlessly using the authoritative combat resolver `DuelRules.resolve()` and `BotController` logic with identical simultaneous Reload/Shield/Shoot rules.
   - Zero scene loading or rendering overhead; completed matches are never re-simulated.
   - Presentation modes:
     - **4x Speed:** Sequential stepped simulation with 0.3s tick interval.
     - **8x Speed:** Sequential stepped simulation with 0.15s tick interval.
     - **Instant:** Pure headless resolution of all remaining bot matches in the round or tournament.

---

## 2. Rankings & Placements ($N=32$)

The ranking system strictly assigns placements based on elimination round depth:

| Placement | Round Eliminated | Tied Count | Final Rank |
| :--- | :--- | :--- | :--- |
| **Champion** | Won Finals (Round 4) | 1 | **#1** |
| **Runner-Up** | Championship Loser (Round 4) | 1 | **#2** |
| **Semifinals** | Semifinals Losers (Round 3) | 2 | **Tied #3** |
| **Quarterfinals** | Quarterfinals Losers (Round 2) | 4 | **Tied #5** |
| **Round of 16** | Round of 16 Losers (Round 1) | 8 | **Tied #9** |
| **Round of 32** | Round of 32 Losers (Round 0) | 16 | **Tied #17** |

- Closed-form rank formula for elimination in round $r < R-1$:
  $$\text{rank} = 2^{(R - 1 - r)} + 1$$
- For $N=32$ ($R=5$):
  - $r=0 \implies 2^4 + 1 = 17$
  - $r=1 \implies 2^3 + 1 = 9$
  - $r=2 \implies 2^2 + 1 = 5$
  - $r=3 \implies 2^1 + 1 = 3$
  - $r=4 \implies \text{Runner-Up (Rank 2)}, \text{Champion (Rank 1)}$
- Total tournament wins across all 32 participants = 31 matches; total losses = 31 matches.
- Category statistics: $\text{wins} = \text{wins\_vs\_human} + \text{wins\_vs\_bots}$ and $\text{losses} = \text{losses\_vs\_human} + \text{losses\_vs\_bots}$.

---

## 3. UI Features Implemented

1. **Tournament Lobby Size Selector:**
   - Added bracket size selection row: `[8 GUNS (3 ROUNDS)]`, `[16 GUNS (4 ROUNDS)]`, `[32 GUNS (5 ROUNDS - DEFAULT)]`.
2. **Scrollable Bracket View:**
   - Built inside a responsive `ScrollContainer` with a 6-column inner canvas (5 elimination rounds + 1 Champion podium column).
   - Dynamic tree connector lines rendered via canvas `draw` calls linking matches to their parent pairings.
   - Highlights human match with a 2px GOLD border and auto-scrolls to ensure the player's upcoming duel is immediately visible.
   - Winners displayed in bold GOLD with `✓` prefix; eliminated duelists dimmed.
3. **Interactive Participant Profile Modal:**
   - Clicking on any gunslinger in the bracket opens a detailed frontier dossier:
     - Name & classification (`HUMAN DUELIST` vs. `AI GUNSLINGER`)
     - Current placement & rank
     - Eliminator information (who eliminated them and in which round)
     - Win/loss records: Overall, vs. Human, vs. Bots
     - Personality temperament meters (Aggression, Caution, Greed)
     - Outlaw attire & revolver cosmetics
4. **Accelerated Catch-Up Screen (`show_page("tournament_catchup")`):**
   - Active duel results ticker listing resolved matches with turn counts and arena locations.
   - Speed controls: `[4x SPEED]`, `[8x SPEED]`, `[INSTANT]`.
   - Dynamic progress indicators (e.g. `Round of 32 Progress: 14 / 16 Matches Complete`).
   - `[ADVANCE TO NEXT ROUND ›]` button activates upon round completion.
5. **Defeat Flow & Outlaw Spectator Mode:**
   - On human elimination, players can choose:
     - `[SPECTATE TOURNAMENT]`: Runs accelerated catch-up round-by-round through the Championship to crown the outlaw victor.
     - `[FINISH INSTANTLY]`: Headlessly simulates all remaining rounds immediately and displays final rankings.
     - `[VIEW ARCHIVES]` / `[START NEW TOURNAMENT]`.

---

## 4. Test Verification Summary

All 15 test suites executed through `run_all_tests.ps1` passed with zero errors or hangs:

```
===========================================================
 Wild Wild Cards Test Runner
 Godot:        D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
 Mode:         Windowed
 Timeout:      60s per test
 Total Tests:  15
===========================================================

PASS: test_rules.gd (1s) — 23,739 checks, 0 failures
PASS: test_profile.gd (0.89s) — 1,049 checks, 0 failures
PASS: test_profile_resets.gd (2.86s) — 51 checks, 0 failures
PASS: test_bot_personality.gd (1.54s) — 25,308 checks, 0 failures
PASS: test_difficulty.gd (6.7s) — 86 checks, 0 failures
PASS: test_match_history_data.gd (1.08s) — 50 checks, 0 failures
PASS: test_gauntlet_data.gd (0.88s) — 1,271 checks, 0 failures
PASS: test_arenas.gd (5.07s) — 247 checks, 0 failures
PASS: test_revolvers.gd (4.93s) — 117 checks, 0 failures
PASS: test_finishers_data.gd (1.21s) — 276 checks, 0 failures
PASS: test_replays.gd (5.08s) — 64 checks, 0 failures
PASS: test_tournament_data.gd (1.27s) — 463 checks, 0 failures
PASS: test_tournament.gd (3.2s) — 48 checks, 0 failures
PASS: test_multiplayer.gd (1.83s) — 57 checks, 0 failures
PASS: test_gauntlet.gd (3.73s) — 53 checks, 0 failures

===========================================================
 TEST RUN SUMMARY
 Overall Time: 41.46s
 Passed:       15
 Failed:       0
 Timed Out:    0
 All tests passed successfully!
===========================================================
```
