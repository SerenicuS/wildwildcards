extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
const TEST_PATH := "res://.godot/reset_profile_test.json"
const SETTINGS_PATH := "res://.godot/reset_settings_test.cfg"
const EQUIPPED := {"hat": "gambler", "outfit": "violet", "accessory": "badge"}
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func zero_stats(profile: RefCounted) -> bool:
	for value in profile.stats.values():
		if value != 0:
			return false
	return true

func fixture() -> Dictionary:
	var stats := {}
	for i in range(Profile.STAT_KEYS.size()):
		stats[Profile.STAT_KEYS[i]] = i + 1
	stats.matches_played = 10
	stats.wins = 7
	stats.losses = 3
	stats.shots_blocked = 4
	return {"version": 1, "display_name": "Mara Vale", "appearance": EQUIPPED,
		"equipped_elimination_effect": "future_test", "stats": stats, "reset_revision": 0}

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func command(console: Node, text: String) -> void:
	console.command_input.clear()
	console.command_input.grab_focus()
	for character in text:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			var code: int = character.to_upper().unicode_at(0)
			event.keycode = code
			event.physical_keycode = code
			event.unicode = character.unicode_at(0)
			event.pressed = pressed
			root.push_input(event, true)
	check(console.command_input.text == text, "Console accepts typed command")
	await key(KEY_ENTER)

