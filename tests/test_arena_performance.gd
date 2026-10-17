extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Arenas = preload("res://scripts/ArenaDefinitions.gd")
var checks: int = 0
var failures: int = 0
var background_draws: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Main.new()
	game.profile.path = "res://.godot/arena_performance_profile.json"
	game.settings.path = "res://.godot/arena_performance_settings.cfg"
	root.add_child(game)
	game.set_process(false)
	game.start_local_duel()
	game.state = Main.State.PLAYING
	game.hud.banner.text = ""
	game.arena.backdrop.draw.connect(func(): background_draws += 1)
	var nodes_before: int = get_node_count()
	var measurements := {}
	# Use the same production 60 FPS cap and native window for every location.
	# Samples include actors, HUD, recoil, shields and sparks on the real renderer.
	for id in [Arenas.DEFAULT_ID] + Arenas.ORDER.slice(0, 4):
		game.arena.set_arena_id(id)
		var armed := {"ammo": 1, "shields": 0, "alive": true}
		game.arena.reveal(DuelRules.resolve(armed, armed, 2, 3))
		for i in range(12):
			await process_frame
			await RenderingServer.frame_post_draw
		var draws_before: int = background_draws
		var times: Array[float] = []
		var process_time: float = 0.0
		var render_calls: float = 0.0
		var last: int = Time.get_ticks_usec()
		for i in range(90):
			game.arena.effect_age = fmod(i * 0.016, 0.19)
			await process_frame
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
			process_time += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			render_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var mean: float = 0.0
		for sample in times:
			mean += sample / times.size()
		times.sort()
		var result := {"mean_frame_ms": mean, "p95_frame_ms": times[85], "mean_process_ms": process_time / 90.0, "mean_draw_calls": render_calls / 90.0}
		measurements[id] = result
		print("%s: frame %.2f ms, p95 %.2f ms, process %.3f ms, draw calls %.1f" % [id, mean, times[85], process_time / 90.0, render_calls / 90.0])
		check(background_draws == draws_before, "Static background draw commands remain cached: " + id)
		check(get_node_count() == nodes_before, "Ambient effects create no per-frame nodes: " + id)
		check(int(Arenas.definition(id).ambient.count) <= 16, "Ambient geometry is bounded: " + id)
		var baseline: float = measurements[Arenas.DEFAULT_ID].mean_frame_ms
		check(mean <= maxf(33.4, baseline * 1.75), "No major frame-time regression against original arena: " + id)
	var file := FileAccess.open("res://.godot/arena_performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("Arena performance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
