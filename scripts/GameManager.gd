extends Node

enum State { MAIN_MENU, COUNTDOWN, PLAYING, GAME_OVER, PAUSED }
const TURN_USEC: int = 1000000
var state: State = State.MAIN_MENU
var before_pause: State = State.MAIN_MENU
var player := DuelParticipant.new()
var opponent := DuelParticipant.new()
var bot := BotController.new()
var controller: PlayerController
var arena: DuelArena
var hud: DuelHUD
var selected: int = DuelRules.Action.NONE
var bot_action: int = DuelRules.Action.NONE
var turn: int = 0
var deadline: int = 0
var intro_start: int = 0
var pause_start: int = 0
var combat_log := CombatLog.new()
var debug_console: CanvasLayer
var pending_bot_decision: Dictionary = {}
var elimination: CanvasLayer
var audio: Node
var settings := preload("res://scripts/GameSettings.gd").new()
var main_menu: Control
var profile := preload("res://scripts/ProfileManager.gd").new()

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
	add_child(controller)
	controller.action_selected.connect(submit_action)
	controller.pause_requested.connect(toggle_pause)
	controller.restart_requested.connect(func():
		if state == State.GAME_OVER: start_duel())
	hud.action_selected.connect(submit_action)
	hud.play_requested.connect(start_duel)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.resume_requested.connect(toggle_pause)
	hud.menu_requested.connect(show_menu)
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
	settings.apply_audio(audio)
	settings.apply_display()
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 2
	add_child(menu_layer)
	main_menu = preload("res://scenes/MainMenu.tscn").instantiate()
	main_menu.settings = settings
	main_menu.audio = audio
	main_menu.profile = profile
	menu_layer.add_child(main_menu)
	main_menu.elimination_preview_requested.connect(func(id: String, target: Dictionary): elimination.play(id, target, true))
	main_menu.solo_requested.connect(start_duel)
	main_menu.quit_requested.connect(func(): get_tree().quit())
	profile.changed.connect(_apply_profile)
	_apply_profile()
	show_menu()

func _apply_profile() -> void:
	arena.set_player_appearance(profile.appearance)
	hud.player_display_name = profile.display_name
	hud.update_state(player, opponent, selected, state == State.PLAYING)

func _exit_tree() -> void:
	profile.abandon_match()

func show_menu() -> void:
	elimination.cancel()
	profile.abandon_match()
	audio.stop_all()
	combat_log.end_match("NONE (returned to menu)", turn)
	get_tree().paused = false
	state = State.MAIN_MENU
	controller.accepting = false
	player.reset()
	opponent.reset()
	arena.reset()
	arena.active = false
	arena.hide()
	hud.banner.text = ""
	hud.reveal_text.text = ""
	hud.update_state(player, opponent, 0, false)
	hud.update_timer(1.0, 0)
	hud.hide_overlay()
	hud.hide()
	main_menu.open()

func start_duel() -> void:
	elimination.cancel()
	debug_console.cancel_confirmation()
	profile.begin_match()
	main_menu.hide()
	hud.show()
	arena.show()
	audio.stop_all()
	combat_log.end_match("NONE (restarted)", turn)
	bot.start_match()
	combat_log.start_match(bot.personality_snapshot())
	get_tree().paused = false
	player.reset()
	opponent.reset()
	selected = DuelRules.Action.NONE
	turn = 0
	arena.reset()
	arena.active = true
	hud.hide_overlay()
	hud.reveal_text.text = ""
	state = State.COUNTDOWN
	controller.accepting = false
	intro_start = Time.get_ticks_usec()
	hud.update_state(player, opponent, selected, false)
	hud.update_timer(1.0, 1)
	hud.banner.text = "3"

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if state == State.COUNTDOWN:
		var elapsed: float = float(now - intro_start) / TURN_USEC
		if elapsed >= 2.8:
			state = State.PLAYING
			hud.banner.text = ""
			deadline = intro_start + 2800000 + TURN_USEC
			begin_turn()
		else:
			hud.banner.text = "DRAW!" if elapsed >= 2.4 else str(3 - int(elapsed / 0.8))
	if state == State.PLAYING:
		advance_to(now)
		if state == State.PLAYING:
			hud.update_timer(clampf(float(deadline - now) / TURN_USEC, 0.0, 1.0), turn)

