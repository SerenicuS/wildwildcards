extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func snapshot(ammo: int, shields: int = 0) -> Dictionary:
	return {"ammo": ammo, "shields": shields, "alive": true}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var bot := BotController.new()
	bot.rng.seed = 20261017
	var unique := {}
	for match_index in range(100):
		bot.start_match()
		var personality := bot.personality_snapshot()
		unique[str(personality)] = true
		for value in personality.values():
			check(value >= 0.7 and value <= 1.3, "Multiplier within inclusive range")
		for turn_index in range(24):
			var ammo: int = turn_index % 3
			var shields: int = turn_index % 4
			var last_action: int = bot.previous
			var action: int = bot.choose_action(snapshot(ammo, shields), snapshot(turn_index % 2))
			var decision := bot.last_decision
			check(bot.personality_snapshot() == personality, "Personality fixed for entire match")
			check(action >= 1 and action <= 3 and (ammo > 0 or action != 3) and (shields < 3 or action != 2), "Valid actions and restrictions preserved")
			var expected_base: Array[float] = [6.0 if ammo > 0 else 10.0,
				4.0 if turn_index % 2 > 0 else 0.7, 6.0 if ammo > 0 else 0.0]
			if shields >= 3:
				expected_base[1] = 0.0
			if last_action > 0:
				expected_base[last_action - 1] *= 0.65
			check(decision.base_weights == expected_base, "Existing state and repetition weights preserved")
			var factors := [personality.greed, personality.caution, personality.aggression]
			var total: float = decision.weights[0] + decision.weights[1] + decision.weights[2]
			var sum: float = 0.0
			for i in range(3):
				check(is_equal_approx(decision.weights[i], expected_base[i] * factors[i]), "Correct personality to action mapping")
				check(is_equal_approx(decision.probabilities[i], decision.weights[i] / total), "Probability reflects adjusted weights")
				sum += decision.probabilities[i]
			check(is_equal_approx(sum, 1.0), "Probabilities normalized")
	check(unique.size() > 1, "Different matches generate different personalities")
	# Reproduce the normalized lottery with the same random state. No hidden action
	# is an input to this controller; only public participant snapshots are supplied.
	var predictor := RandomNumberGenerator.new()
	for i in range(1000):
		predictor.state = bot.rng.state
		var roll: float = predictor.randf()
		var chosen: int = bot.choose_action(snapshot(2), snapshot(2))
		var expected: int = 1
		for j in range(3):
			roll -= bot.last_decision.probabilities[j]
			if bot.last_decision.probabilities[j] > 0.0 and roll < 0.0:
				expected = j + 1
				break
		check(chosen == expected, "Actual selection uses normalized adjusted distribution")
	var game = Main.new()
	game.profile.path = "res://.godot/test_bot_profile.json"
	root.add_child(game)
	game.set_process(false)
	game.bot.rng.seed = 44
	game.start_duel()
	var first: Dictionary = game.bot.personality_snapshot()
	var header: String = game.combat_log.full_text()
	check(header.contains("BOT PERSONALITY:") and header.contains("Aggression: " + str(first.aggression)), "Match header records generated personality")
	game.state = Main.State.PLAYING
	game.begin_turn()
	check(game.combat_log.full_text() == header, "No hidden turn information published before resolution")
	var pending: Dictionary = game.pending_bot_decision.duplicate(true)
	game.selected = DuelRules.Action.RELOAD
	game.resolve_turn()
	var text: String = game.combat_log.full_text()
	check(text.contains("Base weights:") and text.contains("Personality:") and text.contains("Adjusted weights:") and text.contains("Probabilities:"), "Resolved turn logs complete weight breakdown")
	check(text.contains("Chosen: " + DuelRules.NAMES[pending.chosen]), "Log records actual committed bot choice")
	check(game.bot.personality_snapshot() == first, "Resolution preserves personality")
	game.start_duel()
	check(game.bot.personality_snapshot() != first and game.bot.previous == 0, "Rematch refreshes personality and repetition state")
	check(game.combat_log.full_text().contains("=== MATCH #2 START ===\nBOT PERSONALITY:"), "Rematch personality has separate header")
	print("Bot personality tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
