extends RefCounted

# An observer of resolved snapshots. Never calls the resolver or bot.
const VERSION := 1
const MAX_BYTES := 16777216
const MAX_TURNS := 10000
const Looks = preload("res://scripts/CharacterAppearance.gd")
const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const Effects = preload("res://scripts/EliminationEffects.gd")
var path := "user://match_history.json"
var max_matches: int = 100
var deferred_writes := false
var _writer: Thread
var _queued_payload := ""
var matches: Array[Dictionary] = [] # newest completed duel first
var runs: Dictionary = {}
var notice := ""
var last_error: Error = OK
var _pending: Dictionary = {}
var _active_run := ""
var _read_only := false
var _sequence: int = 0
var _trusted_primary_hash := ""

static func unique_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func text(value: Variant, fallback: String = "", limit: int = 64) -> String:
	if not value is String:
		return fallback
	var clean := ""
	for character in value.left(limit * 4):
		if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
			clean += character
	clean = clean.strip_edges().left(limit)
	return fallback if clean.is_empty() else clean

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

static func state(value: Variant) -> Dictionary:
	if not value is Dictionary or not integer(value.get("ammo"), 0, 1000000000) or not integer(value.get("shields"), 0, 3) or not value.get("alive") is bool:
		return {}
	return {"ammo": int(value.ammo), "shields": int(value.shields), "alive": value.alive}

static func pair(value: Variant, boolean: bool = false) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for item in value:
		if (boolean and not item is bool) or (not boolean and not integer(item, 0, 3)):
			return false
	return true

