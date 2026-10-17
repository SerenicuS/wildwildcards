extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const Audio = preload("res://scripts/AudioManager.gd")
const TEST_PATH := "res://.godot/difficulty_test_settings.cfg"
const PROFILE_PATH := "res://.godot/test_difficulty_profile.json"
const EXPECTED := {"easy": 2000000, "medium": 1500000, "hard": 1000000}
const A = DuelRules.Action

class TickSpy extends Audio:
	var tick_count: int = 0
	func play_turn_tick() -> void:
		tick_count += 1
		super.play_turn_tick()

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func make_game() -> Node:
	var game = Main.new()
	game.profile.path = PROFILE_PATH
	game.settings.path = TEST_PATH
	root.add_child(game)
	game.set_process(false)
	game.audio.free()
	var audio := TickSpy.new()
	game.add_child(audio)
	game.audio = audio
	game.elimination.audio = audio
	return game

func begin_play(game: Node) -> void:
	game.start_duel()
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func run() -> void:
	if "--verify-difficulty" in OS.get_cmdline_user_args():
		await verify_restart()
		return
	settings_tests()
	var game = make_game()
	timing_tests(game)
	mid_match_and_rematch_tests(game)
	rules_and_bot_tests(game)
	await realtime_tests(game)
	ui_tests(game)
	game.queue_free()
	await process_frame
	# Leave Easy saved for the fresh-process persistence check.
	var cfg := ConfigFile.new()
	cfg.load(TEST_PATH)
	check(cfg.get_value("gameplay", "difficulty") == "easy", "Easy written to disk for restart check")
	print("Difficulty tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func settings_tests() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var fresh := Settings.new()
	fresh.path = TEST_PATH
	fresh.load_settings()
	check(fresh.difficulty == "medium" and fresh.turn_usec() == 1500000, "New installation defaults to Medium")
	for id in EXPECTED:
		check(Settings.difficulty_turn_usec(id) == EXPECTED[id], "Preset duration: " + id)
	check(Settings.difficulty_text("easy").contains("2.0 s") and Settings.difficulty_text("medium").contains("1.5 s")
		and Settings.difficulty_text("hard").contains("1.0 s"), "Labels show turn durations")
	# A file from before difficulty existed: original 1.0 s gameplay.
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "master_volume", 0.6)
	legacy.set_value("audio", "sfx_volume", 0.4)
	legacy.set_value("display", "fullscreen", false)
	legacy.set_value("unrelated", "keep", "preserved")
	legacy.save(TEST_PATH)
	var migrated := Settings.new()
	migrated.path = TEST_PATH
	migrated.load_settings()
	check(migrated.difficulty == "hard" and migrated.turn_usec() == 1000000, "Migrated settings default to Hard")
	check(is_equal_approx(migrated.master_volume, 0.6) and is_equal_approx(migrated.sfx_volume, 0.4), "Migration keeps audio settings")
	check(migrated.save_settings() == OK, "Migrated settings save")
	var reread := ConfigFile.new()
	reread.load(TEST_PATH)
	check(reread.get_value("gameplay", "difficulty") == "hard" and reread.get_value("unrelated", "keep") == "preserved",
		"Migration persisted, unrelated keys preserved")
	# A new install that saved any setting must stay Medium, not migrate to Hard.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var newcomer := Settings.new()
	newcomer.path = TEST_PATH
	newcomer.load_settings()
	newcomer.master_volume = 0.5
	newcomer.save_settings()
	var newcomer_again := Settings.new()
	newcomer_again.path = TEST_PATH
	newcomer_again.load_settings()
	check(newcomer_again.difficulty == "medium", "New install stays Medium after saving other settings")
	reread = ConfigFile.new()
	reread.load(TEST_PATH)
	reread.set_value("gameplay", "difficulty", "nightmare")
	reread.save(TEST_PATH)
	newcomer_again.load_settings()
	check(newcomer_again.difficulty == "medium", "Invalid saved difficulty falls back to Medium")
	reread.set_value("gameplay", "difficulty", 3)
	reread.save(TEST_PATH)
	newcomer_again.load_settings()
	check(newcomer_again.difficulty == "medium", "Non-string saved difficulty falls back to Medium")
	check(not newcomer_again.set_difficulty("impossible") and newcomer_again.difficulty == "medium", "Unknown id rejected")
	newcomer_again.set_difficulty("medium")
	newcomer_again.save_settings()

