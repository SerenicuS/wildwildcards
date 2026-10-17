extends Control

# Reusable paper/ink styling only. No elimination behavior or player data here.
const INK := Color("493020")
const BORDER := Color("6d472d")
const PAPER := Color("dbc399")

static func heading_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Noto Serif", "Liberation Serif"])
	font.font_weight = 800
	return font

static func frame_style(fill: Color = PAPER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	return style

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(frame_style(), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(8, 8, size.x - 16, size.y - 16), BORDER, false, 2)
	draw_rect(Rect2(13, 13, size.x - 26, size.y - 26), Color("ad8459"), false, 1)
	for i in range(90):
		var point := Vector2(18 + (i * 113) % maxi(1, int(size.x) - 36), 18 + (i * 79) % maxi(1, int(size.y) - 36))
		draw_circle(point, 1.0 + (i % 4) * 0.55, Color(0.31, 0.18, 0.08, 0.045))
	for y in [28.0, size.y - 28.0]:
		draw_line(Vector2(28, y), Vector2(size.x - 28, y), Color(BORDER, 0.5), 1)
	for x in [23.0, size.x - 23.0]:
		for y in [23.0, size.y - 23.0]:
			var point := Vector2(x, y)
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -6), point + Vector2(4, 0),
				point + Vector2(0, 6), point + Vector2(-4, 0)]), BORDER)
	# Faint folds and uneven edge staining keep the paper readable without assets.
	draw_line(Vector2(16, size.y * 0.48), Vector2(size.x - 16, size.y * 0.48 - 2), Color(0.3, 0.17, 0.09, 0.06), 2)
	draw_rect(Rect2(15, 15, 5, size.y - 30), Color(0.3, 0.17, 0.09, 0.07))
	draw_rect(Rect2(size.x - 20, 15, 5, size.y - 30), Color(0.3, 0.17, 0.09, 0.07))
