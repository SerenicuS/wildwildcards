extends RefCounted

const Revolver = preload("res://scripts/RevolverAppearance.gd")

const HATS := {"classic": "Drifter", "wide_brim": "Wide Brim", "gambler": "Gambler", "cattleman": "Cattleman", "outlaw": "Outlaw", "cavalry": "Cavalry"}
const OUTFITS := {"teal": "Teal", "rust": "Rust", "violet": "Violet", "sand": "Sand", "black": "Black", "brown": "Brown", "tan": "Tan", "dark_red": "Dark Red", "navy": "Navy", "forest": "Forest Green", "cream": "Cream"}
const COLORS := {"teal": Color("53d6ce"), "rust": Color("c6744d"), "violet": Color("9872ba"), "sand": Color("d1b179"), "black": Color("34343e"), "brown": Color("805840"), "tan": Color("be9766"), "dark_red": Color("923e46"), "navy": Color("414f7a"), "forest": Color("47735a"), "cream": Color("e7d8b6")}
const ACCESSORIES := {"none": "None", "bandana": "Bandana", "badge": "Sheriff Badge", "neckerchief": "Neckerchief", "belt": "Decorative Belt", "gloves": "Gloves"}
const STYLES := {"frontier": "Frontier Jacket", "duster": "Long Duster", "poncho": "Western Poncho", "waistcoat": "Gambler Waistcoat", "outlaw": "Outlaw Coat"}
const TINTS := {"original": "Original", "black": "Black", "brown": "Brown", "tan": "Tan", "dark_red": "Dark Red", "navy": "Navy", "forest": "Forest Green", "cream": "Cream"}

static func catalogs() -> Dictionary:
	return {"hat": HATS, "outfit": OUTFITS, "accessory": ACCESSORIES, "outfit_style": STYLES, "hat_color": TINTS, "accessory_color": TINTS}

static func defaults() -> Dictionary:
	var result := {"hat": "classic", "outfit": "teal", "accessory": "none", "outfit_style": "frontier", "hat_color": "original", "accessory_color": "original"}
	result.merge(Revolver.defaults())
	return result

static func sanitize(value: Variant) -> Dictionary:
	var result := defaults()
	if value is Dictionary:
		var choices := catalogs()
		for key in choices:
			var choice: Variant = value.get(key)
			if choice is String and choices[key].has(choice):
				result[key] = choice
	result.merge(Revolver.sanitize(value), true)
	return result

static func describe(value: Dictionary) -> String:
	var appearance := sanitize(value)
	return "%s · %s\n%s · %s\n%s" % [HATS[appearance.hat], OUTFITS[appearance.outfit], STYLES[appearance.outfit_style], ACCESSORIES[appearance.accessory], Revolver.MODELS[appearance.revolver_model]]

static func randomized(rng: RandomNumberGenerator) -> Dictionary:
	var result := defaults()
	var choices := catalogs()
	choices.merge({"revolver_model": Revolver.MODELS, "revolver_finish": Revolver.FINISHES, "revolver_grip": Revolver.GRIPS})
	for key in choices:
		var ids: Array = choices[key].keys()
		result[key] = ids[rng.randi_range(0, ids.size() - 1)]
	return result
