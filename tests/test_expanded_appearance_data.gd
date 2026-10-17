extends SceneTree

const Profile = preload("res://scripts/ProfileManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
const Run = preload("res://scripts/GauntletRun.gd")
const PATH := "res://.godot/expanded_appearance.json"
var checks := 0
var failures := 0

class Unwritable extends Profile:
	func save_profile(_refresh_backup: bool = false) -> Error:
		return ERR_FILE_CANT_WRITE

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
	if "--verify" in OS.get_cmdline_user_args():
		var restored := Profile.new()
		restored.path = PATH
		restored.load_profile()
		check(restored.appearance.outfit_style == "poncho" and restored.appearance.hat_color == "cream", "Expanded equipped clothing survives new process")
		check(restored.outfit_presets.size() == 4 and restored.outfit_presets[0].name == "Renamed", "Preset count and rename survive new process")
		check(restored.outfit_presets[0].appearance.revolver_model == "python", "Preset revolver survives new process")
	else:
		for version in [1, 2, 3]:
			var path := PATH + str(version)
			var old := {"version": version, "display_name": "Mara", "appearance": {"hat": "gambler", "outfit": "violet", "accessory": "badge"}, "revolver_model": "python", "revolver_finish": "gold", "revolver_grip": "ivory", "stats": {"wins": 4, "losses": 3}, "gauntlet": {"best_streak": 8, "total_runs": 12, "duel_victories": 30}, "equipped_elimination_effect": "wanted_eliminated", "reset_revision": 7}
			write(path, old)
			write(path + ".bak", old)
			var p := Profile.new()
			p.path = path
			p.load_profile()
			check(p.appearance.hat == "gambler" and p.appearance.outfit == "violet" and p.appearance.accessory == "badge", "Legacy cosmetics preserved v%d" % version)
			check(p.appearance.outfit_style == "frontier" and p.appearance.hat_color == "original" and p.appearance.accessory_color == "original", "Legacy visual defaults preserve original art")
			check(p.stats.wins == 4 and p.display_name == "Mara" and p.gauntlet_records.best_streak == 8 and p.equipped_elimination_effect == "wanted_eliminated", "Other profile fields retained")
			var original_bytes := FileAccess.get_file_as_bytes(path)
			check(p.appearance.revolver_model == "python" and p.save_profile() == OK and FileAccess.get_file_as_bytes(path + ".bak") == original_bytes, "Migration keeps revolver and readable old backup")
		var profile := Profile.new()
		profile.path = PATH
		profile.appearance = Looks.sanitize({"hat": "cavalry", "hat_color": "cream", "outfit": "forest", "outfit_style": "poncho", "accessory": "gloves", "accessory_color": "tan", "revolver_model": "python", "revolver_finish": "gold", "revolver_grip": "engraved"})
		var before := profile.appearance.duplicate()
		for i in range(5):
			check(profile.save_outfit_preset("Outfit %d" % i, before) == OK, "Five preset slots writable")
		check(profile.save_outfit_preset("Sixth", before) != OK and profile.outfit_presets.size() == 5, "Sixth preset rejected")
		check(profile.rename_outfit_preset(0, "Renamed") == OK, "Rename works")
		check(profile.delete_outfit_preset(4) == OK and profile.outfit_presets.size() == 4, "Delete works")
		check(profile.rename_outfit_preset(-1, "Bad") != OK and profile.delete_outfit_preset(99) != OK, "Bad preset indices rejected")
		check(profile.appearance == before and profile.stats.matches_played == 0 and profile.gauntlet_records.total_runs == 0, "Preset operations do not equip or affect records")
		profile.outfit_presets[0].appearance.hat = "outlaw"
		check(profile.appearance == before, "Preset appearance is independent of equipped data")
		profile.save_profile()
		var failure := Unwritable.new()
		check(failure.save_outfit_preset("Failed", before) != OK and failure.outfit_presets.is_empty(), "Failed save rolls back new preset")
		failure.outfit_presets.append({"name": "Keep", "appearance": before})
		check(failure.rename_outfit_preset(0, "Failed") != OK and failure.outfit_presets[0].name == "Keep", "Failed rename rolls back")
		check(failure.delete_outfit_preset(0) != OK and failure.outfit_presets.size() == 1, "Failed delete rolls back")
		var reset := Profile.new()
		reset.path = PATH + "reset"
		reset.appearance = before.duplicate()
		reset.save_outfit_preset("Keep", before)
		check(reset.reset_stats() == OK and reset.outfit_presets.size() == 1 and reset.appearance == before, "Stats reset preserves presets and expanded look")
		check(reset.reset_profile() == OK and reset.outfit_presets.is_empty() and reset.appearance == Looks.defaults(), "Full reset clears presets and clothing")
		write(reset.path, "corrupt")
		var recovered := Profile.new()
		recovered.path = reset.path
		recovered.load_profile()
		check(recovered.outfit_presets.is_empty() and recovered.appearance == Looks.defaults(), "Backup recovery cannot undo confirmed profile reset")
		var malformed := {"version": 4, "appearance": {"hat": 7, "hat_color": "missing", "outfit_style": "missing"}, "outfit_presets": [{"name": 17, "appearance": {"accessory": "missing"}}, {}, 5, {"appearance": null}]}
		write(reset.path, malformed)
		write(reset.path + ".bak", {})
		recovered = Profile.new()
		recovered.path = reset.path
		recovered.load_profile()
		check(recovered.appearance == Looks.defaults() and recovered.outfit_presets.size() == 1 and recovered.outfit_presets[0].appearance == Looks.defaults(), "Malformed new fields safely sanitized")
		var run := Run.new()
		run.rng.seed = 50504
		run.begin("hard")
		var seen := {}
		for i in range(200):
			var opponent: Dictionary = run.prepare_next()
			check(opponent.appearance == Looks.sanitize(opponent.appearance), "Gauntlet produces only compatible catalog IDs")
			seen[opponent.appearance.outfit_style] = true
			run.enter_duel(opponent)
			run.record_victory()
		check(seen.size() == Looks.STYLES.size(), "Gauntlet uses every outerwear style")
	print("Expanded appearance data: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
