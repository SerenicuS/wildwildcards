extends SceneTree

const History = preload("res://scripts/MatchHistory.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
const Settings = preload("res://scripts/GameSettings.gd")
const PATH := "res://.godot/history_data_test.json"
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

func metadata(mode: String = "solo", run_id: String = "", duel: int = 0) -> Dictionary:
	return {"mode": mode, "difficulty": "hard", "arena": "ghost_town", "turn_seconds": 1.0, "run_id": run_id, "run_duel": duel,
		"actors": [{"name": "Mara Vale", "appearance": Looks.sanitize({"hat": "cavalry", "outfit_style": "poncho", "revolver_model": "python"})}, {"name": "Calico Finn", "appearance": Looks.defaults()}]}

func record(history: RefCounted, actions: Array) -> Array:
	var states := [{"ammo": 0, "shields": 0, "alive": true}, {"ammo": 0, "shields": 0, "alive": true}]
	var snapshots: Array = []
	for i in actions.size():
		var before := states.duplicate(true)
		var result := DuelRules.resolve(states[0], states[1], actions[i][0], actions[i][1])
		history.record_turn(i + 1, before, actions[i], result)
		snapshots.append({"before": before, "after": [result.left.duplicate(), result.right.duplicate()], "result": result.duplicate(true)})
		states = [result.left, result.right]
	return snapshots

func _initialize() -> void:
	var history := History.new()
	history.path = PATH
	if "--verify" in OS.get_cmdline_user_args():
		history.load_history()
		check(history.matches.size() == 3 and history.matches[0].sequence > history.matches[1].sequence, "History survives fresh process in newest-first order, including equal timestamps")
		check(history.matches[0].actors[0].appearance.revolver_model == "python" and history.matches[0].actors[0].appearance.outfit_style == "poncho", "Cosmetic snapshots persist independently")
		check(history.matches[0].turns.size() == 2 and history.matches[0].finisher == "high_noon", "Recorded turns and concrete finisher persist")
	else:
		check(history.max_matches == 100, "Default history retention is one hundred completed matches")
		check(History.text("X".repeat(100000), "Gunslinger", 24).length() == 24 and History.text("\n\t", "Gunslinger", 24) == "Gunslinger", "Oversized or control-only names are bounded and safe")
		history.path = "res://.godot/missing_history_test/absent.json"
		history.load_history()
		check(history.matches.is_empty(), "Missing history is safe")
		history.path = PATH
		history.begin_match(metadata())
		var snapshots := record(history, [[1,1],[3,3],[3,1],[2,3],[2,1],[2,1],[2,3]])
		check(history.matches.is_empty(), "Turns and shootout draws alone do not create a completed match")
		check(history.complete_match("wanted_eliminated") and history.matches.size() == 1, "Only an authoritative terminal duel is committed")
		check(not history.complete_match("wanted_eliminated") and history.matches.size() == 1, "Duplicate terminal callback cannot save twice")
		var saved: Dictionary = history.matches[0]
		check(saved.total_turns == 7 and saved.winner == 1 and saved.id.length() == 32, "Complete metadata and unique match ID")
		for i in snapshots.size():
			check(saved.turns[i].before == snapshots[i].before and saved.turns[i].after == snapshots[i].after, "Every ammo/shield/alive snapshot matches actual resolver output")
			check(saved.turns[i].actions == snapshots[i].result.actions and saved.turns[i].fired == snapshots[i].result.fired, "Actual effective actions and fired flags preserved")
		check(saved.turns[1].clash and not saved.turns[1].ended, "Shootout draw consumes both bullets but does not finish history")
		check(saved.turns[2].empty_shots[0] and saved.turns[2].after[0].ammo == 0, "Empty shot identified")
		check(saved.turns[3].blocked[1] and saved.turns[3].after[0].alive, "Actual blocked shot recorded")
		check(saved.turns[6].selected[0] == 2 and saved.turns[6].actions[0] == 0 and saved.turns[6].after[0].shields == 0, "Selected shield and authoritative fatigue/NONE retained separately")
		snapshots[0].before[0].ammo = 77
		check(saved.turns[0].before[0].ammo == 0, "Recording never retains mutable input references")
		var copy := history.find_match(saved.id)
		copy.actors[0].appearance.hat = "outlaw"
		check(history.matches[0].actors[0].appearance.hat == "cavalry", "Replay retrieval returns independent snapshots")
		history.begin_match(metadata())
		record(history, [[1,1],[3,3]])
		history.abandon_match()
		check(not history.complete_match("classic") and history.matches.size() == 1, "Abandoned partial duels are omitted")
		var run := history.begin_run()
		for duel in [1,2]:
			history.begin_match(metadata("gauntlet", run, duel))
			record(history, [[1,1],[3,1]] if duel == 1 else [[1,1],[1,3]])
			history.complete_match("high_noon")
		history.end_run(run, 1, "defeat")
		check(history.runs[run].streak == 1 and history.runs[run].ended_by == "Calico Finn" and history.runs[run].status == "defeat", "Gauntlet final streak and ending opponent grouped by run ID")
		check(history.matches[0].run_id == run and history.matches[1].run_id == run, "Individual Gauntlet duels share the run")
		var path := "res://.godot/history_corrupt_test.json"
		write(path, {"version": 1, "matches": [], "runs": {}})
		write(path + ".bak", {})
		history.path = path
		history.save_history()
		history.save_history() # previous valid primary becomes backup
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("{ broken")
		file.close()
		var recovered := History.new()
		recovered.path = path
		recovered.load_history()
		check(recovered.matches.size() == 3 and recovered.notice.contains("backup"), "Corrupt primary recovers complete history backup")
		var backup_bytes := FileAccess.get_file_as_bytes(path + ".bak")
		write(path, {"version": 1, "matches": [{"id": "corrupt"}], "runs": {}})
		history.save_history()
		check(FileAccess.get_file_as_bytes(path + ".bak") == backup_bytes, "Malformed edited primary cannot replace a good recovery backup")
		write(path, [])
		write(path + ".bak", false)
		recovered.load_history()
		check(recovered.matches.is_empty(), "Both corrupt/malformed files fail safely")
		write(path, {"version": 999, "matches": [], "runs": {}})
		recovered.load_history()
		check(recovered.save_history() != OK and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 999, "Unsupported newer version is never overwritten")
		write(path, {"version": 999, "new_collection_format": "preserve"})
		recovered = History.new()
		recovered.path = path
		recovered.load_history()
		check(recovered.save_history() != OK and JSON.parse_string(FileAccess.get_file_as_string(path)).new_collection_format == "preserve", "Future schema without current fields remains protected")
		var bad: Dictionary = saved.duplicate(true)
		bad.arena = "missing_arena"
		bad.actors[0].appearance.hat = "missing_hat"
		check(History.validate_record(bad).arena == History.Arenas.DEFAULT_ID and History.validate_record(bad).actors[0].appearance.hat == "classic", "Unavailable historical cosmetics/arena use safe fallbacks")
		bad.turns[2].before[0].ammo = 19
		check(History.validate_record(bad).is_empty(), "Inconsistent state continuity rejected")
		for malformed in [null, {}, {"id": "bad", "mode": "solo", "turns": []}, {"id": "bad", "mode": "local", "turns": [null]}]:
			check(History.validate_record(malformed).is_empty(), "Malformed match safely rejected")
		history.path = PATH
		history.max_matches = 3
		for i in range(6):
			history.begin_match(metadata("local" if i % 2 == 0 else "solo"))
			record(history, [[1,1],[3,1]])
			history.complete_match("high_noon")
		check(history.matches.size() == 3 and history.matches[0].sequence > history.matches[1].sequence and history.matches[1].sequence > history.matches[2].sequence, "Configured retention evicts whole matches in chronological order")
		check(not history.runs.has(run), "Unreferenced Gauntlet metadata evicted with old matches")
		var unwritable := History.new()
		unwritable.path = "res://.godot/missing_history_test/absent.json"
		unwritable.begin_match(metadata())
		record(unwritable, [[1,1],[3,1]])
		check(unwritable.complete_match("classic") and unwritable.last_error != OK and unwritable.matches.size() == 1 and not unwritable.notice.is_empty(), "Failed disk save keeps complete match available in memory with a notice")
		var config := ConfigFile.new()
		var settings_path := "res://.godot/history_limit_test.cfg"
		config.set_value("history", "max_matches", 7)
		config.set_value("audio", "master_volume", 0.37)
		config.save(settings_path)
		var settings := Settings.new()
		settings.path = settings_path
		settings.load_settings()
		check(settings.history_limit == 7 and is_equal_approx(settings.master_volume, 0.37), "Configurable retention loads without altering audio settings")
		settings.save_settings()
		config.load(settings_path)
		check(config.get_value("history", "max_matches") == 7, "Normal settings saves preserve the history limit")
		config.set_value("history", "max_matches", 5000)
		config.save(settings_path)
		settings.load_settings()
		check(settings.history_limit == 1000, "Configured retention respects a bounded safety ceiling")
		var async_store := History.new()
		async_store.path = "res://.godot/history_async_test.json"
		write(async_store.path, {"version": 1, "matches": [], "runs": {}})
		write(async_store.path + ".bak", {})
		async_store.max_matches = 3
		async_store.deferred_writes = true
		for i in range(6):
			async_store.begin_match(metadata())
			record(async_store, [[1,1],[3,1]])
			async_store.complete_match("high_noon")
		async_store.flush_history()
		var async_loaded := History.new()
		async_loaded.path = async_store.path
		async_loaded.load_history()
		check(async_loaded.matches.size() == 3 and async_loaded.matches[0].id == async_store.matches[0].id, "Coalesced background writes retain the latest complete bounded snapshot")
		check(async_store._writer == null and async_store._queued_payload.is_empty() and async_store.last_error == OK, "Flush joins worker and clears its bounded queue")
		write(async_store.path, {"version": 999, "future": "preserve externally changed file"})
		async_store.begin_match(metadata())
		record(async_store, [[1,1],[3,1]])
		async_store.complete_match("classic")
		async_store.flush_history()
		check(async_store.last_error == ERR_FILE_UNRECOGNIZED and JSON.parse_string(FileAccess.get_file_as_string(async_store.path)).future == "preserve externally changed file", "Worker protects a newer schema written externally after startup")
	print("Match history data: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
