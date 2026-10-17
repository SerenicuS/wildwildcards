extends Node

enum State { MAIN_MENU, COUNTDOWN, PLAYING, GAME_OVER, PAUSED, AWAITING_CONTINUE, EXIT_CONFIRM }
enum GameMode { SOLO, LOCAL_2P, GAUNTLET }

const USEC_PER_SECOND: int = 1000000
const INTRO_USEC: int = 2800000

var turn_usec: int = 1000000
var match_difficulty: String = ""
var match_arena: String = ""
var arena_rng := RandomNumberGenerator.new()
var gauntlet := preload("res://scripts/GauntletRun.gd").new()
var gauntlet_defeated: Dictionary = {}
var exit_intent: String = ""
var exit_snapshot: Dictionary = {}
var mode: GameMode = GameMode.SOLO
var state: State = State.MAIN_MENU
var before_pause: State = State.MAIN_MENU

var player := DuelParticipant.new()
var opponent := DuelParticipant.new()
var bot := BotController.new()

var controller: PlayerController
var controller_p2: PlayerController

var arena: DuelArena
var hud: DuelHUD

var selected: int = DuelRules.Action.NONE
var selected_p2: int = DuelRules.Action.NONE
var bot_action: int = DuelRules.Action.NONE

var turn: int = 0
var deadline: int = 0
var intro_start: int = 0
var pause_start: int = 0
var last_pause_toggle_usec: int = 0
var combat_log := CombatLog.new()
var debug_console: CanvasLayer
var pending_bot_decision: Dictionary = {}
var elimination: CanvasLayer
var audio: Node
var settings := preload("res://scripts/GameSettings.gd").new()
var main_menu: Control
var history := preload("res://scripts/MatchHistory.gd").new()
var replay_viewer: CanvasLayer
var gauntlet_run_id: String = ""
var profile := preload("res://scripts/ProfileManager.gd").new()

# Session statistics for Local 2P (never written to lifetime profile)
var local_session_p1_wins: int = 0
var local_session_p2_wins: int = 0

func _ready() -> void:
	# Pausing the tree freezes tweens and animation; this node can still resume it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 60
	profile.load_profile()
	arena = DuelArena.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = DuelHUD.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(hud)
	
	controller = PlayerController.new()
	controller.player_index = 0
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(controller)
	controller.action_selected.connect(submit_action)
	controller.pause_requested.connect(toggle_pause)
	controller.restart_requested.connect(func():
		if state == State.GAME_OVER: restart_current_duel())
	
	controller_p2 = PlayerController.new()
	controller_p2.player_index = 1
	controller_p2.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(controller_p2)
	controller_p2.action_selected.connect(submit_action_p2)
	controller_p2.pause_requested.connect(toggle_pause)
	controller_p2.restart_requested.connect(func():
		if state == State.GAME_OVER: restart_current_duel())
	
	hud.action_selected.connect(submit_action)
	hud.player_2_action_selected.connect(submit_action_p2)
	hud.play_requested.connect(_on_result_action)
	hud.poster_requested.connect(_view_gauntlet_poster)
	hud.quit_requested.connect(_request_quit)
	hud.resume_requested.connect(_resume_or_cancel_exit)
	hud.menu_requested.connect(_menu_or_cancel_exit)
	
	debug_console = preload("res://scripts/DebugConsole.gd").new()
	debug_console.log_store = combat_log
	debug_console.profile = profile
	debug_console.can_reset = func(): return state == State.MAIN_MENU
	add_child(debug_console)
	audio = preload("res://scripts/AudioManager.gd").new()
	add_child(audio)
	elimination = preload("res://scripts/EliminationController.gd").new()
	elimination.audio = audio
	add_child(elimination)
	elimination.finished.connect(_show_match_result)
	settings.load_settings()
	# Custom profile paths (including tests) get their own separate history file.
	if profile.path != "user://profile.json" and history.path == "user://match_history.json":
		history.path = profile.path.get_basename() + ".history.json"
	history.max_matches = settings.history_limit
	history.load_history()
	history.deferred_writes = true
	arena_rng.randomize()
	settings.apply_audio(audio)
	settings.apply_display()
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 2
	add_child(menu_layer)
	main_menu = preload("res://scenes/MainMenu.tscn").instantiate()
	main_menu.settings = settings
	main_menu.audio = audio
	main_menu.profile = profile
	main_menu.history_store = history
	menu_layer.add_child(main_menu)
	main_menu.elimination_preview_requested.connect(func(id: String, target: Dictionary): elimination.play(id, target, true))
	main_menu.solo_requested.connect(start_duel)
	main_menu.gauntlet_requested.connect(start_gauntlet)
	main_menu.local_requested.connect(start_local_duel)
	main_menu.local_appearance_changed.connect(_apply_profile)
	main_menu.replay_requested.connect(_open_replay)
	main_menu.quit_requested.connect(_request_quit)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_request_quit)
	profile.changed.connect(_apply_profile)
	_apply_profile()
	show_menu()

