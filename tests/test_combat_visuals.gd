extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func state(ammo: int = 0, shields: int = 0) -> Dictionary:
	return {"ammo": ammo, "shields": shields, "alive": true}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Main.new()
	game.profile.path = "res://.godot/test_visuals_profile.json"
	root.add_child(game)
	game.set_process(false)
	game.start_duel()
	game.state = Main.State.PLAYING
	game.deadline = Time.get_ticks_usec() + 1000000
	game.begin_turn()
	game.arena.active = false
	var arena: DuelArena = game.arena
	# Use the real manager resolution route for every action on both sides.
	var cases := [["reload", 1, 1, 0, 0], ["shield", 2, 2, 0, 0],
		["empty", 3, 3, 0, 0], ["shootout", 3, 3, 1, 1],
		["block_right", 3, 2, 1, 0], ["block_left", 2, 3, 0, 1],
		["shoot_left", 3, 0, 1, 0], ["shoot_right", 0, 3, 0, 1]]
	for entry in cases:
		game.player.apply(state(entry[3]))
		game.opponent.apply(state(entry[4]))
		game.selected = entry[1]
		game.bot_action = entry[2]
		game.state = Main.State.PLAYING
		game.resolve_turn()
		game.hud.hide_overlay()
		var resolved_player: Dictionary = game.player.snapshot()
		var resolved_bot: Dictionary = game.opponent.snapshot()
		check(arena.effect_age == 0.0, "Resolved turn immediately starts visuals: " + entry[0])
		for age in [0.0, 0.055, 0.13, 0.28, 0.75]:
			arena.effect_age = age
			for i in range(2):
				var pose: Dictionary = arena.action_pose(i)
				var trail: Dictionary = arena.bullet_trail(i)
				if not arena.fired[i]:
					check(not pose.flash and trail.is_empty(), "Unarmed action never creates flash or bullet")
				if age >= 0.75:
					check(trail.is_empty() and not pose.flash and is_zero_approx(pose.reload) and
						is_zero_approx(pose.shield) and pose.hand.is_equal_approx(Vector2(48, -95)), "Action settles within one-second cycle")
			arena.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var capture_age: float = 0.28 if entry[0] == "reload" else (0.13 if entry[0].begins_with("block") else 0.055)
			if "--capture" in OS.get_cmdline_user_args() and age == capture_age:
				root.get_texture().get_image().save_png("res://.godot/combat_%s.png" % entry[0])
		check(game.player.snapshot() == resolved_player and game.opponent.snapshot() == resolved_bot,
			"Rendering cannot change combat results")
	# Specific geometry / pose checks across both directions.
	for side in range(2):
		var a: int = 3 if side == 0 else 2
		var b: int = 2 if side == 0 else 3
		arena.reveal(DuelRules.resolve(state(1), state(1), a, b))
		arena.effect_age = 0.055
		var trail := arena.bullet_trail(side)
		check(not trail.is_empty() and trail.head.distance_to(trail.tail) <= 66, "Short moving bullet trail")
		check((trail.head.x > trail.tail.x) == (side == 0), "Bullet travels toward opponent")
		check(is_equal_approx(trail.end.x, 853.0 if side == 0 else 427.0), "Blocked bullet ends at shield")
		check(arena.action_pose(side).hand.x < 48, "Armed shot recoils")
		check(arena.action_pose(1 - side).shield > 0.0, "Defender shield visible")
		arena.reveal(DuelRules.resolve(state(), state(), 3, 3))
		arena.effect_age = 0.08
		check(arena.action_pose(side).hand.x > 48 and not arena.action_pose(side).flash,
			"Empty shot has aim reaction without muzzle flash")
		arena.reveal(DuelRules.resolve(state(), state(), 1, 1))
		arena.effect_age = 0.28
		check(arena.action_pose(side).reload > 0.9 and arena.action_pose(side).angle > 0.5,
			"Reload moves revolver and cylinder on either side")
	var result: Dictionary = DuelRules.resolve(state(1), state(1), 3, 3)
	var unchanged: Dictionary = result.duplicate(true)
	arena.reveal(result)
	check(arena.action_pose(0).flash and arena.action_pose(1).flash and
		not arena.bullet_trail(0).is_empty() and not arena.bullet_trail(1).is_empty(), "Both loaded shots start together")
	arena.effect_age = 0.1
	check(arena.bullet_trail(0).head.is_equal_approx(arena.bullet_trail(1).head), "Shootout trails meet in center")
	arena._process(0.1)
	check(result == unchanged, "Visual snapshot does not mutate resolver data")
	arena.reveal(DuelRules.resolve(state(0, 3), state(), 2, 0))
	check(is_zero_approx(arena.action_pose(0).shield), "Rejected fourth shield has no activation effect")
	game.player.reset()
	game.opponent.reset()
	game.state = Main.State.PLAYING
	game.deadline = Time.get_ticks_usec() + 1000000
	game.begin_turn()
	arena.reset()
	game.submit_action(3)
	check(arena.effect_age == 10.0 and arena.fired == [false, false], "Selecting a card never starts effects")
	game.show_menu()
	print("Combat visual tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
