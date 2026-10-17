extends RefCounted

signal changed

const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Effects = preload("res://scripts/EliminationEffects.gd")
const VERSION: int = 5
const GAUNTLET_DEFAULTS := {"best_streak": 0, "total_runs": 0, "duel_victories": 0}
const TOURNAMENT_DEFAULTS := {"tournaments_played": 0, "tournaments_won": 0, "best_finish": "None"}
const FINISH_RANKS := {"None": 0, "Quarterfinals": 1, "Semifinals": 2, "Runner-Up": 3, "Champion": 4}
const STAT_KEYS := ["matches_played", "wins", "losses", "total_turns", "reload_actions", "shield_actions",
	"shoot_actions", "none_actions", "shots_fired", "successful_eliminations", "shots_blocked",
	"shield_turns_against_shoot", "reload_turns_against_shoot", "shootout_draws",
	"opponent_shots_fired", "total_shots_fired"]
var path: String = "user://profile.json"
var display_name: String = "Gunslinger"
var appearance: Dictionary = Appearance.defaults()
var outfit_presets: Array[Dictionary] = []
var equipped_elimination_effect: String = Effects.FALLBACK
var stats: Dictionary = {}
var gauntlet_records: Dictionary = GAUNTLET_DEFAULTS.duplicate()
var tournament_records: Dictionary = TOURNAMENT_DEFAULTS.duplicate()
var _gauntlet_active: bool = false
var _gauntlet_last_duel: int = 0
var load_notice: String = ""
var last_save_error: Error = OK
var _match_active: bool = false
var _last_turn: int = 0
var _dirty: bool = false
var _newer_version: bool = false
var _reset_revision: int = 0

func _revision(value: Dictionary) -> int:
	var revision: Variant = value.get("reset_revision", 0)
	return maxi(0, int(revision)) if (revision is int or revision is float) and is_finite(float(revision)) else 0

func _init() -> void:
	for key in STAT_KEYS:
		stats[key] = 0

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 262144:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary else {}

func load_profile() -> void:
	var saved := _read(path)
	var backup := _read(path + ".bak")
	if saved.is_empty():
		saved = backup
		if not saved.is_empty():
			load_notice = "Recovered profile from backup."
		elif FileAccess.file_exists(path):
			load_notice = "Unreadable profile. Using defaults."
	if saved.is_empty():
		return
	var version: Variant = saved.get("version", 0)
	if not (version is int or version is float) or version > VERSION:
		_newer_version = true
		load_notice = "Unsupported save version; original file preserved."
		return
	# A reset commits its new backup first. If shutdown interrupts the primary
	# replacement, prefer that newer reset over an otherwise readable old primary.
	var backup_version: Variant = backup.get("version", VERSION)
	if _revision(backup) > _revision(saved) and (backup_version is int or backup_version is float) \
			and backup_version >= 1 and backup_version <= VERSION:
		saved = backup
		load_notice = "Recovered confirmed reset from backup."
	_reset_revision = _revision(saved)
	display_name = clean_name(saved.get("display_name", "Gunslinger"))
	appearance = Appearance.sanitize(saved.get("appearance"))
	# Version 1 profiles receive safe cosmetic defaults. Version 2 stores the
	# three revolver IDs explicitly, while runtime portraits share one appearance.
	for key in Appearance.Revolver.defaults():
		if saved.has(key):
			appearance[key] = saved[key]
	appearance = Appearance.sanitize(appearance)
	var saved_presets: Variant = saved.get("outfit_presets", [])
	outfit_presets.clear()
	if saved_presets is Array:
		for preset in saved_presets.slice(0, 5):
			if preset is Dictionary and preset.get("appearance") is Dictionary:
				outfit_presets.append({"name": clean_name(preset.get("name", "Outfit")), "appearance": Appearance.sanitize(preset.appearance)})
	var effect: Variant = saved.get("equipped_elimination_effect", Effects.FALLBACK)
	equipped_elimination_effect = Effects.resolve_id(effect) if effect is String else Effects.FALLBACK
	var saved_stats: Variant = saved.get("stats", {})
	if saved_stats is Dictionary:
		for key in STAT_KEYS:
			var value: Variant = saved_stats.get(key, 0)
			if (value is float or value is int) and is_finite(float(value)):
				stats[key] = int(clampf(float(value), 0.0, 1000000000000.0))
	stats.matches_played = maxi(stats.matches_played, stats.wins + stats.losses)
	var saved_gauntlet: Variant = saved.get("gauntlet", {})
	if saved_gauntlet is Dictionary:
		for key in GAUNTLET_DEFAULTS:
			var value: Variant = saved_gauntlet.get(key, 0)
			if (value is int or value is float) and is_finite(float(value)):
				gauntlet_records[key] = int(clampf(float(value), 0.0, 1000000000000.0))
	var saved_tournament: Variant = saved.get("tournament", {})
	if saved_tournament is Dictionary:
		for key in ["tournaments_played", "tournaments_won"]:
			var value: Variant = saved_tournament.get(key, 0)
			if (value is int or value is float) and is_finite(float(value)):
				tournament_records[key] = int(clampf(float(value), 0.0, 1000000000000.0))
		var finish: Variant = saved_tournament.get("best_finish", "None")
		if finish is String and finish in FINISH_RANKS:
			tournament_records["best_finish"] = finish