func _apply_profile() -> void:
	arena.set_player_appearance(profile.appearance)
	hud.is_gauntlet = mode == GameMode.GAUNTLET
	if mode != GameMode.LOCAL_2P:
		arena.set_opponent_appearance({"hat": "classic", "outfit": "rust", "accessory": "none"})
		hud.player_display_name = profile.display_name
		hud.opponent_display_name = "Copper Jack"
		hud.is_local_2p = false
		if mode == GameMode.GAUNTLET and not gauntlet.opponent.is_empty():
			arena.set_opponent_appearance(gauntlet.opponent.appearance)
			hud.opponent_display_name = gauntlet.opponent.name
	else:
		arena.set_player_appearance(main_menu.local_appearance(0))
		arena.set_opponent_appearance(main_menu.local_appearance(1))
		hud.player_display_name = "Player 1"
		hud.opponent_display_name = "Player 2"
		hud.is_local_2p = true
	_refresh_hud_state()

func _exit_tree() -> void:
	if gauntlet.active:
		history.end_run(gauntlet_run_id, gauntlet.streak, "interrupted")
	profile.abandon_match()
	profile.end_gauntlet_run()
	history.flush_history()

func show_menu() -> void:
	if mode == GameMode.GAUNTLET and gauntlet.active:
		_request_gauntlet_exit("menu")
		return
	_show_menu_confirmed()

func _show_menu_confirmed() -> void:
	history.abandon_match()
	gauntlet_defeated.clear()
	exit_intent = ""
	elimination.cancel()
	if mode == GameMode.SOLO:
		profile.abandon_match()
	audio.stop_all()
	combat_log.end_match("NONE (returned to menu)", turn)
	get_tree().paused = false
	state = State.MAIN_MENU
	controller.accepting = false
	controller_p2.accepting = false
	selected = DuelRules.Action.NONE
	selected_p2 = DuelRules.Action.NONE
	bot_action = DuelRules.Action.NONE
	player.reset()
	opponent.reset()
	arena.reset()
	arena.active = false
	arena.hide()
	hud.banner.text = ""
	hud.reveal_text.text = ""
	_refresh_hud_state()
	hud.update_timer(1.0, 0)
	hud.hide_overlay()
	hud.hide()
	main_menu.open()

func restart_current_duel() -> void:
	if state == State.EXIT_CONFIRM:
		_confirm_gauntlet_exit()
		return
	if mode == GameMode.GAUNTLET:
		if state == State.AWAITING_CONTINUE:
			return # Only the explicit Continue button can leave victory results.
		elif gauntlet.active:
			_request_gauntlet_exit("restart")
		else:
			start_gauntlet()
		return
	# Keep the actual location, including a resolved Random choice, on rematch.
	_start_match_flow(true)

func start_duel() -> void:
	if gauntlet.active:
		_request_gauntlet_exit("solo")
		return
	mode = GameMode.SOLO
	_start_match_flow()

func start_local_duel() -> void:
	if gauntlet.active:
		_request_gauntlet_exit("local")
		return
	mode = GameMode.LOCAL_2P
	_start_match_flow()