static func actor(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var look := Looks.sanitize(source.get("appearance"))
	return {"name": text(source.get("name"), "Gunslinger", 24), "appearance": look,
		"coat": Color.from_string(text(source.get("coat")), Looks.COLORS[look.outfit]).to_html()}

static func validate_record(value: Variant) -> Dictionary:
	if not value is Dictionary or text(value.get("id")).is_empty() or not value.get("mode") in ["solo", "local", "gauntlet", "tournament"]:
		return {}
	var turns: Variant = value.get("turns")
	var actors: Variant = value.get("actors")
	if not turns is Array or turns.is_empty() or turns.size() > MAX_TURNS or not actors is Array or actors.size() != 2:
		return {}
	if not integer(value.get("timestamp"), 0, 32503680000) or not integer(value.get("winner"), 0, 2):
		return {}
	var clean_turns: Array = []
	for i in turns.size():
		var turn: Variant = turns[i]
		if not turn is Dictionary or turn.get("number") != i + 1 or not pair(turn.get("selected")) or not pair(turn.get("actions")):
			return {}
		for key in ["fired", "blocked", "empty_shots"]:
			if not pair(turn.get(key), true):
				return {}
		if not turn.get("clash") is bool or not turn.get("ended") is bool or not integer(turn.get("winner"), -1, 2):
			return {}
		for key in ["before", "after"]:
			if not turn.get(key) is Array or turn[key].size() != 2 or state(turn[key][0]).is_empty() or state(turn[key][1]).is_empty():
				return {}
		var before := [state(turn.before[0]), state(turn.before[1])]
		var after := [state(turn.after[0]), state(turn.after[1])]
		if not before[0].alive or not before[1].alive or (i > 0 and before != clean_turns[-1].after):
			return {}
		var ended: bool = not after[0].alive or not after[1].alive
		var winner: int = (0 if after[0].alive else (1 if after[1].alive else 2)) if ended else -1
		if turn.ended != ended or turn.winner != winner or ended != (i == turns.size() - 1):
			return {}
		clean_turns.append({"number": i + 1, "selected": [int(turn.selected[0]), int(turn.selected[1])],
			"actions": [int(turn.actions[0]), int(turn.actions[1])], "before": before, "after": after,
			"fired": turn.fired.duplicate(), "blocked": turn.blocked.duplicate(), "empty_shots": turn.empty_shots.duplicate(),
			"clash": turn.clash, "ended": ended, "winner": winner})
	if value.winner != clean_turns[-1].winner:
		return {}
	var seconds: Variant = value.get("turn_seconds", 1.0)
	var finisher := Effects.resolve_id(text(value.get("finisher")))
	if finisher == "random": finisher = Effects.FALLBACK # Replays require a concrete effect.
	return {"id": text(value.id), "timestamp": int(value.timestamp), "mode": value.mode,
		"sequence": int(value.get("sequence", 0)) if integer(value.get("sequence", 0), 0, 1000000000000) else 0,
		"difficulty": text(value.get("difficulty")), "arena": Arenas.definition(text(value.get("arena"))).id,
		"actors": [actor(actors[0]), actor(actors[1])], "winner": int(value.winner), "total_turns": clean_turns.size(),
		"turn_seconds": float(seconds) if (seconds is int or seconds is float) and is_finite(float(seconds)) and seconds >= 0.1 and seconds <= 10.0 else 1.0,
		"finisher": finisher, "run_id": text(value.get("run_id")),
		"run_duel": int(value.get("run_duel", 0)) if integer(value.get("run_duel", 0), 0, 1000000000) else 0,
		"turns": clean_turns}

static func _read(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if integer(data.get("version"), VERSION + 1, 1000000):
		return data # Future schemas may not have today's collection fields.
	return data if integer(data.get("version"), 1, 1000000) and data.get("matches") is Array and data.get("runs") is Dictionary else {}

func load_history() -> void:
	matches.clear()
	runs.clear()
	_trusted_primary_hash = ""
	var data := _read(path)
	var primary_loaded := not data.is_empty()
	if data.is_empty():
		data = _read(path + ".bak")
		if not data.is_empty():
			notice = "Recovered history from backup."
		elif FileAccess.file_exists(path):
			notice = "Unreadable history; using an empty history."
	if data.is_empty():
		return
	if data.version != VERSION:
		_read_only = true
		notice = "Unsupported history version; original file preserved."
		return
	var seen := {}
	for value in data.matches.slice(0, 1000):
		var record := validate_record(value)
		if record.is_empty() or seen.has(record.id):
			continue
		matches.append(record)
		_sequence = maxi(_sequence, record.sequence)
		seen[record.id] = true
	matches.sort_custom(func(a: Dictionary, b: Dictionary): return a.sequence > b.sequence if a.sequence != b.sequence else a.timestamp > b.timestamp)
	if matches.size() < data.matches.size() and notice.is_empty():
		notice = "Invalid or duplicate history entries were omitted."
	if primary_loaded and matches.size() == data.matches.size():
		_trusted_primary_hash = FileAccess.get_sha256(path)
	for id in data.runs.keys().slice(0, 1000):
		var run: Variant = data.runs[id]
		if not id is String or not run is Dictionary or not integer(run.get("timestamp"), 0, 32503680000) or not integer(run.get("streak"), 0, 1000000000):
			continue
		runs[text(id)] = {"id": text(id), "timestamp": int(run.timestamp), "streak": int(run.streak),
			"ended_by": text(run.get("ended_by")), "status": "interrupted" if run.get("status") == "active" else text(run.get("status"), "interrupted")}
	_trim()

func _trim() -> void:
	while matches.size() > clampi(max_matches, 1, 1000):
		matches.pop_back()
	var referenced := {_active_run: true}
	for record in matches:
		referenced[record.run_id] = true
	for id in runs.keys():
		if not referenced.has(id):
			runs.erase(id)

func _encode() -> String:
	if _read_only:
		last_error = ERR_FILE_UNRECOGNIZED
		notice = "Unsupported history version; original file preserved."
		return ""
	_trim()
	var encoded := JSON.stringify({"version": VERSION, "matches": matches, "runs": runs})
	while encoded.to_utf8_buffer().size() > MAX_BYTES and matches.size() > 1:
		matches.pop_back()
		_trim()
		encoded = JSON.stringify({"version": VERSION, "matches": matches, "runs": runs})
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		last_error = ERR_OUT_OF_MEMORY
		notice = "History exceeds its 16 MiB storage safety limit."
		return ""
	return encoded

static func _write_payload(encoded: String, destination: String, trusted_hash: String) -> Dictionary:
	# Worker touches local immutable payload/file data only, never scene nodes or
	# the live collections. Revalidate an externally modified primary before backup.
	var digest := FileAccess.get_sha256(destination) if FileAccess.file_exists(destination) else ""
	var backup_safe := not digest.is_empty() and digest == trusted_hash
	if not backup_safe:
		var old := _read(destination)
		if not old.is_empty() and old.version > VERSION:
			return {"error": ERR_FILE_UNRECOGNIZED, "hash": ""}
		backup_safe = not old.is_empty() and old.version == VERSION and old.matches.all(func(value: Variant): return not validate_record(value).is_empty())
	var file := FileAccess.open(destination + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"error": FileAccess.get_open_error(), "hash": ""}
	file.store_string(encoded)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK and backup_safe:
		error = DirAccess.copy_absolute(destination, destination + ".bak")
	if error == OK:
		error = DirAccess.rename_absolute(destination + ".tmp", destination)
	return {"error": error, "hash": FileAccess.get_sha256(destination) if error == OK else ""}

func _adopt_write(result: Dictionary) -> void:
	last_error = result.error
	if last_error == OK:
		_trusted_primary_hash = result.hash
		if notice == "Could not save history; retained in this session.": notice = ""
	elif last_error == ERR_FILE_UNRECOGNIZED:
		_read_only = true
		notice = "Unsupported history version; original file preserved."
	else:
		notice = "Could not save history; retained in this session."

func save_history() -> Error:
	flush_history()
	var encoded := _encode()
	if not encoded.is_empty(): _adopt_write(_write_payload(encoded, path, _trusted_primary_hash))
	return last_error

func _start_write(encoded: String) -> void:
	var destination := path
	var digest := _trusted_primary_hash
	_writer = Thread.new()
	var error := _writer.start(func(): return _write_payload(encoded, destination, digest))
	if error != OK:
		_writer = null
		_adopt_write(_write_payload(encoded, destination, digest))

func _persist() -> void:
	if not deferred_writes:
		save_history()
		return
	poll_history()
	var encoded := _encode()
	if encoded.is_empty(): return
	if _writer == null: _start_write(encoded)
	else: _queued_payload = encoded # One coalesced latest snapshot, never an unbounded queue.

func poll_history() -> void:
	if _writer != null and not _writer.is_alive():
		_adopt_write(_writer.wait_to_finish())
		_writer = null
		_start_queued()

func _start_queued() -> void:
	var encoded := _queued_payload
	_queued_payload = ""
	if not encoded.is_empty() and not _read_only: _start_write(encoded)

func flush_history() -> void:
	# Used at application shutdown and explicit synchronous save boundaries.
	while _writer != null:
		_adopt_write(_writer.wait_to_finish())
		_writer = null
		_start_queued()

func begin_match(metadata: Dictionary) -> void:
	_pending = metadata.duplicate(true)
	_pending.id = unique_id()
	_pending.turns = []

func abandon_match() -> void:
	_pending.clear()

func record_turn(number: int, before: Array, selected: Array, result: Dictionary) -> void:
	if _pending.is_empty() or number != _pending.turns.size() + 1 or (not _pending.turns.is_empty() and _pending.turns[-1].ended):
		return
	if _pending.turns.size() >= MAX_TURNS:
		_pending.clear()
		notice = "Duel exceeded the 10,000-turn recording limit; no partial replay saved."
		return
	var ended: bool = not result.left.alive or not result.right.alive
	_pending.turns.append({"number": number, "selected": selected.duplicate(), "actions": result.actions.duplicate(),
		"before": before.duplicate(true), "after": [result.left.duplicate(), result.right.duplicate()],
		"fired": result.fired.duplicate(), "blocked": [result.fired[0] and result.actions[1] == 2, result.fired[1] and result.actions[0] == 2],
		"empty_shots": [result.actions[0] == 3 and not result.fired[0], result.actions[1] == 3 and not result.fired[1]],
		"clash": result.clash, "ended": ended, "winner": (0 if result.left.alive else (1 if result.right.alive else 2)) if ended else -1})

func complete_match(finisher: String) -> bool:
	if _pending.is_empty() or _pending.turns.is_empty() or not _pending.turns[-1].ended:
		return false
	_pending.timestamp = int(Time.get_unix_time_from_system())
	_sequence += 1
	_pending.sequence = _sequence
	_pending.winner = _pending.turns[-1].winner
	_pending.finisher = finisher
	var record := validate_record(_pending)
	_pending.clear() # Consume before persistence or callbacks; never count twice.
	if record.is_empty():
		notice = "Invalid recording omitted from history."
		return false
	matches.push_front(record)
	if runs.has(record.run_id):
		var run: Dictionary = runs[record.run_id]
		run.streak = record.run_duel if record.winner == 0 else maxi(0, record.run_duel - 1)
		if record.winner != 0:
			run.ended_by = record.actors[1].name
			run.status = "defeat"
			if _active_run == record.run_id: _active_run = ""
	_persist()
	return true

func begin_run() -> String:
	_active_run = unique_id()
	runs[_active_run] = {"id": _active_run, "timestamp": int(Time.get_unix_time_from_system()), "streak": 0, "ended_by": "", "status": "active"}
	_persist()
	return _active_run

func end_run(id: String, streak: int, status: String = "abandoned", ended_by: String = "") -> void:
	var changed := _active_run == id
	if runs.has(id):
		var previous: Dictionary = runs[id].duplicate()
		runs[id].streak = streak
		if runs[id].status == "active":
			runs[id].status = status
		if not ended_by.is_empty(): runs[id].ended_by = text(ended_by)
		changed = changed or previous != runs[id]
	if _active_run == id: _active_run = ""
	if changed or last_error != OK: _persist()

func find_match(id: String) -> Dictionary:
	for record in matches:
		if record.id == id:
			return record.duplicate(true)
	return {}
