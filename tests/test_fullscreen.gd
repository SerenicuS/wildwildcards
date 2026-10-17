extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const TEST_PATH := "res://.godot/fullscreen_test_settings.cfg"
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func alt_enter(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.alt_pressed = true
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	await settle()

func capture(name_value: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		root.get_texture().get_image().save_png("res://.godot/fullscreen_%s.png" % name_value)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var verifying: bool = "--verify" in OS.get_cmdline_user_args()
	if not verifying:
		ConfigFile.new().save(TEST_PATH)
	var game = Main.new()
	game.profile.path = "res://.godot/test_fullscreen_profile.json"
	game.settings.path = TEST_PATH
	root.add_child(game)
	game.set_process(false)
	await settle()
	var menu = game.main_menu
	menu.show_page("settings")
	await settle()
	if verifying:
		check(game.settings.fullscreen and game.settings.is_fullscreen(), "Fresh process applies saved native fullscreen")
		check(menu.fullscreen_toggle.button_pressed, "Restarted Settings shows actual fullscreen state")
		check(DisplayServer.window_get_size() == DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()), "Restarted native window covers display")
	else:
		var window_size: Vector2i = DisplayServer.window_get_size()
		check(not game.settings.is_fullscreen() and not menu.fullscreen_toggle.button_pressed, "Default windowed mode")
		menu.fullscreen_toggle.button_pressed = true
		await settle()
		var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Settings changes actual native mode")
		check(DisplayServer.window_get_size() == screen_size and DisplayServer.window_get_size() != window_size, "Fullscreen changes physical window dimensions")
		check(DisplayServer.window_get_position() == DisplayServer.screen_get_position(DisplayServer.window_get_current_screen()), "Fullscreen covers screen origin")
		check(menu.fullscreen_toggle.button_pressed, "Toggle synchronized after enable")
		await capture("menu")
		menu.fullscreen_toggle.button_pressed = false
		await settle()
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == window_size, "Windowed restores normal native window size")
		await alt_enter()
		check(game.settings.is_fullscreen() and menu.fullscreen_toggle.button_pressed, "Alt+Enter enables fullscreen and syncs toggle")
		await alt_enter(true)
		check(game.settings.is_fullscreen(), "Held-key echoes do not flip mode repeatedly")
		await alt_enter()
		check(not game.settings.is_fullscreen() and not menu.fullscreen_toggle.button_pressed, "Alt+Enter returns to windowed and syncs toggle")
		# An external mode change must be reflected when Settings is reopened.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		await settle()
		menu.show_page("home")
		menu.show_page("settings")
		await settle()
		check(menu.fullscreen_toggle.button_pressed, "Reopened toggle reads actual native mode, not stale preference")
		menu._set_fullscreen(false)
		await settle()
		DisplayServer.window_set_size(Vector2i(1000, 800))
		await settle()
		check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "Aspect ratio explicitly preserved")
		check(root.get_visible_rect().size.is_equal_approx(Vector2(1280, 720)), "Non-16:9 window keeps original logical canvas")
		check(menu.design.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "Menu remains centered at non-16:9 size")
		for button in menu.buttons.values():
			check(root.get_visible_rect().encloses(button.get_global_rect()), "Menu buttons remain on canvas")
		await capture("windowed_tall")
		# Click Back using window-pixel coordinates transformed from the UI canvas.
		var logical: Vector2 = menu.buttons.back.get_global_rect().get_center()
		var pixel: Vector2 = root.get_final_transform() * logical
		var motion := InputEventMouseMotion.new()
		motion.position = pixel
		root.push_input(motion, false)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = pixel
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, false)
		await settle()
		check(menu.page == "home", "Scaled menu accepts mouse input")
		game.start_duel()
		game.intro_start = Time.get_ticks_usec() - 2800000
		game._process(0.0)
		var old_deadline: int = game.deadline
		var old_selection: int = game.selected
		await alt_enter()
		check(game.settings.is_fullscreen() and game.deadline == old_deadline and game.selected == old_selection, "Gameplay Alt+Enter does not change turn deadline or action")
		check(root.get_visible_rect().encloses(game.hud.cards[0].get_global_rect()) and root.get_visible_rect().encloses(game.hud.cards[2].get_global_rect()), "Gameplay cards remain visible in fullscreen")
		await capture("gameplay")
		game.settings.save_settings()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	game.queue_free()
	await process_frame
	print("Fullscreen%s tests: %d checks, %d failures" % [" restart" if verifying else "", checks, failures])
	quit(1 if failures else 0)
