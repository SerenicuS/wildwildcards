extends CanvasLayer

# Read-only rendering. No profile, participant, bot or live manager references.
signal closed
const History = preload("res://scripts/MatchHistory.gd")
const Arenas = preload("res://scripts/ArenaDefinitions.gd")
var record: Dictionary = {}
var sfx_trim: float = 0.0
var music_trim: float = 0.0
var arena: Node2D
var audio: Node
var finisher: CanvasLayer
var design: Control
var turn_label: Label
var state_label: Label
var outcome_label: Label
var buttons: Dictionary = {}
var speed_picker: OptionButton
var index: int = -1
var speed: float = 1.0
var playing := false
var elapsed := 0.0
var _animate := false
var _finisher_started := false
var _finisher_done := false
var _closing := false

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	record = History.validate_record(record)
	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	design = Control.new()
	design.size = Vector2(1280, 720)
	surface.add_child(design)
	surface.resized.connect(func(): design.position = (surface.size - design.size) / 2)
	design.position = (surface.size - design.size) / 2
	arena = preload("res://scripts/Arena.gd").new()
	design.add_child(arena)
	arena.set_process(false)
	audio = preload("res://scripts/AudioManager.gd").new()
	add_child(audio)
	audio.sfx_volume_db = sfx_trim
	audio.music_volume_db = music_trim
	finisher = preload("res://scripts/EliminationController.gd").new()
	finisher.audio = audio
	add_child(finisher)
	finisher.finished.connect(func():
		_finisher_done = true
		_set_playing(false))
	_panel(Rect2(20, 16, 1240, 159))
	_panel(Rect2(20, 537, 1240, 165))
	if record.is_empty():
		_label("Replay unavailable: invalid or incomplete recording.", Rect2(40, 40, 1200, 40), 24)
		_button("back", "RETURN TO HISTORY", Rect2(880, 640, 340, 42), close)
		return
	arena.set_arena_id(record.arena)
	arena.set_player_appearance(record.actors[0].appearance)
	var opponent: Dictionary = record.actors[1].appearance.duplicate()
	opponent.coat_color = Color.from_string(record.actors[1].coat, Color("ec8b73"))
	arena.set_opponent_appearance(opponent)
	var mode_name: String = "LOCAL / OFFLINE" if record.mode == "local" else str(record.mode).to_upper()
	_label("REPLAY · %s · %s · %s" % [mode_name, Arenas.definition(record.arena).name, record.difficulty.to_upper()], Rect2(40, 28, 1200, 32), 21)
	_label("%s   vs   %s" % [record.actors[0].name, record.actors[1].name], Rect2(40, 67, 1200, 32), 23)
	state_label = _label("", Rect2(40, 111, 1200, 52), 18)
	turn_label = _label("", Rect2(40, 549, 1200, 28), 20)
	outcome_label = _label("", Rect2(40, 582, 1200, 30), 16)
	outcome_label.size.y = 46
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("previous", "< PREVIOUS", Rect2(40, 640, 160, 42), func(): seek(index - 1))
	_button("next", "NEXT >", Rect2(212, 640, 130, 42), func(): seek(index + 1))
	_button("play", "PLAY", Rect2(354, 640, 125, 42), toggle_play)
	_button("restart", "RESTART", Rect2(491, 640, 140, 42), restart)
	speed_picker = OptionButton.new()
	speed_picker.position = Vector2(648, 640)
	speed_picker.size = Vector2(135, 42)
	speed_picker.focus_mode = Control.FOCUS_NONE
	for caption in ["0.5x", "1x", "2x"]:
		speed_picker.add_item(caption)
	speed_picker.select(1)
	speed_picker.item_selected.connect(func(selection: int): set_speed([0.5, 1.0, 2.0][selection]))
	design.add_child(speed_picker)
	_button("back", "RETURN TO HISTORY", Rect2(880, 640, 340, 42), close)
	seek(0)

