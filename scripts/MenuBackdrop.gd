extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("19191f"))
	var offset: Vector2 = (size - Vector2(1280, 720)) * 0.5
	draw_set_transform(offset)
	# Static silhouettes and sparse dust: no textures, particles, or frame work.
	draw_circle(Vector2(410, 420), 310, Color("202029"))
	draw_circle(Vector2(448, 450), 246, Color("25222c"))
	draw_circle(Vector2(425, 425), 193, Color("2c2630"))
	draw_circle(Vector2(425, 425), 191, Color("24222a"))
	draw_arc(Vector2(425, 425), 205, 0.2, 2.65, 64, Color("59414b"), 1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 614), Vector2(160, 539), Vector2(277, 612),
		Vector2(493, 530), Vector2(730, 637), Vector2(1280, 586), Vector2(1280, 720), Vector2(0, 720)]), Color("2e272c"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 678), Vector2(170, 609), Vector2(390, 677),
		Vector2(640, 609), Vector2(900, 680), Vector2(1280, 625), Vector2(1280, 720), Vector2(0, 720)]), Color("342a2c"))
	for i in range(42):
		var point := Vector2(37 + (i * 193) % 1220, 57 + (i * 109) % 600)
		draw_circle(point, 1.0 if i % 3 else 1.8, Color(0.85, 0.65, 0.4, 0.13))
	draw_rect(Rect2(28, 28, 1224, 664), Color("705541"), false, 1)
	for corner in [Vector2(28, 28), Vector2(1252, 28), Vector2(28, 692), Vector2(1252, 692)]:
		draw_circle(corner, 3, Color("c49a60"))
	# Three physical cards form the menu's emblem; each carries an existing action.
	_draw_card(offset, Vector2(241, 532), -0.23, "reload", Color("bd713e"))
	_draw_card(offset, Vector2(520, 532), 0.23, "shoot", Color("936454"))
	_draw_card(offset, Vector2(380, 511), 0.0, "shield", Color("448c90"))
	draw_set_transform(offset)
	# A small revolver-cylinder seal anchors the navigation panel.
	draw_circle(Vector2(836, 119), 24, Color("342c31"))
	draw_arc(Vector2(836, 119), 23, 0, TAU, 32, Color("b78b52"), 1.5, true)
	for i in range(6):
		var point := Vector2(836, 119) + Vector2.from_angle(i * TAU / 6) * 13
		draw_circle(point, 4.0, Color("b78b52"))
	draw_circle(Vector2(836, 119), 3, Color("b78b52"))

func _draw_card(offset: Vector2, position: Vector2, angle: float, emblem: String, tint: Color) -> void:
	draw_set_transform(offset + position + Vector2(5, 9), angle)
	draw_style_box(_card_style(Color(0.03, 0.03, 0.05, 0.45), Color.TRANSPARENT), Rect2(-78, -100, 156, 200))
	draw_set_transform(offset + position, angle)
	draw_style_box(_card_style(Color("d8bf91"), Color("f3dbab")), Rect2(-78, -100, 156, 200))
	draw_rect(Rect2(-68, -90, 136, 180), tint.darkened(0.25), false, 1)
	for i in range(13):
		var y: float = -79 + i * 13
		draw_line(Vector2(-60, y), Vector2(58 - i % 4 * 7, y), Color(0.35, 0.23, 0.15, 0.055), 1)
	for point in [Vector2(-56, -72), Vector2(56, 72)]:
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -8), point + Vector2(5, 0),
			point + Vector2(0, 8), point + Vector2(-5, 0)]), tint)
	match emblem:
		"reload":
			for x in [-17, 8]:
				draw_rect(Rect2(x, -14, 10, 41), tint)
				draw_circle(Vector2(x + 5, -14), 5, tint)
				draw_rect(Rect2(x - 2, 23, 14, 4), tint.darkened(0.2))
		"shield":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(29, -20), Vector2(24, 15),
				Vector2(0, 38), Vector2(-24, 15), Vector2(-29, -20)]), tint)
			draw_line(Vector2(0, -21), Vector2(0, 22), Color("d8bf91"), 3)
			draw_line(Vector2(-14, -2), Vector2(14, -2), Color("d8bf91"), 3)
		"shoot":
			draw_rect(Rect2(-31, -13, 65, 13), tint)
			draw_rect(Rect2(-22, -2, 14, 33), tint)
			draw_circle(Vector2(-9, -5), 13, tint)
			draw_arc(Vector2(-9, -5), 8, 0, TAU, 16, Color("d8bf91"), 2)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(-49, 73), emblem.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 98, 15, tint.darkened(0.2))

func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style
