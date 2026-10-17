extends RefCounted

# Stable save IDs. Unknown future IDs render as classic without rewriting saves.
const LABELS := {"classic": "Classic", "wanted_eliminated": "WANTED: ELIMINATED"}
const DESCRIPTIONS := {
	"classic": "The original hit and fall. Straight to the result.",
	"wanted_eliminated": "A wanted portrait sealed with a red elimination stamp."
}

static func resolve_id(id: String) -> String:
	return id if LABELS.has(id) else "classic"