func begin_turn() -> void:
	turn += 1
	selected = DuelRules.Action.NONE
	bot_action = bot.choose_action(opponent.snapshot(), player.snapshot())
	pending_bot_decision = bot.last_decision.duplicate(true)
	controller.accepting = true
	hud.update_state(player, opponent, selected, true)
	audio.play_turn_tick()

func advance_to(now: int) -> void:
	# Advance by absolute deadlines, including missed turns after a frame stall.
	# Never reset to 'now + duration', which would accumulate frame-time drift.
	while state == State.PLAYING and now >= deadline:
		resolve_turn()
		if state == State.PLAYING:
			deadline += TURN_USEC
			begin_turn()

func submit_action(action: int) -> void:
	if state != State.PLAYING:
		return
	# Input can arrive before _process on an expired frame. Resolve the old turn
	# first so a late event cannot change an already elapsed turn.
	advance_to(Time.get_ticks_usec())
	if state != State.PLAYING:
		return
	if action < DuelRules.Action.NONE or action > DuelRules.Action.SHOOT:
		return
	selected = DuelRules.Action.NONE if action == DuelRules.Action.SHIELD and player.shields >= 3 else action
	hud.update_state(player, opponent, selected, true)

func resolve_turn() -> void:
	if state == State.GAME_OVER:
		return
	controller.accepting = false
	var before_player: Dictionary = player.snapshot()
	var before_bot: Dictionary = opponent.snapshot()
	var result: Dictionary = DuelRules.resolve(before_player, before_bot, selected, bot_action)
	player.apply(result.left)
	opponent.apply(result.right)
	profile.record_turn(turn, result)
	audio.play_resolution(result)
	combat_log.record_turn(turn, before_player, before_bot, selected, bot_action, result, pending_bot_decision)
	arena.reveal(result)
	hud.reveal(result)
	if not player.alive or not opponent.alive:
		state = State.GAME_OVER
		hud.update_timer(0.0, turn)
		hud.update_state(player, opponent, 0, false)
		var winner_effect: String = profile.equipped_elimination_effect if player.alive else "classic"
		var defeated := {"name": "Copper Jack" if player.alive else profile.display_name,
			"appearance": arena.player_appearance if not player.alive else {},
			"coat": Color("ec8b73") if player.alive else arena.player_coat()}
		if not elimination.play(winner_effect, defeated):
			_show_match_result()

func _show_match_result() -> void:
	if state != State.GAME_OVER:
		return
	var title: String = "VICTORY" if player.alive else "DEFEAT"
	hud.show_overlay("over", title, "%d turns played\nFinal ammo — You: %d  /  Jack: %d\nPress R for another duel" % [turn, player.ammo, opponent.ammo])

func toggle_pause() -> void:
	if state == State.PAUSED:
		var paused_for: int = Time.get_ticks_usec() - pause_start
		deadline += paused_for
		intro_start += paused_for
		state = before_pause
		get_tree().paused = false
		hud.hide_overlay()
		controller.accepting = state == State.PLAYING
	elif state == State.PLAYING or state == State.COUNTDOWN:
		var now: int = Time.get_ticks_usec()
		if state == State.PLAYING:
			advance_to(now)
		if state == State.GAME_OVER:
			return
		before_pause = state
		state = State.PAUSED
		pause_start = now
		controller.accepting = false
		hud.show_overlay("pause", "PAUSED", "Take a breath.\nThe turn clock is frozen.\nESC or Resume to return to the duel.")
		get_tree().paused = true
