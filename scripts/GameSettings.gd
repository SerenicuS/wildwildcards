extends RefCounted

const Arenas = preload("res://scripts/ArenaDefinitions.gd")

# Turn-speed presets. Difficulty changes ONLY the authoritative turn duration.
const DIFFICULTY_ORDER: Array[String] = ["easy", "medium", "hard"]
const DIFFICULTIES := {
	"easy": {"label": "EASY", "turn_usec": 2000000},
	"medium": {"label": "MEDIUM", "turn_usec": 1500000},
	"hard": {"label": "HARD", "turn_usec": 1000000},
}
const DEFAULT_DIFFICULTY := "medium"
# Settings files written before difficulty existed always played 1.0 s turns.
const LEGACY_DIFFICULTY := "hard"

var path: String = "user://settings.cfg"
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false
var difficulty: String = DEFAULT_DIFFICULTY
var preferred_arena: String = Arenas.DEFAULT_ID
var history_limit: int = 100

static func difficulty_turn_usec(id: String) -> int:
	return DIFFICULTIES.get(id, DIFFICULTIES[DEFAULT_DIFFICULTY]).turn_usec

static func difficulty_text(id: String) -> String:
	return "%s  ·  %.1f s per turn" % [DIFFICULTIES[id].label, difficulty_turn_usec(id) / 1000000.0]

func turn_usec() -> int:
	return difficulty_turn_usec(difficulty)

func set_difficulty(id: String) -> bool:
	if not DIFFICULTIES.has(id):
		return false
	difficulty = id
	return true

func set_arena(id: String) -> bool:
	if not Arenas.valid_preference(id):
		return false
	preferred_arena = id
	return true

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		# No settings file yet: a new installation.
		difficulty = DEFAULT_DIFFICULTY
		preferred_arena = Arenas.DEFAULT_ID
		return
	var saved_arena: Variant = config.get_value("cosmetics", "arena", Arenas.DEFAULT_ID)
	var saved_limit: Variant = config.get_value("history", "max_matches", 100)
	if (saved_limit is int or saved_limit is float) and is_finite(float(saved_limit)):
		history_limit = clampi(int(saved_limit), 1, 1000)
	preferred_arena = saved_arena if Arenas.valid_preference(saved_arena) else Arenas.DEFAULT_ID
	master_volume = _volume(config.get_value("audio", "master_volume", 1.0))
	sfx_volume = _volume(config.get_value("audio", "sfx_volume", 1.0))
	var saved_fullscreen: Variant = config.get_value("display", "fullscreen", false)
	fullscreen = saved_fullscreen if saved_fullscreen is bool else false
	if not config.has_section_key("gameplay", "difficulty"):
		# Migrated install: keep the original one-second gameplay.
		difficulty = LEGACY_DIFFICULTY
	else:
		var saved_difficulty: Variant = config.get_value("gameplay", "difficulty")
		difficulty = saved_difficulty if saved_difficulty is String and DIFFICULTIES.has(saved_difficulty) else DEFAULT_DIFFICULTY

func _volume(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return 1.0

func save_settings() -> Error:
	# Retain any unrelated settings already stored in this file.
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("gameplay", "difficulty", difficulty)
	config.set_value("cosmetics", "arena", preferred_arena)
	config.set_value("history", "max_matches", history_limit)
	return config.save(path)

func apply_audio(audio: Node) -> void:
	var master: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(master, master_volume <= 0.0)
	audio.sfx_volume_db = maxf(-80.0, linear_to_db(maxf(sfx_volume, 0.0001)))

func is_fullscreen() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func apply_display() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	# Editor-embedded windows can reject the request. Never report success from
	# the saved preference alone; keep it for the next standalone launch.
	return is_fullscreen() == fullscreen
