extends SceneTree

const History = preload("res://scripts/MatchHistory.gd")
const Viewer = preload("res://scripts/ReplayViewer.gd")
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
	Engine.max_fps = 60
	var history := History.new()
	history.path = "res://.godot/history_performance.json"
	history.save_history()
	history.deferred_writes = true
	var times: Array[float] = []
	for i in range(120):
		history.begin_match({"mode": "solo", "difficulty": "hard", "arena": "ghost_town", "turn_seconds": 1.0,
			"actors": [{"name": "Mara", "appearance": History.Looks.sanitize({"outfit_style": "poncho", "hat": "cavalry", "revolver_model": "python"})}, {"name": "Jack", "appearance": History.Looks.defaults()}]})
		var zero := {"ammo": 0, "shields": 0, "alive": true}
		var first := DuelRules.resolve(zero, zero, 1, 1)
		history.record_turn(1, [zero, zero], [1, 1], first)
		var second := DuelRules.resolve(first.left, first.right, 3, 1)
		history.record_turn(2, [first.left, first.right], [3, 1], second)
		var start := Time.get_ticks_usec()
		history.complete_match("classic")
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	history.flush_history()
	check(history.matches.size() == 100 and history.matches[0].turns.size() == 2, "One hundred complete matches retained without partial turns")
	check(history.last_error == OK and FileAccess.get_file_as_bytes(history.path).size() < History.MAX_BYTES, "Atomic file remains bounded and readable")
	times.sort()
	check(times[114] < 33.4, "Completed-duel snapshot scheduling stays below a 33 ms frame budget at the 95th percentile")
	var viewer := Viewer.new()
	viewer.record = history.matches[0].duplicate(true)
	root.add_child(viewer)
	await process_frame
	await process_frame
	var nodes: int = get_node_count()
	var samples := {}
	for speed in [0.5, 1.0, 2.0]:
		viewer.set_speed(speed)
		var start := Time.get_ticks_usec()
		var draw_calls := 0.0
		for i in range(90):
			if i % 30 == 0: viewer.seek((i / 30) % 2)
			await process_frame
			await RenderingServer.frame_post_draw
			draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var frame_ms := float(Time.get_ticks_usec() - start) / 90000.0
		samples[str(speed)] = {"frame_ms": snappedf(frame_ms, 0.01), "draw_calls": snappedf(draw_calls / 90.0, 0.1)}
		check(frame_ms < 33.4 and get_node_count() == nodes, "Replay at each speed keeps its frame budget and stable scene node count")
	for dimensions in [Vector2i(960, 540), Vector2i(1600, 900)]:
		root.size = dimensions
		await process_frame
		await process_frame
		check(viewer.design.position.is_equal_approx((viewer.design.get_parent().size - Vector2(1280, 720)) / 2.0), "Replay remains centered at common 16:9 sizes")
	print("Replay performance: %d checks, %d failures; save p95 %.2f ms; frames %s" % [checks, failures, times[114], JSON.stringify(samples)])
	viewer.queue_free()
	await process_frame
	quit(int(failures > 0))
