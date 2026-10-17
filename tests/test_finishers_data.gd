extends SceneTree

const Profile = preload("res://scripts/ProfileManager.gd")
const Effects = preload("res://scripts/EliminationEffects.gd")
const PATH := "res://.godot/finishers_data.json"
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _initialize() -> void:
	var profile := Profile.new()
	profile.path = PATH
	if "--verify" in OS.get_cmdline_user_args():
		profile.load_profile()
		check(profile.equipped_elimination_effect == "random", "Random preference persists as Random, not the last sampled animation")
		check(profile.outfit_presets.size() == 1 and profile.appearance.outfit_style == "duster" and profile.appearance.revolver_model == "python", "Restart retains preset, clothing and gun")
		check(profile.stats.wins == 8 and profile.gauntlet_records.best_streak == 12, "Restart retains independent lifetime records")
	else:
		check(profile.equipped_elimination_effect == Effects.FALLBACK, "Fresh profiles use WANTED fallback")
		for version in [1, 2, 3, 4]:
			for invalid in [null, "", "future_unknown", 15]:
				var old := {"version": version, "display_name": "Mara", "stats": {"wins": 8, "losses": 2}, "gauntlet": {"best_streak": 12}, "appearance": {"hat": "gambler", "outfit_style": "duster"}, "revolver_model": "python", "equipped_elimination_effect": invalid, "outfit_presets": [{"name": "Trail", "appearance": {"hat": "cattleman"}}], "reset_revision": 3}
				if invalid == null:
					old.erase("equipped_elimination_effect")
				write(PATH, old)
				write(PATH + ".bak", old)
				profile = Profile.new()
				profile.path = PATH
				profile.load_profile()
				check(profile.equipped_elimination_effect == Effects.FALLBACK, "Invalid legacy finisher falls back safely")
				check(profile.display_name == "Mara" and profile.stats.wins == 8 and profile.gauntlet_records.best_streak == 12 and profile.outfit_presets.size() == 1 and profile.appearance.revolver_model == "python", "Migration preserves all other profile data")
				var backup := FileAccess.get_file_as_bytes(PATH)
				check(profile.equip_loadout(profile.appearance, "random") == OK and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Migration/equip preserves old readable backup")
		var rng := RandomNumberGenerator.new()
		rng.seed = 50505
		var seen := {}
		for i in range(200):
			var chosen := Effects.choose("random", rng)
			check(chosen in Effects.RANDOM_POOL, "Random chooses only a cinematic, never itself or Classic")
			seen[chosen] = true
		check(seen.size() == 4, "Random reaches all four finishers")
		for id in Effects.LABELS:
			var definition := Effects.definition(id)
			check(definition.id == id and definition.name == Effects.LABELS[id] and ResourceLoader.exists(definition.animation) and definition.preview, "Every registry entry has identity, name, preview and valid animation reference")
			check(definition.duration <= 1.5 and definition.duration >= 0.0, "Registry duration remains short")
			check(profile.equip_loadout(profile.appearance, id) == OK, "All stable IDs can be equipped and saved")
			var restored := Profile.new()
			restored.path = PATH
			restored.load_profile()
			check(restored.equipped_elimination_effect == id, "Each selected ID reloads unchanged, including Classic")
		check(Effects.resolve_id("bad") == Effects.FALLBACK and Effects.choose("bad", rng) == Effects.FALLBACK, "Runtime fallback agrees with persistence")
		profile.equip_loadout(profile.appearance, "random")
		check(profile.reset_stats() == OK and profile.equipped_elimination_effect == "random" and profile.outfit_presets.size() == 1, "Stats reset preserves finisher and presets")
		profile.stats.wins = 8
		profile.stats.matches_played = 8
		profile.gauntlet_records.best_streak = 12
		profile.save_profile(true)
	print("Finisher registry/persistence: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
