extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Effects = preload("res://scripts/EliminationEffects.gd")
var checks := 0
var failures := 0
var completions := 0

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
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
	await settle()

func choose(menu: Control, id: String) -> void:
	for index in menu.elimination_selector.item_count:
		if menu.elimination_selector.get_item_metadata(index) == id:
			menu.elimination_selector.select(index)
			menu.elimination_selector.item_selected.emit(index)
			return
	check(false, "Missing finisher option " + id)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func lethal(game: Node, p1: bool = true) -> void:
	game.state = Main.State.PLAYING
	game.turn = 1
	game.player.ammo = 1 if p1 else 0
	game.opponent.ammo = 0 if p1 else 1
	game.selected = 3 if p1 else 1
	game.selected_p2 = 1 if p1 else 3
	game.bot_action = 1 if p1 else 3
	game.resolve_turn()

func capture(id: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("res://.godot/finisher_%s.png" % id)

func run() -> void:
	var fresh := Profile.new()
	fresh.path = "res://.godot/finishers_ui.json"
	fresh.display_name = "Mara Vale"
	fresh.appearance.hat = "cavalry"
	fresh.appearance.outfit_style = "poncho"
	fresh.appearance.revolver_model = "python"
	fresh.save_profile(true)
	var game := Main.new()
	game.profile.path = fresh.path
	game.settings.path = "res://.godot/finishers_ui.cfg"
	root.add_child(game)
	game.set_process(false)
	await settle()
	var menu: Control = game.main_menu
	var fx: CanvasLayer = game.elimination
	fx.finished.connect(func(): completions += 1)
	menu.show_page("customize")
	await settle()
	for id in Effects.LABELS:
		choose(menu, id)
		var before: Dictionary = game.profile.stats.duplicate()
		await click(menu.buttons.preview_effect)
		check(fx.active and fx.previewing and game.state == Main.State.MAIN_MENU, "Each finisher previews without entering gameplay")
		check(fx.winner.name == "Mara Vale" and fx.winner.appearance == menu.draft_appearance, "Preview receives winner identity and complete draft cosmetics")
		await create_timer(0.65 if id != "classic" else 0.3).timeout
		if id in ["dead_mans_hand", "high_noon", "smoke_mirrors"]:
			check(fx.cinematic.winner_label.text == "Mara Vale", "Cinematic reveals the winner, not defeated name")
			await capture(id)
		if id == "dead_mans_hand":
			check(fx.cinematic.CARD_RANKS == ["A", "A", "8", "8"] and fx.cinematic.CARD_SUITS == ["spades", "clubs", "spades", "clubs"], "Dead Man's Hand contains both black aces and both black eights")
		if id == "high_noon":
			check(fx.cinematic.portrait.player_appearance == menu.draft_appearance, "High Noon silhouette includes equipped clothing and revolver")
		fx.skip_button.pressed.emit()
		fx.skip()
		check(not fx.active and completions == 0 and game.profile.stats == before and game.profile.equipped_elimination_effect == "wanted_eliminated", "Preview and repeated skip do not save, record, or emit results")
	for child in menu.content.get_children():
		if child is Control:
			check(child.get_global_rect().end.y <= 635, "Expanded finisher selector fits existing menu")
	await capture("customize")
	# Natural completion for every cinematic uses the existing post-result callback.
	for id in Effects.RANDOM_POOL:
		game.profile.equip_loadout(game.profile.appearance, id)
		game.start_duel()
		var wins_before: int = game.profile.stats.wins
		var completed_before := completions
		lethal(game)
		check(game.state == Main.State.GAME_OVER and fx.active and fx.effect_id == id and not game.hud.overlay.visible, "Confirmed Solo victory starts the selected finisher before results")
		check(fx.winner.name == "Mara Vale" and fx.target.name == "Copper Jack", "Winner and defeated descriptors are distinct")
		check(game.profile.stats.wins == wins_before + 1 and not game.controller.accepting and game.player.ammo == 0, "Authoritative win, ammunition and input lock commit before animation")
		game.resolve_turn()
		check(game.profile.stats.wins == wins_before + 1, "Repeated lethal callback cannot duplicate a win")
		await create_timer(1.55).timeout
		check(not fx.active and game.hud.overlay.visible and completions == completed_before + 1, "Every cinematic naturally completes once and opens results")
		fx.skip()
		check(completions == completed_before + 1 and game.profile.stats.wins == wins_before + 1, "Late skip cannot duplicate completion or records")
	for id in ["dead_mans_hand", "high_noon", "smoke_mirrors"]:
		game.profile.equip_loadout(game.profile.appearance, id)
		game.start_duel()
		lethal(game)
		var recorded: Dictionary = game.profile.stats.duplicate()
		key(KEY_SPACE)
		check(not fx.active and game.hud.overlay.visible and game.profile.stats == recorded, "Keyboard skip is safe for each new animation")
		game.start_duel()
		lethal(game)
		await click(fx.skip_button)
		check(not fx.active and game.hud.overlay.visible, "Visible Skip Finisher action works with a mouse")
		game.start_duel()
		lethal(game)
		key(KEY_R)
		check(game.state == Main.State.COUNTDOWN and not fx.active, "R cancels each cinematic and starts a rematch")
		for actions in [[3, 3, 1, 1], [3, 2, 1, 0], [3, 1, 0, 0]]:
			game.start_duel()
			game.state = Main.State.PLAYING
			game.turn = 1
			game.selected = actions[0]
			game.bot_action = actions[1]
			game.player.ammo = actions[2]
			game.opponent.ammo = actions[3]
			game.resolve_turn()
			check(game.player.alive and game.opponent.alive and not fx.active, "Shootouts, shield blocks and empty shots never trigger a cinematic")
	# Random is rerolled per victory by its own RNG, leaving preference untouched.
	game.profile.equip_loadout(game.profile.appearance, "random")
	fx.rng.seed = 50505
	var seen := {}
	for i in range(16):
		game.start_duel()
		lethal(game)
		seen[fx.effect_id] = true
		check(fx.effect_id in Effects.RANDOM_POOL and game.profile.equipped_elimination_effect == "random", "Random samples a concrete effect without saving it")
		fx.skip()
	check(seen.size() == 4, "Repeated victories can show every Random finisher")
	var bot_rng_state: int = game.bot.rng.state
	for i in range(8):
		fx.play("random", {"name": "Preview"}, true)
		fx.skip()
	check(game.bot.rng.state == bot_rng_state, "Random finisher previews cannot consume bot decision RNG")
	game.show_menu()
	# Local P1 and P2 selection flows are session-only and follow their winner.
	var saved_effect: String = game.profile.equipped_elimination_effect
	for player in [1, 2]:
		menu.show_page("customize")
		menu.show_page("clothing", true)
		var target: OptionButton = menu.content.get_child(1)
		target.select(player)
		target.item_selected.emit(player)
		menu.show_page("customize", true)
		choose(menu, "high_noon" if player == 1 else "smoke_mirrors")
		await click(menu.buttons.equip)
		check(game.profile.equipped_elimination_effect == saved_effect, "Local finisher equip never overwrites the primary save")
		await click(menu.buttons.preview_effect)
		check(fx.winner.name == "Player %d" % player, "Local preview uses selected player's identity")
		fx.skip()
	for p1 in [true, false]:
		game.start_local_duel()
		var before := game.profile.stats.duplicate()
		lethal(game, p1)
		check(fx.effect_id == ("high_noon" if p1 else "smoke_mirrors") and fx.winner.name == ("Player 1" if p1 else "Player 2"), "Local winner uses their own selected finisher and name")
		fx.skip()
		check(game.profile.stats == before and game.hud.overlay.visible, "Local result remains separate from Solo statistics")
	game.show_menu()
	# Gauntlet records once before presentation, then waits for both stages.
	game.profile.equip_loadout(game.profile.appearance, "dead_mans_hand")
	game.start_gauntlet()
	for victory in range(1, 4):
		lethal(game)
		check(game.gauntlet.streak == victory and game.state == Main.State.GAME_OVER and fx.active, "Gauntlet records once and waits for finisher completion")
		game.resolve_turn()
		if victory == 1:
			await create_timer(1.55).timeout
		else:
			fx.skip()
		var opponent_before: Dictionary = game.gauntlet.opponent.duplicate(true)
		fx.skip()
		check(game.state == Main.State.AWAITING_CONTINUE and game.gauntlet.streak == victory and game.gauntlet.opponent == opponent_before, "Skip starts only persistent victory results")
		game._process(0.0)
		check(game.gauntlet.duel_number == victory, "Next opponent does not start before Continue")
		game.hud.primary.pressed.emit()
		check(game.gauntlet.duel_number == victory + 1 and game.state == Main.State.COUNTDOWN and not fx.active, "Explicit Continue action advances exactly once")
	game.show_menu()
	game._confirm_gauntlet_exit()
	# Rematch/menu cancellation cannot leave delayed cinematic callbacks alive.
	game.start_duel()
	lethal(game)
	var before := game.profile.stats.duplicate()
	game.start_duel()
	await create_timer(1.6).timeout
	check(not fx.active and not game.hud.overlay.visible and game.state == Main.State.COUNTDOWN and game.profile.stats == before, "Rapid rematch cancels every old tween/result callback")
	lethal(game)
	game.show_menu()
	await create_timer(1.6).timeout
	check(game.state == Main.State.MAIN_MENU and not fx.active and not game.hud.overlay.visible, "Menu navigation cancels pending animation completion")
	game.queue_free()
	await process_frame
	print("Expanded finishers integration: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
