class_name BotController
extends RefCounted

var rng := RandomNumberGenerator.new()
var previous: int = DuelRules.Action.NONE
var aggression: float = 1.0
var caution: float = 1.0
var greed: float = 1.0
# Private-to-controller diagnostics, published by the manager only after resolution.
var last_decision: Dictionary = {}

func _init() -> void:
	rng.randomize()

func start_match() -> void:
	aggression = rng.randf_range(0.7, 1.3)
	caution = rng.randf_range(0.7, 1.3)
	greed = rng.randf_range(0.7, 1.3)
	previous = DuelRules.Action.NONE
	last_decision = {}

func personality_snapshot() -> Dictionary:
	return {"aggression": aggression, "caution": caution, "greed": greed}

func set_personality(personality: Dictionary) -> void:
	aggression = float(personality.get("aggression", aggression))
	caution = float(personality.get("caution", caution))
	greed = float(personality.get("greed", greed))
	previous = DuelRules.Action.NONE
	last_decision = {}

func choose_action(own: Dictionary, opponent: Dictionary) -> int:
	# Only public state is accepted; current player selection is never supplied.
	var weights: Array[float] = [6.0 if own.ammo > 0 else 10.0,
		4.0 if opponent.ammo > 0 else 0.7, 6.0 if own.ammo > 0 else 0.0]
	if own.shields >= 3:
		weights[1] = 0.0
	if previous > 0:
		weights[previous - 1] *= 0.65
	var base_weights: Array[float] = weights.duplicate()
	var multipliers: Array[float] = [greed, caution, aggression]
	for i in range(3):
		weights[i] *= multipliers[i]
	var total: float = weights[0] + weights[1] + weights[2]
	var probabilities: Array[float] = []
	for weight in weights:
		probabilities.append(weight / total)
	var available: Array[String] = []
	for i in range(3):
		if weights[i] > 0.0:
			available.append(DuelRules.NAMES[i + 1])
	last_decision = {"ammo": own.ammo, "base_weights": base_weights,
		"personality": multipliers, "weights": weights.duplicate(),
		"probabilities": probabilities, "available": available}
	var roll: float = rng.randf()
	for i in range(3):
		roll -= probabilities[i]
		if probabilities[i] > 0.0 and roll < 0.0:
			previous = i + 1
			last_decision.chosen = previous
			return previous
	last_decision.chosen = DuelRules.Action.RELOAD
	return DuelRules.Action.RELOAD
