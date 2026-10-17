extends RefCounted

const HATS := {"classic": "Drifter", "wide_brim": "Wide Brim", "gambler": "Gambler"}
const OUTFITS := {"teal": "Teal", "rust": "Rust", "violet": "Violet", "sand": "Sand"}
const COLORS := {"teal": Color("53d6ce"), "rust": Color("c6744d"), "violet": Color("9872ba"), "sand": Color("d1b179")}
const ACCESSORIES := {"none": "None", "bandana": "Bandana", "badge": "Sheriff Badge"}

static func defaults() -> Dictionary:
	return {"hat": "classic", "outfit": "teal", "accessory": "none"}

static func sanitize(value: Variant) -> Dictionary:
	var result := defaults()
	if value is Dictionary:
		for entry in [["hat", HATS], ["outfit", OUTFITS], ["accessory", ACCESSORIES]]:
			var choice: Variant = value.get(entry[0])
			if choice is String and entry[1].has(choice):
				result[entry[0]] = choice
	return result

static func describe(value: Dictionary) -> String:
	var appearance := sanitize(value)
	return "%s · %s\nAccessory: %s" % [HATS[appearance.hat], OUTFITS[appearance.outfit], ACCESSORIES[appearance.accessory]]
