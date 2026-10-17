class_name DuelRules
extends RefCounted

enum Action { NONE, RELOAD, SHIELD, SHOOT }
const NAMES = ["NONE", "RELOAD", "SHIELD", "SHOOT"]

static func resolve(left: Dictionary, right: Dictionary, left_action: int, right_action: int) -> Dictionary:
	# Inputs are immutable snapshots. Controllers and visuals share no rule state.
	var states: Array = [left.duplicate(), right.duplicate()]
	var actions: Array[int] = [left_action, right_action]
	var fired: Array[bool] = [false, false]
	for i in range(2):
		if actions[i] == Action.SHIELD and states[i].shields >= 3:
			actions[i] = Action.NONE
		fired[i] = actions[i] == Action.SHOOT and states[i].ammo > 0
		states[i].shields = states[i].shields + 1 if actions[i] == Action.SHIELD else 0
		if actions[i] == Action.RELOAD:
			states[i].ammo += 1
		elif fired[i]:
			states[i].ammo -= 1
	var clash: bool = fired[0] and fired[1]
	if not clash:
		for i in range(2):
			if fired[i] and actions[1 - i] != Action.SHIELD:
				states[1 - i].alive = false
	return {"left": states[0], "right": states[1], "actions": actions, "fired": fired, "clash": clash}
