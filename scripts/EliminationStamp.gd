extends Control

var font: Font = preload("res://scripts/WantedPoster.gd").heading_font()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var ink := Color("9b2928")
	draw_rect(Rect2(Vector2.ZERO, size), ink, false, 5)
	draw_rect(Rect2(Vector2(7, 7), size - Vector2(14, 14)), ink, false, 1)
	var text := "ELIMINATED"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 43).x
	draw_string(font, Vector2((size.x - width) / 2, 61), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 43, ink)
	# Deterministic wear; no texture, particles, or per-frame randomness.
	for i in range(65):
		var point := Vector2(12 + (i * 71) % 350, 12 + (i * 29) % 61)
		draw_line(point, point + Vector2(3 + i % 7, -1), Color("dbc399"), 1)
