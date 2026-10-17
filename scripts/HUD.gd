class_name DuelHUD
extends Control

signal action_selected(action: int)
signal play_requested
signal quit_requested
signal resume_requested
signal menu_requested

const GOLD := Color("f4cc89")
const INK := Color("111f30")
var left_stats: Label
var right_stats: Label
var timer_text: Label
var turn_text: Label
var timer_bar: ProgressBar
var selection_text: Label
var reveal_text: Label
var banner: Label
var cards: Array[Button] = []
var overlay: Panel
var overlay_title: Label
var overlay_copy: Label
var primary: Button
var secondary: Button
var overlay_mode: String = "menu"
var reveal_tween: Tween
var player_display_name: String = "Gunslinger"

func box(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	return style

func label_at(text_value: String, rect: Rect2, size: int, color: Color = Color("e9e9df"), centered: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label

func button_at(text_value: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", box(Color("1b3042"), Color("42576a")))
	button.add_theme_stylebox_override("hover", box(Color("2b4559"), GOLD, 2))
	button.add_theme_stylebox_override("pressed", box(Color("3c4e55"), GOLD, 3))
	button.add_theme_stylebox_override("disabled", box(Color("172631"), Color("30404b")))
	add_child(button)
	return button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_at("W I L D   W I L D   C A R D S", Rect2(40, 18, 1200, 24), 17, GOLD, true)
	left_stats = label_at("", Rect2(48, 67, 330, 95), 23, Color("7ce4dc"))
	left_stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left_stats.clip_text = true
	right_stats = label_at("", Rect2(902, 67, 330, 95), 23, Color("ffad91"))
	right_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_text = label_at("TURN 01", Rect2(470, 57, 340, 30), 18, GOLD, true)
	timer_text = label_at("1.00", Rect2(490, 83, 300, 65), 48, Color.WHITE, true)
	timer_bar = ProgressBar.new()
	timer_bar.position = Vector2(490, 151)
	timer_bar.size = Vector2(300, 7)
	timer_bar.show_percentage = false
	timer_bar.max_value = 1.0
	timer_bar.add_theme_stylebox_override("background", box(Color("273b4c"), Color.TRANSPARENT, 0))
	timer_bar.add_theme_stylebox_override("fill", box(GOLD, Color.TRANSPARENT, 0))
	add_child(timer_bar)
	banner = label_at("", Rect2(270, 221, 740, 80), 48, GOLD, true)
	reveal_text = label_at("", Rect2(260, 304, 760, 42), 24, Color("fbe0b6"), true)
	selection_text = label_at("NO ACTION SELECTED — choose before the bell", Rect2(200, 510, 880, 32), 19, GOLD, true)
	var descriptions := ["[A]  RELOAD\n+1 bullet", "[S]  SHIELD\nBlock a shot · 3 in a row", "[D]  SHOOT\nFire 1 bullet"]
	for i in range(3):
		var card := button_at(descriptions[i], Rect2(242 + i * 270, 554, 256, 106))
		card.pressed.connect(func(): action_selected.emit(i + 1))
		cards.append(card)
	label_at("A / S / D to choose   ·   Change your mind before time runs out   ·   ESC to pause", Rect2(80, 684, 1120, 25), 16, Color("adb6bd"), true)
	overlay = Panel.new()
	overlay.position = Vector2(305, 193)
	overlay.size = Vector2(670, 310)
	overlay.add_theme_stylebox_override("panel", box(Color("142536"), GOLD, 2))
	add_child(overlay)
	overlay_title = _overlay_label("", Rect2(20, 28, 630, 50), 34)
	overlay_copy = _overlay_label("", Rect2(20, 89, 630, 94), 18)
	primary = button_at("PLAY", Rect2(363, 406, 260, 60))
	secondary = button_at("QUIT", Rect2(657, 406, 260, 60))
	primary.pressed.connect(func():
		if overlay_mode == "pause": resume_requested.emit()
		else: play_requested.emit())
	secondary.pressed.connect(func():
		if overlay_mode == "menu": quit_requested.emit()
		else: menu_requested.emit())

func _overlay_label(text_value: String, rect: Rect2, size_value: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_value)
	overlay.add_child(label)
	return label

func show_overlay(mode: String, title: String, copy: String) -> void:
	overlay_mode = mode
	var compact: bool = mode == "over"
	overlay.position = Vector2(435, 185) if compact else Vector2(305, 193)
	overlay.size = Vector2(410, 310) if compact else Vector2(670, 310)
	overlay_title.size.x = 370 if compact else 630
	overlay_copy.size.x = 370 if compact else 630
	primary.position = Vector2(455, 390) if compact else Vector2(363, 406)
	secondary.position = Vector2(655, 390) if compact else Vector2(657, 406)
	primary.size.x = 175 if compact else 260
	secondary.size.x = 175 if compact else 260
	overlay_title.text = title
	overlay_copy.text = copy
	overlay.show()
	primary.show()
	secondary.show()
	primary.text = "RESUME" if mode == "pause" else ("PLAY" if mode == "menu" else "REMATCH  [R]")
	secondary.text = "QUIT" if mode == "menu" else "MAIN MENU"

func hide_overlay() -> void:
	overlay.hide()
	primary.hide()
	secondary.hide()

func update_state(left: DuelParticipant, right: DuelParticipant, selected: int, enabled: bool) -> void:
	left_stats.text = "YOU / %s\nAmmo  %d   ·   Shields  %d/3" % [player_display_name, left.ammo, left.shields]
	right_stats.text = "BOT / COPPER JACK\nAmmo  %d   ·   Shields  %d/3" % [right.ammo, right.shields]
	for i in range(3):
		cards[i].disabled = not enabled or (i == 1 and left.shields >= 3)
		cards[i].add_theme_stylebox_override("normal", box(Color("34484d") if selected == i + 1 else Color("1b3042"), GOLD if selected == i + 1 else Color("42576a"), 3 if selected == i + 1 else 1))
	cards[1].text = "[S]  SHIELD\nREST REQUIRED" if left.shields >= 3 else "[S]  SHIELD\nBlock a shot · 3 in a row"
	cards[2].text = "[D]  SHOOT\nEmpty · aim only" if left.ammo == 0 else "[D]  SHOOT\nFire 1 bullet"
	selection_text.text = "NO ACTION SELECTED — choose before the bell" if selected == 0 else "SELECTED: %s   ·   You can still change" % DuelRules.NAMES[selected]

func update_timer(remaining: float, turn: int) -> void:
	timer_text.text = "%.2f" % remaining
	timer_bar.value = remaining
	turn_text.text = "TURN %02d" % turn

func reveal(result: Dictionary) -> void:
	var names: Array[String] = []
	for i in range(2):
		var action: int = result.actions[i]
		names.append("CLICK!" if action == DuelRules.Action.SHOOT and not result.fired[i] else DuelRules.NAMES[action])
	reveal_text.text = "YOU: %s     /     JACK: %s" % names
	banner.text = "CLASH!" if result.clash else ""
	if reveal_tween:
		reveal_tween.kill()
	reveal_text.scale = Vector2(1.04, 1.04)
	reveal_text.modulate.a = 1.0
	timer_text.modulate = GOLD
	reveal_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_parallel(true)
	reveal_tween.tween_property(reveal_text, "scale", Vector2.ONE, 0.15)
	reveal_tween.tween_property(timer_text, "modulate", Color.WHITE, 0.18)
	reveal_tween.tween_property(reveal_text, "modulate:a", 0.0, 0.25).set_delay(0.65)
