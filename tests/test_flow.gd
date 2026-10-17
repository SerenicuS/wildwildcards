extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Rules = preload("res://scripts/DuelRules.gd")
var checks: int = 0
var failures: int = 0
var game: Node

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Main.new()
	game.profile.path = "res://.godot/test_flow_profile.json"
	root.add_child(game)
	game.set_process(false)
	check(game.state == Main.State.MAIN_MENU, "Starts at main menu")
	# These checks cover the original 1.0 s mode (Hard); set in memory only.
	game.settings.set_difficulty("hard")
	game.start_duel()
	check(game.state == Main.State.COUNTDOWN, "Duel starts with countdown")
	# Synthetic calls still respect the existing shared-key debounce.
	game.last_pause_toggle_usec -= 60000
	game.toggle_pause()
	check(paused and game.state == Main.State.PAUSED, "Introduction pauses")
	game.last_pause_toggle_usec -= 60000
	game.hud.resume_requested.emit()
	check(not paused and game.state == Main.State.COUNTDOWN, "Resume signal works while paused")
	game.intro_start = Time.get_ticks_usec() - 2800000
	game._process(0.0)
	check(game.state == Main.State.PLAYING and game.turn == 1, "Countdown begins turn one")
	game.submit_action(Rules.Action.RELOAD)
	game.submit_action(Rules.Action.SHOOT)
	check(game.selected == Rules.Action.SHOOT, "Selection can change")
	game.selected = Rules.Action.RELOAD
	game.bot_action = Rules.Action.RELOAD
	game.deadline = Time.get_ticks_usec() - 1
	var boundary: int = game.deadline
	game.advance_to(boundary)
	check(game.player.ammo == 1 and game.opponent.ammo == 1, "Both reload simultaneously")
	check(game.selected == Rules.Action.NONE and game.turn == 2, "New turn clears selection")
	check(game.deadline == boundary + 1000000, "Deadline advances exactly one second")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	key.echo = true
	game.controller._unhandled_key_input(key)
	check(game.selected == Rules.Action.NONE, "Held key echo ignored")
	key.echo = false
	game.controller._unhandled_key_input(key)
	check(game.selected == Rules.Action.RELOAD, "Fresh key press accepted")
	game.selected = Rules.Action.NONE
	game.bot_action = Rules.Action.RELOAD
	game.advance_to(game.deadline)
	check(game.player.ammo == 1 and game.opponent.ammo == 2, "NONE allows bot to continue")
	game.player.shields = 3
	game.submit_action(Rules.Action.SHIELD)
	check(game.selected == Rules.Action.NONE, "Fourth shield becomes NONE")
	# Synthetic calls still respect the existing shared-key debounce.
	game.last_pause_toggle_usec -= 60000
	game.toggle_pause()
	var frozen_deadline: int = game.deadline
	game.pause_start -= 1500000
	# Synthetic calls still respect the existing shared-key debounce.
	game.last_pause_toggle_usec -= 60000
	game.toggle_pause()
	check(game.deadline >= frozen_deadline + 1500000, "Pause shifts turn deadline")
	game.player.ammo = 0
	game.player.shields = 0
	game.selected = Rules.Action.NONE
	game.bot_action = Rules.Action.SHOOT
	game.advance_to(game.deadline)
	check(game.state == Main.State.GAME_OVER and not game.player.alive, "Bot can defeat inactive player")
	game.start_duel()
	check(game.player.alive and game.opponent.alive and game.player.ammo == 0 and game.opponent.ammo == 0 and game.turn == 0, "Rematch resets match")
	# Test a late event and catch-up without allowing random bot shots to end it.
	game.state = Main.State.PLAYING
	game.bot_action = Rules.Action.RELOAD
	game.deadline = Time.get_ticks_usec() - 100
	game.begin_turn()
	game.bot_action = Rules.Action.RELOAD
	game.submit_action(Rules.Action.RELOAD)
	check(game.player.ammo == 0 and game.selected == Rules.Action.RELOAD, "Late event applies to next turn")
	game.hud.cards[2].pressed.emit()
	check(game.selected == Rules.Action.SHOOT, "Mouse shoot card emits its own action")
	game.hud.cards[0].pressed.emit()
	check(game.selected == Rules.Action.RELOAD, "Mouse reload card emits its own action")
	var first_deadline: int = game.deadline
	for i in range(300):
		game.selected = Rules.Action.RELOAD
		game.bot_action = Rules.Action.RELOAD
		game.advance_to(game.deadline)
	check(game.deadline == first_deadline + 300000000, "300 turn deadlines have zero cumulative drift")
	game.show_menu()
	check(game.state == Main.State.MAIN_MENU and not paused, "Main menu resets pause")
	print("Flow tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
