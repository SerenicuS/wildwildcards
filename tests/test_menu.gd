extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const TEST_PATH := "res://.godot/menu_test_settings.cfg"
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func click(control: Control) -> void:
	# Container layout settles at frame end, including after a page or mode swap.
	await process_frame
	await RenderingServer.frame_post_draw
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func capture(game: Node, name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if "--capture" in OS.get_cmdline_user_args():
		root.get_texture().get_image().save_png("res://.godot/menu_%s.png" % name_value)
	var panel_bottom: float = 635.0
	for child in game.main_menu.content.get_children():
		check(child.position.y + child.size.y + game.main_menu.content.position.y <= panel_bottom,
			"Page content stays within panel: " + name_value)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var verifying: bool = "--verify-settings" in OS.get_cmdline_user_args()
	if not verifying:
		var seed_config := ConfigFile.new()
		seed_config.set_value("unrelated", "keep", "preserved")
		seed_config.save(TEST_PATH)
	var game = Main.new()
	game.profile.path = "res://.godot/test_menu_profile.json"
	game.settings.path = TEST_PATH
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	var menu = game.main_menu
	check(game.state == Main.State.MAIN_MENU and menu.visible and not game.hud.visible, "Launch opens dedicated main menu")
	check(menu.title_label.text.replace("\n", " ") == "WILD WILD CARDS", "Official game title")
	if verifying:
		check(is_equal_approx(game.settings.master_volume, 0.37) and is_equal_approx(game.settings.sfx_volume, 0.58), "Fresh process restores audio settings")
		check(game.settings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fresh process restores fullscreen")
		check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.37)) and is_equal_approx(game.audio.sfx_volume_db, linear_to_db(0.58)), "Restored audio values applied")
		await click(menu.buttons.settings)
		check(menu.master_slider.value == 37 and menu.sfx_slider.value == 58 and menu.fullscreen_toggle.button_pressed, "Settings UI reflects persistent values")
	else:
		await capture(game, "home")
		await click(menu.buttons.play)
		check(menu.page == "play", "Mouse opens Play submenu")
		check(menu.buttons.casual.disabled, "Casual PvP option disabled")
		check(not menu.buttons.local.disabled, "Local PvP option enabled")
		await capture(game, "play")
		await click(menu.buttons.casual)
		check(game.state == Main.State.MAIN_MENU and menu.page == "play", "Disabled casual PvP cannot start game")
		await click(menu.buttons.back)
		check(menu.page == "home", "Play Back works")
		for page in ["customize", "profile"]:
			await click(menu.buttons[page])
			check(menu.page == page and (is_instance_valid(menu.name_edit) if page == "profile" else
				menu.appearance_selectors.size() == 3), "Functional profile/customize entry point: " + page)
			await capture(game, page)
			await click(menu.buttons.back)
			check(menu.page == "home", "Placeholder Back works")
		await click(menu.buttons.settings)
		await capture(game, "settings")
		menu.master_slider.value = 0
		check(AudioServer.is_bus_mute(0), "Master zero mutes output")
		menu.master_slider.value = 37
		menu.sfx_slider.value = 58
		check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.37)), "Master slider applies volume immediately")
		check(is_equal_approx(game.audio.sfx_volume_db, linear_to_db(0.58)), "SFX slider uses existing audio manager")
		await click(menu.fullscreen_toggle)
		await process_frame
		check(game.settings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Mouse fullscreen toggle works")
		var readback := Settings.new()
		readback.path = TEST_PATH
		readback.load_settings()
		check(readback.fullscreen and is_equal_approx(readback.master_volume, 0.37) and is_equal_approx(readback.sfx_volume, 0.58), "Settings saved to disk")
		var config := ConfigFile.new()
		config.load(TEST_PATH)
		check(config.get_value("unrelated", "keep") == "preserved", "Unrelated settings preserved")
		await click(menu.fullscreen_toggle)
		check(not game.settings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
			"Fullscreen toggle returns to windowed mode")
		await click(menu.fullscreen_toggle)
		await click(menu.buttons.back)
		await click(menu.buttons.play)
		await click(menu.buttons.solo)
		check(game.state == Main.State.COUNTDOWN and not menu.visible and game.hud.visible and game.arena.visible, "Solo starts existing introduction")
		game.intro_start = Time.get_ticks_usec() - 2800000
		game._process(0.0)
		check(game.state == Main.State.PLAYING and game.turn == 1, "Existing duel starts normally")
		game.opponent.ammo = 1
		game.selected = DuelRules.Action.NONE
		game.bot_action = DuelRules.Action.SHOOT
		game.advance_to(game.deadline)
		check(game.state == Main.State.GAME_OVER and game.hud.primary.text == "REMATCH  [R]", "Existing game over/rematch available")
		await click(game.hud.primary)
		check(game.state == Main.State.COUNTDOWN and game.player.alive and game.player.ammo == 0, "Mouse rematch resets duel")
		game.state = Main.State.PLAYING
		game.turn = 1
		game.opponent.ammo = 1
		game.bot_action = DuelRules.Action.SHOOT
		game.selected = DuelRules.Action.NONE
		game.resolve_turn()
		await click(game.hud.secondary)
		check(game.state == Main.State.MAIN_MENU and menu.visible and menu.page == "home", "Completed match returns to main menu")
		var quit_seen := [false]
		# Observe the menu's signal without invoking GameManager's real quit handler.
		for connection in menu.quit_requested.get_connections():
			menu.quit_requested.disconnect(connection.callable)
		menu.quit_requested.connect(func(): quit_seen[0] = true)
		await click(menu.buttons.quit)
		check(quit_seen[0], "Quit button emits exit request")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, 0)
	print("Menu%s tests: %d checks, %d failures" % [" persistence restart" if verifying else " navigation/settings", checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
