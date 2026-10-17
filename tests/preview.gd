# Optional visual smoke check: runs the real renderer, saves two screenshots.
extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.profile.path = "res://.godot/preview_profile.json"
	root.add_child(game)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_menu.png")
	game.start_duel()
	game.intro_start -= 2800000
	await process_frame
	await process_frame
	game.submit_action(DuelRules.Action.RELOAD)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_play.png")
	# Exercise every rendered effect, including death and the game-over overlay.
	for pair in [[1, 1], [3, 2], [3, 3], [3, 0]]:
		game.player.ammo = 2
		game.opponent.ammo = 2
		game.selected = pair[0]
		game.bot_action = pair[1]
		game.resolve_turn()
		await create_timer(0.24).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_result.png")
	print("Visual smoke check completed")
	quit()