func _start_match_flow(rematch: bool = false) -> void:
	if mode == GameMode.GAUNTLET:
		match_arena = gauntlet.arena_id
	elif not rematch or match_arena.is_empty():
		match_arena = settings.Arenas.choose(settings.preferred_arena, arena_rng)
	arena.set_arena_id(match_arena)
	elimination.cancel()
	debug_console.cancel_confirmation()
	if mode == GameMode.SOLO:
		profile.begin_match()
	main_menu.hide()
	hud.show()
	arena.show()
	audio.stop_all()
	combat_log.end_match("NONE (restarted)", turn)
	
	if mode != GameMode.LOCAL_2P:
		bot.start_match()
		combat_log.start_match(bot.personality_snapshot(), "ENDLESS GAUNTLET" if mode == GameMode.GAUNTLET else "SOLO")
	else:
		combat_log.start_match({}, "LOCAL 1v1 DUEL")
	
	get_tree().paused = false
	player.reset()
	opponent.reset()
	selected = DuelRules.Action.NONE
	selected_p2 = DuelRules.Action.NONE
	bot_action = DuelRules.Action.NONE
	turn = 0
	if mode == GameMode.GAUNTLET:
		deadline = 0
	arena.reset()
	arena.active = true
	hud.hide_overlay()
	hud.reveal_text.text = ""
	state = State.COUNTDOWN
	controller.accepting = false
	controller_p2.accepting = false
	
	_apply_profile()
	
	match_difficulty = gauntlet.difficulty if mode == GameMode.GAUNTLET else settings.difficulty
	turn_usec = settings.difficulty_turn_usec(match_difficulty)
	intro_start = Time.get_ticks_usec()
	_refresh_hud_state()
	hud.update_timer(1.0, 1, turn_seconds())
	hud.banner.text = "3"
	history.begin_match({"mode": ["solo", "local", "gauntlet"][mode], "difficulty": match_difficulty,
		"arena": match_arena, "turn_seconds": turn_seconds(), "run_id": gauntlet_run_id if mode == GameMode.GAUNTLET else "",
		"run_duel": gauntlet.duel_number if mode == GameMode.GAUNTLET else 0,
		"actors": [{"name": hud.player_display_name, "appearance": arena.player_appearance.duplicate(), "coat": arena.player_coat().to_html()},
			{"name": hud.opponent_display_name, "appearance": arena.opponent_appearance.duplicate(), "coat": arena.opponent_coat().to_html()}]})

func turn_seconds() -> float:
	return float(turn_usec) / USEC_PER_SECOND

func _process(_delta: float) -> void:
	history.poll_history()
	var now: int = Time.get_ticks_usec()
	if state == State.COUNTDOWN:
		var elapsed: float = float(now - intro_start) / USEC_PER_SECOND
		if now - intro_start >= INTRO_USEC:
			state = State.PLAYING
			hud.banner.text = ""
			deadline = intro_start + INTRO_USEC + turn_usec
			begin_turn()
		else:
			hud.banner.text = "DRAW!" if elapsed >= 2.4 else str(3 - int(elapsed / 0.8))
	if state == State.PLAYING:
		advance_to(now)
		if state == State.PLAYING:
			hud.update_timer(clampf(float(deadline - now) / turn_usec, 0.0, 1.0), turn, turn_seconds())

func begin_turn() -> void:
	turn += 1
	selected = DuelRules.Action.NONE
	selected_p2 = DuelRules.Action.NONE
	if mode != GameMode.LOCAL_2P:
		bot_action = bot.choose_action(opponent.snapshot(), player.snapshot())
		pending_bot_decision = bot.last_decision.duplicate(true)
		controller.accepting = true
		controller_p2.accepting = false
	else:
		bot_action = DuelRules.Action.NONE
		pending_bot_decision = {}
		controller.accepting = true
		controller_p2.accepting = true
	_refresh_hud_state()
	audio.play_turn_tick()

func advance_to(now: int) -> void:
	while state == State.PLAYING and now >= deadline:
		resolve_turn()
		if state == State.PLAYING:
			deadline += turn_usec
			begin_turn()

func submit_action(action: int) -> void:
	if state != State.PLAYING:
		return
	advance_to(Time.get_ticks_usec())
	if state != State.PLAYING:
		return
	if action < DuelRules.Action.NONE or action > DuelRules.Action.SHOOT:
		return
	selected = DuelRules.Action.NONE if action == DuelRules.Action.SHIELD and player.shields >= 3 else action
	_refresh_hud_state()

func submit_action_p2(action: int) -> void:
	if state != State.PLAYING or mode != GameMode.LOCAL_2P:
		return
	advance_to(Time.get_ticks_usec())
	if state != State.PLAYING:
		return
	if action < DuelRules.Action.NONE or action > DuelRules.Action.SHOOT:
		return
	selected_p2 = DuelRules.Action.NONE if action == DuelRules.Action.SHIELD and opponent.shields >= 3 else action
	_refresh_hud_state()

func _refresh_hud_state() -> void:
	if hud:
		hud.update_state_2p(player, opponent, selected, selected_p2, state == State.PLAYING)
		hud.update_gauntlet(gauntlet.streak, profile.gauntlet_records.best_streak, gauntlet.duel_number)

