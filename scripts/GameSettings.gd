extends RefCounted

var path: String = "user://settings.cfg"
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	master_volume = _volume(config.get_value("audio", "master_volume", 1.0))
	sfx_volume = _volume(config.get_value("audio", "sfx_volume", 1.0))
	var saved_fullscreen: Variant = config.get_value("display", "fullscreen", false)
	fullscreen = saved_fullscreen if saved_fullscreen is bool else false

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