func _panel(rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("18212f")
	style.border_color = Color("ba9467")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	design.add_child(panel)

func _label(value: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f1d7ac"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(label)
	return label

func _button(id: String, caption: String, rect: Rect2, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	design.add_child(button)
	buttons[id] = button

func seek(next_index: int) -> void:
	if record.is_empty():
		return
	_set_playing(false)
	finisher.cancel()
	audio.stop_all()
	_finisher_started = false
	_finisher_done = false
	elapsed = 0.0
	index = clampi(next_index, -1, record.turns.size() - 1)
	arena.reset()
	arena.active = true
	if index == -1:
		arena.effect_age = 10.0
		_state_text(record.turns[0].before)
		outcome_label.text = "Initial state · recorded actions only; no bot decisions are regenerated."
	else:
		var turn: Dictionary = record.turns[index]
		arena.reveal(_result(turn))
		_state_text(turn.after, turn.before)
		outcome_label.text = _events(turn)
		_animate = true
		audio.play_resolution(_result(turn))
	turn_label.text = "TURN %d / %d · %s" % [index + 1, record.total_turns, "INITIAL STATE" if index < 0 else " / ".join([DuelRules.NAMES[record.turns[index].actions[0]], DuelRules.NAMES[record.turns[index].actions[1]]])]
	buttons.previous.disabled = index == -1
	buttons.next.disabled = index == record.turns.size() - 1

func _result(turn: Dictionary) -> Dictionary:
	return {"left": turn.after[0].duplicate(), "right": turn.after[1].duplicate(),
		"actions": turn.actions.duplicate(), "fired": turn.fired.duplicate(), "clash": turn.clash}

func _state_text(states: Array, before: Array = []) -> void:
	if before.is_empty(): before = states
	state_label.text = "Ammo:  %s %d → %d   |   %s %d → %d\nShield streak:  %d → %d   |   %d → %d" % [record.actors[0].name, before[0].ammo, states[0].ammo, record.actors[1].name, before[1].ammo, states[1].ammo, before[0].shields, states[0].shields, before[1].shields, states[1].shields]

func _events(turn: Dictionary) -> String:
	var events: Array[String] = []
	for i in range(2):
		if turn.selected[i] != turn.actions[i]: events.append("%s: shield fatigue" % record.actors[i].name)
		if turn.empty_shots[i]: events.append("%s: empty shot" % record.actors[i].name)
		elif turn.blocked[i]: events.append("%s: shot blocked" % record.actors[i].name)
		elif turn.fired[i]: events.append("%s: fired" % record.actors[i].name)
	if turn.clash: events.append("SHOOTOUT · both survive")
	if turn.ended: events.append("DRAW" if turn.winner == 2 else "%s WINS" % record.actors[turn.winner].name)
	return " · ".join(events) if not events.is_empty() else "Duel continues."

func restart() -> void:
	seek(-1)

func _set_playing(value: bool) -> void:
	playing = value
	_animate = value
	if buttons.has("play"):
		buttons.play.text = "PAUSE" if value else "PLAY"
	if is_instance_valid(finisher) and finisher.active and finisher.tween:
		if value: finisher.tween.play()
		else: finisher.tween.pause()

func toggle_play() -> void:
	if record.is_empty(): return
	if playing:
		_set_playing(false)
		return
	if _finisher_done:
		seek(-1)
	if index == -1:
		seek(0)
	_set_playing(true)

func set_speed(value: float) -> void:
	if not value in [0.5, 1.0, 2.0]: return
	speed = value
	if is_instance_valid(finisher) and finisher.tween:
		finisher.tween.set_speed_scale(speed)

func _process(delta: float) -> void:
	if record.is_empty() or not is_instance_valid(arena): return
	if _animate:
		arena._process(delta * speed)
		if not playing and arena.effect_age >= 1.0: _animate = false
	if not playing or finisher.active: return
	elapsed += delta * speed
	if elapsed < record.turn_seconds: return
	var remainder: float = elapsed - record.turn_seconds
	elapsed = 0.0
	if index < record.turns.size() - 1:
		seek(index + 1)
		elapsed = remainder
		_set_playing(true)
	elif not _finisher_started:
		_finisher_started = true
		if record.winner == 2:
			_finisher_done = true
			_set_playing(false)
			return
		var winner: int = record.winner
		var defeated: Dictionary = record.actors[1 - winner].duplicate(true)
		defeated.coat = Color.from_string(defeated.coat, Color.TRANSPARENT)
		if finisher.play(record.finisher, defeated, false, record.actors[winner]):
			finisher.tween.set_speed_scale(speed)
		else:
			_finisher_done = true
			_set_playing(false)

func close() -> void:
	if _closing: return
	_closing = true
	_set_playing(false)
	finisher.cancel()
	audio.stop_all()
	closed.emit()

func _exit_tree() -> void:
	if is_instance_valid(finisher): finisher.cancel()
	if is_instance_valid(audio): audio.stop_all()
