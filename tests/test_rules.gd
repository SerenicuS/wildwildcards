extends SceneTree

const Rules = preload("res://scripts/DuelRules.gd")
const Participant = preload("res://scripts/DuelParticipant.gd")
const Bot = preload("res://scripts/BotController.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func snapshot(ammo: int = 0, shields: int = 0) -> Dictionary:
	return {"ammo": ammo, "shields": shields, "alive": true}

func _initialize() -> void:
	var fresh = Participant.new()
	check(fresh.ammo == 0 and fresh.shields == 0 and fresh.alive, "Initial state")
	# Exhaust every action pair, small ammo combination and shield fatigue state.
	for ammo_left in range(3):
		for ammo_right in range(3):
			for shields_left in range(4):
				for shields_right in range(4):
					for a in range(4):
						for b in range(4):
							verify_case(ammo_left, ammo_right, shields_left, shields_right, a, b)
	var stacked: Dictionary = snapshot()
	for i in range(1000):
		stacked = Rules.resolve(stacked, snapshot(), Rules.Action.RELOAD, Rules.Action.NONE).left
	check(stacked.ammo == 1000, "No ammo cap")
	fresh.apply(stacked)
	fresh.reset()
	check(fresh.ammo == 0 and fresh.shields == 0 and fresh.alive, "Restart resets participant")
	var bot = Bot.new()
	bot.rng.seed = 42
	for i in range(1000):
		var own := snapshot(i % 3, i % 4)
		var action: int = bot.choose_action(own, snapshot(i % 2))
		check(action >= 1 and action <= 3, "Bot chooses valid action")
		check(not (own.ammo == 0 and action == Rules.Action.SHOOT), "Bot respects ammo")
		check(not (own.shields == 3 and action == Rules.Action.SHIELD), "Bot respects shield fatigue")
	print("Combat tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_case(al: int, ar: int, sl: int, sr: int, a: int, b: int) -> void:
	var left := snapshot(al, sl)
	var right := snapshot(ar, sr)
	var result: Dictionary = Rules.resolve(left, right, a, b)
	var effective_a: int = 0 if a == 2 and sl == 3 else a
	var effective_b: int = 0 if b == 2 and sr == 3 else b
	var shot_a: bool = effective_a == 3 and al > 0
	var shot_b: bool = effective_b == 3 and ar > 0
	check(left == snapshot(al, sl) and right == snapshot(ar, sr), "Pure resolver preserves input")
	check(result.left.ammo == al + int(effective_a == 1) - int(shot_a), "Left ammo")
	check(result.right.ammo == ar + int(effective_b == 1) - int(shot_b), "Right ammo")
	check(result.left.shields == (sl + 1 if effective_a == 2 else 0), "Left fatigue")
	check(result.right.shields == (sr + 1 if effective_b == 2 else 0), "Right fatigue")
	check(result.left.alive == (not shot_b or effective_a == 2 or shot_a), "Left simultaneous survival")
	check(result.right.alive == (not shot_a or effective_b == 2 or shot_b), "Right simultaneous survival")
	check(result.clash == (shot_a and shot_b), "Clash only with two loaded shots")
	var mirrored: Dictionary = Rules.resolve(right, left, b, a)
	check(result.left == mirrored.right and result.right == mirrored.left, "Symmetric rules")
