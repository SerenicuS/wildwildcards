extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const TEST_PATH := "res://.godot/revolver_test.json"
var checks: int = 0
var failures: int = 0

class UnwritableProfile extends Profile:
	func save_profile(_refresh_backup: bool = false) -> Error:
		return ERR_FILE_CANT_WRITE

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

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func choose(menu: Control, key: String, id: String) -> void:
	var picker: OptionButton = menu.revolver_selectors[key]
	for index in picker.item_count:
		if picker.get_item_metadata(index) == id:
			picker.select(index)
			picker.item_selected.emit(index)
			return
	check(false, "Missing picker ID: " + id)

func select_target(menu: Control, index: int) -> void:
	menu.revolver_target_selector.select(index)
	menu.revolver_target_selector.item_selected.emit(index)

func persistence_checks() -> void:
	var path := "res://.godot/revolver_migration.json"
	var old := {"version": 1, "display_name": "Mara", "appearance": {"hat": "gambler", "outfit": "violet", "accessory": "badge"},
		"equipped_elimination_effect": "wanted_eliminated", "stats": {"matches_played": 7, "wins": 4, "losses": 3}, "reset_revision": 4}
	write_json(path, old)
	write_json(path + ".bak", old)
	var profile := Profile.new()
	profile.path = path
	profile.load_profile()
	check(Revolver.sanitize(profile.appearance) == Revolver.defaults(), "Version 1 gets safe revolver defaults")
	check(profile.display_name == "Mara" and profile.stats.wins == 4 and profile.appearance.hat == "gambler", "Migration preserves identity, stats and look")
	check(profile.equipped_elimination_effect == "wanted_eliminated" and profile._reset_revision == 4, "Migration preserves finisher and confirmed-reset revision")
	var equipped: Dictionary = profile.appearance.duplicate()
	equipped.merge({"revolver_model": "python", "revolver_finish": "gold", "revolver_grip": "engraved"}, true)
	check(profile.equip(equipped) == OK, "Migrated profile saves normally")
	var legacy := Profile.new()
	legacy.path = "res://.godot/revolver_legacy_equip.json"
	legacy.appearance = equipped.duplicate()
	check(legacy.equip({"hat": "wide_brim"}) == OK and Revolver.sanitize(legacy.appearance) == Revolver.sanitize(equipped), "Legacy character-only equip preserves the selected revolver")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(disk.version == Profile.VERSION and disk.revolver_model == "python" and disk.revolver_finish == "gold" and disk.revolver_grip == "engraved", "Current schema retains all three explicit revolver IDs")
	check(not disk.appearance.has("revolver_model"), "Save has one authoritative location for revolver IDs")
	profile.set_display_name("Mara") # Rotate a readable version-2 backup.
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("not valid json")
	broken.close()
	var recovered := Profile.new()
	recovered.path = path
	recovered.load_profile()
	check(recovered.appearance == equipped and recovered.stats.wins == 4, "Backup recovery retains equipped revolver and statistics")
	check(recovered.reset_stats() == OK and recovered.appearance == equipped, "Statistics reset preserves all revolver cosmetics")
	var reloaded := Profile.new()
	reloaded.path = path
	reloaded.load_profile()
	check(reloaded.stats.wins == 0 and reloaded.appearance == equipped, "Confirmed reset backup persists zero stats and equipped revolver")
	check(reloaded.reset_profile() == OK and reloaded.appearance == Looks.defaults(), "Full reset restores revolver defaults")
	old.reset_revision = 5
	write_json(path, {"version": 1, "reset_revision": 4, "stats": {"wins": 99}})
	write_json(path + ".bak", old)
	reloaded = Profile.new()
	reloaded.path = path
	reloaded.load_profile()
	check(reloaded._reset_revision == 5 and reloaded.stats.wins == 4, "New manager still prefers a newer confirmed reset in a version-1 backup")
	write_json(path, {"version": 2, "revolver_model": "unknown", "revolver_finish": 17, "revolver_grip": null})
	write_json(path + ".bak", {})
	reloaded = Profile.new()
	reloaded.path = path
	reloaded.load_profile()
	check(Revolver.sanitize(reloaded.appearance) == Revolver.defaults(), "Malformed cosmetic IDs safely use defaults")
	var failing := UnwritableProfile.new()
	check(failing.equip_loadout(equipped, "wanted_eliminated") != OK and failing.appearance == Looks.defaults() and failing.equipped_elimination_effect == "wanted_eliminated", "Failed save rolls back complete look and finisher")