static func clean_name(value: Variant) -> String:
	if not value is String:
		return "Gunslinger"
	var result := ""
	for character in value:
		if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
			result += character
	result = result.strip_edges().left(24)
	return "Gunslinger" if result.is_empty() else result

func win_rate() -> float:
	return 100.0 * stats.wins / stats.matches_played if stats.matches_played > 0 else 0.0

func save_profile(refresh_backup: bool = false) -> Error:
	if _newer_version:
		last_save_error = ERR_FILE_UNRECOGNIZED
		return last_save_error
	var payload := {"version": VERSION, "display_name": display_name, "appearance": appearance,
		"equipped_elimination_effect": equipped_elimination_effect, "stats": stats, "reset_revision": _reset_revision}
	payload.appearance = Appearance.sanitize(appearance)
	for key in Appearance.Revolver.defaults():
		payload.appearance.erase(key)
	payload.merge(Appearance.Revolver.sanitize(appearance))
	payload["outfit_presets"] = outfit_presets
	payload["gauntlet"] = gauntlet_records
	payload["tournament"] = tournament_records
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_save_error = FileAccess.get_open_error()
		return last_save_error
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	last_save_error = file.get_error()
	file.close()
	if last_save_error != OK:
		return last_save_error
	# Keep the last readable save. Never replace a good backup with corrupt data.
	var current := _read(path)
	if refresh_backup:
		last_save_error = DirAccess.copy_absolute(path + ".tmp", path + ".bak.tmp")
		if last_save_error == OK:
			last_save_error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if last_save_error != OK:
			return last_save_error
	elif not current.is_empty() and _revision(current) >= _reset_revision:
		last_save_error = DirAccess.copy_absolute(path, path + ".bak")
		if last_save_error != OK:
			return last_save_error
	last_save_error = DirAccess.rename_absolute(path + ".tmp", path)
	if last_save_error == OK:
		_dirty = false
	elif refresh_backup:
		# The reset is already durably committed in the newer backup. Keep it in
		# memory and retry the primary on the next save, rather than resurrecting it.
		_dirty = true
		return OK
	return last_save_error

func is_match_active() -> bool:
	return _match_active or _gauntlet_active

func begin_gauntlet_run() -> bool:
	if _gauntlet_active:
		return false
	abandon_match()
	_gauntlet_active = true
	_gauntlet_last_duel = 0
	gauntlet_records.total_runs += 1 # Count at start, never again on loss/exit.
	_save_gauntlet_records()
	return true

func record_gauntlet_victory(duel: int, streak: int) -> bool:
	if not _gauntlet_active or duel <= _gauntlet_last_duel or streak != _gauntlet_last_duel + 1 or duel != streak:
		return false
	_gauntlet_last_duel = duel
	gauntlet_records.duel_victories += 1
	gauntlet_records.best_streak = maxi(gauntlet_records.best_streak, streak)
	_save_gauntlet_records()
	return true

func end_gauntlet_run() -> bool:
	if not _gauntlet_active:
		return false
	_gauntlet_active = false
	if _dirty:
		save_profile()
	return true

func _save_gauntlet_records() -> void:
	_dirty = true
	save_profile()
	changed.emit()

func record_tournament_result(won_championship: bool, finish_position: String) -> void:
	tournament_records.tournaments_played += 1
	if won_championship:
		tournament_records.tournaments_won += 1
	var current_rank: int = int(FINISH_RANKS.get(tournament_records.best_finish, 0))
	var new_rank: int = int(FINISH_RANKS.get(finish_position, 0))
	if new_rank > current_rank:
		tournament_records.best_finish = finish_position
	_dirty = true
	save_profile()
	changed.emit()

func reset_stats() -> Error:
	return _reset(false)

func reset_profile() -> Error:
	return _reset(true)