func timing_tests(game: Node) -> void:
	for id in EXPECTED:
		var usec: int = EXPECTED[id]
		var seconds: float = usec / 1000000.0
		game.settings.set_difficulty(id)
		game.start_duel()
		check(game.turn_usec == usec and game.match_difficulty == id, "Match locks duration: " + id)
		check(game.hud.timer_text.text == "%.2f" % seconds, "Countdown shows full turn time: " + id)
		var ticks_before: int = game.audio.tick_count
		var intro: int = Time.get_ticks_usec() - Main.INTRO_USEC
		game.intro_start = intro
		game._process(0.0)
		check(game.state == Main.State.PLAYING and game.turn == 1 and game.deadline == intro + Main.INTRO_USEC + usec,
			"First authoritative deadline uses difficulty: " + id)
		check(game.audio.tick_count == ticks_before + 1, "One tick on first turn: " + id)
		check(absf(game.hud.timer_text.text.to_float() - seconds) <= 0.05 and game.hud.timer_bar.value > 0.95,
			"HUD starts at full duration: " + id)
		# Mid-turn display: half the duration left, bar at half.
		game.deadline = Time.get_ticks_usec() + usec / 2
		game._process(0.0)
		check(absf(game.hud.timer_text.text.to_float() - seconds * 0.5) <= 0.05 and absf(game.hud.timer_bar.value - 0.5) <= 0.05,
			"HUD mid-turn seconds and bar in sync: " + id)
		# Authoritative boundary: nothing resolves one microsecond early.
		var deadline: int = game.deadline
		game.selected = A.RELOAD
		game.bot_action = A.RELOAD
		game.advance_to(deadline - 1)
		check(game.turn == 1 and game.player.ammo == 0, "No early resolution: " + id)
		game.advance_to(deadline)
		check(game.turn == 2 and game.player.ammo == 1 and game.opponent.ammo == 1, "Simultaneous resolution at deadline: " + id)
		check(game.deadline == deadline + usec, "Next deadline advances by %d usec: %s" % [usec, id])
		check(game.audio.tick_count == ticks_before + 2, "Exactly one tick per turn: " + id)
		# Duplicate calls at the same instant never re-resolve or re-tick.
		var turn_now: int = game.turn
		game.advance_to(deadline)
		game.advance_to(deadline)
		check(game.turn == turn_now and game.audio.tick_count == ticks_before + 2, "No duplicate resolution/tick: " + id)
		# Frame-stall catch-up: exactly one resolution and tick per elapsed turn, zero drift.
		var start_deadline: int = game.deadline
		var start_turn: int = game.turn
		var start_ticks: int = game.audio.tick_count
		game.bot.rng.seed = 7
		game.advance_to(start_deadline + 2 * usec)
		if game.state == Main.State.PLAYING:
			check(game.turn == start_turn + 3 and game.audio.tick_count == start_ticks + 3 and game.deadline == start_deadline + 3 * usec,
				"Catch-up resolves each missed turn once: " + id)
		var first: int = game.deadline
		for i in range(100):
			if game.state != Main.State.PLAYING:
				break
			game.selected = A.RELOAD
			game.bot_action = A.RELOAD
			game.advance_to(game.deadline)
		if game.state == Main.State.PLAYING:
			check(game.deadline == first + 100 * usec, "100 turns have zero cumulative drift: " + id)

