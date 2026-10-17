extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Effects = preload("res://scripts/EliminationEffects.gd")
const TEST_PATH := "res://.godot/elimination_test.json"
var checks: int = 0
var failures: int = 0
var completions: int = 0

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

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func duel(game: Node, left_ammo: int, right_ammo: int, left: int, right: int) -> void:
	game.start_duel()
	game.state = Main.State.PLAYING
	game.turn = 1
	game.player.ammo = left_ammo
	game.opponent.ammo = right_ammo
	game.selected = left
	game.bot_action = right
	game.resolve_turn()

func run() -> void:
	var verify := "--verify" in OS.get_cmdline_user_args()
	if not verify:
		var fresh := Profile.new()
		fresh.path = TEST_PATH
		fresh.save_profile(true)
	var game := Main.new()
	game.profile.path = TEST_PATH
	game.settings.path = "res://.godot/elimination_settings.cfg"
	root.add_child(game)
	game.set_process(false)
	var fx: CanvasLayer = game.elimination
	fx.finished.connect(func(): completions += 1)
	var menu: Control = game.main_menu
	if verify:
		check(game.profile.equipped_elimination_effect == "wanted_eliminated", "Effect persists through process restart")
		menu.show_page("customize")
		check(menu.draft_effect == "wanted_eliminated" and menu.buttons.equip.disabled, "Restarted selector reflects equipped effect")
		check(game.profile.appearance.hat == "gambler", "Appearance saved atomically alongside effect")
	else:
		var unwritable := UnwritableProfile.new()
		var original: Dictionary = unwritable.appearance.duplicate()
		check(unwritable.equip_loadout({"hat": "gambler"}, "wanted_eliminated") != OK, "Failed equip reports save error")
		check(unwritable.appearance == original and unwritable.equipped_elimination_effect == "classic", "Failed save rolls back both appearance and effect")
		check(unwritable.equip_loadout(original, "invalid_effect") == ERR_INVALID_PARAMETER, "Unknown new effect cannot be equipped")
		check(Effects.resolve_id("future_effect") == "classic", "Future IDs safely fall back to Classic")
		duel(game, 1, 0, 3, 1)
		check(not fx.active and game.hud.overlay.visible, "Classic retains immediate result presentation")
		check(game.profile.stats.matches_played == 1, "Classic result counted once")
		game.show_menu()
		menu.show_page("customize")
		await settle()
		check(menu.elimination_selector.item_count == 2, "Two effect choices")
		menu.elimination_selector.select(1)
		menu.elimination_selector.item_selected.emit(1)
		menu.appearance_selectors.hat.select(2)
		menu.appearance_selectors.hat.item_selected.emit(2)
		check(game.profile.equipped_elimination_effect == "classic", "Draft does not equip automatically")
		var before: Dictionary = game.profile.stats.duplicate()
		await click(menu.buttons.preview_effect)
		check(fx.active and fx.previewing and game.state == Main.State.MAIN_MENU, "Preview launches without entering duel")
		check(fx.target.appearance.hat == "gambler", "Preview uses draft character appearance")
		await create_timer(0.50).timeout
		check(fx.stamp_count == 1, "Preview plays one stamp")
		var stamp_voice_seen := false
		for voice in game.audio.voices:
			if voice.stream == game.audio.SOUNDS.stamp:
				stamp_voice_seen = true
				check(is_equal_approx(voice.volume_db, -14.0 + game.audio.sfx_volume_db), "Stamp obeys existing sound-effects volume trim")
		check(stamp_voice_seen, "Stamp cue reaches the existing audio playback pool")
		if "--capture" in OS.get_cmdline_user_args():
			await settle()
			root.get_texture().get_image().save_png("res://.godot/elimination_preview.png")
		key(KEY_SPACE)
		check(not fx.active and completions == 0, "Key skips preview without emitting match completion")
		check(not fx.portrait.active and fx.tween == null, "Canceled preview leaves no character animation or tween running")
		check(game.profile.stats == before and not game.profile.is_match_active(), "Preview changes no statistics or match state")
		await click(menu.buttons.equip)
		check(game.profile.equipped_elimination_effect == "wanted_eliminated", "Equip saves chosen effect")
		check(menu.buttons.equip.disabled, "Equipped indicator refreshes")
		if "--capture" in OS.get_cmdline_user_args():
			await settle()
			root.get_texture().get_image().save_png("res://.godot/elimination_customize.png")
		var loaded := Profile.new()
		loaded.path = TEST_PATH
		loaded.load_profile()
		check(loaded.equipped_elimination_effect == "wanted_eliminated", "Saved effect reloads")
		check(loaded.appearance.hat == "gambler", "Appearance and effect persist together")
		duel(game, 1, 1, 3, 3)
		check(game.state == Main.State.PLAYING and not fx.active, "Shootout draw never triggers elimination")
		check(game.profile.stats.shootout_draws == before.shootout_draws + 1, "Shootout retains authoritative statistics")
		duel(game, 1, 0, 3, 2)
		check(not fx.active and game.opponent.alive, "Shield block never triggers elimination")
		duel(game, 0, 0, 3, 1)
		check(not fx.active and game.opponent.alive, "Empty shot never triggers elimination")
		duel(game, 0, 1, 1, 3)
		check(not fx.active and game.hud.overlay_title.text == "DEFEAT", "Bot victory always uses Classic")
		duel(game, 1, 0, 3, 1)
		check(fx.active and not fx.previewing and not game.hud.overlay.visible, "Player victory defers only result UI")
		check(game.state == Main.State.GAME_OVER and not game.controller.accepting, "Combat is already finished during cosmetic playback")
		check(fx.target.name == "Copper Jack" and fx.target.coat == Color("ec8b73"), "Correct defeated bot portrait and original coat")
		check(fx.portrait.player_appearance.hat == "classic", "Bot portrait does not inherit winner customization")
		check(game.audio.sting_voice.stream == game.audio.SOUNDS.victory, "Existing victory audio remains authoritative")
		before = game.profile.stats.duplicate()
		var count_before: int = fx.stamp_count
		game.resolve_turn()
		check(game.profile.stats == before and fx.stamp_count == count_before, "Repeated terminal callback cannot reprocess result")
		await create_timer(0.80).timeout
		check(fx.stamp_count == count_before + 1, "Real elimination stamps exactly once")
		check(game.audio.SOUNDS.stamp.get_length() < 0.25, "Stamp is a lightweight short sample")
		await create_timer(0.65).timeout
		check(not fx.active and game.hud.overlay.visible and completions == 1, "Animation completes and opens existing result UI within 1.5 seconds")
		check(game.profile.stats == before, "Effect completion never processes results again")
		duel(game, 1, 0, 3, 1)
		before = game.profile.stats.duplicate()
		count_before = fx.stamp_count
		key(KEY_SPACE)
		check(not fx.active and game.hud.overlay.visible, "Keyboard skip opens results immediately")
		check(game.profile.stats == before, "Skip preserves already recorded result")
		await create_timer(0.65).timeout
		check(fx.stamp_count == count_before, "Skip cancels pending stamp cue")
		duel(game, 1, 0, 3, 1)
		await click(fx.surface)
		check(not fx.active and game.hud.overlay.visible, "Mouse click skips effect")
		duel(game, 1, 0, 3, 1)
		key(KEY_R)
		check(game.state == Main.State.COUNTDOWN and not fx.active, "Rapid R rematch cancels cosmetics and starts normally")
		await create_timer(1.4).timeout
		check(not game.hud.overlay.visible and not fx.active, "No stale tween reopens old result after rematch")
		duel(game, 1, 0, 3, 1)
		game.show_menu()
		await create_timer(1.4).timeout
		check(game.state == Main.State.MAIN_MENU and not fx.active and not game.hud.overlay.visible, "Menu navigation cancels old effect callbacks")
		menu.show_page("customize")
		menu.elimination_selector.select(0)
		menu.elimination_selector.item_selected.emit(0)
		await click(menu.buttons.preview_effect)
		check(fx.active and fx.previewing and not fx.portrait.alive[0], "Classic preview demonstrates original defeated pose")
		key(KEY_SPACE)
		check(game.profile.equipped_elimination_effect == "wanted_eliminated", "Previewing Classic never changes equipped selection")
		for voice in game.audio.voices:
			check(not (voice.stream == game.audio.SOUNDS.stamp and voice.playing), "Canceled effect leaves no stamp playing")
	game.queue_free()
	await process_frame
	print("Elimination%s: %d checks, %d failures" % [" restart" if verify else " integration", checks, failures])
	quit(1 if failures else 0)
