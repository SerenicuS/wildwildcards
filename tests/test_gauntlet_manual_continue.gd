extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func click(control: Control) -> void:
	await settle()
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func win(game: Node) -> void:
	game.state = Main.State.PLAYING
	game.player.ammo = 2
	game.player.shields = 2
	game.opponent.shields = 2
	game.turn = 4
	game.selected = 3
	game.bot_action = 1
	game.resolve_turn()

func run() -> void:
	var fresh := Profile.new()
	fresh.path = "res://.godot/manual_continue.json"
	fresh.equipped_elimination_effect = "high_noon"
	fresh.save_profile(true)
	var game := Main.new()
	game.profile.path = fresh.path
	game.settings.path = "res://.godot/manual_continue.cfg"
	root.add_child(game)
	game.set_process(false)
	await settle()
	game.gauntlet.rng.seed = 50506
	game.start_gauntlet()
	var first: Dictionary = game.gauntlet.opponent.duplicate(true)
	win(game)
	var rng_state: int = game.gauntlet.rng.state
	check(game.gauntlet.streak == 1 and game.profile.gauntlet_records.duel_victories == 1, "Victory increments authoritative streak and records once")
	check(game.state == Main.State.GAME_OVER and game.elimination.active, "Equipped finisher plays first")
	await create_timer(1.6).timeout
	check(game.state == Main.State.AWAITING_CONTINUE and not game.elimination.active and game.hud.overlay.visible, "Natural finisher completion displays persistent results")
	check(game.hud.primary.text == "CONTINUE TO NEXT DUEL" and game.hud.overlay_copy.text.contains("Upcoming duel: 2") and game.hud.overlay_copy.text.contains("Current streak: 1"), "Results clearly identify Continue, streak and upcoming duel")
	check(game.gauntlet.rng.state == rng_state and game.gauntlet.opponent == first, "No new opponent or arena generated before Continue")
	game.resolve_turn()
	game._show_match_result()
	check(game.gauntlet.streak == 1 and game.profile.gauntlet_records.duel_victories == 1, "Repeated result callbacks cannot count twice")
	for code in [KEY_A, KEY_S, KEY_D, KEY_J, KEY_K, KEY_L, KEY_R, KEY_ENTER, KEY_ESCAPE]:
		key(code)
	check(game.state == Main.State.AWAITING_CONTINUE and game.hud.overlay.visible and game.gauntlet.duel_number == 1, "Gameplay and former shortcut keys cannot dismiss results or advance")
	# Real wall-clock wait with the production process loop running, not a fake
	# extended delay or altered clock. This also catches delayed tween callbacks.
	game.set_process(true)
	var start := Time.get_ticks_usec()
	await create_timer(31.0).timeout
	game.set_process(false)
	check(Time.get_ticks_usec() - start >= 30000000, "Waited at least thirty actual seconds")
	check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.duel_number == 1 and game.hud.overlay.visible, "Thirty-plus seconds never starts another duel")
	check(game.gauntlet.rng.state == rng_state and game.gauntlet.opponent == first, "Waiting consumes no opponent/arena RNG")
	root.get_texture().get_image().save_png("res://.godot/gauntlet_manual_victory.png")
	await click(game.hud.tertiary)
	check(game.elimination.active and game.elimination.previewing and game.elimination.tween == null and game.elimination.target.name == first.name, "View Poster opens persistent defeated portrait without scheduling a result")
	game._continue_gauntlet()
	check(game.gauntlet.duel_number == 1, "Continue is blocked while inspecting poster")
	await create_timer(1.5).timeout
	check(game.elimination.active and game.state == Main.State.AWAITING_CONTINUE, "Poster remains open until explicitly closed")
	await click(game.elimination.skip_button)
	check(not game.elimination.active and game.hud.overlay.visible and game.gauntlet.streak == 1, "Closing poster returns to unchanged victory screen")
	await click(game.hud.secondary)
	check(game.state == Main.State.EXIT_CONFIRM and paused and game.gauntlet.active, "Return to Menu requires confirmation while run is active")
	await click(game.hud.secondary)
	check(game.state == Main.State.AWAITING_CONTINUE and not paused and game.hud.primary.text == "CONTINUE TO NEXT DUEL", "Cancel exit restores persistent victory screen")
	await click(game.hud.primary)
	var next: Dictionary = game.gauntlet.opponent.duplicate(true)
	var next_rng: int = game.gauntlet.rng.state
	check(game.gauntlet.duel_number == 2 and game.state == Main.State.COUNTDOWN and not game.hud.overlay.visible, "Explicit Continue starts the next duel")
	check(next.name != first.name and next.arena != first.arena and game.match_arena == next.arena and next.appearance == game.arena.opponent_appearance, "Existing randomized opponent, appearance and nonrepeating arena generator reused")
	check(game.player.ammo == 0 and game.opponent.ammo == 0 and game.player.shields == 0 and game.opponent.shields == 0 and game.turn == 0 and game.selected == 0 and game.bot_action == 0 and game.deadline == 0, "Next duel resets ammo, fatigue, actions, turn and deadline")
	for i in range(8):
		game.hud.primary.pressed.emit()
		game._continue_gauntlet()
	check(game.gauntlet.opponent == next and game.gauntlet.rng.state == next_rng and game.gauntlet.duel_number == 2 and game.profile.gauntlet_records.total_runs == 1, "Repeated/queued Continue clicks cannot generate duplicate matches")
	# Skipping a finisher with R can only reveal results, never continue.
	win(game)
	key(KEY_R)
	check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.duel_number == 2 and game.gauntlet.streak == 2, "R during finisher stops at results")
	await click(game.hud.primary)
	game.state = Main.State.PLAYING
	game.turn = 1
	game.player.ammo = 0
	game.opponent.ammo = 1
	game.selected = 1
	game.bot_action = 3
	game.resolve_turn()
	check(game.state == Main.State.GAME_OVER and not game.gauntlet.active and game.hud.overlay_copy.text.contains("Final streak: 2") and game.hud.overlay_copy.text.contains("Best streak: 2"), "Defeat shows final streak and personal best")
	game.set_process(true)
	await create_timer(2.0).timeout
	game.set_process(false)
	check(game.state == Main.State.GAME_OVER and game.hud.overlay.visible and game.gauntlet.duel_number == 3, "Defeat never automatically restarts")
	await click(game.hud.primary)
	check(game.gauntlet.active and game.gauntlet.streak == 0 and game.gauntlet.duel_number == 1, "Explicit Restart Gauntlet starts a fresh run")
	game.profile.equipped_elimination_effect = "classic"
	win(game)
	await click(game.hud.secondary)
	await click(game.hud.primary)
	check(game.state == Main.State.MAIN_MENU and not game.gauntlet.active and not game.profile.is_match_active() and not paused, "Confirmed Return to Menu ends run and returns cleanly")
	check(game.profile.gauntlet_records.best_streak == 2 and game.profile.stats.matches_played == 0, "Records retained and Solo statistics untouched")
	game.queue_free()
	await process_frame
	print("Gauntlet manual Continue: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
