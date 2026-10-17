# Wild Wild Cards

A lightweight Godot 4.x dueling prototype, verified with Godot 4.7.2. Open `project.godot` in Godot and press F6 on `scenes/Main.tscn`, or F5 to run the project. No external assets, plugins, or dependencies are needed.

The game opens on its fantasy-Western main menu. Choose **Play → Solo Duel** to face Copper Jack. Casual PvP and Local PvP remain disabled Coming Soon entries. Each submenu has a Back button.

**Profile** edits your display name (default Gunslinger, up to 24 characters) and shows lifetime completed matches, wins, losses, win rate, and equipped appearance. Use **Save Name** to confirm the edit.

The Profile page is styled as a WANTED / DEAD OR ALIVE poster, using the equipped character's live portrait and saved match/win/loss/win-rate/shield-block totals. Its bounty is a decorative score only: `500 + 250 × wins + 25 × shots_blocked`. It cannot be spent. `WantedPoster.gd` contains reusable paper, ink, border and heading styling for both the profile and the cosmetic elimination poster.

## Developer profile reset commands

Open the console with **backtick (`)** and click its command field to type. Opening it does not focus the field, so A/S/D remain available until you choose to type a command. Type `help` for a command summary. Resets are allowed only after returning to the main menu.

- `reset_stats` asks for `confirm_reset_stats`: zeroes every lifetime counter while preserving name, appearance and equipped elimination-effect field.
- `reset_profile` asks for `confirm_reset_profile`: restores default identity, appearance, elimination field and counters.
- Confirm within **30 seconds**. Any different command, closing/clearing the console, or starting a match cancels confirmation. A confirmation is consumed before execution, preventing duplicate execution.
- Neither reset changes gameplay settings or combat logs. Profile changes save immediately through ProfileManager and refresh an open poster.

Confirmed resets refresh the recovery backup with the post-reset data before replacing the primary. An additive `reset_revision` field lets recovery select a newer confirmed reset over a stale primary if that replacement is interrupted. Subsequent saves cannot copy a pre-reset primary over the newer backup. If the primary replacement fails after the recovery copy committed, the console reports that the reset is safe in the backup and the primary will be retried; it never reports that old statistics should be restored.

## Customization, saves, and controls

**Customize** offers three hat styles, four outfit colors, and None/Bandana/Sheriff Badge accessories. Selections update a live character preview. **Equip** saves the look and chosen elimination effect together for actual Solo Duel gameplay; Back discards an unconfirmed preview. The original geometric character and action animations are reused, so these are simple silhouette/color/accessory changes, not layered sprite assets.

Profile data lives separately in `user://profile.json` (schema version 1), with a previous readable `.bak` save and temporary-file replacement. Missing/corrupt fields use defaults; a readable backup recovers a damaged primary. Newer unsupported save versions are preserved rather than overwritten. Settings files are unaffected. `equipped_elimination_effect` stores the stable cosmetic ID (`classic` by default). Existing save files remain compatible; unrecognized future IDs render as Classic without rewriting the stored value.

Lifetime counters observe actual resolved turns. Action counters use the effective action (an exhausted shield counts as NONE). Empty Shoot attempts count as Shoot actions but not fired shots. `shots_fired` is the player's bullets; `opponent_shots_fired` and `total_shots_fired` also retain the bot's bullets, so a shootout records both bullets and no elimination. `shots_blocked` counts actual incoming bullets, while `shield_turns_against_shoot` and `reload_turns_against_shoot` include empty opponent Shoot attempts. Shootout draws count turns; they do not end matches. Completed duels add exactly one win or loss. Resolved turns from abandoned duels remain in detailed totals but do not add a completed match. Saves occur after completed duels, confirmed identity/appearance edits, and when leaving an unfinished duel.

**Settings** provides Master Volume, Sound Effects Volume, and a fullscreen/windowed toggle. Changes apply immediately and save automatically to `user://settings.cfg` in the existing application data directory. Master controls effects and musical stings; Sound Effects uses the existing audio manager's volume trim. No accounts or network access are used.

**Alt+Enter** toggles fullscreen from menus, duels, and pause. Settings reads the actual native window mode when reopened. The 1280 × 720 canvas keeps its 16:9 aspect ratio when the window changes size, with letterboxing on other aspect ratios.

Godot's editor-embedded Game view cannot change native window mode. For fullscreen testing, run a standalone game window (disable **Embed Game on Next Play** in the editor's Game window options), or launch `godot --path .` from this folder. This checkout's local editor metadata sets `game_view/embed_on_play=false`; an already-open editor needs to reload that preference. If embedding still rejects a fullscreen request, the toggle shows the actual windowed state and the saved fullscreen preference remains available for a standalone launch.

