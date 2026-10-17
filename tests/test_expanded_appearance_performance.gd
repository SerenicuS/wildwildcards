extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Main.new()
	game.profile.path = "res://.godot/expanded_performance.json"
	game.settings.path = "res://.godot/expanded_performance.cfg"
	root.add_child(game)
	game.set_process(false)
	game.start_local_duel()
	game.state = Main.State.PLAYING
	var nodes: int = get_node_count()
	var measurements := {}
	for style in ["frontier", "duster", "poncho", "waistcoat", "outlaw"]:
		game.arena.set_player_appearance(Looks.sanitize({"hat": "cattleman", "outfit_style": style, "accessory": "gloves", "revolver_model": "python", "revolver_finish": "gold", "revolver_grip": "engraved"}))
		game.arena.set_opponent_appearance(Looks.sanitize({"hat": "cavalry", "outfit_style": style, "accessory": "belt", "revolver_model": "schofield", "revolver_finish": "silver"}))
		var armed := {"ammo": 1, "shields": 0, "alive": true}
		game.arena.reveal(DuelRules.resolve(armed, armed, 2, 3))
		for i in range(12):
			await process_frame
			await RenderingServer.frame_post_draw
		var start := Time.get_ticks_usec()
		var calls := 0.0
		for i in range(90):
			game.arena.effect_age = fmod(i * 0.016, 0.19)
			await process_frame
			await RenderingServer.frame_post_draw
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var elapsed := float(Time.get_ticks_usec() - start) / 90000.0
		measurements[style] = {"frame_ms": snappedf(elapsed, 0.01), "draw_calls": snappedf(calls / 90.0, 0.1)}
		if get_node_count() != nodes:
			failures += 1
			push_error("Cosmetic rendering changed scene node count")
	# With the production 60 FPS cap, expanded outfits should stay near baseline.
	for style in measurements:
		if measurements[style].frame_ms > maxf(33.4, measurements.frontier.frame_ms * 1.75):
			failures += 1
			push_error("Expanded outfit exceeded baseline frame budget: " + style)
	print("Expanded appearance performance: 10 checks, %d failures; %s" % [failures, JSON.stringify(measurements)])
	game.queue_free()
	await process_frame
	quit(int(failures > 0))