func _reset(identity_too: bool) -> Error:
	if is_match_active():
		return ERR_BUSY
	var previous := {"name": display_name, "appearance": appearance.duplicate(), "effect": equipped_elimination_effect,
		"stats": stats.duplicate(), "gauntlet": gauntlet_records.duplicate(), "tournament": tournament_records.duplicate(), "presets": outfit_presets.duplicate(true), "revision": _reset_revision, "dirty": _dirty}
	for key in stats:
		stats[key] = 0
	gauntlet_records = GAUNTLET_DEFAULTS.duplicate()
	tournament_records = TOURNAMENT_DEFAULTS.duplicate()
	if identity_too:
		outfit_presets.clear()
		display_name = "Gunslinger"
		appearance = Appearance.defaults()
		equipped_elimination_effect = Effects.FALLBACK
	_reset_revision += 1
	var error := save_profile(true)
	if error != OK:
		display_name = previous.name
		appearance = previous.appearance
		equipped_elimination_effect = previous.effect
		stats = previous.stats
		gauntlet_records = previous.gauntlet
		tournament_records = previous.tournament
		outfit_presets = previous.presets
		_reset_revision = previous.revision
		_dirty = previous.dirty
		return error
	_last_turn = 0
	load_notice = ""
	changed.emit()
	return OK

func set_display_name(value: String) -> Error:
	var previous := display_name
	display_name = clean_name(value)
	var error := save_profile()
	if error != OK:
		display_name = previous
	else:
		changed.emit()
	return error

func equip(value: Dictionary) -> Error:
	return equip_loadout(value, equipped_elimination_effect)

func equip_loadout(value: Dictionary, effect: String) -> Error:
	if not Effects.LABELS.has(effect):
		return ERR_INVALID_PARAMETER
	var previous := appearance
	var previous_effect := equipped_elimination_effect
	var complete := value.duplicate()
	# Partial/legacy callers preserve fields they do not know about, including
	# expanded clothing and revolvers. Sanitization still rejects invalid IDs.
	for key in Appearance.defaults():
		if not complete.has(key):
			complete[key] = appearance.get(key, Appearance.defaults()[key])
	appearance = Appearance.sanitize(complete)
	equipped_elimination_effect = effect
	var error := save_profile()
	if error != OK:
		appearance = previous
		equipped_elimination_effect = previous_effect
	else:
		changed.emit()
	return error

func save_outfit_preset(caption: String, value: Dictionary) -> Error:
	if outfit_presets.size() >= 5:
		return ERR_OUT_OF_MEMORY
	return _commit_presets(outfit_presets + [{"name": clean_name(caption), "appearance": Appearance.sanitize(value)}])

func rename_outfit_preset(index: int, caption: String) -> Error:
	if index < 0 or index >= outfit_presets.size():
		return ERR_INVALID_PARAMETER
	var next := outfit_presets.duplicate(true)
	next[index].name = clean_name(caption)
	return _commit_presets(next)

func delete_outfit_preset(index: int) -> Error:
	if index < 0 or index >= outfit_presets.size():
		return ERR_INVALID_PARAMETER
	var next := outfit_presets.duplicate(true)
	next.remove_at(index)
	return _commit_presets(next)

func _commit_presets(next: Array) -> Error:
	var previous := outfit_presets
	outfit_presets = []
	outfit_presets.assign(next)
	var error := save_profile()
	if error != OK:
		outfit_presets = previous
	else:
		changed.emit()
	return error

func begin_match() -> void:
	abandon_match()
	_match_active = true
	_last_turn = 0

func abandon_match() -> void:
	_match_active = false
	if _dirty:
		save_profile()

func record_turn(turn: int, result: Dictionary) -> void:
	# This observer consumes authoritative resolved outcomes, never input events.
	if not _match_active or turn <= _last_turn:
		return
	_last_turn = turn
	_dirty = true
	stats.total_turns += 1
	var action: int = result.actions[0]
	stats[["none_actions", "reload_actions", "shield_actions", "shoot_actions"][action]] += 1
	stats.shots_fired += int(result.fired[0])
	stats.opponent_shots_fired += int(result.fired[1])
	stats.total_shots_fired += int(result.fired[0]) + int(result.fired[1])
	if action == DuelRules.Action.SHIELD:
		stats.shield_turns_against_shoot += int(result.actions[1] == DuelRules.Action.SHOOT)
		stats.shots_blocked += int(result.fired[1])
	if action == DuelRules.Action.RELOAD:
		stats.reload_turns_against_shoot += int(result.actions[1] == DuelRules.Action.SHOOT)
	stats.shootout_draws += int(result.clash)
	stats.successful_eliminations += int(result.fired[0] and not result.right.alive and not result.clash)
	if not result.left.alive or not result.right.alive:
		_match_active = false # Lock before saving or signaling; finish exactly once.
		stats.matches_played += 1
		stats.wins += int(result.left.alive)
		stats.losses += int(not result.left.alive)
		save_profile()
		changed.emit()
