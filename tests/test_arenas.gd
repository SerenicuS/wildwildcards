extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const SETTINGS_PATH := "res://.godot/arena_test_settings.cfg"
const PROFILE_PATH := "res://.godot/arena_test_profile.json"
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
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func select_arena(menu: Control, id: String) -> void:
	for i in menu.arena_selector.item_count:
		if menu.arena_selector.get_item_metadata(i) == id:
			menu.arena_selector.select(i)
			menu.arena_selector.item_selected.emit(i)
			return
	check(false, "Missing arena selection: " + id)

func begin(game: Node, local: bool = false) -> void:
	if local:
		game.start_local_duel()
	else:
		game.start_duel()
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func resolve(game: Node, left: int, right: int) -> void:
	game.selected = left
	game.selected_p2 = right
	game.bot_action = right
	game.advance_to(game.deadline)

func settings_checks() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", 0.73)
	config.set_value("audio", "sfx_volume", 0.64)
	config.set_value("unrelated", "keep", "preserved")
	config.save(SETTINGS_PATH)
	var migrated := Settings.new()
	migrated.path = SETTINGS_PATH
	migrated.load_settings()
	check(migrated.preferred_arena == Arenas.DEFAULT_ID and migrated.difficulty == "hard", "Legacy settings retain original arena and one-second pace")
	check(not migrated.set_arena("invalid") and migrated.preferred_arena == Arenas.DEFAULT_ID, "Invalid arena IDs are rejected")
	for invalid in ["missing_arena", 17, true]:
		config.set_value("cosmetics", "arena", invalid)
		config.save(SETTINGS_PATH)
		migrated.load_settings()
		check(migrated.preferred_arena == Arenas.DEFAULT_ID, "Malformed persisted arena uses safe default")
	migrated.save_settings()