func resolve_turn() -> void:
	if state in [State.GAME_OVER, State.AWAITING_CONTINUE, State.EXIT_CONFIRM]:
		return
	controller.accepting = false
	controller_p2.accepting = false
	var before_player: Dictionary = player.snapshot()
	var before_opponent: Dictionary = opponent.snapshot()
	var action_right: int = selected_p2 if mode == GameMode.LOCAL_2P else bot_action
	var result: Dictionary = DuelRules.resolve(before_player, before_opponent, selected, action_right)
	player.apply(result.left)
	opponent.apply(result.right)
	history.record_turn(turn, [before_player, before_opponent], [selected, action_right], result)
	if mode == GameMode.SOLO:
		profile.record_turn(turn, result)
	audio.play_resolution(result)
	var p1_name: String = profile.display_name if mode != GameMode.LOCAL_2P else "Player 1"
	var p2_name: String = hud.opponent_display_name
	if mode == GameMode.SOLO:
		combat_log.record_turn(turn, before_player, before_opponent, selected, action_right, result, pending_bot_decision)
	elif mode == GameMode.GAUNTLET:
		combat_log.record_turn(turn, before_player, before_opponent, selected, action_right, result, pending_bot_decision, p1_name, p2_name)
	else:
		combat_log.record_turn(turn, before_player, before_opponent, selected, action_right, result, {}, "Player 1", "Player 2")
	arena.reveal(result)
	hud.reveal(result)
	if not player.alive or not opponent.alive:
		state = State.GAME_OVER
		if mode == GameMode.GAUNTLET:
			if player.alive:
				if gauntlet.record_victory():
					profile.record_gauntlet_victory(gauntlet.duel_number, gauntlet.streak)
			else:
				gauntlet.finish()
				profile.end_gauntlet_run()
		hud.update_timer(0.0, turn)
		_refresh_hud_state()
		if not player.alive and not opponent.alive:
			history.complete_match("classic")
			# Shootout draw: do not trigger finishers on shootout draws
			_show_match_result()
		else:
			var winner_is_p1: bool = player.alive
			if mode == GameMode.LOCAL_2P:
				if winner_is_p1:
					local_session_p1_wins += 1
				else:
					local_session_p2_wins += 1
			var winner_effect: String = main_menu.local_finisher(0 if winner_is_p1 else 1) if mode == GameMode.LOCAL_2P else (profile.equipped_elimination_effect if winner_is_p1 else "classic")
			var defeated_name: String = ("Copper Jack" if winner_is_p1 else profile.display_name) if mode == GameMode.SOLO else (p2_name if winner_is_p1 else p1_name)
			var defeated_app: Dictionary = ({} if winner_is_p1 else arena.player_appearance) if mode == GameMode.SOLO else (arena.opponent_appearance if winner_is_p1 else arena.player_appearance)
			var defeated_coat: Color = (Color("ec8b73") if winner_is_p1 else arena.player_coat()) if mode == GameMode.SOLO else (arena.opponent_coat() if winner_is_p1 else arena.player_coat())
			if mode == GameMode.GAUNTLET:
				defeated_name = p2_name if winner_is_p1 else profile.display_name
				defeated_app = arena.opponent_appearance if winner_is_p1 else arena.player_appearance
				defeated_coat = arena.opponent_coat() if winner_is_p1 else arena.player_coat()
			var defeated := {"name": defeated_name, "appearance": defeated_app, "coat": defeated_coat}
			if mode == GameMode.GAUNTLET and winner_is_p1:
				gauntlet_defeated = defeated.duplicate(true)
			var victor := {"name": p1_name if winner_is_p1 else p2_name,
				"appearance": arena.player_appearance if winner_is_p1 else arena.opponent_appearance}
			var playing_finisher: bool = elimination.play(winner_effect, defeated, false, victor)
			history.complete_match(elimination.effect_id)
			if mode == GameMode.GAUNTLET and not gauntlet.active:
				history.end_run(gauntlet_run_id, gauntlet.streak, "defeat", p2_name)
			if not playing_finisher:
				_show_match_result()

