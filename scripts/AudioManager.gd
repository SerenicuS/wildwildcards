extends Node

# Trim controls are independent and may attenuate, never remove mix headroom.
var sfx_volume_db: float = 0.0:
	set(value):
		sfx_volume_db = clampf(value, -80.0, 0.0)
		for voice in voices:
			voice.volume_db = -14.0 + sfx_volume_db + voice.get_meta("gain_db", 0.0)
var music_volume_db: float = 0.0:
	set(value):
		music_volume_db = clampf(value, -80.0, 0.0)
		if sting_voice:
			sting_voice.volume_db = -15.0 + music_volume_db

const VOICE_COUNT: int = 6
const SOUNDS := {
	"stamp": preload("res://assets/audio/stamp.wav"),
	"reload": preload("res://assets/audio/reload.wav"),
	"shoot_left": preload("res://assets/audio/shoot_left.wav"),
	"shoot_right": preload("res://assets/audio/shoot_right.wav"),
	"empty": preload("res://assets/audio/empty.wav"),
	"shield": preload("res://assets/audio/shield.wav"),
	"impact": preload("res://assets/audio/impact.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
	"tick": preload("res://assets/audio/tick.wav"),
}
const GAINS := {"reload": -2.0, "empty": -3.0, "shield": -5.0, "impact": -2.0, "tick": -6.0}
var voices: Array[AudioStreamPlayer] = []
var sting_voice: AudioStreamPlayer
var next_voice: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	sting_voice = AudioStreamPlayer.new()
	sting_voice.volume_db = -15.0 + music_volume_db
	add_child(sting_voice)

func play_effect(sound: String) -> void:
	# Reserve the last existing voice for the rhythm. Combat cannot steal it,
	# and catching up elapsed turns replaces a tick instead of layering ticks.
	var voice: AudioStreamPlayer = voices[VOICE_COUNT - 1]
	if sound != "tick":
		voice = voices[next_voice]
		for i in range(VOICE_COUNT - 1):
			if not voices[i].playing:
				voice = voices[i]
				break
		next_voice = (next_voice + 1) % (VOICE_COUNT - 1)
	voice.stop()
	voice.stream = SOUNDS[sound]
	voice.set_meta("gain_db", GAINS.get(sound, 0.0))
	voice.volume_db = -14.0 + sfx_volume_db + GAINS.get(sound, 0.0)
	voice.play()

func play_turn_tick() -> void:
	play_effect("tick")

func play_resolution(result: Dictionary) -> void:
	for i in range(2):
		match result.actions[i]:
			DuelRules.Action.RELOAD:
				play_effect("reload")
			DuelRules.Action.SHIELD:
				play_effect("shield")
			DuelRules.Action.SHOOT:
				if result.fired[i]:
					play_effect("shoot_left" if i == 0 else "shoot_right")
					if not result.clash and result.actions[1 - i] == DuelRules.Action.SHIELD:
						# The impact sample contains its own tiny offset, no duplicate gunshot.
						play_effect("impact")
				else:
					play_effect("empty")
	if not result.left.alive or not result.right.alive:
		voices[VOICE_COUNT - 1].stop()
		sting_voice.stop()
		sting_voice.stream = SOUNDS["victory" if result.left.alive else "defeat"]
		sting_voice.play()

func stop_effect(sound: String) -> void:
	for voice in voices:
		if voice.stream == SOUNDS.get(sound):
			voice.stop()

func stop_all() -> void:
	for voice in voices:
		voice.stop()
	sting_voice.stop()

func _exit_tree() -> void:
	stop_all()