func run() -> void:
	var verify := "--verify" in OS.get_cmdline_user_args()
	if not verify:
		persistence_checks()
		var fresh := Profile.new()
		fresh.path = TEST_PATH
		fresh.appearance.hat = "gambler"
		fresh.appearance.outfit = "violet"
		fresh.appearance.accessory = "badge"
		fresh.equipped_elimination_effect = "wanted_eliminated"
		fresh.save_profile(true)
	var game := Main.new()
	game.profile.path = TEST_PATH
	game.settings.path = "res://.godot/revolver_settings.cfg"
	root.add_child(game)
	game.set_process(false)
	var menu: Control = game.main_menu
	menu.show_page("customize")
	await click(menu.buttons.revolver)
	check(menu.page == "revolver" and menu.revolver_selectors.size() == 3, "Customize exposes all three revolver selectors")
	if verify:
		check(game.profile.appearance.revolver_model == "schofield" and game.profile.appearance.revolver_finish == "silver" and game.profile.appearance.revolver_grip == "ivory", "Revolver survives process restart")
		check(menu.buttons.equip.disabled, "Equipped indicator survives restart")
		check(menu.local_revolvers[0].is_empty() and menu.local_revolvers[1] == Revolver.defaults(), "Guest session loadouts do not persist or overwrite primary profile")
	else:
		var saved_text := FileAccess.get_file_as_string(TEST_PATH)
		var hashes := {}
		var atlas := Image.create(380 * 4, 115 * 16, false, Image.FORMAT_RGBA8)
		var model_images := Image.create(380 * 2, 115 * 2, false, Image.FORMAT_RGBA8)
		var combo: int = 0
		for model in Revolver.MODELS:
			choose(menu, "revolver_model", model)
			for finish in Revolver.FINISHES:
				choose(menu, "revolver_finish", finish)
				for grip in Revolver.GRIPS:
					choose(menu, "revolver_grip", grip)
					check(menu.revolver_preview.configuration == Revolver.sanitize(menu.draft_appearance), "Every selector immediately updates live preview")
					await settle()
					var rect: Rect2 = menu.revolver_preview.get_global_rect()
					var pixels := root.get_texture().get_image().get_region(Rect2i(rect))
					hashes[pixels.get_data().hex_encode().sha256_text()] = true
					atlas.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i((combo % 4) * 380, (combo / 4) * 115))
					if finish == "iron" and grip == "walnut":
						var i: int = Revolver.MODELS.keys().find(model)
						model_images.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i((i % 2) * 380, (i / 2) * 115))
					combo += 1
		check(combo == 64 and hashes.size() == 64, "All 64 combinations render distinctly")
		if "--capture" in OS.get_cmdline_user_args():
			atlas.save_png("res://.godot/revolver_combinations.png")
			model_images.save_png("res://.godot/revolver_models.png")
		check(FileAccess.get_file_as_string(TEST_PATH) == saved_text, "Trying all combinations writes nothing")
		await click(menu.buttons.back)
		menu.show_page("customize")
		await click(menu.buttons.revolver)
		check(menu.draft_appearance == game.profile.appearance, "Cancel discards unconfirmed revolver changes")
		choose(menu, "revolver_model", "schofield")
		choose(menu, "revolver_finish", "silver")
		choose(menu, "revolver_grip", "ivory")
		await click(menu.buttons.gunslinger)
		check(menu.draft_appearance.revolver_model == "schofield", "Switching Customize sections preserves draft")
		await click(menu.buttons.revolver)
		await click(menu.buttons.equip)
		check(game.profile.appearance.revolver_model == "schofield" and menu.buttons.equip.disabled, "Equip saves revolver and updates equipped indicator")
		check(game.profile.appearance.hat == "gambler" and game.profile.appearance.outfit == "violet" and game.profile.appearance.accessory == "badge" and game.profile.equipped_elimination_effect == "wanted_eliminated", "Weapon equip preserves character and elimination cosmetics")
		if "--capture" in OS.get_cmdline_user_args():
			await settle()
			root.get_texture().get_image().save_png("res://.godot/revolver_customize.png")
		saved_text = FileAccess.get_file_as_string(TEST_PATH)
		select_target(menu, 1)
		choose(menu, "revolver_model", "python")
		choose(menu, "revolver_finish", "blued")
		choose(menu, "revolver_grip", "ebony")
		await click(menu.buttons.equip)
		select_target(menu, 2)
		choose(menu, "revolver_model", "cobra")
		choose(menu, "revolver_finish", "gold")
		choose(menu, "revolver_grip", "engraved")
		await click(menu.buttons.equip)
		check(FileAccess.get_file_as_string(TEST_PATH) == saved_text, "Equipping either local loadout never writes primary profile")
		check(menu.local_revolvers[0].revolver_model == "python" and menu.local_revolvers[1].revolver_model == "cobra", "Local players keep separate session configurations")
		choose(menu, "revolver_model", "peacemaker")
		await click(menu.buttons.back)
		menu.show_page("customize")
		await click(menu.buttons.revolver)
		select_target(menu, 2)
		check(menu.draft_appearance.revolver_model == "cobra" and FileAccess.get_file_as_string(TEST_PATH) == saved_text, "Cancel also discards unconfirmed local-player changes")
		await click(menu.buttons.gunslinger)
		check(menu.draft_appearance == game.profile.appearance, "Session target cannot leak into saved character Equip")
		var before: Dictionary = game.profile.stats.duplicate()
		game.start_local_duel()
		check(game.arena.player_appearance.revolver_model == "python" and game.arena.opponent_appearance.revolver_model == "cobra", "Both local fighters display their separate equipped models")
		check(Revolver.sanitize(game.arena.player_appearance) == menu.local_revolvers[0] and Revolver.sanitize(game.arena.opponent_appearance) == menu.local_revolvers[1], "Both local fighters retain their own finishes and grips")
		game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
		game._process(0.0)
		var duration: int = game.turn_usec
		game.submit_action(1)
		game.submit_action_p2(1)
		var boundary: int = game.deadline
		game.advance_to(boundary)
		check(game.player.ammo == 1 and game.opponent.ammo == 1 and game.deadline == boundary + duration, "Cosmetic loadouts preserve reload gain and turn deadline")
		game.submit_action(3)
		game.submit_action_p2(3)
		game.advance_to(game.deadline)
		check(game.player.alive and game.opponent.alive and game.player.ammo == 0 and game.opponent.ammo == 0 and not game.elimination.active, "Local different guns preserve simultaneous shootout rules")
		check(game.profile.stats == before, "Local cosmetics and gameplay do not change lifetime statistics")
		game.arena.active = false
		game.arena.clock = 0.0
		for model in Revolver.MODELS:
			for side in range(2):
				var app := Looks.defaults()
				app.revolver_model = model
				if side == 0:
					game.arena.set_player_appearance(app)
				else:
					game.arena.set_opponent_appearance(app)
				var armed := {"ammo": 1, "shields": 0, "alive": true}
				game.arena.reveal(DuelRules.resolve(armed, armed, 3, 3))
				game.arena.effect_age = 0.0
				var pose: Dictionary = game.arena.action_pose(side)
				var expected: Vector2 = game.arena._world_point(side, pose.hand + Revolver.muzzle(app).rotated(pose.angle))
				check(game.arena.muzzle_world(side).is_equal_approx(expected) and game.arena.bullet_trail(side).head.is_equal_approx(expected), "Trail begins at model muzzle for both facings")
				await settle()
				var flash_center: Vector2 = game.arena._world_point(side, pose.hand + (Revolver.muzzle(app) + Vector2(5, 0)).rotated(pose.angle))
				var pixel: Color = root.get_texture().get_image().get_pixelv(Vector2i(flash_center))
				check(pixel.r > 0.9 and pixel.g > 0.8 and pixel.b > 0.6, "Rendered muzzle flash aligns with each model and facing")
		game.restart_current_duel()
		check(game.arena.player_appearance.revolver_model == "python" and game.arena.opponent_appearance.revolver_model == "cobra", "Rematch restores both session loadouts")
		game.state = Main.State.PLAYING
		game.turn = 1
		game.player.ammo = 1
		game.selected = 3
		game.selected_p2 = 1
		game.resolve_turn()
		check(game.elimination.active and game.elimination.portrait.player_appearance.revolver_model == "cobra", "WANTED elimination portrait uses defeated local player's revolver")
		game.elimination.skip()
		game.restart_current_duel()
		game.state = Main.State.PLAYING
		game.turn = 1
		game.opponent.ammo = 1
		game.selected = 1
		game.selected_p2 = 3
		game.resolve_turn()
		check(game.elimination.active and game.elimination.portrait.player_appearance.revolver_model == "python", "Player 2 victory shows Player 1's actual revolver in the existing finisher")
		game.elimination.skip()
		check(game.profile.stats == before, "Both local victories preserve lifetime statistics")
		game.show_menu()
		game.start_duel()
		check(game.arena.player_appearance.revolver_model == "schofield" and game.arena.opponent_appearance.get("revolver_model") == "peacemaker", "Solo uses saved gun and keeps bot default gun")
		game.state = Main.State.PLAYING
		game.turn = 1
		game.player.ammo = 1
		game.selected = 3
		game.bot_action = 1
		game.resolve_turn()
		check(game.elimination.active and game.profile.stats.matches_played == before.matches_played + 1, "Solo lethal result and WANTED effect work with cosmetic guns")
		game.elimination.skip()
		game.resolve_turn()
		check(game.profile.stats.matches_played == before.matches_played + 1, "No duplicate solo result recording")
	game.queue_free()
	await process_frame
	print("Revolver%s: %d checks, %d failures" % [" restart" if verify else " integration", checks, failures])
	quit(1 if failures else 0)
