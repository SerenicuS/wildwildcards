extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func play(game: Node) -> void:
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func win(game: Node) -> void:
	game.player.ammo = 1
	game.selected = 3
	game.bot_action = 1
	game.advance_to(game.deadline)

func run() -> void:
	var fresh := Profile.new()
	fresh.path = "res://.godot/gauntlet_edges.json"
	fresh.equipped_elimination_effect = "classic"
	fresh.save_profile(true)
	var game := Main.new()
	game.profile.path = fresh.path
	game.settings.path = "res://.godot/gauntlet_edges.cfg"
	root.add_child(game)
	game.set_process(false)
	game.settings.difficulty = "hard"
	game.start_gauntlet()
	play(game)
	win(game)
	check(game.state == Main.State.AWAITING_CONTINUE and not game.elimination.active, "Classic wins enter the transition immediately")
	game.set_process(true)
	# Match orchestration uses monotonic wall time. Do not count the large first
	# rendered frame's startup delta as elapsed transition time in this test.
	var limit: int = Time.get_ticks_usec() + 2000000
	while game.state == Main.State.AWAITING_CONTINUE and Time.get_ticks_usec() < limit:
		await process_frame
	game.set_process(false)
	check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.duel_number == 1 and game.gauntlet.streak == 1, "Real process loop keeps results visible indefinitely")
	game.hud.primary.pressed.emit()
	play(game)
	game.profile.equipped_elimination_effect = "wanted_eliminated"
	win(game)
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	root.push_input(event, true)
	check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.duel_number == 2 and game.gauntlet.streak == 2, "R skips only the finisher and stops at results")
	game.hud.primary.pressed.emit()
	await create_timer(1.4).timeout
	check(game.gauntlet.duel_number == 3 and not game.elimination.active and not game.hud.overlay.visible, "Canceled finisher/transition leaves no delayed callback")
	var intro_before: int = game.intro_start
	game.show_menu()
	check(game.state == Main.State.EXIT_CONFIRM and paused, "Countdown exits require confirmation")
	game.exit_snapshot.time -= 250000
	game._cancel_gauntlet_exit()
	check(game.state == Main.State.COUNTDOWN and game.intro_start >= intro_before + 250000, "Countdown resumes without losing frozen time")
	play(game)
	game.last_pause_toggle_usec -= 60000
	game.toggle_pause()
	game.restart_current_duel()
	game._confirm_gauntlet_exit()
	game._confirm_gauntlet_exit()
	check(game.gauntlet.streak == 0 and game.profile.gauntlet_records.total_runs == 2 and not paused, "Confirmed pause restart creates just one fresh run")
	play(game)
	game.opponent.ammo = 1
	game.selected = 1
	game.bot_action = 3
	game.deadline = Time.get_ticks_usec() - 100
	game.show_menu()
	check(game.state == Main.State.MAIN_MENU and not game.gauntlet.active and game.profile.gauntlet_records.best_streak == 2, "Exit cannot bypass an already-expired lethal turn")
	game.start_gauntlet()
	play(game)
	game.player.ammo = 1
	game.selected = 3
	game.bot_action = 1
	game.deadline = Time.get_ticks_usec() - 100
	game.show_menu()
	check(game.state == Main.State.EXIT_CONFIRM and game.gauntlet.streak == 1 and game.profile.gauntlet_records.duel_victories == 3, "Exit records an already-expired legitimate victory before confirmation")
	game._confirm_gauntlet_exit()
	game.start_gauntlet()
	play(game)
	win(game)
	game.get_window().close_requested.emit()
	check(game.state == Main.State.EXIT_CONFIRM and not game.elimination.active, "Window close during WANTED shows an unobscured confirmation")
	var prepared: Dictionary = game.gauntlet.opponent.duplicate(true)
	game._cancel_gauntlet_exit()
	check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.opponent == prepared, "Cancel during finisher exit preserves the resolved opponent until Continue")
	check(game.profile.reset_stats() == ERR_BUSY, "Persistent records stay guarded between duels")
	game.show_menu()
	game._confirm_gauntlet_exit()
	game.profile.equipped_elimination_effect = "classic"
	game.start_gauntlet()
	await process_frame
	var node_count: int = get_node_count()
	for i in range(50):
		play(game)
		win(game)
		game._show_match_result()
		game.resolve_turn()
		game._continue_gauntlet()
		check(game.gauntlet.streak == i + 1 and game.gauntlet.duel_number == i + 2, "Repeated fast victories never duplicate/skip progression")
		check(game.player.ammo == 0 and game.opponent.ammo == 0 and game.player.shields == 0 and game.opponent.shields == 0, "Every continued duel starts with clean combat resources")
	check(get_node_count() == node_count, "Fifty continued duels add no nodes or Timer nodes")
	check(game.profile.gauntlet_records.best_streak == 50 and game.profile.gauntlet_records.duel_victories == 54 and game.profile.gauntlet_records.total_runs == 5, "Long-run records match actual outcomes")
	game.show_menu()
	game._confirm_gauntlet_exit()
	check(game.gauntlet_defeated.is_empty() and not paused, "Final abandon cleans up transition state")
	game.queue_free()
	await process_frame
	print("Gauntlet edge cases: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