func mid_match_and_rematch_tests(game: Node) -> void:
	game.settings.set_difficulty("hard")
	begin_play(game)
	var deadline: int = game.deadline
	# Changing the selection mid-match (as the saved setting) never affects the active match.
	game.settings.set_difficulty("easy")
	game.selected = A.RELOAD
	game.bot_action = A.RELOAD
	game.advance_to(deadline)
	check(game.turn_usec == 1000000 and game.deadline == deadline + 1000000, "Mid-match change does not alter active turns")
	game.settings.set_difficulty("medium")
	begin_play(game)
	check(game.turn_usec == 1500000, "New match applies newly selected difficulty")
	game.player.ammo = 0
	game.player.shields = 0
	game.opponent.ammo = 1
	game.selected = A.NONE
	game.bot_action = A.SHOOT
	game.advance_to(game.deadline)
	check(game.state == Main.State.GAME_OVER, "Match ends")
	game._show_match_result()
	check(game.hud.overlay_copy.text.contains("MEDIUM 1.5 s"), "Result overlay names the difficulty")
	var ticks: int = game.audio.tick_count
	game.advance_to(game.deadline + 10 * game.turn_usec)
	check(game.audio.tick_count == ticks, "No ticks or turns after game over")
	game.controller.restart_requested.emit()
	check(game.state == Main.State.COUNTDOWN and game.turn_usec == 1500000 and game.match_difficulty == "medium",
		"Rematch [R] preserves selected difficulty")
	game.state = Main.State.GAME_OVER
	game.hud.play_requested.emit()
	check(game.turn_usec == 1500000, "Rematch button preserves selected difficulty")
	# Pause shifts the deadline by the paused time without changing duration.
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)
	game.last_pause_toggle_usec -= 60000 # Advance synthetic debounce clock too.
	game.toggle_pause()
	var frozen: int = game.deadline
	game.pause_start -= 700000
	game.last_pause_toggle_usec -= 60000 # Advance synthetic debounce clock too.
	game.toggle_pause()
	check(game.deadline >= frozen + 700000 and game.turn_usec == 1500000, "Pause preserves duration and shifts deadline")
	game.show_menu()

func bot_trace(game: Node, id: String) -> Array:
	game.settings.set_difficulty(id)
	game.bot.rng.seed = 424242
	begin_play(game)
	var trace: Array = [game.bot.personality_snapshot()]
	var plan: Array[int] = [A.RELOAD, A.SHIELD, A.SHIELD, A.SHIELD, A.SHIELD, A.RELOAD, A.SHOOT, A.SHIELD, A.NONE, A.RELOAD]
	var leak_free: bool = true
	for i in range(60):
		if game.state != Main.State.PLAYING:
			break
		var committed: int = game.bot_action
		var decision: Dictionary = game.pending_bot_decision.duplicate(true)
		game.submit_action(plan[i % plan.size()])
		# Player input after the bot committed can never change its action or RNG state.
		leak_free = leak_free and game.bot_action == committed and game.pending_bot_decision == decision
		trace.append([game.turn, committed, decision, game.selected, game.player.snapshot(), game.opponent.snapshot()])
		game.advance_to(game.deadline)
	trace.append([game.state, game.player.snapshot(), game.opponent.snapshot()])
	check(leak_free, "Bot never sees the player's current action: " + id)
	return trace