- **A** reloads one bullet, **S** shields, **D** shoots. Click the cards for mouse controls.
- Each turn lasts one second. Change your selection until the deadline; no selection means NONE. Every new turn requires a fresh key press or click.
- **Escape** pauses/resumes, including during the introduction. **R** starts a rematch after game over.
- Three consecutive shields are allowed. Reload, Shoot, or NONE resets shield fatigue.
- Empty shots only aim. Two loaded shots clash: both spend one bullet and survive. A loaded shot beats Reload, NONE, or an empty shot.

The bot commits at the start of each turn using only public ammunition and shield counts. Previous turn actions remain briefly visible while the next turn is already running.

## Elimination effects

Customize includes **Classic** and **WANTED: ELIMINATED**, a description, and **Preview**. Preview uses the draft appearance without starting a match, recording statistics, or equipping anything. Equip confirms appearance and effect in one profile save.

In Solo Duel, a player victory uses the player's equipped effect on Copper Jack; a bot victory uses Classic. Classic keeps the original immediate result screen. WANTED: ELIMINATED lets the hit play first, then shows the defeated character on an aged poster, slams a distressed red stamp with an original short impact sound and subtle poster motion, and fades into the existing result UI in about 1.3 seconds. Click or press a key to skip; R still starts an immediate rematch. Backtick and Alt+Enter retain their console/display shortcuts.

`EliminationEffects.gd` defines stable IDs, labels and descriptions. `EliminationController.gd` handles only cosmetic playback, cancellation and completion, using shared WantedPoster styling and CharacterPreview rendering. Its input is an effect ID plus a defeated-character descriptor (name, appearance, optional exact coat color), so future loadouts can use the same controller. GameManager alone chooses the winner's loadout and records/resolves the match before presentation. Blocks, empty shots, and shootout draws never enter this path. Preview has no result callback. Cancellation stops its tween, portrait animation and stamp sound before a rematch or menu transition.

Portraits reuse the existing geometric character artwork; bot portraits retain Copper Jack's original salmon coat, classic hat and no accessory. Lettering uses the existing system serif font fallback and can vary slightly across platforms. No online systems, unlocks or new elimination mechanics are included.

## Audio

Original procedural effects in `assets/audio/` cover reload, shield, empty trigger, left/right gunshots, ricochet impact, victory/defeat stings, a quiet turn tick, and the elimination stamp. `scripts/AudioManager.gd` plays completed combat results through six reusable effect voices and a separate musical-sting voice; playback never waits or controls turn timing. There is no background music. Internal `sfx_volume_db` and `music_volume_db` trims independently reduce the balanced defaults (0 dB trim; negative values quieter).

Regenerate the included 22,050 Hz, 16-bit PCM WAVs with `python tools/generate_audio.py` (Python standard library only). Python is not needed to play. The renamed project retains the legacy user-data directory for saved-settings compatibility; internal scene names and project paths remain unchanged.

## Architecture

`scripts/GameManager.gd` controls match states and absolute monotonic deadlines. `DuelRules.gd` is a pure, deterministic snapshot resolver. `DuelParticipant.gd` holds combat state. `PlayerController.gd` emits input actions and `BotController.gd` chooses independently. `Arena.gd` draws the procedural arena/characters; `HUD.gd` builds the interface. A future controller can submit an action through `GameManager.submit_action`; networking is intentionally absent.

`scenes/MainMenu.tscn` and `scripts/MainMenu.gd` own menu pages and mouse navigation, with procedural artwork in `MenuBackdrop.gd`. `GameSettings.gd` handles local persistence and applying audio/display preferences. GameManager only connects Solo/Quit signals and switches menu/game visibility. Menu art uses native drawing and available system serif fonts with fallback, with no external assets.

