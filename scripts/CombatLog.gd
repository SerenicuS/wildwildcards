class_name CombatLog
extends RefCounted

signal changed

# Whole entries are evicted, never partial turns. The copy contains all retained text.
const MAX_CHARACTERS: int = 262144
const TRUNCATED := "[Older session entries removed: 262,144-character limit.]\n\n"
var entries: Array[String] = []
var character_count: int = 0
var truncated: bool = false
var match_number: int = 0
var match_open: bool = false

func append(entry: String) -> void:
	entries.append(entry)
	character_count += entry.length()
	while character_count > MAX_CHARACTERS and entries.size() > 1:
		character_count -= entries.pop_front().length()
		truncated = true
	changed.emit()

func full_text() -> String:
	return (TRUNCATED if truncated else "") + "".join(entries)

func clear() -> void:
	entries.clear()
	character_count = 0
	truncated = false
	# Keep match numbering even when the user clears the display mid-match.
	changed.emit()

func start_match(personality: Dictionary = {}) -> void:
	match_number += 1
	match_open = true
	var text := "=== MATCH #%d START ===\n" % match_number
	if not personality.is_empty():
		text += "BOT PERSONALITY:\nAggression: %s\nCaution: %s\nGreed: %s\n" % [
			str(personality.aggression), str(personality.caution), str(personality.greed)]
	append(text + "\n")

func end_match(winner: String, turns: int) -> void:
	if not match_open:
		return
	match_open = false
	append("=== MATCH #%d END ===\nWinner: %s\nTurns: %d\n\n" % [match_number, winner, turns])

func record_turn(turn: int, before_player: Dictionary, before_bot: Dictionary,
		selected_player: int, selected_bot: int, result: Dictionary, decision: Dictionary) -> void:
	var text := "[M%d T%02d] PLAYER: %s | BOT: %s\n" % [match_number, turn,
		DuelRules.NAMES[selected_player], DuelRules.NAMES[selected_bot]]
	text += "Ammo: P %d→%d | B %d→%d\n" % [before_player.ammo, result.left.ammo, before_bot.ammo, result.right.ammo]
	text += "Shield: P %d→%d | B %d→%d\n" % [before_player.shields, result.left.shields, before_bot.shields, result.right.shields]
	var events: Array[String] = []
	var names := ["Player", "Bot"]
	var chosen := [selected_player, selected_bot]
	for i in range(2):
		if chosen[i] != result.actions[i]:
			events.append("%s shield unavailable; resolved as NONE." % names[i])
		if result.actions[i] == DuelRules.Action.SHOOT:
			if not result.fired[i]:
				events.append("%s aimed without ammunition (empty shot; no bullet fired)." % names[i])
			elif result.clash:
				events.append("%s fired; bullet consumed in shootout draw." % names[i])
			elif result.actions[1 - i] == DuelRules.Action.SHIELD:
				events.append("%s fired; shot blocked by %s shield." % [names[i], names[1 - i]])
			else:
				events.append("%s fired; hit %s." % [names[i], names[1 - i]])
		elif result.actions[i] == DuelRules.Action.RELOAD:
			events.append("%s reloaded." % names[i])
		elif result.actions[i] == DuelRules.Action.SHIELD:
			events.append("%s shielded." % names[i])
		else:
			events.append("%s performed NONE." % names[i])
	text += "Shots/actions: %s\n" % " ".join(events)
	var winner := ""
	if not result.left.alive or not result.right.alive:
		winner = "PLAYER" if result.left.alive else ("BOT" if result.right.alive else "DRAW")
	text += "Result: %s\n" % (("%s wins." % winner) if winner != "" else (
		"Shootout draw. Both bullets consumed; duel continues." if result.clash else "Duel continues."))
	# Metadata comes from the actual weighted choice, never a reconstructed model.
	if not decision.is_empty():
		text += "BOT DECISION:\nAmmo before turn: %d\nAvailable actions: %s\n" % [decision.ammo, ", ".join(decision.available)]
		for entry in [["Base weights", decision.base_weights], ["Personality", decision.personality],
				["Adjusted weights", decision.weights], ["Probabilities", decision.probabilities]]:
			text += "%s: Reload=%s, Shield=%s, Shoot=%s\n" % [entry[0], str(entry[1][0]), str(entry[1][1]), str(entry[1][2])]
		text += "Chosen: %s\n" % DuelRules.NAMES[decision.chosen]
	append(text + "\n")
	if winner != "":
		end_match(winner, turn)
