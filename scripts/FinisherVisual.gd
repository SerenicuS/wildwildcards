extends Control

# Bounded native drawing, driven by the existing controller's single tween.
# No gameplay callbacks, particles, shaders, timers or profile writes.
const Poster = preload("res://scripts/WantedPoster.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const INK := Color("17151e")
const GOLD := Color("efc586")
const CARD_RANKS := ["A", "A", "8", "8"]
const CARD_SUITS := ["spades", "clubs", "spades", "clubs"]
var effect_id: String
var winner: Dictionary
var progress: float = 0.0
var heading: Label
var winner_label: Label
var subtitle: Label
var portrait: Node2D
var font: Font = Poster.heading_font()

func configure(id: String, victor: Dictionary) -> void:
	effect_id = id
	winner = victor.duplicate(true)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var titles := {"dead_mans_hand": "DEAD MAN'S HAND", "high_noon": "HIGH NOON", "smoke_mirrors": "SMOKE & MIRRORS"}
	heading = _label(titles[effect_id], Rect2(140, 72, 1000, 65), 48)
	winner_label = _label(str(winner.get("name", "Gunslinger")), Rect2(140, 548, 1000, 55), 39)
	subtitle = _label("HOLDS THE WINNING HAND" if effect_id == "dead_mans_hand" else "THE LAST GUNSLINGER STANDING", Rect2(140, 608, 1000, 27), 17)
	if effect_id == "high_noon":
		portrait = preload("res://scripts/CharacterPreview.gd").new()
		portrait.position = Vector2(610, 534)
		portrait.scale = Vector2(1.7, 1.7)
		portrait.set_player_appearance(winner.get("appearance", {}))
		portrait.modulate = Color("211b24")
		add_child(portrait)
		portrait.set_process(false)
		# Text stays above the silhouette during its reveal.
		move_child(winner_label, -1)
		move_child(subtitle, -1)
	set_progress(0.0)

func _label(text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)
	add_child(label)
	return label

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if is_instance_valid(winner_label):
		var reveal := smoothstep(0.28, 0.68, progress)
		winner_label.modulate.a = reveal
		winner_label.position.y = 548 + 20 * (1.0 - reveal)
		subtitle.modulate.a = reveal
		heading.modulate.a = smoothstep(0.0, 0.22, progress)
	if is_instance_valid(portrait):
		portrait.modulate.a = smoothstep(0.08, 0.35, progress)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), INK)
	match effect_id:
		"dead_mans_hand":
			draw_arc(Vector2(640, 350), 288, 0, TAU, 48, Color("504044"), 2, true)
			for i in range(4):
				var slide := smoothstep(0.03 * i, 0.38 + 0.03 * i, progress)
				var origin := Vector2(395 + i * 160, 325 + absf(i - 1.5) * 13)
				origin += Vector2((-1050 if i % 2 == 0 else 1050) * (1.0 - slide), -160 * (1.0 - slide))
				draw_set_transform(origin, lerpf((-0.7 if i % 2 == 0 else 0.7), (i - 1.5) * 0.13, slide))
				_draw_card(i)
			draw_set_transform(Vector2.ZERO)
		"high_noon":
			for i in range(14):
				var color := Color("733c55").lerp(Color("f3b868"), float(i) / 13.0)
				draw_rect(Rect2(0, 32 + i * 34, 1280, 35), color)
			draw_circle(Vector2(640, 301), 145 + 8 * progress, Color("ffdc93"))
			draw_colored_polygon(PackedVector2Array([Vector2(0, 442), Vector2(160, 347), Vector2(310, 439), Vector2(480, 373), Vector2(705, 449), Vector2(950, 362), Vector2(1280, 435), Vector2(1280, 550), Vector2(0, 550)]), Color("65414b"))
			draw_rect(Rect2(0, 475, 1280, 245), Color("322533"))
			for x in [140.0, 1100.0]:
				draw_rect(Rect2(x, 383, 90, 107), Color("211b24"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 383), Vector2(x + 45, 348), Vector2(x + 100, 383)]), Color("211b24"))
			# Short golden sweep provides a reveal without flashing the screen.
			var reveal := smoothstep(0.18, 0.65, progress)
			draw_line(Vector2(640 - reveal * 320, 146), Vector2(640 + reveal * 320, 146), GOLD, 2)
		"smoke_mirrors":
			draw_arc(Vector2(640, 350), 235, 0, TAU, 48, Color("51434c"), 1.5, true)
			draw_set_transform(Vector2(285, 420), -0.2, Vector2(2.6, 2.6))
			Revolver.draw_weapon(self, winner.get("appearance", {}), 0.0, 1.0)
			draw_set_transform(Vector2.ZERO)
			var opacity := 0.36 * (1.0 - smoothstep(0.30, 0.94, progress))
			for i in range(20):
				var x := 300 + (i % 7) * 112 + progress * (140 + i * 4)
				var y := 390 - (i / 7) * 76 - progress * (80 + i * 3) + sin(progress * 3 + i) * 20
				var radius: float = 50 + (i % 4) * 14 + progress * 24
				# Three faint nested puffs soften edges without a shader or texture.
				for ring in range(3):
					draw_circle(Vector2(x, y), radius * (1.15 - ring * 0.18), Color(0.66, 0.66, 0.73, opacity * 0.32))
	# Letterboxing is inside the unchanged 1280x720 logical canvas.
	draw_rect(Rect2(0, 0, 1280, 32), Color("100f17"))
	draw_rect(Rect2(0, 688, 1280, 32), Color("100f17"))

func _draw_card(index: int) -> void:
	draw_style_box(Poster.frame_style(Color("ead8b4")), Rect2(-70, -105, 140, 210))
	draw_rect(Rect2(-61, -96, 122, 192), Color("bba078"), false, 1)
	draw_string(font, Vector2(-55, -65), CARD_RANKS[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	_draw_suit(Vector2(-43, -43), 7, CARD_SUITS[index])
	_draw_suit(Vector2.ZERO, 27, CARD_SUITS[index])
	draw_string(font, Vector2(34, 88), CARD_RANKS[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)

func _draw_suit(center: Vector2, radius: float, suit: String) -> void:
	if suit == "clubs":
		for offset in [Vector2(0, -0.45), Vector2(-0.43, 0.15), Vector2(0.43, 0.15)]:
			draw_circle(center + offset * radius, radius * 0.48, INK)
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.85, radius * 0.1), center + Vector2(0, radius * 0.45), center + Vector2(-radius * 0.85, radius * 0.1)]), INK)
		draw_circle(center + Vector2(-0.36, 0.12) * radius, radius * 0.46, INK)
		draw_circle(center + Vector2(0.36, 0.12) * radius, radius * 0.46, INK)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, 0.1) * radius, center + Vector2(-0.35, 0.85) * radius, center + Vector2(0.35, 0.85) * radius]), INK)
