extends RefCounted

# Stable save IDs, including the original optional immediate-result presentation.
const FALLBACK := "wanted_eliminated"
const RANDOM_POOL := ["wanted_eliminated", "dead_mans_hand", "high_noon", "smoke_mirrors"]
const LABELS := {"classic": "Classic", "wanted_eliminated": "WANTED: ELIMINATED",
	"dead_mans_hand": "Dead Man's Hand", "high_noon": "High Noon", "smoke_mirrors": "Smoke & Mirrors", "random": "Random"}
const DESCRIPTIONS := {
	"classic": "The original hit and fall. Straight to the result.",
	"wanted_eliminated": "A wanted portrait sealed with a red elimination stamp.",
	"dead_mans_hand": "Two black aces. Two black eights. One winning hand.",
	"high_noon": "The winning gunslinger framed against a blazing sunset.",
	"smoke_mirrors": "Revolver smoke clears to reveal the winner.",
	"random": "A fresh choice from the four cinematic finishers each victory."
}
const DURATIONS := {"classic": 0.0, "wanted_eliminated": 1.29, "dead_mans_hand": 1.44,
	"high_noon": 1.44, "smoke_mirrors": 1.44, "random": 1.44}

static func resolve_id(id: String) -> String:
	return id if LABELS.has(id) else FALLBACK

static func choose(id: String, rng: RandomNumberGenerator) -> String:
	var resolved := resolve_id(id)
	return RANDOM_POOL[rng.randi_range(0, RANDOM_POOL.size() - 1)] if resolved == "random" else resolved

static func definition(id: String) -> Dictionary:
	var resolved := resolve_id(id)
	return {"id": resolved, "name": LABELS[resolved], "description": DESCRIPTIONS[resolved],
		"duration": DURATIONS[resolved], "preview": true,
		"animation": "res://scripts/FinisherVisual.gd" if resolved in ["dead_mans_hand", "high_noon", "smoke_mirrors"] else "res://scripts/EliminationController.gd"}
