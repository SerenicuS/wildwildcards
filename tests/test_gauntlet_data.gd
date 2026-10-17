extends SceneTree

const Run = preload("res://scripts/GauntletRun.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const PATH := "res://.godot/gauntlet_data.json"
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _initialize() -> void:
	var run := Run.new()
	run.rng.seed = 503
	run.begin("medium")
	check(run.active and run.streak == 0 and not run.record_victory(), "Run starts at zero and cannot win an unprepared duel")
	check(run.pick_arena("only", ["only"]) == "only", "Single-arena fallback does not deadlock")
	check(run.pick_arena("", []) == Run.Arenas.DEFAULT_ID, "Empty registry fallback is safe")
	var arenas := {}
	var appearances := {}
	for i in range(250):
		var next := run.prepare_next()
		check(next.arena != run.arena_id and next.name != run.opponent.get("name", ""), "Consecutive opponents and arenas do not repeat")
		check(Appearance.sanitize(next.appearance) == next.appearance, "All generated cosmetics are valid catalog entries")
		check(run.enter_duel(next) and not run.enter_duel(next), "Duel entry cannot be replayed")
		check(run.prepare_next().is_empty(), "No next opponent is generated before winning")
		arenas[next.arena] = true
		appearances[hash(next.appearance)] = true
		check(run.record_victory() and not run.record_victory() and run.streak == i + 1, "Each resolved duel increments the streak exactly once")
	check(arenas.size() == 5 and appearances.size() > 100, "Run reuses all arenas and varied existing cosmetics")
	check(run.finish() and not run.finish() and not run.record_victory(), "Run finishes exactly once")
	run.begin("hard")
	check(run.streak == 0 and run.duel_number == 0 and run.difficulty == "hard", "A new run always resets current progression")
	for version in [1, 2]:
		write_json(PATH, {"version": version, "display_name": "Mara", "appearance": {"hat": "gambler"}, "stats": {"wins": 4, "matches_played": 4}})
		write_json(PATH + ".bak", {})
		var migrated := Profile.new()
		migrated.path = PATH
		migrated.load_profile()
		check(migrated.gauntlet_records == Profile.GAUNTLET_DEFAULTS and migrated.stats.wins == 4 and migrated.appearance.hat == "gambler", "Old profiles migrate without changing statistics or appearance")
	var profile := Profile.new()
	profile.path = PATH
	profile.stats.wins = 4
	profile.stats.matches_played = 4
	check(profile.begin_gauntlet_run() and not profile.begin_gauntlet_run() and profile.gauntlet_records.total_runs == 1, "A run is counted only at initial start")
	check(profile.is_match_active() and profile.reset_stats() == ERR_BUSY and profile.reset_profile() == ERR_BUSY, "Profile resets are blocked throughout active runs")
	check(not profile.record_gauntlet_victory(3, 3), "Out-of-order victory cannot create a personal best")
	check(profile.record_gauntlet_victory(1, 1) and not profile.record_gauntlet_victory(1, 1), "Persistent victories are deduplicated")
	check(profile.record_gauntlet_victory(2, 2) and profile.gauntlet_records.best_streak == 2 and profile.gauntlet_records.duel_victories == 2, "Best and cumulative wins use achieved streaks")
	check(profile.stats.wins == 4 and profile.stats.matches_played == 4, "Gauntlet records do not alter Solo counters")
	check(profile.end_gauntlet_run() and not profile.end_gauntlet_run(), "Finalization is idempotent")
	profile.begin_gauntlet_run()
	profile.end_gauntlet_run()
	check(profile.gauntlet_records.total_runs == 2 and profile.gauntlet_records.best_streak == 2, "An abandoned zero-win run preserves the best without adding a win")
	profile.save_profile()
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(json.version == Profile.VERSION and json.gauntlet.best_streak == 2, "Records use the versioned profile save")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ corrupted")
	file.close()
	var recovered := Profile.new()
	recovered.path = PATH
	recovered.load_profile()
	check(recovered.gauntlet_records == profile.gauntlet_records and recovered.stats.wins == 4, "Readable backup recovers gauntlet records and existing statistics")
	check(recovered.reset_stats() == OK and recovered.gauntlet_records == Profile.GAUNTLET_DEFAULTS, "Confirmed statistics reset includes gauntlet records")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var reset := Profile.new()
	reset.path = PATH
	reset.load_profile()
	check(reset.gauntlet_records == Profile.GAUNTLET_DEFAULTS, "Reset-safe backup cannot resurrect old gauntlet records")
	write_json(PATH, {"version": Profile.VERSION, "gauntlet": {"best_streak": -5, "total_runs": "bad", "duel_victories": 2}})
	write_json(PATH + ".bak", {})
	var invalid := Profile.new()
	invalid.path = PATH
	invalid.load_profile()
	check(invalid.gauntlet_records.best_streak == 0 and invalid.gauntlet_records.total_runs == 0 and invalid.gauntlet_records.duel_victories == 2, "Malformed records use nonnegative defaults")
	print("Gauntlet data: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
