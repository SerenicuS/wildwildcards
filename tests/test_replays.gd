extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const History = preload("res://scripts/MatchHistory.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const PATH := "res://.godot/replay_integration_profile.json"
var checks := 0
var failures := 0

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

func play(game: Node) -> void:
	game.intro_start = Time.get_ticks_usec() - Main.INTRO_USEC
	game._process(0.0)

func resolve(game: Node, left: int, right: int) -> void:
	game.selected = left
	game.selected_p2 = right
	game.bot_action = right
	game.advance_to(game.deadline)

func capture(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("res://.godot/replay_%s.png" % name)

func run() -> void:
	var verify := "--verify" in OS.get_cmdline_user_args()
	if not verify:
		var profile := Profile.new()
		profile.path = PATH
		profile.appearance.hat = "cavalry"
		profile.appearance.outfit_style = "poncho"
		profile.appearance.revolver_model = "python"
		profile.save_profile(true)
		var history := History.new()
		history.path = PATH.get_basename() + ".history.json"
		history.save_history()
		var settings := Settings.new()
		settings.path = "res://.godot/replay_integration.cfg"
		settings.difficulty = "hard"
		settings.preferred_arena = "ghost_town"
		settings.save_settings()
	var game := Main.new()
	game.profile.path = PATH
	game.settings.path = "res://.godot/replay_integration.cfg"
	root.add_child(game)
	game.set_process(false)
	await settle()
	var menu: Control = game.main_menu
	if verify:
		check(game.history.matches.size() == 4, "All completed Solo, local and Gauntlet matches survive process restart")
		check(game.history.runs.size() == 1 and game.history.runs.values()[0].streak == 1 and game.history.runs.values()[0].status == "defeat", "Run grouping and final streak survive restart")
		menu.show_page("history")
		check(menu.history_list.item_count == 4, "Restarted History screen displays retained matches")
	else:
		game.start_duel()
		play(game)
		resolve(game, 1, 1)
		resolve(game, 3, 3)
		check(game.history.matches.is_empty(), "Shootout is a turn, never a completed match")
		resolve(game, 3, 1)
		resolve(game, 2, 3)
		resolve(game, 2, 1)
		resolve(game, 2, 1)
		resolve(game, 2, 3)
		check(game.history.matches.size() == 1 and game.history.matches[0].total_turns == 7 and game.history.matches[0].winner == 1, "Authoritative Solo match recorded completely")
		game.resolve_turn()
		check(game.history.matches.size() == 1, "Duplicate terminal resolution cannot duplicate history")
		var solo: Dictionary = game.history.matches[0].duplicate(true)
		check(solo.turns[1].clash and solo.turns[2].empty_shots[0] and solo.turns[3].blocked[1], "Production recorder captures shootout, empty and blocked shots")
		check(solo.turns[6].selected[0] == 2 and solo.turns[6].actions[0] == 0, "Production recorder preserves fatigue-selected and effective actions")
		game.main_menu.local_finishers[0] = "smoke_mirrors"
		game.main_menu.local_appearances[1] = History.Looks.sanitize({"hat": "outlaw", "outfit": "dark_red", "outfit_style": "duster", "revolver_model": "cobra"})
		game.main_menu.local_revolvers[1].revolver_model = "cobra"
		game.start_local_duel()
		play(game)
		resolve(game, 1, 1)
		resolve(game, 3, 1)
		check(game.history.matches.size() == 2 and game.history.matches[0].mode == "local" and game.history.matches[0].actors[1].appearance.revolver_model == "cobra", "Local/offline result captures independent clothing and guns")
		var local: Dictionary = game.history.matches[0].duplicate(true)
		check(local.finisher == "smoke_mirrors" and local.actors[0].name == "Player 1" and local.actors[1].name == "Player 2", "Local winner finisher and both names captured")
		game.profile.equipped_elimination_effect = "random"
		game.start_gauntlet()
		play(game)
		resolve(game, 1, 1)
		resolve(game, 3, 1)
		check(game.history.matches.size() == 3 and game.history.matches[0].finisher == game.elimination.effect_id and game.history.matches[0].finisher != "random", "Random finisher stores the actual effect used, never rerolls in replay")
		game.elimination.skip()
		var run_id: String = game.gauntlet_run_id
		game._continue_gauntlet()
		play(game)
		resolve(game, 1, 1)
		resolve(game, 1, 3)
		check(game.history.matches.size() == 4 and game.history.matches[0].run_id == run_id and game.history.matches[1].run_id == run_id, "Individual Gauntlet duels group by one stable run ID")
		check(game.history.runs[run_id].streak == 1 and game.history.runs[run_id].ended_by == game.hud.opponent_display_name, "Run summary records final streak and defeating opponent")
		game.show_menu()
		game.history.flush_history()
		var stats: Dictionary = game.profile.stats.duplicate()
		var records: Dictionary = game.profile.gauntlet_records.duplicate()
		var live_player: Dictionary = game.player.snapshot()
		var live_opponent: Dictionary = game.opponent.snapshot()
		var profile_bytes := FileAccess.get_file_as_bytes(PATH)
		var history_bytes := FileAccess.get_file_as_bytes(game.history.path)
		await click(menu.buttons.history)
		check(menu.history_list.item_count == 4, "History newest-first list includes all completed modes")
		for child in menu.content.get_children():
			if child is Control: check(child.get_global_rect().end.y <= 635, "History controls fit established menu")
		menu.history_list.select(3)
		menu.history_list.item_selected.emit(3)
		await capture("history")
		await click(menu.buttons.replay)
		var viewer: CanvasLayer = game.replay_viewer
		viewer.set_process(false)
		check(viewer.record.id == solo.id and not menu.visible and game.state == Main.State.MAIN_MENU, "Replay uses independent viewer without entering live gameplay")
		check(viewer.arena.arena_id == solo.arena and viewer.arena.player_appearance == solo.actors[0].appearance, "Replay restores recorded arena and player cosmetics")
		var backgrounds := {}
		for arena_id in History.Arenas.ORDER:
			viewer.arena.set_arena_id(arena_id)
			await settle()
			check(viewer.arena.arena_id == arena_id, "Every existing arena loads in the isolated replay renderer")
			backgrounds[hash(root.get_texture().get_image().get_region(Rect2i(0, 180, 1280, 300)).get_data())] = true
		check(backgrounds.size() == History.Arenas.ORDER.size(), "All replay arena backgrounds remain visually distinct")
		viewer.arena.set_arena_id(solo.arena)
		await click(viewer.buttons.previous)
		check(viewer.index == -1 and viewer.state_label.text.contains("0 → 0"), "Previous reaches initial recorded state")
		await click(viewer.buttons.next)
		await click(viewer.buttons.next)
		check(viewer.index == 1 and viewer.arena.clash and viewer.arena.fired == solo.turns[1].fired, "Next replays original simultaneous shootout")
		for i in solo.turns.size():
			viewer.seek(i)
			check(viewer.arena.actions == solo.turns[i].actions and viewer.arena.alive == [solo.turns[i].after[0].alive, solo.turns[i].after[1].alive], "Every rendered turn uses recorded actions and actual alive state")
			check(viewer.state_label.text.contains("%d → %d" % [solo.turns[i].before[0].ammo, solo.turns[i].after[0].ammo]), "Replay ammo display follows recorded before/after snapshot")
		await capture("combat")
		for speed in [0.5, 1.0, 2.0]:
			viewer.seek(0)
			viewer.set_speed(speed)
			viewer.toggle_play()
			viewer._process(0.75 / speed)
			check(viewer.index == 0, "Speed does not advance before recorded turn duration")
			viewer._process(0.30 / speed)
			check(viewer.index == 1, "0.5x/1x/2x advance after scaled recorded duration")
			viewer.toggle_play()
			var age: float = viewer.arena.effect_age
			viewer._process(2.0)
			check(viewer.index == 1 and viewer.arena.effect_age == age, "Pause freezes timeline and action animation")
		await click(viewer.buttons.restart)
		check(viewer.index == -1 and not viewer.playing, "Restart resets replay without starting a match")
		await click(viewer.buttons.back)
		check(menu.visible and menu.page == "history", "Return restores History screen")
		# Play the saved local victory and its concrete finisher with independent audio.
		menu.history_list.select(2)
		menu.history_list.item_selected.emit(2)
		await click(menu.buttons.replay)
		viewer = game.replay_viewer
		viewer.set_process(false)
		check(viewer.arena.opponent_appearance.revolver_model == "cobra" and viewer.arena.opponent_appearance.outfit_style == "duster", "Replay restores separate mirrored opponent equipment")
		viewer.seek(1)
		viewer.toggle_play()
		viewer._process(1.1)
		check(viewer.finisher.active and viewer.finisher.effect_id == "smoke_mirrors" and viewer.finisher.winner.name == "Player 1", "Replay finisher uses recorded winner and saved concrete effect")
		viewer.finisher.skip()
		check(not viewer.playing and viewer._finisher_done, "Finisher completion ends only replay playback")
		viewer.restart()
		viewer.set_speed(2.0)
		viewer.set_process(true)
		viewer.toggle_play()
		await create_timer(2.3).timeout
		check(viewer.index == 1 and viewer._finisher_done and not viewer.playing and not viewer.finisher.active, "Real process playback at 2x naturally runs all turns and completes the recorded finisher")
		viewer.set_process(false)
		for id in History.Effects.RANDOM_POOL:
			viewer.record.finisher = id # Isolated viewer fixture, not the saved match.
			viewer.seek(1)
			viewer.toggle_play()
			viewer._process(1.1)
			check(viewer.finisher.active and viewer.finisher.effect_id == id, "Every existing finisher can render at replay end")
			if id == "wanted_eliminated":
				check(viewer.finisher.portrait.player_appearance == local.actors[1].appearance, "Replay WANTED portrait retains defeated cosmetics")
			viewer.finisher.skip()
		await click(viewer.buttons.back)
		menu.history_filter = 3
		menu.show_page("history")
		check(menu.history_list.item_count == 1, "Gauntlet filter groups the run once")
		menu.history_list.select(0)
		menu.history_list.item_selected.emit(0)
		check(menu.history_details.text.contains("Final streak: 1") and menu.history_details.text.contains("Defeated (retained):"), "Run summary exposes date, streak, defeated list and ending opponent")
		await capture("gauntlet")
		await click(menu.buttons.replay)
		check(menu.history_list.item_count == 2, "Run details expose both individual match replays")
		check(game.profile.stats == stats and game.profile.gauntlet_records == records and game.player.snapshot() == live_player and game.opponent.snapshot() == live_opponent, "All replay navigation, animation and finishers leave live state and statistics untouched")
		check(FileAccess.get_file_as_bytes(PATH) == profile_bytes and FileAccess.get_file_as_bytes(game.history.path) == history_bytes, "Playback never writes profile or history files")
	game.queue_free()
	await process_frame
	print("Replay%s integration: %d checks, %d failures" % [" restart" if verify else "", checks, failures])
	quit(int(failures > 0))
