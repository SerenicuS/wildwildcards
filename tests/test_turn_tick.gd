extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Audio = preload("res://scripts/AudioManager.gd")

class TickSpy extends Audio:
	var tick_count: int = 0
	func play_turn_tick() -> void:
		tick_count += 1
		super.play_turn_tick()

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func active_ticks(audio: Node) -> int:
	var count: int = 0
	for voice in audio.voices:
		if voice.playing and voice.stream == Audio.SOUNDS.tick:
			count += 1
	return count

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Main.new()
	game.profile.path = "res://.godot/test_tick_profile.json"
	root.add_child(game)
	game.set_process(false)
	game.audio.free()
	var audio := TickSpy.new()
	game.add_child(audio)
	game.audio = audio
	var voice: AudioStreamPlayer = audio.voices[Audio.VOICE_COUNT - 1]
	var stream: AudioStreamWAV = Audio.SOUNDS.tick
	check(stream != null and stream.get_length() > 0.0 and stream.get_length() < 0.1, "Short tick asset loads")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(voice.bus)) and audio.sfx_volume_db == 0.0,
		"Tick bus unmuted and SFX trim at normal default")
	# These checks cover the original 1.0 s mode (Hard); set in memory only.
	game.settings.set_difficulty("hard")
	game.start_duel()
	check(audio.tick_count == 0, "No ticking during introduction")
	game.intro_start = Time.get_ticks_usec() - 2800000
	game._process(0.0)
	check(game.turn == 1 and audio.tick_count == 1 and active_ticks(audio) == 1, "Exactly one tick on first gameplay turn")
	check(is_equal_approx(voice.volume_db, -20.0), "Tick has corrected audible gain")
	for sound in ["reload", "shield", "shoot_left", "shoot_right"]:
		var combat_gain: float = -14.0 + Audio.GAINS.get(sound, 0.0)
		check(voice.volume_db < combat_gain, "Tick quieter than " + sound)
	for i in range(20):
		game._process(0.0)
	check(audio.tick_count == 1, "Ordinary frames never duplicate tick")
	# Advance the actual turn deadlines; no separate tick timer exists.
	for i in range(3):
		var deadline: int = game.deadline
		game.selected = DuelRules.Action.RELOAD
		game.bot_action = DuelRules.Action.RELOAD
		game.advance_to(deadline)
		check(audio.tick_count == game.turn and game.deadline == deadline + 1000000,
			"One tick per turn, one-second deadlines preserved")
		check(active_ticks(audio) == 1, "Catch-up never layers ticking voices")
	# Even a saturated combat pool cannot replace or multiply the tick.
	for i in range(20):
		audio.play_effect("shoot_left")
	check(active_ticks(audio) == 1 and voice.playing, "Combat cannot steal tick voice")
	audio.sfx_volume_db = -3.0
	check(is_equal_approx(voice.volume_db, -23.0), "Tick respects existing volume control")
	audio.sfx_volume_db = 0.0
	game.last_pause_toggle_usec -= 60000 # Synthetic pause/resume respects existing debounce.
	game.toggle_pause()
	game._process(0.0)
	game.last_pause_toggle_usec -= 60000 # Synthetic pause/resume respects existing debounce.
	game.toggle_pause()
	check(audio.tick_count == game.turn, "Pause/resume adds no ticks")
	game.selected = DuelRules.Action.NONE
	game.bot_action = DuelRules.Action.SHOOT
	game.advance_to(game.deadline)
	var final_count: int = audio.tick_count
	check(game.state == Main.State.GAME_OVER and final_count == game.turn, "Fatal turn does not start another tick")
	check(active_ticks(audio) == 0, "Game over stops any remaining tick playback")
	game.advance_to(game.deadline + 5000000)
	game._process(0.0)
	check(audio.tick_count == final_count, "No ticking after match ends")
	game.start_duel()
	check(active_ticks(audio) == 0, "Rematch clears old tick playback")
	game.intro_start = Time.get_ticks_usec() - 2800000
	game._process(0.0)
	check(audio.tick_count == final_count + 1 and active_ticks(audio) == 1, "Rematch first turn ticks once")
	game.show_menu()
	check(active_ticks(audio) == 0, "Menu stops rhythm")
	if "--audition" in OS.get_cmdline_user_args():
		# Real-time playback via the actual game loop for a few uninterrupted turns.
		game.start_duel()
		game.intro_start = Time.get_ticks_usec() - 2800000
		game.set_process(true)
		await create_timer(3.2).timeout
		game.set_process(false)
		check(audio.tick_count > final_count + 1, "Real turn cycle triggers tick playback")
	print("Turn tick tests: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
