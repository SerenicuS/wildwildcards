extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const Tournament = preload("res://scripts/TournamentCircuit.gd")

const PROFILE_PATH := "res://.godot/tourn_integration.json"
const SETTINGS_PATH := "res://.godot/tourn_integration.cfg"
const TOURN_ACTIVE_PATH := "res://.godot/tourn_integration_active.json"
const TOURN_HISTORY_PATH := "res://.godot/tourn_integration_history.json"

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILURE: " + message)

func clean_test_files() -> void:
	for path in [PROFILE_PATH, PROFILE_PATH + ".tmp", PROFILE_PATH + ".bak",
			SETTINGS_PATH, TOURN_ACTIVE_PATH, TOURN_ACTIVE_PATH + ".tmp",
			TOURN_HISTORY_PATH, TOURN_HISTORY_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func play_countdown(game: Node) -> void:
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func win_duel(game: Node) -> void:
	game.player.ammo = 1
	game.player.shields = 0
	game.opponent.shields = 0
	game.opponent.ammo = 0
	game.selected = 3 # Shoot
	game.bot_action = 1 # Reload
	game.advance_to(game.deadline)

func lose_duel(game: Node) -> void:
	game.player.ammo = 0
	game.player.shields = 0
	game.opponent.shields = 0
	game.opponent.ammo = 1
	game.selected = 1 # Reload
	game.bot_action = 3 # Shoot
	game.advance_to(game.deadline)

func run() -> void:
	clean_test_files()

	var initial_profile := Profile.new()
	initial_profile.path = PROFILE_PATH
	initial_profile.display_name = "Judge Morgan"
	initial_profile.equipped_elimination_effect = "wanted_eliminated"
	initial_profile.save_profile(true)

	var initial_settings := Settings.new()
	initial_settings.path = SETTINGS_PATH
	initial_settings.difficulty = "medium"
	initial_settings.save_settings()

	var game := Main.new()
	game.profile.path = PROFILE_PATH
	game.settings.path = SETTINGS_PATH
	game.tournament.active_path = TOURN_ACTIVE_PATH
	game.tournament.history_path = TOURN_HISTORY_PATH
	root.add_child(game)
	game.set_process(false)

	var menu: Control = game.main_menu
	await settle()

	# 1. Menu navigation: Play page has tournament option
	menu.show_page("play")
	await settle()
	check(menu.buttons.has("tournament"), "Play page includes Tournament Circuit option")
	check(menu.buttons.has("solo") and menu.buttons.has("gauntlet") and menu.buttons.has("local"), "Existing game modes preserved")

	# 2. Open Tournament Circuit entry page
	menu.show_page("tournament")
	await settle()
	check(menu.tournament_view != null, "Tournament view instantiated")
	check(not game.tournament.has_active_tournament(), "Starts with no active tournament")

	# 3. Create 32-Participant Tournament
	game.tournament.rng.seed = 445566
	game.tournament.create_tournament("Judge Morgan", game.profile.appearance, game.profile.appearance, "medium", 32)
	check(game.tournament.has_active_tournament(), "Active 32-player tournament created")
	check(game.tournament.participants.size() == 32, "32 participants generated")
	check(game.tournament.total_rounds == 5, "5 rounds created for 32 gunslingers")

	# 4. View Bracket Page
	menu.show_page("tournament")
	await settle()
	check(game.tournament.current_round == 0, "Current round is Round of 32")
	var r32_opp: Dictionary = game.tournament.get_human_opponent()
	check(not r32_opp.is_empty(), "Human has an identified R32 opponent")

	# 5. Start Tournament Duel
	game.start_tournament_match()
	await settle()
	check(game.mode == Main.GameMode.TOURNAMENT, "GameMode set to TOURNAMENT")
	check(game.state == Main.State.COUNTDOWN, "Game state enters COUNTDOWN")
	check(game.hud.opponent_display_name == r32_opp.name, "HUD displays tournament opponent name")
	check(game.hud.player_display_name == "Judge Morgan", "HUD displays player name")
	check(game.turn_usec == 1500000, "Turn speed matches medium difficulty (1.5s)")

	# 6. Countdown and duel play
	play_countdown(game)
	check(game.state == Main.State.PLAYING, "Game state enters PLAYING after countdown")

	# 7. Pause testing during Tournament
	game.toggle_pause()
	check(game.state == Main.State.PAUSED, "Tournament duel pauses on toggle")
	check(game.hud.overlay.visible and game.hud.tertiary.text == "RESTART DUEL", "Pause overlay shows Restart Duel in tournament")
	game.last_pause_toggle_usec -= 60000
	game.toggle_pause()
	check(game.state == Main.State.PLAYING, "Tournament duel resumes on toggle")

	# 8. Win Round of 32
	win_duel(game)
	check(game.state == Main.State.GAME_OVER, "Game enters GAME_OVER on lethal hit")
	check(game.elimination.active, "Elimination finisher plays")
	game.elimination.skip()
	await settle()

	check(game.hud.overlay.visible and game.hud.overlay_mode == "tournament_catchup", "Catch-up overlay offered after duel win")

	# 9. Enter Catch-Up Screen
	game._on_result_action() # Clicks CATCH-UP (SIMULATE)
	await settle()
	check(menu.page == "tournament_catchup", "Transitioned to tournament catchup screen")
	check(menu.tournament_view != null, "Catch-up view instantiated")

	# Instant finish remaining Round of 32 matches
	game.tournament.finish_round_simulation_instant(game.tournament.current_round)
	check(game.tournament.is_round_complete(0), "All Round of 32 matches completed")
	game.tournament.advance_to_next_round()
	check(game.tournament.current_round == 1, "Advanced to Round of 16 (Round 1)")

	# 10. Play and Win Round of 16
	menu.show_page("tournament")
	await settle()
	game.start_tournament_match()
	await settle()
	play_countdown(game)
	win_duel(game)
	game.elimination.skip()
	await settle()

	game.tournament.finish_round_simulation_instant(game.tournament.current_round)
	game.tournament.advance_to_next_round()
	check(game.tournament.current_round == 2, "Advanced to Quarterfinals (Round 2)")

	# 11. Play and Win Quarterfinals
	menu.show_page("tournament")
	await settle()
	game.start_tournament_match()
	await settle()
	play_countdown(game)
	win_duel(game)
	game.elimination.skip()
	await settle()

	game.tournament.finish_round_simulation_instant(game.tournament.current_round)
	game.tournament.advance_to_next_round()
	check(game.tournament.current_round == 3, "Advanced to Semifinals (Round 3)")

	# 12. Play and Win Semifinals
	menu.show_page("tournament")
	await settle()
	game.start_tournament_match()
	await settle()
	play_countdown(game)
	win_duel(game)
	game.elimination.skip()
	await settle()

	game.tournament.finish_round_simulation_instant(game.tournament.current_round)
	game.tournament.advance_to_next_round()
	check(game.tournament.current_round == 4, "Advanced to Championship (Round 4)")

	# 13. Play and Win Championship
	menu.show_page("tournament")
	await settle()
	game.start_tournament_match()
	await settle()
	play_countdown(game)
	win_duel(game)
	game.elimination.skip()
	await settle()

	# 14. Championship Victory Celebration
	check(game.tournament.status == "completed", "Tournament marked completed")
	check(game.tournament.champion_slot == game.tournament.human_slot, "Human crowned Champion of 32 gunslingers")
	check(game.hud.overlay.visible and game.hud.overlay_title.text == "TOURNAMENT CHAMPION!", "Championship celebration overlay shown")
	check(game.hud.tertiary.visible and game.hud.tertiary.text == "COMMEMORATIVE POSTER", "Commemorative poster button available on celebration")
	check(game.profile.tournament_records.tournaments_won == 1, "Profile records 1 tournament won")
	check(game.profile.tournament_records.best_finish == "Champion", "Profile best finish updated to Champion")

	# 15. View Commemorative WANTED Poster
	game._view_gauntlet_poster()
	await settle()
	check(game.elimination.active, "Commemorative poster active")
	check(game.elimination.target.name == "Judge Morgan", "Poster displays champion player name")
	game.elimination.skip()
	await settle()

	# 16. Return to Tournament Bracket View
	game._return_to_tournament_bracket()
	await settle()
	check(menu.visible and menu.page == "tournament", "Returned to tournament bracket page")

	# 17. Check Tournament Archives Page
	menu.show_page("tournament_history")
	await settle()
	check(menu.page == "tournament_history", "On tournament history page")
	var history_records: Array = game.tournament.load_history()
	check(history_records.size() == 1, "Tournament archived in history")
	check(history_records[0].human_won and history_records[0].champion_name == "Judge Morgan", "Archive records correct champion")
	check(history_records[0].tournament_size == 32, "Archive preserves 32-player tournament size")

	# 18. Check Player Profile Page displays Tournament stats
	menu.show_page("profile")
	await settle()
	check(menu.profile_stat_labels.has("tournaments_won"), "Profile displays tournaments won label")
	check(menu.profile_stat_labels["tournaments_won"].text == "1", "Tournaments won displays 1")
	check(menu.profile_stat_labels.has("best_finish") and menu.profile_stat_labels["best_finish"].text == "Champion", "Best finish displays Champion")

	# 19. Defeat and Finish Instantly Flow
	game.tournament.create_tournament("Judge Morgan", game.profile.appearance, game.profile.appearance, "medium", 32)
	menu.show_page("tournament")
	await settle()
	game.start_tournament_match()
	await settle()
	play_countdown(game)
	lose_duel(game)
	game.elimination.skip()
	await settle()
	check(game.tournament.status == "eliminated", "Human marked eliminated on duel loss")
	check(game.hud.overlay.visible and game.hud.overlay_mode == "tournament_out", "Elimination overlay displayed")

	# Finish Instantly
	game.tournament.finish_all_remaining_tournament_instant()
	check(game.tournament.champion_slot >= 0 and game.tournament.champion_slot != game.tournament.human_slot, "Outlaw champion crowned headlessly")
	menu.show_page("tournament")
	await settle()
	check(menu.page == "tournament", "Bracket reflects completed tournament")

	clean_test_files()
	print("Tournament Circuit Flow & Integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