func _show_match_result() -> void:
	if state != State.GAME_OVER:
		return
	if mode == GameMode.GAUNTLET:
		if gauntlet.active and player.alive:
			_await_gauntlet_continue()
		else:
			hud.show_overlay("gauntlet_end", "GAUNTLET ENDED", "Final streak: %d\nBest streak: %d\nPress R to start a fresh run" % [gauntlet.streak, profile.gauntlet_records.best_streak])
			hud.primary.text = "RESTART GAUNTLET"
		return
	var pace: String = "%s %.1f s" % [settings.DIFFICULTIES[match_difficulty].label, turn_seconds()] if settings.DIFFICULTIES.has(match_difficulty) else "%.1f s" % turn_seconds()
	if mode == GameMode.LOCAL_2P:
		var title: String = "DRAW"
		if player.alive and not opponent.alive:
			title = "PLAYER 1 WINS"
		elif opponent.alive and not player.alive:
			title = "PLAYER 2 WINS"
		var copy: String = "%d turns  ·  %s\nFinal ammo — P1: %d  /  P2: %d\nSession Score — P1: %d  /  P2: %d\nPress R for another duel" % [
			turn, pace, player.ammo, opponent.ammo, local_session_p1_wins, local_session_p2_wins]
		hud.show_overlay("over", title, copy)
	else:
		var title: String = "VICTORY" if player.alive else "DEFEAT"
		hud.show_overlay("over", title, "%d turns  ·  %s\nFinal ammo — You: %d  /  Jack: %d\nPress R for another duel" % [turn, pace, player.ammo, opponent.ammo])

func start_gauntlet() -> void:
	if gauntlet.active:
		_request_gauntlet_exit("restart")
		return
	mode = GameMode.GAUNTLET
	gauntlet.begin(settings.difficulty)
	gauntlet_run_id = history.begin_run()
	gauntlet.enter_duel(gauntlet.prepare_next())
	profile.begin_gauntlet_run()
	gauntlet_defeated.clear()
	_start_match_flow()

func _await_gauntlet_continue() -> void:
	if state != State.GAME_OVER or not gauntlet.active or not gauntlet.duel_recorded:
		return
	state = State.AWAITING_CONTINUE
	_show_gauntlet_victory()

func _show_gauntlet_victory() -> void:
	hud.show_gauntlet_victory(gauntlet.streak, gauntlet.duel_number + 1)
	_refresh_hud_state()

func _on_result_action() -> void:
	if state == State.EXIT_CONFIRM:
		_confirm_gauntlet_exit()
	elif mode == GameMode.GAUNTLET:
		if state == State.AWAITING_CONTINUE:
			_continue_gauntlet()
		elif state == State.GAME_OVER and not gauntlet.active:
			start_gauntlet()
		elif state == State.PAUSED:
			restart_current_duel()
	else:
		restart_current_duel()

func _unhandled_key_input(event: InputEvent) -> void:
	if mode == GameMode.GAUNTLET and state == State.AWAITING_CONTINUE \
			and event is InputEventKey and event.pressed and not event.echo \
			and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed \
			and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		_continue_gauntlet()
		get_viewport().set_input_as_handled()

func _continue_gauntlet() -> void:
	if state != State.AWAITING_CONTINUE or not gauntlet.active or not gauntlet.duel_recorded or elimination.active:
		return
	# Consume this result before generation. Duplicate/queued button events are
	# ignored once the new countdown begins; no second opponent is prepared.
	state = State.COUNTDOWN
	var prepared: Dictionary = gauntlet.prepare_next()
	if not gauntlet.enter_duel(prepared):
		state = State.AWAITING_CONTINUE
		return
	gauntlet_defeated.clear()
	_start_match_flow()

func _view_gauntlet_poster() -> void:
	if state == State.AWAITING_CONTINUE and not elimination.active and not gauntlet_defeated.is_empty():
		elimination.view_poster(gauntlet_defeated)

func _request_quit() -> void:
	if gauntlet.active:
		_request_gauntlet_exit("quit")
	else:
		get_tree().quit()

func _menu_or_cancel_exit() -> void:
	if state == State.EXIT_CONFIRM:
		_cancel_gauntlet_exit()
	else:
		show_menu()

func _resume_or_cancel_exit() -> void:
	if state == State.EXIT_CONFIRM:
		_cancel_gauntlet_exit()
	else:
		toggle_pause()

