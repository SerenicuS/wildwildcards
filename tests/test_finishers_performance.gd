extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Effects = preload("res://scripts/EliminationEffects.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Main.new()
	game.profile.path = "res://.godot/finisher_performance.json"
	game.settings.path = "res://.godot/finisher_performance.cfg"
	root.add_child(game)
	game.set_process(false)
	var fx: CanvasLayer = game.elimination
	var target := {"name": "Mara Vale", "appearance": game.profile.appearance.duplicate()}
	var measurements := {}
	for id in Effects.RANDOM_POOL:
		fx.play(id, target, true, target)
		fx.tween.pause()
		if id == "wanted_eliminated":
			fx.paper.modulate.a = 1.0
			fx.stamp.modulate.a = 1.0
			fx.stamp.scale = Vector2.ONE
		for i in range(8):
			await process_frame
			await RenderingServer.frame_post_draw
		var start := Time.get_ticks_usec()
		var calls := 0.0
		for i in range(60):
			if is_instance_valid(fx.cinematic):
				fx.cinematic.set_progress(0.15 + float(i) / 75.0)
			await process_frame
			await RenderingServer.frame_post_draw
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		measurements[id] = {"frame_ms": snappedf(float(Time.get_ticks_usec() - start) / 60000.0, 0.01), "draw_calls": snappedf(calls / 60.0, 0.1)}
		var count: int = get_node_count()
		for i in range(12):
			fx.play(id, target, true, target)
			fx.skip()
		check(get_node_count() == count, "Repeated same finisher creates no accumulated scene nodes")
		check(not fx.active and fx.tween == null and not fx.surface.visible, "Repeated skips leave no active playback")
	for id in measurements:
		check(measurements[id].frame_ms <= maxf(33.4, measurements.wanted_eliminated.frame_ms * 1.75), "Finisher remains close to existing WANTED frame budget")
	# Test window resizing using the unchanged logical canvas/stretch system.
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		fx.play("high_noon", target, true, target)
		await process_frame
		await process_frame
		check(fx.design.position.is_equal_approx((fx.surface.size - Vector2(1280, 720)) / 2.0), "Finisher remains centered at common 16:9 sizes")
		check(fx.skip_button.get_global_rect().intersects(fx.surface.get_global_rect()), "Skip action remains on screen after resize")
		fx.skip()
	print("Finisher performance/layout: %d checks, %d failures; %s" % [checks, failures, JSON.stringify(measurements)])
	game.queue_free()
	await process_frame
	quit(int(failures > 0))