func capture(name_value: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		root.get_texture().get_image().save_png("res://.godot/wanted_%s.png" % name_value)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stats_restart: bool = "--verify-stats" in OS.get_cmdline_user_args()
	var profile_restart: bool = "--verify-profile" in OS.get_cmdline_user_args()
	if not stats_restart and not profile_restart:
		write_text(TEST_PATH, JSON.stringify(fixture()))
		write_text(TEST_PATH + ".bak", JSON.stringify(fixture()))
		var settings := ConfigFile.new()
		settings.set_value("audio", "master_volume", 0.73)
		settings.set_value("audio", "sfx_volume", 0.42)
		settings.set_value("display", "fullscreen", false)
		settings.save(SETTINGS_PATH)
	var settings_before: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	var game = Main.new()
	game.settings.path = SETTINGS_PATH
	game.profile.path = TEST_PATH
	root.add_child(game)
	game.set_process(false)
	var profile: RefCounted = game.profile
	var console: Node = game.debug_console
	var menu: Control = game.main_menu
	menu.show_page("profile")
	await settle()
	if stats_restart:
		check(zero_stats(profile) and profile.display_name == "Mara Vale" and profile.appearance == EQUIPPED and
			profile.equipped_elimination_effect == "future_test", "Fresh process preserves identity/appearance/effect and reset stats")
		check(menu.profile_stat_labels.shots_blocked.text == "0" and menu.profile_portrait.player_appearance == EQUIPPED, "Restart poster reflects reset and equipped portrait")
		await recovery_checks(profile, false)
		# Next verify a full reset through the same developer-command input.
		await key(KEY_QUOTELEFT)
		var before: Dictionary = profile.stats.duplicate()
		await command(console, "reset_profile")
		check(profile.display_name == "Mara Vale" and profile.stats == before, "Full reset prompt does not mutate profile")
		await command(console, "confirm_reset_profile")
		check(profile.display_name == "Gunslinger" and profile.appearance == Looks.defaults() and
			profile.equipped_elimination_effect == "classic" and zero_stats(profile), "Confirmed reset_profile restores every default")
		check(menu.name_edit.text == "Gunslinger" and menu.profile_portrait.player_appearance == Looks.defaults(), "Open poster immediately refreshes identity and portrait")
		check(game.arena.player_appearance == Looks.defaults() and game.hud.player_display_name == "Gunslinger", "Gameplay presentation receives profile reset")
		var saved: String = FileAccess.get_file_as_string(TEST_PATH)
		await command(console, "confirm_reset_profile")
		check(FileAccess.get_file_as_string(TEST_PATH) == saved, "Repeated full confirmation cannot execute twice")
	elif profile_restart:
		check(profile.display_name == "Gunslinger" and profile.appearance == Looks.defaults() and
			profile.equipped_elimination_effect == "classic" and zero_stats(profile), "Fresh process restores confirmed default profile")
		await recovery_checks(profile, true)
	else:
		check(menu.wanted_paper.visible and not menu.navigation_panel.visible, "Profile uses wanted parchment")
		check(menu.profile_stat_labels.matches_played.text == "10" and menu.profile_stat_labels.wins.text == "7" and
			menu.profile_stat_labels.losses.text == "3" and menu.profile_stat_labels.win_rate.text == "70.0%" and
			menu.profile_stat_labels.shots_blocked.text == "4", "Wanted poster displays saved statistics")
		check(menu.profile_portrait.player_appearance == EQUIPPED and menu.bounty_label.text == "BOUNTY  $2350", "Equipped portrait and deterministic decorative bounty")
		await capture("poster")
		var other_look := {"hat": "wide_brim", "outfit": "rust", "accessory": "bandana"}
		check(profile.equip(other_look) == OK and menu.profile_portrait.player_appearance == other_look,
			"Open wanted portrait immediately reflects confirmed customization")
		check(profile.equip(EQUIPPED) == OK and menu.profile_portrait.player_appearance == EQUIPPED,
			"Wanted portrait restores equipped fixture")
		var original: Dictionary = profile.stats.duplicate()
		await key(KEY_QUOTELEFT)
		check(console.panel.visible and profile.stats == original and not console.command_input.has_focus(), "Opening console never resets or steals typing focus")
		await command(console, "confirm_reset_stats")
		check(profile.stats == original, "Bare confirmation does nothing")
		await command(console, "reset_stats")
		check(profile.stats == original and console.pending_command == "reset_stats", "Stats reset requires explicit confirmation")
		await command(console, "help")
		await command(console, "confirm_reset_stats")
		check(profile.stats == original, "Different command cancels confirmation")
		await command(console, "reset_profile")
		await command(console, "confirm_reset_stats")
		await command(console, "confirm_reset_profile")
		check(profile.stats == original and profile.display_name == "Mara Vale", "Wrong confirmation cancels both reset paths")
		await command(console, "reset_stats")
		console.confirmation_deadline = Time.get_ticks_usec() - 1
		await command(console, "confirm_reset_stats")
		check(profile.stats == original, "Expired confirmation cannot reset")
		await command(console, "reset_stats")
		await key(KEY_QUOTELEFT)
		await key(KEY_QUOTELEFT)
		await command(console, "confirm_reset_stats")
		check(profile.stats == original, "Closing console cancels pending reset")
		await command(console, "reset_stats")
		game.start_duel()
		check(console.pending_command == "", "Starting match cancels confirmation")
		for current_state in [Main.State.COUNTDOWN, Main.State.PLAYING, Main.State.PAUSED, Main.State.GAME_OVER]:
			game.state = current_state
			var player_before: Dictionary = game.player.snapshot()
			var opponent_before: Dictionary = game.opponent.snapshot()
			await command(console, "reset_stats")
			await command(console, "reset_profile")
			await command(console, "confirm_reset_stats")
			check(profile.stats == original and profile.display_name == "Mara Vale" and game.player.snapshot() == player_before and
				game.opponent.snapshot() == opponent_before, "Reset rejected outside main menu; combat untouched")
		check(profile.reset_stats() == ERR_BUSY and profile.reset_profile() == ERR_BUSY, "Profile manager independently rejects active-match reset")
		game.show_menu()
		menu.show_page("profile")
		menu.name_edit.text = "Unconfirmed name"
		await command(console, "reset_stats")
		await command(console, "confirm_reset_stats")
		check(zero_stats(profile), "All lifetime counters reset to zero")
		check(profile.display_name == "Mara Vale" and profile.appearance == EQUIPPED and profile.equipped_elimination_effect == "future_test", "Stats reset preserves name/appearance/elimination field")
		check(menu.profile_stat_labels.wins.text == "0" and menu.profile_stat_labels.shots_blocked.text == "0" and
			menu.profile_stat_labels.win_rate.text == "0.0%" and menu.bounty_label.text == "BOUNTY  $500", "Open poster immediately refreshes reset statistics")
		check(menu.name_edit.text == "Unconfirmed name", "Stats refresh preserves unconfirmed name edit")
		var saved: String = FileAccess.get_file_as_string(TEST_PATH)
		await command(console, "confirm_reset_stats")
		check(FileAccess.get_file_as_string(TEST_PATH) == saved and game.combat_log.full_text().count("Statistics reset and saved.") == 1, "Confirmation consumed; no accidental double execution")
		await capture("console")
		await key(KEY_QUOTELEFT)
		await capture("reset")
	check(FileAccess.get_file_as_string(SETTINGS_PATH) == settings_before and is_equal_approx(game.settings.master_volume, 0.73) and
		is_equal_approx(game.settings.sfx_volume, 0.42), "Profile resets never touch gameplay settings")
	game.queue_free()
	await process_frame
	print("Wanted/reset%s tests: %d checks, %d failures" % [" stats restart" if stats_restart else (" profile restart" if profile_restart else ""), checks, failures])
	quit(1 if failures else 0)

func recovery_checks(profile: RefCounted, defaults: bool) -> void:
	var saved: String = FileAccess.get_file_as_string(TEST_PATH)
	write_text(TEST_PATH, "{ broken json")
	var recovered := Profile.new()
	recovered.path = TEST_PATH
	recovered.load_profile()
	check(zero_stats(recovered), "Reset-safe backup cannot resurrect pre-reset statistics")
	check(recovered.display_name == ("Gunslinger" if defaults else "Mara Vale") and
		recovered.appearance == (Looks.defaults() if defaults else EQUIPPED), "Backup retains correct post-reset identity")
	# Simulate interruption between backup commit and primary replacement.
	write_text(TEST_PATH, JSON.stringify(fixture()))
	recovered = Profile.new()
	recovered.path = TEST_PATH
	recovered.load_profile()
	check(zero_stats(recovered) and recovered.display_name == profile.display_name, "Newer confirmed reset wins over readable stale primary")
	check(recovered.save_profile() == OK, "Recovered reset can save normally")
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".bak"))
	check(backup.stats.wins == 0 and backup.stats.total_turns == 0, "Normal save never rotates pre-reset primary into backup")
	write_text(TEST_PATH, saved)
