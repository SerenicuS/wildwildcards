class_name DuelParticipant
extends RefCounted

var ammo: int = 0
var shields: int = 0
var alive: bool = true

func reset() -> void:
	ammo = 0
	shields = 0
	alive = true

func snapshot() -> Dictionary:
	return {"ammo": ammo, "shields": shields, "alive": alive}

func apply(state: Dictionary) -> void:
	ammo = state.ammo
	shields = state.shields
	alive = state.alive
