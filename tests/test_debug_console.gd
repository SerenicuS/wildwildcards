extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Main.new()
	game.profile.path = "res://.godot/test_console_profile.json"
	root.add_child(game)
	game.set_process(false)
	check(not game.debug_console.panel.visible, "Console hidden by default")
	await key(KEY_QUOTELEFT)
	check(game.debug_console.panel.visible and not paused, "Backtick opens without pausing")
	await key(KEY_QUOTELEFT)
	check(not game.debug_console.panel.visible, "Backtick closes")
	game.start_duel()
	game.intro_start = Time.get_ticks_usec() - 2800000
	game._process(0.0)
	check(not game.combat_log.full_text().contains("BOT DECISION"), "No decision before first resolution")
	var captured: Dictionary = game.pending_bot_decision.duplicate(true)
	check(captured.weights.size() == 3 and captured.chosen == game.bot_action, "Diagnostics capture actual bot choice")
	await key(KEY_QUOTELEFT)
	for pair in [[KEY_A, 1], [KEY_S, 2], [KEY_D, 3]]:
		await key(pair[0])
		check(game.selected == pair[1], "A/S/D pass through console")
	game.selected = DuelRules.Action.RELOAD
	game.bot_action = DuelRules.Action.RELOAD
	game.pending_bot_decision = {}
	game.resolve_turn()
	var text: String = game.combat_log.full_text()
	check(text.contains("[M1 T01] PLAYER: RELOAD | BOT: RELOAD") and text.contains("Ammo: P 0→1 | B 0→1"), "Actual reload snapshots logged")
	game.begin_turn()
	check(game.combat_log.full_text() == text, "Next hidden decision is not published")
	game.selected = DuelRules.Action.SHOOT
	game.bot_action = DuelRules.Action.SHOOT
	game.resolve_turn()
	text = game.combat_log.full_text()
	check(text.contains("Shootout draw. Both bullets consumed") and text.contains("Ammo: P 1→0 | B 1→0"), "Shootout draw logged")
	check(text.contains("BOT DECISION:") and text.contains("Adjusted weights:"), "Resolved decision diagnostics logged")
	game.begin_turn()
	game.selected = DuelRules.Action.SHOOT
	game.bot_action = DuelRules.Action.RELOAD
	game.resolve_turn()
	check(game.combat_log.full_text().contains("Player aimed without ammunition"), "Empty shot identified")
	game.begin_turn()
	game.player.shields = 2
	game.selected = DuelRules.Action.SHIELD
	game.bot_action = DuelRules.Action.SHOOT
	game.resolve_turn()
	text = game.combat_log.full_text()
	check(text.contains("Shield: P 2→3 | B 0→0") and text.contains("shot blocked by Player shield"), "Shield streak and blocked shot")
	game.begin_turn()
	game.selected = DuelRules.Action.SHIELD
	game.bot_action = DuelRules.Action.NONE
	game.resolve_turn()
	text = game.combat_log.full_text()
	check(text.contains("shield unavailable; resolved as NONE") and text.contains("Shield: P 3→0"), "Fatigue rejection and reset recorded")
	# Actual elapsed time while visible must still complete a turn.
	game.begin_turn()
	game.bot_action = DuelRules.Action.RELOAD
	game.deadline = Time.get_ticks_usec() + 1000000
	var turn_before: int = game.turn
	game.set_process(true)
	await create_timer(1.08).timeout
	game.set_process(false)
	check(game.debug_console.panel.visible and game.turn == turn_before + 1, "Timer resolves while console open")
	game.opponent.ammo = 1
	game.selected = DuelRules.Action.NONE
	game.bot_action = DuelRules.Action.SHOOT
	game.resolve_turn()
	check(game.combat_log.full_text().contains("Winner: BOT") and game.combat_log.full_text().contains("=== MATCH #1 END ==="), "Match winner recorded")
	text = game.combat_log.full_text()
	game.start_duel()
	check(game.combat_log.full_text().begins_with(text) and game.combat_log.full_text().contains("=== MATCH #2 START ==="), "Rematch preserves history and separates matches")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/debug_console_preview.png")
	if DisplayServer.get_name() != "headless":
		game.debug_console.copy_button.pressed.emit()
		check(DisplayServer.clipboard_get().replace("\r\n", "\n") == game.combat_log.full_text(), "Copy button copies entire retained session (native line endings)")
	else:
		print("Clipboard check skipped on headless DisplayServer")
	game.debug_console.clear_button.pressed.emit()
	check(game.combat_log.full_text() == "" and game.debug_console.history.text == "", "Clear button clears stored and visible history")
	game.start_duel()
	check(game.combat_log.match_number == 3, "Clear preserves session match numbering")
	await key(KEY_QUOTELEFT)
	game.state = Main.State.PLAYING
	game.begin_turn()
	game.bot_action = DuelRules.Action.RELOAD
	game.resolve_turn()
	check(game.combat_log.full_text().contains("[M3 T01]"), "Closed console keeps recording")
	var limited := CombatLog.new()
	for i in range(1000):
		limited.append("Entry %04d " % i + "x".repeat(500) + "\n")
	check(limited.truncated and limited.character_count <= CombatLog.MAX_CHARACTERS, "Session history bounded")
	check(limited.full_text().begins_with(CombatLog.TRUNCATED) and limited.full_text().ends_with("x".repeat(500) + "\n"), "Eviction marks truncation and keeps newest complete entry")
	print("Debug console tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