func rules_and_bot_tests(game: Node) -> void:
	var traces: Dictionary = {}
	for id in EXPECTED:
		traces[id] = bot_trace(game, id)
	check(traces.easy == traces.medium and traces.medium == traces.hard, "Bot personality, decisions, and outcomes identical across difficulties")
	for id in EXPECTED:
		game.settings.set_difficulty(id)
		begin_play(game)
		check(game.player.ammo == 0 and game.opponent.ammo == 0 and game.player.shields == 0, "Starting ammo/shields unchanged: " + id)
		game.player.shields = 3
		game.submit_action(A.SHIELD)
		check(game.selected == A.NONE, "Fourth consecutive shield still rejected: " + id)
		game.player.shields = 2
		game.submit_action(A.SHIELD)
		game.bot_action = A.RELOAD
		game.advance_to(game.deadline)
		check(game.player.shields == 3 and game.opponent.ammo == 1, "Shield streak counts normally: " + id)
		game.selected = A.RELOAD
		game.bot_action = A.SHOOT
		game.advance_to(game.deadline)
		check(game.state == Main.State.GAME_OVER and not game.player.alive and game.opponent.ammo == 0,
			"Damage/elimination rules unchanged: " + id)
	game.show_menu()

func realtime_tests(game: Node) -> void:
	# Real game loop: one full turn measured with the monotonic clock.
	for id in EXPECTED:
		game.settings.set_difficulty(id)
		game.start_duel()
		game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
		game._process(0.0)
		var turn_start: int = game.deadline - game.turn_usec
		var ticks: int = game.audio.tick_count
		game.set_process(true)
		var timeout: int = Time.get_ticks_usec() + 4000000
		while game.turn == 1 and Time.get_ticks_usec() < timeout:
			await process_frame
		var observed: int = Time.get_ticks_usec() - turn_start
		game.set_process(false)
		check(game.turn == 2 and absi(observed - EXPECTED[id]) <= 60000,
			"Real turn lasts ~%.1f s (observed %.3f s): %s" % [EXPECTED[id] / 1000000.0, observed / 1000000.0, id])
		check(game.audio.tick_count == ticks + 1, "Real loop ticks exactly once at turn boundary: " + id)
		print("  %s: real turn %.3f s" % [id, observed / 1000000.0])
	game.show_menu()

func ui_tests(game: Node) -> void:
	var menu = game.main_menu
	game.settings.set_difficulty("medium")
	menu.show_page("play")
	var selector: OptionButton = menu.difficulty_selector
	check(is_instance_valid(selector) and selector.item_count == 3, "Play page has difficulty selector")
	check(selector.get_item_text(0).contains("EASY") and selector.get_item_text(0).contains("2.0 s")
		and selector.get_item_text(1).contains("MEDIUM") and selector.get_item_text(1).contains("1.5 s")
		and selector.get_item_text(2).contains("HARD") and selector.get_item_text(2).contains("1.0 s"), "Selector lists durations")
	check(selector.get_item_metadata(selector.selected) == "medium", "Selector reflects current setting")
	check(menu.buttons.has("solo") and menu.buttons.has("back"), "Solo/back buttons still present")
	selector.select(0)
	selector.item_selected.emit(0)
	check(game.settings.difficulty == "easy", "Selecting Easy updates settings")
	var readback := Settings.new()
	readback.path = TEST_PATH
	readback.load_settings()
	check(readback.difficulty == "easy", "Selection persisted to settings file")
	menu.buttons.solo.pressed.emit()
	check(game.state == Main.State.COUNTDOWN and game.turn_usec == 2000000, "Solo Duel starts with selected difficulty")
	game.show_menu()
	# Simulated restart in-process.
	var second = make_game()
	check(second.settings.difficulty == "easy", "Difficulty restored by a new GameManager")
	second.main_menu.show_page("play")
	check(second.main_menu.difficulty_selector.get_item_metadata(second.main_menu.difficulty_selector.selected) == "easy",
		"Restored selector shows Easy")
	second.queue_free()

func verify_restart() -> void:
	var game = make_game()
	check(game.settings.difficulty == "easy", "Fresh process restores Easy difficulty")
	game.main_menu.show_page("play")
	check(game.main_menu.difficulty_selector.get_item_metadata(game.main_menu.difficulty_selector.selected) == "easy",
		"Fresh process selector shows Easy")
	game.start_duel()
	check(game.turn_usec == 2000000, "Fresh process match uses restored difficulty")
	print("Difficulty restart tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
