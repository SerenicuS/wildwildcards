extends RefCounted

# Presentation-only catalog. No combat code consumes these configurations.
const DEFAULT_ID := "desert_ridge"
const RANDOM_ID := "random"
const ORDER := ["dusty_main_street", "last_call_saloon", "iron_horse_station", "ghost_town", "desert_ridge"]
const DEFINITIONS := {
	"desert_ridge": {"id": "desert_ridge", "name": "Desert Ridge", "description": "The original desert showdown, beneath a golden moon.",
		"background": {"kind": "legacy"}, "ambient": {"kind": "none", "count": 0}, "preview": {"kind": "scene"}},
	"dusty_main_street": {"id": "dusty_main_street", "name": "Dusty Main Street", "description": "Weathered storefronts, desert dust and the last light of sunset.",
		"background": {"sky": Color("754e54"), "ground": Color("59413d"), "edge": Color("bc8a62"), "horizon": Color("60454b"),
			"orb": {"position": Vector2(875, 192), "radius": 66, "color": Color("dca36d")},
			"features": [
				{"kind": "building", "rect": Rect2(28, 230, 245, 239), "wood": Color("4b3939"), "sign": "GENERAL STORE"},
				{"kind": "building", "rect": Rect2(490, 256, 245, 213), "wood": Color("533c3b"), "sign": "SILVER SPUR"},
				{"kind": "building", "rect": Rect2(1020, 204, 233, 265), "wood": Color("493638"), "sign": "SHERIFF"}]},
		"ambient": {"kind": "dust", "count": 12, "color": Color(0.87, 0.66, 0.43, 0.16), "speed": 17.0}, "preview": {"kind": "scene"}},
	"last_call_saloon": {"id": "last_call_saloon", "name": "The Last Call Saloon", "description": "Lantern light, old timber and swinging saloon doors.",
		"background": {"sky": Color("30252e"), "ground": Color("382a2c"), "edge": Color("97714d"), "interior": true,
			"features": [{"kind": "bar", "rect": Rect2(38, 216, 224, 251)},
				{"kind": "doors", "rect": Rect2(540, 190, 200, 278)},
				{"kind": "lantern", "position": Vector2(324, 220)}, {"kind": "lantern", "position": Vector2(953, 220)},
				{"kind": "sign", "rect": Rect2(480, 193, 320, 42), "text": "THE LAST CALL"}]},
		"ambient": {"kind": "lantern", "count": 2, "color": Color(1.0, 0.72, 0.36, 0.08), "speed": 1.2,
			"positions": [Vector2(324, 229), Vector2(953, 229)]}, "preview": {"kind": "scene"}},
	"iron_horse_station": {"id": "iron_horse_station", "name": "Iron Horse Station", "description": "A timber platform beside a waiting steam locomotive.",
		"background": {"sky": Color("344953"), "ground": Color("38343a"), "edge": Color("aa9270"), "horizon": Color("293c46"), "platform": true,
			"features": [{"kind": "building", "rect": Rect2(25, 205, 242, 262), "wood": Color("3a3b3d"), "sign": "IRON HORSE"},
				{"kind": "train", "position": Vector2(510, 276)},
				{"kind": "sign", "rect": Rect2(1024, 255, 214, 42), "text": "PLATFORM  1"}]},
		"ambient": {"kind": "steam", "count": 6, "color": Color(0.72, 0.78, 0.78, 0.10), "speed": 12.0,
			"origin": Vector2(568, 265)}, "preview": {"kind": "scene"}},
	"ghost_town": {"id": "ghost_town", "name": "Ghost Town", "description": "Boarded windows and drifting mist beneath a cold moon.",
		"background": {"sky": Color("152332"), "ground": Color("26323a"), "edge": Color("66727c"), "horizon": Color("22333e"), "stars": true,
			"orb": {"position": Vector2(985, 215), "radius": 54, "color": Color("a7b4c4")},
			"features": [{"kind": "building", "rect": Rect2(25, 213, 248, 256), "wood": Color("2c373e"), "sign": "HOTEL", "abandoned": true},
				{"kind": "building", "rect": Rect2(485, 250, 270, 219), "wood": Color("303740"), "sign": "UNDERTAKER", "abandoned": true},
				{"kind": "building", "rect": Rect2(1030, 195, 222, 274), "wood": Color("2b333d"), "sign": "SALOON", "abandoned": true}]},
		"ambient": {"kind": "mist", "count": 7, "color": Color(0.61, 0.69, 0.79, 0.08), "speed": 9.0}, "preview": {"kind": "scene"}}
}

static func valid_preference(value: Variant) -> bool:
	return value is String and (value == RANDOM_ID or DEFINITIONS.has(value))

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, DEFINITIONS[DEFAULT_ID])

static func choose(preference: String, rng: RandomNumberGenerator) -> String:
	return ORDER[rng.randi_range(0, ORDER.size() - 1)] if preference == RANDOM_ID else str(definition(preference).id)