func run() -> void:
	var verify := "--verify" in OS.get_cmdline_user_args()
	var verify_random := "--verify-random" in OS.get_cmdline_user_args()
	if not verify and not verify_random:
		settings_checks()
		var fresh := Profile.new()
		fresh.path = PROFILE_PATH
		fresh.appearance.merge({"hat": "gambler", "revolver_model": "python", "revolver_finish": "silver", "revolver_grip": "ivory"}, true)
		fresh.equipped_elimination_effect = "wanted_eliminated"
		fresh.save_profile(true)
	var game := Main.new()
	game.settings.path = SETTINGS_PATH
	game.profile.path = PROFILE_PATH
	root.add_child(game)
	game.set_process(false)
	var menu: Control = game.main_menu
	menu.show_page("play")
	await settle()
	check(menu.arena_selector.item_count == 6, "Four new locations, original location and Random are selectable")
	if verify or verify_random:
		var expected := Arenas.RANDOM_ID if verify_random else "ghost_town"
		check(game.settings.preferred_arena == expected and menu.arena_preview.arena_id == expected, "Fresh process restores preference and preview")
		check(menu.arena_selector.get_item_metadata(menu.arena_selector.selected) == expected, "Fresh selector reflects saved arena")
		await click(menu.buttons.solo)
		check(Arenas.DEFINITIONS.has(game.match_arena) and (verify_random or game.match_arena == expected), "Restored preference starts a real location")
		var chosen: String = game.match_arena
		game.restart_current_duel()
		check(game.match_arena == chosen, "Restored arena remains fixed on rematch")
		check(game.settings.difficulty == "hard" and is_equal_approx(game.settings.master_volume, 0.73), "Restart preserves unrelated settings")
		if verify:
			game.settings.set_arena(Arenas.RANDOM_ID)
			game.settings.save_settings()
	else:
		var profile_text := FileAccess.get_file_as_string(PROFILE_PATH)
		var preview_hashes := {}
		var scene_hashes := {}
		var sheet := Image.create(1280, 1080, false, Image.FORMAT_RGBA8)
		menu.local_revolvers[0] = {"revolver_model": "schofield", "revolver_finish": "blued", "revolver_grip": "ebony"}
		menu.local_revolvers[1] = {"revolver_model": "cobra", "revolver_finish": "gold", "revolver_grip": "engraved"}
		for id in Arenas.ORDER:
			select_arena(menu, id)
			await settle()
			check(game.settings.preferred_arena == id and menu.arena_preview.arena_id == id, "Selection immediately updates matching preview")
			check(FileAccess.get_file_as_string(PROFILE_PATH) == profile_text, "Arena selection never writes the player profile")
			for child in menu.content.get_children():
				check(child.position.y + child.size.y + menu.content.position.y <= 635, "Play controls and preview fit the existing panel")
			var preview_rect: Rect2i = Rect2i(menu.arena_preview.get_global_rect())
			var preview: Image = root.get_texture().get_image().get_region(preview_rect)
			preview_hashes[hash(preview.get_data())] = true
			await click(menu.buttons.solo)
			check(game.state == Main.State.COUNTDOWN and game.match_arena == id and game.arena.arena_id == id, "Solo button launches selected arena with existing countdown")
			# Isolate the cached background for comparison with the shared preview.
			game.hud.hide()
			game.arena.self_modulate.a = 0.0
			game.arena.ambient.hide()
			await settle()
			var background := root.get_texture().get_image()
			scene_hashes[hash(background.get_data())] = true
			background.resize(preview.get_width(), preview.get_height(), Image.INTERPOLATE_LANCZOS)
			var difference: float = 0.0
			for y in preview.get_height():
				for x in preview.get_width():
					var a := preview.get_pixel(x, y)
					var b := background.get_pixel(x, y)
					difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			difference /= preview.get_width() * preview.get_height() * 3.0
			check(difference < 0.08, "Preview and gameplay share the same background: " + id)
			game.arena.self_modulate.a = 1.0
			game.arena.ambient.show()
			game.hud.show()
			game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
			game._process(0.0)
			game.arena.active = false
			game.arena.clock = 0.0
			await settle()
			if "--capture" in OS.get_cmdline_user_args():
				var shot := root.get_texture().get_image()
				shot.save_png("res://.godot/arena_%s.png" % id)
				shot.resize(640, 360)
				var i: int = Arenas.ORDER.find(id)
				sheet.blit_rect(shot, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
			for side in range(2):
				var armed := {"ammo": 1, "shields": 0, "alive": true}
				game.arena.reveal(DuelRules.resolve(armed, armed, 3, 3))
				game.arena.effect_age = 0.0
				game.arena.queue_redraw()
				await settle()
				var app: Dictionary = game.arena.player_appearance if side == 0 else game.arena.opponent_appearance
				var pose: Dictionary = game.arena.action_pose(side)
				var flash: Vector2 = game.arena._world_point(side, pose.hand + (Revolver.muzzle(app) + Vector2(5, 0)).rotated(pose.angle))
				var pixel := root.get_texture().get_image().get_pixelv(Vector2i(flash))
				check(pixel.r > 0.9 and pixel.g > 0.8 and pixel.b > 0.6, "Muzzle flash stays visible in arena on both sides")
				game.arena.reveal(DuelRules.resolve(armed, armed, 2 if side == 0 else 3, 3 if side == 0 else 2))
				game.arena.effect_age = 0.06
				game.arena.queue_redraw()
				await settle()
				var point: Vector2 = game.arena._world_point(side, Vector2(78, -82))
				pixel = root.get_texture().get_image().get_pixelv(Vector2i(point))
				check(pixel.g > 0.6 and pixel.b > 0.75, "Shield stays visible in arena on both sides")
			for local in [false, true]:
				begin(game, local)
				check(game.match_arena == id and game.turn == 1 and game.turn_usec == 1000000, "Both modes preserve location and original hard timing")
				var stats_before: Dictionary = game.profile.stats.duplicate()
				var expected_gun: String = "schofield" if local else "python"
				check(game.arena.player_appearance.revolver_model == expected_gun and game.arena.opponent_appearance.revolver_model == ("cobra" if local else "peacemaker"), "Arena preserves saved and local revolver loadouts")
				var deadline: int = game.deadline
				resolve(game, 1, 1)
				check(game.player.ammo == 1 and game.opponent.ammo == 1 and game.deadline == deadline + 1000000, "Reload and deadline unchanged in each mode/arena")
				resolve(game, 2, 3)
				check(game.player.alive and game.player.shields == 1 and game.opponent.ammo == 0 and not game.elimination.active, "Shield block unchanged and does not trigger finisher")
				resolve(game, 3, 1)
				check(game.state == Main.State.GAME_OVER and game.player.alive and not game.opponent.alive and game.elimination.active, "Lethal result and WANTED work in both modes and every arena")
				check(game.profile.stats == stats_before if local else game.profile.stats.wins == stats_before.wins + 1, "Arena does not alter Solo statistics or local isolation")
				game.restart_current_duel()
				check(game.match_arena == id and not game.elimination.active and game.state == Main.State.COUNTDOWN, "Rematch preserves location and cleans up finisher")
				game.show_menu()
				check(game.state == Main.State.MAIN_MENU and not game.arena.visible, "Return to menu works in every arena")
			menu.show_page("play")
			profile_text = FileAccess.get_file_as_string(PROFILE_PATH)
		check(preview_hashes.size() == 5 and scene_hashes.size() == 5, "All five previews and backgrounds are distinct")
		if "--capture" in OS.get_cmdline_user_args():
			sheet.save_png("res://.godot/arena_contact_sheet.png")
		select_arena(menu, Arenas.RANDOM_ID)
		check(menu.arena_preview.arena_id == Arenas.RANDOM_ID, "Random displays a preview collage rather than rolling a location")
		var rng := RandomNumberGenerator.new()
		rng.seed = 50301
		game.arena_rng.seed = 50301
		var seen := {}
		var bot_rng_before: int = game.bot.rng.state
		for i in range(30):
			game.start_local_duel()
			var expected: String = Arenas.choose(Arenas.RANDOM_ID, rng)
			check(game.match_arena == expected, "Random uses isolated arena RNG exactly once at new duel start")
			seen[game.match_arena] = true
			var rng_state: int = game.arena_rng.state
			game.restart_current_duel()
			check(game.match_arena == expected and game.arena_rng.state == rng_state, "Random rematch never rerolls")
		check(seen.size() == 5 and game.bot.rng.state == bot_rng_before, "Random reaches all locations without touching bot RNG")
		var concrete: String = game.match_arena
		game.settings.set_arena("ghost_town")
		game._apply_profile()
		game._process(0.0)
		check(game.match_arena == concrete and game.arena.arena_id == concrete, "Preference changes do not replace an active location")
		game.show_menu()
		menu.show_page("play")
		select_arena(menu, "ghost_town")
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		check(config.get_value("unrelated", "keep") == "preserved" and game.settings.difficulty == "hard" and is_equal_approx(game.settings.sfx_volume, 0.64), "Arena saves preserve unrelated settings and difficulty")
		if "--capture" in OS.get_cmdline_user_args():
			await settle()
			root.get_texture().get_image().save_png("res://.godot/arena_selection.png")
		game.settings.fullscreen = true
		check(game.settings.apply_display(), "Native fullscreen mode applies with arena selection open")
		await settle()
		check(root.get_visible_rect().encloses(menu.arena_preview.get_global_rect()) and root.get_visible_rect().encloses(menu.buttons.local.get_global_rect()), "Fullscreen keeps arena preview and launch controls visible")
		await click(menu.buttons.local)
		check(game.match_arena == "ghost_town" and game.mode == Main.GameMode.LOCAL_2P, "Scaled Local button launches selected arena")
		check(root.get_visible_rect().encloses(game.hud.cards[0].get_global_rect()), "Gameplay HUD remains visible over selected arena in fullscreen")
		var scale: Vector2 = game.arena.get_global_transform_with_canvas().get_scale()
		check(is_equal_approx(scale.x, scale.y), "Arena retains uniform canvas scaling")
		game.settings.fullscreen = false
		game.settings.apply_display()
		await settle()
		check(not game.settings.is_fullscreen(), "Windowed mode restores after arena fullscreen check")
	game.queue_free()
	await process_frame
	print("Arena%s: %d checks, %d failures" % [" random restart" if verify_random else (" restart" if verify else " integration"), checks, failures])
	quit(1 if failures else 0)