`ProfileManager.gd` owns local identity, versioned profile persistence and guarded resolved-turn statistics. `CharacterAppearance.gd` is the shared appearance catalog/validation. `CharacterPreview.gd` reuses Arena's fighter drawing for customization, and GameManager applies confirmed profile changes to Arena/HUD. Neither profile nor appearance data enters the combat resolver or bot controller.

The window uses a 1280 × 720 logical canvas, resizable with preserved aspect ratio, the GL Compatibility renderer, and a 60 FPS cap. Pause shifts deadlines by the paused duration. Normal animation never delays turns; frame stalls advance through elapsed deadlines without extending them.

## Automated checks

Run with your Godot executable:

```text
godot --headless --path . --editor --import
godot --headless --path . --script tests/test_rules.gd
godot --headless --path . --script tests/test_flow.gd
python tests/test_audio_samples.py
godot --path . --script tests/test_audio.gd
godot --path . --script tests/test_menu.gd -- --capture
godot --path . --script tests/test_menu.gd -- --verify-settings
godot --path . --script tests/test_fullscreen.gd -- --capture
godot --path . --script tests/test_fullscreen.gd -- --verify
godot --headless --path . --script tests/test_profile.gd
godot --path . --script tests/test_elimination.gd -- --capture
godot --path . --script tests/test_elimination.gd -- --verify
godot --path . --script tests/test_profile_ui.gd -- --capture
godot --path . --script tests/test_profile_ui.gd -- --verify
godot --path . --script tests/test_profile_resets.gd -- --capture
godot --path . --script tests/test_profile_resets.gd -- --verify-stats
godot --path . --script tests/test_profile_resets.gd -- --verify-profile
godot --headless --path . --quit-after 120
```

Optional rendered smoke check: `godot --path . --script tests/preview.gd`. This briefly opens the game and saves menu, gameplay, and result PNGs in `tests/`.

Menu checks use mouse events for navigation, disabled modes, profile/customization entry points, fullscreen/windowed transitions, rematch, return to menu, and quit signaling. Settings writes use a separate `.godot/menu_test_settings.cfg`, leaving user preferences untouched. Run the two menu commands in order to test persistence across an actual process restart. `--capture` saves page previews under `.godot/`.

Profile checks cover counters against resolved action/ammo/fatigue combinations, duplicate protection, file replacement, corruption/backup handling, defaults, name sanitation, and unsupported versions. The UI suite verifies live preview versus equip, actual gameplay pixels, and a real process restart. All game integration tests use isolated profile files under `.godot/`; they never modify the player's lifetime record.

Run the three wanted/reset commands in order. They use isolated profile/settings fixtures to check actual command typing, confirmation/cancellation/expiry, active-match rejection, duplicate protection, live poster refresh, and both reset types across separate processes. Recovery tests corrupt the primary and simulate interruption with a readable pre-reset primary to verify that reset-safe backup data wins.

The audio/branding suite checks all ten resources, action-to-sound mapping, simultaneous fire, blocks, victory/defeat, gain controls, the fixed playback pool, unchanged one-second turns, window/menu branding, and the legacy saved-settings directory. Add `-- --audition` to play each effect in sequence. PCM sample checks verify durations, levels, fades, stereo separation, and a conservative mix peak bound below full scale.

On this Windows Godot build, rapid combat tests using the headless Dummy audio driver can emit pending-playback cleanup warnings at shutdown. Use `--headless --audio-driver WASAPI` for those integration tests; both gameplay and personality suites run clean with the real audio driver. Normal windowed playback also runs clean.

Combat checks exhaust action pairs, ammunition values, and shield fatigue, including symmetry and unchanged input snapshots. Flow checks exercise selection, fresh key presses, timing, pause, NONE turns, game over, and restart. Procedural graphics need no import pipeline beyond Godot itself.

Verified locally: 23,739 combat checks and 21 flow checks passed, including 300 consecutive deadline advances. A rendered smoke run exercised reload, shield impacts, clashes, and game over on Intel UHD 630 with no script errors. A sustained 60 FPS performance benchmark and manual long-session playtesting have not been performed.

Elimination checks cover Classic compatibility, both winners, blocked/empty/clashing turns, authoritative result deduplication, preview isolation, atomic equip failure rollback, separate-process persistence, stamp playback, keyboard/mouse skip, and cancellation on rapid rematch/menu navigation. Tests use isolated `.godot/` saves. `--capture` saves the effect and Customize screenshots there.
