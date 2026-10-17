extends RefCounted

# Run progression and cosmetic generation only. Combat stays in DuelRules.
const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const NAMES := ["Dusty Mae", "Iron Ada", "Silas Crow", "Rio Reed", "Pearl Flint", "Calico Finn", "Ash Boone", "Marlow West"]
var rng := RandomNumberGenerator.new()
var active: bool = false
var streak: int = 0
var duel_number: int = 0
var difficulty: String = "hard"
var arena_id: String = ""
var opponent: Dictionary = {}
var duel_recorded: bool = false

func _init() -> void:
	rng.randomize()

func begin(preset: String) -> void:
	active = true
	streak = 0
	duel_number = 0
	difficulty = preset
	arena_id = ""
	opponent = {}
	duel_recorded = false

func pick_arena(previous: String, available: Array = Arenas.ORDER) -> String:
	var choices := available.duplicate()
	if choices.size() > 1:
		choices.erase(previous)
	return Arenas.DEFAULT_ID if choices.is_empty() else str(choices[rng.randi_range(0, choices.size() - 1)])

func prepare_next() -> Dictionary:
	if not active or (duel_number > 0 and not duel_recorded):
		return {}
	var names := NAMES.duplicate()
	if not opponent.is_empty():
		names.erase(opponent.name)
	var appearance := Appearance.randomized(rng)
	return {"name": names[rng.randi_range(0, names.size() - 1)], "appearance": appearance,
		"arena": pick_arena(arena_id), "number": streak + 1}

func enter_duel(prepared: Dictionary) -> bool:
	if not active or prepared.is_empty() or prepared.get("number") != streak + 1 or (duel_number > 0 and not duel_recorded):
		return false
	opponent = prepared.duplicate(true)
	arena_id = prepared.arena
	duel_number = prepared.number
	duel_recorded = false
	return true

func record_victory() -> bool:
	if not active or duel_recorded or duel_number != streak + 1:
		return false
	duel_recorded = true
	streak += 1
	return true

func finish() -> bool:
	if not active:
		return false
	active = false
	duel_recorded = true
	return true
