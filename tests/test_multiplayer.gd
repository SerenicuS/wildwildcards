extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Rules = preload("res://scripts/DuelRules.gd")
const A = DuelRules.Action

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILURE: " + message)

func _initialize() -> void:
	call_deferred("run")

func make_game() -> Node:
	var game = Main.new()
	game.profile.path = "res://.godot/test_multiplayer_profile.json"
	root.add_child(game)
	game.set_process(false)
	return game

func begin_match(game: Node) -> void:
	game.start_local_duel()
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func send_key(game: Node, keycode: int, p2: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	key.echo = false
	if p2:
		game.controller_p2._unhandled_key_input(key)
	else:
		game.controller._unhandled_key_input(key)

func run() -> void:
	print("--- Running Local Multiplayer 1v1 Test Suite ---")
	var game = make_game()
	
	# Initial state & menu check
	check(game.state == Main.State.MAIN_MENU, "Game starts in MAIN_MENU")
	game.main_menu.show_page("play")
	check(not game.main_menu.buttons.local.disabled, "LOCAL PvP button is enabled in main menu")
	
	# Test start local duel flow
	game.start_local_duel()
	check(game.mode == Main.GameMode.LOCAL_2P, "Game mode set to LOCAL_2P")
	check(game.state == Main.State.COUNTDOWN, "Duel starts in COUNTDOWN")
	check(game.hud.is_local_2p, "HUD configured for local 2P")
	check(game.hud.player_display_name == "Player 1", "P1 display name set to Player 1")
	check(game.hud.opponent_display_name == "Player 2", "P2 display name set to Player 2")
	check(not game.profile.is_match_active(), "Local 2P does not mark profile match active")
	
	# Transition to PLAYING
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)
	check(game.state == Main.State.PLAYING and game.turn == 1, "Game enters PLAYING state at Turn 1")
	check(game.controller.accepting and game.controller_p2.accepting, "Both P1 and P2 controllers accepting input")
	
	# Test Requirement 9 & Hidden Actions:
	# Check HUD does not display choices before resolution
	check(game.hud.selection_text.text.contains("Player 1: CHOOSING...") and game.hud.selection_text.text.contains("Player 2: CHOOSING..."), "Neutral CHOOSING indicator when no actions selected")
	send_key(game, KEY_A, false) # P1 Reload
	check(game.selected == A.RELOAD, "P1 selected Reload via key A")
	check(game.hud.selection_text.text.contains("Player 1: READY") and not game.hud.selection_text.text.contains("RELOAD"), "P1 selection hidden; shows only neutral READY indicator")
	
	# Test Requirement 8: Changing selections before resolution
	send_key(game, KEY_S, false) # P1 changes to Shield
	check(game.selected == A.SHIELD, "P1 can change selection to Shield")
	send_key(game, KEY_D, false) # P1 changes to Shoot
	check(game.selected == A.SHOOT, "P1 can change selection to Shoot")
	send_key(game, KEY_A, false) # P1 changes back to Reload
	check(game.selected == A.RELOAD, "P1 changes back to Reload")
	
	send_key(game, KEY_L, true) # P2 selects Shoot (key L)
	check(game.selected_p2 == A.SHOOT, "P2 selected Shoot via key L")
	check(game.hud.selection_text.text.contains("Player 2: READY") and not game.hud.selection_text.text.contains("SHOOT"), "P2 selection hidden; shows only neutral READY indicator")
	send_key(game, KEY_K, true) # P2 changes to Shield (key K)
	check(game.selected_p2 == A.SHIELD, "P2 can change selection to Shield")
	send_key(game, KEY_J, true) # P2 changes to Reload (key J)
	check(game.selected_p2 == A.RELOAD, "P2 changes selection to Reload")
	
	# Test Requirement 1: Both players reload on Turn 1
	var turn1_deadline: int = game.deadline
	game.advance_to(turn1_deadline)
	check(game.player.ammo == 1 and game.opponent.ammo == 1, "Test 1: Both players reload simultaneously, ammo is 1 for both")
	check(game.turn == 2, "Turn advances to 2")
	check(game.hud.reveal_text.text.contains("PLAYER 1: RELOAD") and game.hud.reveal_text.text.contains("PLAYER 2: RELOAD"), "Both actions revealed simultaneously upon resolution")
	
	# Test Requirement 2: Player 1 shoots while Player 2 reloads
	# P1 has 1 ammo, fires and eliminates P2 who is reloading.
	send_key(game, KEY_D, false) # P1 Shoot
	send_key(game, KEY_J, true)  # P2 Reload
	check(game.selected == A.SHOOT and game.selected_p2 == A.RELOAD, "P1 shoots, P2 reloads")
	game.advance_to(game.deadline)
	check(game.player.alive and not game.opponent.alive, "Test 2: P1 armed shot eliminates reloading P2")
	check(game.state == Main.State.GAME_OVER, "Game over on elimination")
	game._show_match_result()
	check(game.hud.overlay_title.text == "PLAYER 1 WINS", "Match result shows PLAYER 1 WINS")
	check(game.local_session_p1_wins == 1 and game.local_session_p2_wins == 0, "Local session tracks P1 win")
	
	# Test Rematch preserves local 2P mode and session score
	game.hud.primary.pressed.emit()
	check(game.mode == Main.GameMode.LOCAL_2P, "Rematch preserves LOCAL_2P mode")
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)
	check(game.state == Main.State.PLAYING and game.turn == 1, "Rematch starts Turn 1")
	check(game.player.ammo == 0 and game.opponent.ammo == 0, "Ammo resets to 0 for rematch")
	
	# Test Requirement 3: Player 2 shoots while Player 1 reloads
	# Turn 1: both reload
	send_key(game, KEY_A, false)
	send_key(game, KEY_J, true)
	game.advance_to(game.deadline)
	check(game.player.ammo == 1 and game.opponent.ammo == 1, "Turn 1 reloaded")
	# Turn 2: P1 Reload, P2 Shoot
	send_key(game, KEY_A, false)
	send_key(game, KEY_L, true)
	game.advance_to(game.deadline)
	check(not game.player.alive and game.opponent.alive, "Test 3: P2 armed shot eliminates reloading P1")
	check(game.state == Main.State.GAME_OVER, "Game over on P2 victory")
	game._show_match_result()
	check(game.hud.overlay_title.text == "PLAYER 2 WINS", "Match result shows PLAYER 2 WINS")
	check(game.local_session_p1_wins == 1 and game.local_session_p2_wins == 1, "Local session tracks P1 and P2 wins: 1-1")
	
	# Test Requirement 4: Both players shoot with ammunition (shootout draw / clash)
	game.start_local_duel()
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)
	# Both reload to get 1 ammo
	send_key(game, KEY_A, false)
	send_key(game, KEY_J, true)
	game.advance_to(game.deadline)
	check(game.player.ammo == 1 and game.opponent.ammo == 1, "Both armed with 1 bullet")
	# Both shoot
	send_key(game, KEY_D, false)
	send_key(game, KEY_L, true)
	game.advance_to(game.deadline)
	check(game.player.alive and game.opponent.alive, "Test 4: Both players shoot with ammo; shootout draw cancels lethal damage")
	check(game.player.ammo == 0 and game.opponent.ammo == 0, "Test 4: Both bullets consumed in shootout draw")
	check(game.hud.banner.text == "CLASH!", "HUD displays CLASH! banner on draw")
	check(game.elimination.active == false, "Finisher effect NOT triggered on shootout draw")
	
	# Test Requirement 5: Both players shoot without ammunition
	check(game.player.ammo == 0 and game.opponent.ammo == 0, "Both players have 0 ammo")
	send_key(game, KEY_D, false)
	send_key(game, KEY_L, true)
	game.advance_to(game.deadline)
	check(game.player.alive and game.opponent.alive, "Test 5: Both shoot empty; duel continues")
	check(game.hud.reveal_text.text.contains("CLICK!") and game.hud.reveal_text.text.contains("CLICK!"), "Both produce empty CLICK! on empty shoot")
	
	# Test Requirement 6: Shield blocks an armed shot
	# P1 reloads (ammo 1), P2 shields
	send_key(game, KEY_A, false)
	send_key(game, KEY_K, true)
	game.advance_to(game.deadline)
	check(game.player.ammo == 1 and game.opponent.shields == 1, "P1 has 1 ammo, P2 has 1 shield")
	# P1 shoots, P2 shields
	send_key(game, KEY_D, false)
	send_key(game, KEY_K, true)
	game.advance_to(game.deadline)
	check(game.player.ammo == 0, "P1 bullet consumed")
	check(game.opponent.alive, "Test 6: P2 shield successfully blocks armed shot")
	check(game.opponent.shields == 2, "P2 shield streak is now 2")
	
	# Test Requirement 7: Three consecutive shields permitted, but fourth is prevented
	# P2 currently has 2 shields.
	# Next turn: P2 shields again -> streak 3
	send_key(game, KEY_A, false) # P1 reloads
	send_key(game, KEY_K, true)  # P2 shields (3rd consecutive)
	game.advance_to(game.deadline)
	check(game.opponent.shields == 3, "P2 completes 3rd consecutive shield")
	# 4th turn: P2 attempts 4th shield
	send_key(game, KEY_K, true) # P2 tries 4th shield
	check(game.selected_p2 == A.NONE, "Test 7: 4th consecutive shield input rejected and clamped to NONE")
	# If forced to submit, DuelRules also enforces it
	game.selected_p2 = A.SHIELD
	game.advance_to(game.deadline)
	check(game.opponent.shields == 0, "Test 7: DuelRules enforces shield limit; shields reset to 0 after fatigue/rest")
	
	# Test Requirement 10: Shared timer never resolves early, accurately advances
	check(game.turn_usec == game.settings.turn_usec(), "Shared timer uses authoritative difficulty turn_usec")
	var deadline_before = game.deadline
	game.advance_to(deadline_before - 100)
	check(game.state == Main.State.PLAYING, "Timer does not resolve before deadline")
	game.advance_to(deadline_before)
	check(game.deadline == deadline_before + game.turn_usec, "Deadline advances by exactly turn_usec")
	
	# Test profile isolation: ensure lifetime stats were not modified by local 2P match
	var profile_read = game.profile
	check(profile_read.stats.matches_played == 0 and profile_read.stats.wins == 0 and profile_read.stats.losses == 0,
		"Local 2P match does NOT touch profile stats")
	
	# Test Return to Menu
	game.show_menu()
	check(game.state == Main.State.MAIN_MENU, "show_menu returns to MAIN_MENU")
	check(game.main_menu.visible, "Main menu is visible")
	
	game.queue_free()
	await process_frame
	print("Multiplayer 1v1 tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
