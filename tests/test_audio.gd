extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Audio = preload("res://scripts/AudioManager.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func snapshot(ammo: int = 0, shields: int = 0) -> Dictionary:
	return {"ammo": ammo, "shields": shields, "alive": true}

func effects(manager: Node) -> Array[String]:
	var result: Array[String] = []
	for voice in manager.voices:
		if voice.playing:
			result.append(voice.stream.resource_path.get_file().get_basename())
	result.sort()
	return result

func verify(manager: Node, left: Dictionary, right: Dictionary, a: int, b: int,
		expected: Array, sting: String = "") -> void:
	manager.stop_all()
	manager.play_resolution(DuelRules.resolve(left, right, a, b))
	expected.sort()
	check(effects(manager) == expected, "Correct resolved sound events: %s" % str(expected))
	check(manager.sting_voice.playing == (sting != ""), "Sting only on elimination")
	if sting != "":
		check(manager.sting_voice.stream == Audio.SOUNDS[sting], "Correct winner sting")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manager := Audio.new()
	root.add_child(manager)
	for sound in Audio.SOUNDS:
		var stream: AudioStreamWAV = Audio.SOUNDS[sound]
		check(stream != null and stream.get_length() > 0.0, "WAV loads: " + sound)
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 22050, "Lightweight PCM format: " + sound)
	verify(manager, snapshot(), snapshot(), 1, 1, ["reload", "reload"])
	verify(manager, snapshot(), snapshot(), 2, 0, ["shield"])
	verify(manager, snapshot(), snapshot(), 3, 0, ["empty"])
	verify(manager, snapshot(), snapshot(), 3, 3, ["empty", "empty"])
	verify(manager, snapshot(1), snapshot(), 3, 1, ["shoot_left", "reload"], "victory")
	verify(manager, snapshot(), snapshot(1), 3, 3, ["empty", "shoot_right"], "defeat")
	verify(manager, snapshot(1), snapshot(1), 3, 3, ["shoot_left", "shoot_right"])
	check(Audio.SOUNDS.shoot_left.stereo and Audio.SOUNDS.shoot_right.stereo and
		Audio.SOUNDS.shoot_left.data != Audio.SOUNDS.shoot_right.data, "Shootout uses distinct stereo gunshots")
	verify(manager, snapshot(1), snapshot(), 3, 2, ["shoot_left", "shield", "impact"])
	verify(manager, snapshot(), snapshot(1), 2, 3, ["shield", "shoot_right", "impact"])
	verify(manager, snapshot(0, 3), snapshot(1), 2, 3, ["shoot_right"], "defeat")
	verify(manager, snapshot(), snapshot(), 0, 0, [])
	manager.stop_all()
	manager.play_turn_tick()
	check(effects(manager) == ["tick"], "Quiet rhythm tick")
	var tick_voice: AudioStreamPlayer = manager.voices[Audio.VOICE_COUNT - 1]
	check(is_equal_approx(tick_voice.volume_db, -20.0) and tick_voice.volume_db < -19.0,
		"Tick audible at -20 dB, below shield and other combat gains")
	manager.play_effect("reload")
	manager.sfx_volume_db = -8.0
	manager.music_volume_db = -10.0
	check(is_equal_approx(manager.sting_voice.volume_db, -25.0), "Independent music trim")
	for voice in manager.voices:
		check(is_equal_approx(voice.volume_db, -22.0 + voice.get_meta("gain_db", 0.0)), "SFX trim updates active voices")
	var node_count: int = manager.get_child_count()
	for i in range(100):
		manager.play_effect("shoot_left")
	check(manager.get_child_count() == node_count and node_count == 7, "Fixed playback pool under overlapping events")
	manager.stop_all()
	check(effects(manager).is_empty() and not manager.sting_voice.playing, "Stop clears rematch/menu audio")
	manager.queue_free()
	await process_frame
	var game = Main.new()
	game.profile.path = "res://.godot/test_audio_profile.json"
	root.add_child(game)
	game.set_process(false)
	check(ProjectSettings.get_setting("application/config/name") == "Wild Wild Cards", "Project renamed")
	check(game.main_menu.title_label.text.replace("\n", " ") == "WILD WILD CARDS", "Main menu renamed")
	check(root.title == "Wild Wild Cards", "Window title follows branding")
	check(OS.get_user_data_dir().replace("\\", "/").ends_with("Godot/app_userdata/Card Gunslinger"), "Legacy saved-settings path preserved")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/audio_brand_preview.png")
	game.start_duel()
	game.intro_start = Time.get_ticks_usec() - 2800000
	game._process(0.0)
	check(effects(game.audio) == ["tick"], "Turn start plays rhythm cue")
	game.audio.stop_all()
	game.submit_action(1)
	game.submit_action(3)
	check(effects(game.audio).is_empty(), "Action selection is silent")
	game.submit_action(1)
	game.bot_action = 1
	game.deadline = Time.get_ticks_usec() + 1000000
	var first_deadline: int = game.deadline
	var test_timeout: int = Time.get_ticks_usec() + 2500000
	game.set_process(true)
	# SceneTreeTimer uses frame deltas; gameplay uses monotonic deadlines. Wait
	# for the actual transition and inspect sounds before the 40 ms tick ends.
	while game.turn == 1 and Time.get_ticks_usec() < test_timeout:
		await process_frame
	game.set_process(false)
	check(game.turn == 2 and game.player.ammo == 1 and game.opponent.ammo == 1,
		"Audio does not delay next one-second turn")
	check(game.deadline == first_deadline + 1000000 and Time.get_ticks_usec() >= first_deadline,
		"Audio preserves absolute one-second deadlines")
	check(effects(game.audio) == ["reload", "reload", "tick"], "Resolved simultaneous actions overlap with next tick")
	game.show_menu()
	check(effects(game.audio).is_empty(), "Menu stops remaining match audio")
	if "--audition" in OS.get_cmdline_user_args():
		for sound in Audio.SOUNDS:
			game.audio.stop_all()
			if sound in ["victory", "defeat"]:
				game.audio.sting_voice.stream = Audio.SOUNDS[sound]
				game.audio.sting_voice.play()
			else:
				game.audio.play_effect(sound)
			await create_timer(Audio.SOUNDS[sound].get_length() + 0.1).timeout
	print("Audio/branding tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
