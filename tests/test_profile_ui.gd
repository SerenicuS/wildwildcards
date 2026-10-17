extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
const TEST_PATH := "res://.godot/profile_ui_test.json"
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

func click(control: Control) -> void:
	await settle()
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func capture(name_value: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		root.get_texture().get_image().save_png("res://.godot/profile_%s.png" % name_value)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var verifying: bool = "--verify" in OS.get_cmdline_user_args()
	if not verifying:
		var initial := preload("res://scripts/ProfileManager.gd").new()
		initial.path = TEST_PATH
		initial.save_profile()
	var game = Main.new()
	game.settings.path = "res://.godot/profile_ui_settings.cfg"
	game.profile.path = TEST_PATH
	root.add_child(game)
	game.set_process(false)
	await settle()
	var menu = game.main_menu
	var equipped := {"hat": "gambler", "outfit": "rust", "accessory": "bandana"}
	if verifying:
		check(game.profile.display_name == "Mara Vale" and game.profile.appearance == Looks.sanitize(equipped), "Fresh process restores name and appearance")
		check(game.profile.stats.matches_played == 1 and game.profile.stats.wins == 1, "Fresh process restores lifetime stats")
		check(game.arena.player_appearance == Looks.sanitize(equipped), "Restored appearance wired into actual arena")
	else:
		await click(menu.buttons.profile)
		check(menu.name_edit.text == "Gunslinger", "Default name shown")
		await capture("default")
		menu.name_edit.text = "Mara Vale"
		await click(menu.buttons.save_name)
		check(game.profile.display_name == "Mara Vale" and game.hud.player_display_name == "Mara Vale", "Saved identity reaches game HUD")
		await click(menu.buttons.back)
		await click(menu.buttons.customize)
		check(menu.appearance_selectors.hat.item_count >= 3 and menu.appearance_selectors.outfit.item_count >= 4 and
			menu.appearance_selectors.accessory.item_count >= 3, "Required appearance options available")
		check(menu.buttons.equip.disabled, "Current appearance marked equipped")
		for key in equipped:
			var picker: OptionButton = menu.appearance_selectors[key]
			for i in range(picker.item_count):
				if picker.get_item_metadata(i) == Looks.sanitize(equipped)[key]:
					picker.select(i)
					picker.item_selected.emit(i)
		check(menu.character_preview.player_appearance == Looks.sanitize(equipped) and game.profile.appearance == Looks.defaults(), "Live preview changes without equipping")
		check(not menu.buttons.equip.disabled and menu.appearance_status.text.contains("not equipped"), "Pending appearance clearly marked")
		await capture("preview")
		await click(menu.buttons.back)
		await click(menu.buttons.customize)
		check(menu.draft_appearance == Looks.defaults(), "Back discards unconfirmed draft")
		menu.character_preview.active = false
		menu.character_preview.clock = 0.0
		for group in [["hat", Looks.HATS], ["outfit", Looks.OUTFITS], ["accessory", Looks.ACCESSORIES]]:
			var rendered := {}
			for choice in group[1]:
				var look := Looks.defaults()
				look[group[0]] = choice
				menu.character_preview.set_player_appearance(look)
				await settle()
				var image_data: Image = root.get_texture().get_image().get_region(Rect2i(797, 186, 145, 140))
				rendered[hash(image_data.get_data())] = true
			check(rendered.size() == group[1].size(), "Every option has distinct shared-renderer pixels: " + group[0])
		menu.character_preview.set_player_appearance(menu.draft_appearance)
		for key in equipped:
			var picker: OptionButton = menu.appearance_selectors[key]
			for i in range(picker.item_count):
				if picker.get_item_metadata(i) == Looks.sanitize(equipped)[key]:
					picker.select(i)
					picker.item_selected.emit(i)
		await click(menu.buttons.equip)
		check(game.profile.appearance == Looks.sanitize(equipped) and game.arena.player_appearance == Looks.sanitize(equipped) and menu.buttons.equip.disabled, "Equip persists and applies shared appearance")
		await capture("equipped")
		for control in menu.content.get_children():
			check(control.position.y + control.size.y + menu.content.position.y <= 635, "Customization fits existing menu panel")
		await click(menu.buttons.back)
		await click(menu.buttons.play)
		await click(menu.buttons.solo)
		game.intro_start = Time.get_ticks_usec() - 2800000
		game._process(0.0)
		game.arena.active = false
		game.arena.clock = 0.0
		game.arena.queue_redraw()
		await settle()
		var custom_image: Image = root.get_texture().get_image()
		await capture("gameplay")
		game.arena.set_player_appearance(Looks.defaults())
		await settle()
		var default_image: Image = root.get_texture().get_image()
		check(custom_image.get_pixel(350, 400) != default_image.get_pixel(350, 400), "Actual Solo Duel outfit pixels change")
		check(custom_image.get_region(Rect2i(300, 280, 150, 190)).get_data() != default_image.get_region(Rect2i(300, 280, 150, 190)).get_data(), "Gameplay appearance visibly differs")
		check(custom_image.get_region(Rect2i(880, 280, 150, 190)).get_data() == default_image.get_region(Rect2i(880, 280, 150, 190)).get_data(), "Player customization leaves bot artwork unchanged")
		game.arena.set_player_appearance(equipped)
		game.intro_start = Time.get_ticks_usec() - 2800000
		game._process(0.0)
		game.player.ammo = 1
		game.selected = DuelRules.Action.SHOOT
		game.bot_action = DuelRules.Action.RELOAD
		game.resolve_turn()
		check(game.profile.stats.matches_played == 1 and game.profile.stats.wins == 1 and game.profile.stats.successful_eliminations == 1, "Authoritative resolution records win once")
		game.resolve_turn()
		check(game.profile.stats.matches_played == 1, "Duplicate finish callback cannot add a match")
		game.show_menu()
		await click(menu.buttons.profile)
		check(game.profile.stats.matches_played == 1 and game.profile.display_name == "Mara Vale", "Return to menu retains identity/statistics")
		await capture("record")
		game.start_duel()
		check(game.profile.stats.matches_played == 1 and game.arena.player_appearance == Looks.sanitize(equipped), "Rematch preserves lifetime profile and appearance")
		game.show_menu()
	game.queue_free()
	await process_frame
	print("Profile UI%s tests: %d checks, %d failures" % [" restart" if verifying else "", checks, failures])
	quit(1 if failures else 0)
