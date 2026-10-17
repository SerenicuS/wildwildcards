extends SceneTree

const Profile = preload("res://scripts/ProfileManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
const TEST_PATH := "res://.godot/profile_data_test.json"

class MemoryProfile extends Profile:
	var saves: int = 0
	func save_profile(_refresh_backup: bool = false) -> Error:
		saves += 1
		_dirty = false
		return OK

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func state(ammo: int = 0, shields: int = 0) -> Dictionary:
	return {"ammo": ammo, "shields": shields, "alive": true}

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _initialize() -> void:
	var profile := MemoryProfile.new()
	check(profile.display_name == "Gunslinger" and profile.appearance == Looks.defaults() and
		profile.equipped_elimination_effect == "wanted_eliminated", "Default identity, look and future elimination field")
	check(profile.stats.total_turns == 0 and profile.win_rate() == 0.0, "Fresh stats")
	profile.begin_match()
	var turns := [[1, 1, 0, 0], [2, 3, 1, 1], [2, 3, 1, 0], [1, 3, 1, 0], [3, 3, 2, 1], [3, 1, 1, 0]]
	for i in range(turns.size()):
		var t: Array = turns[i]
		var result := DuelRules.resolve(state(t[2]), state(t[3]), t[0], t[1])
		profile.record_turn(i + 1, result)
		var once := profile.stats.duplicate()
		profile.record_turn(i + 1, result)
		check(profile.stats == once, "Duplicate resolved-turn callback ignored")
	var expected := {"matches_played": 1, "wins": 1, "losses": 0, "total_turns": 6,
		"reload_actions": 2, "shield_actions": 2, "shoot_actions": 2, "none_actions": 0,
		"shots_fired": 2, "opponent_shots_fired": 2, "total_shots_fired": 4,
		"successful_eliminations": 1, "shots_blocked": 1, "shield_turns_against_shoot": 2,
		"reload_turns_against_shoot": 1, "shootout_draws": 1}
	check(profile.stats == expected, "Golden match: every detailed counter, both shootout bullets, empty attempts, blocks and elimination")
	profile.abandon_match()
	profile.record_turn(7, DuelRules.resolve(state(1), state(), 3, 0))
	check(profile.stats == expected and profile.saves == 1, "Ended match cannot be counted twice on menu/late callbacks")
	profile.begin_match()
	profile.record_turn(1, DuelRules.resolve(state(), state(1), 3, 3))
	check(profile.stats.matches_played == 2 and profile.stats.wins == 1 and profile.stats.losses == 1 and profile.win_rate() == 50.0,
		"Rematch accumulates lifetime wins/losses and win rate")
	check(profile.stats.shots_fired == 2, "Empty shoot is an action, never a fired shot")
	profile.begin_match()
	profile.record_turn(1, DuelRules.resolve(state(0, 3), state(), 2, 0))
	profile.abandon_match()
	check(profile.stats.none_actions == 1 and profile.stats.matches_played == 2, "Fatigued shield counts as resolved NONE; abandoned duel adds no win/loss")
	# All action pairs, ammo availability and fatigue states, using the actual resolver.
	for ammo_p in range(2):
		for ammo_b in range(2):
			for streak in range(4):
				for p_action in range(4):
					for b_action in range(4):
						var counter := MemoryProfile.new()
						counter.begin_match()
						var result := DuelRules.resolve(state(ammo_p, streak), state(ammo_b), p_action, b_action)
						counter.record_turn(1, result)
						check(counter.stats.shots_fired == int(result.fired[0]) and counter.stats.total_shots_fired == int(result.fired[0]) + int(result.fired[1]), "Shots from actual fired flags")
						check(counter.stats.shots_blocked == int(result.actions[0] == 2 and result.fired[1]), "Actual shield block")
						check(counter.stats.shootout_draws == int(result.clash) and (not result.clash or counter.stats.successful_eliminations == 0), "Shootout never eliminates")
						check(counter.stats.reload_actions + counter.stats.shield_actions + counter.stats.shoot_actions + counter.stats.none_actions == 1, "Exactly one resolved action counted")
	var disk := Profile.new()
	disk.path = TEST_PATH
	check(disk.set_display_name("  Mara Vale  ") == OK, "Name save succeeds")
	check(disk.equip({"hat": "gambler", "outfit": "rust", "accessory": "bandana"}) == OK, "Replacing existing save succeeds")
	var loaded := Profile.new()
	loaded.path = TEST_PATH
	loaded.load_profile()
	check(loaded.display_name == "Mara Vale" and loaded.appearance == disk.appearance and loaded.equipped_elimination_effect == "wanted_eliminated", "Identity, look and elimination field survive reload")
	loaded.begin_match()
	loaded.record_turn(1, DuelRules.resolve(state(1), state(), 3, 0))
	var reopened := Profile.new()
	reopened.path = TEST_PATH
	reopened.load_profile()
	check(reopened.stats.matches_played == 1 and reopened.stats.wins == 1 and reopened.stats.shots_fired == 1, "Completed match stats persisted")
	reopened.abandon_match()
	check(reopened.stats.matches_played == 1, "Scene reload/menu cannot recount saved outcome")
	var missing := Profile.new()
	missing.path = "res://.godot/no_such_directory/profile.json"
	missing.load_profile()
	check(missing.display_name == "Gunslinger" and missing.stats.matches_played == 0, "Missing file uses defaults")
	var invalid_path := "res://.godot/profile_invalid.json"
	write_json(invalid_path, "not a profile object")
	var invalid := Profile.new()
	invalid.path = invalid_path
	invalid.load_profile()
	check(invalid.display_name == "Gunslinger" and invalid.stats.total_turns == 0, "Corrupt file uses defaults")
	var broken_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	broken_file.store_string("{ broken json")
	broken_file.close()
	invalid = Profile.new()
	invalid.path = invalid_path
	invalid.load_profile()
	check(invalid.display_name == "Gunslinger" and invalid.stats.matches_played == 0, "Invalid JSON syntax does not crash")
	write_json(invalid_path, {"version": 1, "display_name": 43, "appearance": {"hat": "unknown"},
		"stats": {"wins": -4, "losses": "bad", "total_turns": -2}})
	invalid = Profile.new()
	invalid.path = invalid_path
	invalid.load_profile()
	check(invalid.display_name == "Gunslinger" and invalid.appearance == Looks.defaults() and invalid.stats.total_turns == 0, "Malformed fields have sensible defaults")
	write_json(TEST_PATH, false)
	var recovered := Profile.new()
	recovered.path = TEST_PATH
	recovered.load_profile()
	check(recovered.display_name == "Mara Vale" and recovered.load_notice.contains("backup"), "Readable backup recovers corrupted primary")
	write_json(invalid_path, {"version": 999, "future": "keep"})
	var future := Profile.new()
	future.path = invalid_path
	future.load_profile()
	check(future.set_display_name("New") != OK and JSON.parse_string(FileAccess.get_file_as_string(invalid_path)).future == "keep", "Newer save version preserved")
	check(Profile.clean_name("\n \t") == "Gunslinger" and Profile.clean_name("x".repeat(80)).length() == 24, "Name normalization and length limit")
	print("Profile data/statistics tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
