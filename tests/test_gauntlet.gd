extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const PROFILE_PATH := "res://.godot/gauntlet_integration.json"
const SETTINGS_PATH := "res://.godot/gauntlet_integration.cfg"
var checks: int = 0
var failures: int = 0

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

func play(game: Node) -> void:
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func resolve(game: Node, left: int, right: int) -> void:
	game.selected = left
	game.bot_action = right
	game.advance_to(game.deadline)

func win(game: Node) -> void:
	game.player.ammo = 1
	game.player.shields = 2
	game.opponent.shields = 2
	game.selected = 3
	game.bot_action = 1
	game.advance_to(game.deadline)

func capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await settle()
		root.get_texture().get_image().save_png("res://.godot/gauntlet_%s.png" % name)

func run() -> void:
	var verify := "--verify" in OS.get_cmdline_user_args()
	if not verify:
		var initial := Profile.new()
		initial.path = PROFILE_PATH
		initial.equipped_elimination_effect = "wanted_eliminated"
		initial.appearance.revolver_model = "python"
		initial.save_profile(true)
		var settings := Settings.new()
		settings.path = SETTINGS_PATH
		settings.difficulty = "hard"
		settings.preferred_arena = "ghost_town"
		settings.save_settings()
	var game := Main.new()
	game.profile.path = PROFILE_PATH
	game.settings.path = SETTINGS_PATH
	root.add_child(game)
	game.set_process(false)
	game.gauntlet.rng.seed = 50503
	game.bot.rng.seed = 13412
	var menu: Control = game.main_menu
	if verify:
		check(game.profile.gauntlet_records.best_streak == 3 and game.profile.gauntlet_records.duel_victories == 3, "Best and achieved wins persist across process restart")
		check(game.profile.gauntlet_records.total_runs == 3 and game.profile.stats.matches_played == 0, "Runs persist separately from Solo matches")
		game.start_gauntlet()
		check(game.gauntlet.streak == 0 and game.hud.gauntlet_text.text.contains("BEST STREAK: 3"), "Restarted game starts a fresh zero-streak run with saved best")
		game.show_menu()
		game._confirm_gauntlet_exit()
	else:
		menu.show_page("play")
		await settle()
		check(menu.buttons.has("gauntlet") and menu.buttons.has("solo") and menu.buttons.has("local"), "All three game modes remain available")
		for child in menu.content.get_children():
			check(child.position.y + child.size.y + menu.content.position.y <= 635, "Play options fit the existing menu panel")
		await capture("menu")
		await click(menu.buttons.gauntlet)
		check(game.mode == Main.GameMode.GAUNTLET and game.gauntlet.active and game.gauntlet.streak == 0 and game.gauntlet.duel_number == 1, "Menu starts a zero-streak gauntlet")
		check(game.profile.gauntlet_records.total_runs == 1 and game.profile.is_match_active(), "Run is saved once and profile resets are blocked")
		check(game.turn_usec == 1000000 and game.match_difficulty == "hard", "Selected difficulty reused")
		check(game.arena.player_appearance.revolver_model == "python" and game.hud.opponent_display_name == game.gauntlet.opponent.name, "Saved player cosmetics and randomized opponent are applied")
		check(game.hud.gauntlet_text.visible and game.hud.gauntlet_text.text.contains("CURRENT STREAK: 0"), "Compact streak/best/duel HUD appears")
		play(game)
		await capture("hud")
		resolve(game, 1, 1)
		resolve(game, 3, 3)
		check(game.player.alive and game.opponent.alive and game.gauntlet.streak == 0 and game.profile.gauntlet_records.duel_victories == 0, "Shootout draws do not advance the run")
		resolve(game, 1, 1)
		resolve(game, 2, 3)
		check(game.gauntlet.streak == 0 and not game.elimination.active and game.player.alive, "Shield blocks do not advance the run")
		var first_bot: Dictionary = game.gauntlet.opponent.duplicate(true)
		var first_personality: Dictionary = game.bot.personality_snapshot()
		var first_arena: String = game.match_arena
		win(game)
		check(game.gauntlet.streak == 1 and game.profile.gauntlet_records.best_streak == 1 and game.profile.gauntlet_records.duel_victories == 1, "Authoritative victory records exactly one streak increment")
		check(game.state == Main.State.GAME_OVER and game.elimination.active, "WANTED plays before the persistent victory results")
		check(game.elimination.target.name == first_bot.name and game.elimination.portrait.player_appearance == first_bot.appearance, "WANTED captures the actual defeated randomized appearance")
		game.resolve_turn()
		check(game.gauntlet.streak == 1, "Repeated lethal callback does nothing")
		await create_timer(1.45).timeout
		check(game.state == Main.State.AWAITING_CONTINUE and not game.elimination.active, "Finisher completion waits for Continue")
		var rng_state: int = game.gauntlet.rng.state
		game._show_match_result()
		check(game.gauntlet.opponent == first_bot and game.gauntlet.rng.state == rng_state, "Repeated finish signal does not generate another opponent")
		check(game.hud.overlay_copy.text.contains("Upcoming duel: 2"), "Persistent results show upcoming duel number")
		check(not game.hud.gauntlet_preview.visible, "No next arena is prepared before Continue")
		await capture("victory")
		var held_space := InputEventKey.new()
		held_space.keycode = KEY_SPACE
		held_space.pressed = true
		held_space.echo = true
		root.push_input(held_space, true)
		check(game.state == Main.State.AWAITING_CONTINUE, "Held Space echo cannot advance results")
		key(KEY_SPACE)
		check(game.state == Main.State.COUNTDOWN and game.gauntlet.duel_number == 2, "Fresh Space press explicitly continues to next duel")
		key(KEY_SPACE)
		game.hud.primary.pressed.emit()
		var pending: Dictionary = game.gauntlet.opponent.duplicate(true)
		check(game.state == Main.State.COUNTDOWN and game.gauntlet.duel_number == 2 and game.gauntlet.streak == 1, "Continue starts next duel")
		check(pending.arena != first_arena and pending.name != first_bot.name, "Continue randomizes opponent and non-repeated arena")
		check(game.player.ammo == 0 and game.opponent.ammo == 0 and game.player.shields == 0 and game.opponent.shields == 0 and game.selected == 0 and game.bot_action == 0 and game.deadline == 0, "Ammo, shields, selections and timer reset")
		check(game.bot.personality_snapshot() != first_personality and game.gauntlet.opponent == pending, "Next duel applies fresh existing bot personality and cosmetics")
		game._continue_gauntlet()
		check(game.gauntlet.duel_number == 2 and game.profile.gauntlet_records.total_runs == 1, "Duplicate Continue cannot skip a duel or count a new run")
		game.settings.difficulty = "easy"
		play(game)
		check(game.turn_usec == 1000000, "Active run keeps its selected difficulty")
		win(game)
		game.elimination.skip()
		check(game.gauntlet.streak == 2 and game.state == Main.State.AWAITING_CONTINUE, "Finisher skip safely enters persistent victory results")
		game._process(0.0)
		check(game.state == Main.State.AWAITING_CONTINUE, "Process loop cannot auto-continue")
		await click(game.hud.primary)
		check(game.state == Main.State.COUNTDOWN and game.gauntlet.duel_number == 3, "Continue starts the third duel")
		play(game)
		var old_deadline: int = game.deadline
		var old_intro: int = game.intro_start
		var records: Dictionary = game.profile.gauntlet_records.duplicate()
		game.show_menu()
		check(game.state == Main.State.EXIT_CONFIRM and paused and game.gauntlet.active and game.profile.gauntlet_records == records, "Mid-run menu request requires confirmation without finalizing")
		game.resolve_turn()
		game.submit_action(3)
		check(game.profile.gauntlet_records == records and not game.controller.accepting, "Confirmation prevents duplicate resolution and action submissions")
		await capture("exit")
		game.exit_snapshot.time -= 200000
		await click(game.hud.secondary)
		check(game.state == Main.State.PLAYING and not paused and game.deadline >= old_deadline + 200000 and game.intro_start >= old_intro + 200000, "Cancel restores gameplay and shifts deadlines by frozen time")
		game.last_pause_toggle_usec -= 60000
		game.toggle_pause()
		await click(game.hud.tertiary)
		check(game.state == Main.State.EXIT_CONFIRM and game.exit_intent == "restart", "Paused Restart Run also requires confirmation")
		game._cancel_gauntlet_exit()
		check(game.state == Main.State.PAUSED and paused, "Cancel from pause restores the paused overlay")
		game.last_pause_toggle_usec -= 60000
		game.toggle_pause()
		win(game)
		game.elimination.skip()
		var victory_before: Dictionary = game.gauntlet.opponent.duplicate(true)
		game.show_menu()
		game.exit_snapshot.time -= 200000
		game._cancel_gauntlet_exit()
		check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.opponent == victory_before, "Cancel exit restores persistent results without generating an opponent")
		await click(game.hud.primary)
		play(game)
		game.player.ammo = 0
		game.opponent.ammo = 1
		resolve(game, 1, 3)
		check(game.state == Main.State.GAME_OVER and not game.gauntlet.active and not game.profile.is_match_active(), "A loss ends the whole run")
		check(game.gauntlet.streak == 3 and game.hud.overlay_copy.text.contains("Final streak: 3") and game.hud.overlay_copy.text.contains("Best streak: 3"), "Final screen shows correct streak and best")
		check(game.hud.primary.text == "RESTART GAUNTLET" and game.profile.gauntlet_records.total_runs == 1 and game.profile.stats.matches_played == 0, "End screen offers restart; no duplicate run or Solo statistics")
		await capture("ended")
		game.resolve_turn()
		game._process(0.0)
		check(game.profile.gauntlet_records.duel_victories == 3 and game.gauntlet.duel_number == 4, "Loss does not start another opponent or add a win")
		key(KEY_R)
		check(game.gauntlet.active and game.gauntlet.streak == 0 and game.gauntlet.duel_number == 1 and game.profile.gauntlet_records.total_runs == 2, "R restarts a fresh zero-streak run")
		check(game.turn_usec == 2000000, "New run uses the newly selected preset")
		game.show_menu()
		await click(game.hud.primary)
		game._confirm_gauntlet_exit()
		check(game.state == Main.State.MAIN_MENU and not paused and game.profile.gauntlet_records.total_runs == 2 and game.profile.gauntlet_records.best_streak == 3, "Confirmed abandon is idempotent and preserves actual best")
		game.start_gauntlet()
		play(game)
		game.get_window().close_requested.emit()
		check(game.state == Main.State.EXIT_CONFIRM and game.exit_intent == "quit", "Window close/quit requires active-run confirmation")
		key(KEY_ESCAPE)
		check(game.state == Main.State.PLAYING and game.gauntlet.active and not paused, "Escape cancels quit confirmation without ending run")
		game.show_menu()
		game._confirm_gauntlet_exit()
		check(game.profile.gauntlet_records.total_runs == 3 and game.profile.gauntlet_records.best_streak == 3, "Zero-win exits count a started run but never add best or victories")
	game.queue_free()
	await process_frame
	print("Gauntlet%s: %d checks, %d failures" % [" restart" if verify else " integration", checks, failures])
	quit(1 if failures else 0)