func _request_gauntlet_exit(intent: String) -> void:
	if not gauntlet.active or state == State.EXIT_CONFIRM:
		return
	if state == State.PLAYING:
		advance_to(Time.get_ticks_usec())
		if not gauntlet.active:
			_perform_exit_intent(intent)
			return
	# A recorded victory stays recorded; shorten its cosmetic before displaying
	# the confirmation above the normal HUD layer.
	if elimination.active:
		elimination.skip()
	exit_snapshot = {"state": state, "paused": get_tree().paused, "time": Time.get_ticks_usec()}
	exit_intent = intent
	state = State.EXIT_CONFIRM
	controller.accepting = false
	controller_p2.accepting = false
	get_tree().paused = true
	hud.show_overlay("confirm_exit", "END THIS RUN?", "Leaving ends the current gauntlet.\nAchieved streak: %d  ·  Best: %d\nUnfinished duels do not add victories." % [gauntlet.streak, profile.gauntlet_records.best_streak])
	hud.primary.text = "END RUN" if intent != "restart" else "RESTART RUN"
	hud.secondary.text = "KEEP PLAYING"
	_refresh_hud_state()

func _cancel_gauntlet_exit() -> void:
	if state != State.EXIT_CONFIRM or exit_intent.is_empty():
		return
	var elapsed: int = Time.get_ticks_usec() - int(exit_snapshot.time)
	state = exit_snapshot.state
	get_tree().paused = exit_snapshot.paused
	if not exit_snapshot.paused:
		deadline += elapsed
		intro_start += elapsed
	exit_intent = ""
	controller.accepting = state == State.PLAYING
	if state == State.AWAITING_CONTINUE:
		_show_gauntlet_victory()
	elif state == State.PAUSED:
		hud.show_overlay("pause", "PAUSED", "Take a breath.\nThe turn clock is frozen.\nESC or Resume to return to the duel.")
		hud.tertiary.text = "RESTART RUN"
	else:
		hud.hide_overlay()
	_refresh_hud_state()

func _confirm_gauntlet_exit() -> void:
	if state != State.EXIT_CONFIRM or exit_intent.is_empty():
		return
	var intent := exit_intent
	exit_intent = "" # Consume before callbacks; confirmation cannot run twice.
	gauntlet.finish()
	profile.end_gauntlet_run()
	history.end_run(gauntlet_run_id, gauntlet.streak)
	gauntlet_defeated.clear()
	elimination.cancel()
	get_tree().paused = false
	state = State.GAME_OVER
	_perform_exit_intent(intent)

func _open_replay(record: Dictionary) -> void:
	if state != State.MAIN_MENU or is_instance_valid(replay_viewer):
		return
	replay_viewer = preload("res://scripts/ReplayViewer.gd").new()
	replay_viewer.record = record.duplicate(true)
	replay_viewer.sfx_trim = audio.sfx_volume_db
	replay_viewer.music_trim = audio.music_volume_db
	main_menu.hide()
	add_child(replay_viewer)
	replay_viewer.closed.connect(func():
		main_menu.show()
		main_menu.show_page("history")
		replay_viewer.queue_free())

func _perform_exit_intent(intent: String) -> void:
	match intent:
		"quit": get_tree().quit()
		"restart": start_gauntlet()
		"solo": start_duel()
		"local": start_local_duel()
		_: _show_menu_confirmed()

func toggle_pause() -> void:
	if state == State.EXIT_CONFIRM:
		last_pause_toggle_usec = Time.get_ticks_usec()
		_cancel_gauntlet_exit()
		return
	if state != State.PAUSED and state != State.PLAYING and state != State.COUNTDOWN:
		return
	var now: int = Time.get_ticks_usec()
	if now - last_pause_toggle_usec < 50000:
		return
	last_pause_toggle_usec = now
	if state == State.PAUSED:
		var paused_for: int = now - pause_start
		deadline += paused_for
		intro_start += paused_for
		state = before_pause
		get_tree().paused = false
		hud.hide_overlay()
		controller.accepting = state == State.PLAYING
		controller_p2.accepting = state == State.PLAYING and mode == GameMode.LOCAL_2P
		_refresh_hud_state()
	elif state == State.PLAYING or state == State.COUNTDOWN:
		if state == State.PLAYING:
			advance_to(now)
		if state not in [State.PLAYING, State.COUNTDOWN]:
			return
		before_pause = state
		state = State.PAUSED
		pause_start = now
		controller.accepting = false
		controller_p2.accepting = false
		hud.show_overlay("pause", "PAUSED", "Take a breath.\nThe turn clock is frozen.\nESC or Resume to return to the duel.")
		if mode == GameMode.GAUNTLET:
			hud.tertiary.text = "RESTART RUN"
		get_tree().paused = true
