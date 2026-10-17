extends Node2D

const Arenas = preload("res://scripts/ArenaDefinitions.gd")
var definition: Dictionary = Arenas.definition(Arenas.DEFAULT_ID)
var signage_font: Font = preload("res://scripts/WantedPoster.gd").heading_font()

func set_definition(value: Dictionary) -> void:
	definition = value
	queue_redraw()

func _draw() -> void:
	paint(self, definition, signage_font)

static func signboard(canvas: CanvasItem, rect: Rect2, text: String, font: Font) -> void:
	canvas.draw_rect(rect, Color("2b2830"))
	canvas.draw_rect(rect.grow(-3), Color("98704f"), false, 2)
	var font_size := 18
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, rect.position + Vector2((rect.size.x - width) / 2, rect.size.y * 0.66), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("d1b58d"))

static func paint(canvas: CanvasItem, data: Dictionary, font: Font) -> void:
	var bg: Dictionary = data.background
	if bg.get("kind", "") == "legacy":
		paint_legacy(canvas)
		return
	canvas.draw_rect(Rect2(0, 0, 1280, 720), bg.sky)
	if bg.has("orb"):
		canvas.draw_circle(bg.orb.position, bg.orb.radius, bg.orb.color.darkened(0.08))
		canvas.draw_circle(bg.orb.position, bg.orb.radius - 8, bg.orb.color)
	if bg.get("stars", false):
		for i in range(24):
			canvas.draw_circle(Vector2(30 + (i * 137) % 1220, 110 + (i * 67) % 150), 1, Color("7c899b"))
	if bg.has("horizon"):
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 415), Vector2(180, 290), Vector2(400, 410),
			Vector2(610, 275), Vector2(840, 405), Vector2(1100, 310), Vector2(1280, 405), Vector2(1280, 475), Vector2(0, 475)]), bg.horizon)
	if bg.get("interior", false):
		for x in range(0, 1280, 64):
			canvas.draw_rect(Rect2(x + 2, 126, 60, 343), Color("3c2c31") if x % 128 else Color("39292f"))
		canvas.draw_rect(Rect2(0, 116, 1280, 12), Color("765442"))
		canvas.draw_rect(Rect2(0, 430, 1280, 40), Color("241f28"))
	for feature in bg.get("features", []):
		paint_feature(canvas, feature, font)
	canvas.draw_rect(Rect2(0, 474, 1280, 8), bg.edge)
	canvas.draw_rect(Rect2(0, 482, 1280, 238), bg.ground)
	if bg.get("interior", false) or bg.get("platform", false):
		for y in range(485, 720, 29):
			canvas.draw_line(Vector2(0, y), Vector2(1280, y), bg.ground.darkened(0.2), 2)
		for x in range(-250, 1550, 110):
			canvas.draw_line(Vector2(640 + (x - 640) * 0.55, 482), Vector2(x, 720), bg.ground.darkened(0.18), 1)
	else:
		for x in range(20, 1280, 53):
			canvas.draw_line(Vector2(x, 494), Vector2(x + 23, 494), bg.ground.lightened(0.08), 2)

static func paint_feature(canvas: CanvasItem, feature: Dictionary, font: Font) -> void:
	match feature.kind:
		"building":
			var rect: Rect2 = feature.rect
			var wood: Color = feature.wood
			var abandoned: bool = feature.get("abandoned", false)
			canvas.draw_rect(rect, wood)
			canvas.draw_rect(Rect2(rect.position - Vector2(7, 10), Vector2(rect.size.x + 14, 19)), wood.lightened(0.14))
			for y in range(int(rect.position.y) + 55, int(rect.end.y), 22):
				canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), wood.darkened(0.15), 2)
			signboard(canvas, Rect2(rect.position + Vector2(9, 13), Vector2(rect.size.x - 18, 36)), feature.sign, font)
			for side in [0.12, 0.68]:
				var window := Rect2(rect.position + Vector2(rect.size.x * side, 76), Vector2(43, 66))
				canvas.draw_rect(window.grow(4), wood.lightened(0.16))
				canvas.draw_rect(window, Color("252430") if abandoned else Color("34313b"))
				if abandoned:
					canvas.draw_line(window.position, window.end, Color("675b5a"), 9)
					canvas.draw_line(Vector2(window.end.x, window.position.y + 10), Vector2(window.position.x, window.end.y - 10), Color("514e53"), 7)
				else:
					canvas.draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y), wood, 3)
			var door := Rect2(Vector2(rect.get_center().x - 20, rect.end.y - 83), Vector2(40, 83))
			canvas.draw_rect(door, wood.darkened(0.28))
			canvas.draw_circle(door.position + Vector2(32, 46), 2, Color("b39163"))
			canvas.draw_rect(Rect2(rect.position.x - 8, rect.end.y - 8, rect.size.x + 16, 8), wood.lightened(0.16))
		"sign":
			signboard(canvas, feature.rect, feature.text, font)
		"lantern":
			var point: Vector2 = feature.position
			canvas.draw_line(point + Vector2(0, -73), point, Color("111e28"), 3)
			canvas.draw_circle(point + Vector2(0, 9), 27, Color(0.96, 0.63, 0.28, 0.07))
			canvas.draw_rect(Rect2(point - Vector2(10, 4), Vector2(20, 30)), Color("231f29"))
			canvas.draw_rect(Rect2(point - Vector2(6, 0), Vector2(12, 21)), Color("d6a666"))
			canvas.draw_rect(Rect2(point - Vector2(13, 8), Vector2(26, 5)), Color("151d29"))
		"doors":
			var rect: Rect2 = feature.rect
			canvas.draw_rect(rect, Color("171d27"))
			for x in [rect.position.x - 7, rect.end.x + 1]:
				canvas.draw_rect(Rect2(x, rect.position.y, 6, rect.size.y), Color("795644"))
			for side in range(2):
				var door := Rect2(rect.position + Vector2(8 + side * 95, 72 + side * 8), Vector2(89, 132))
				canvas.draw_rect(door, Color("75503e"))
				for y in range(int(door.position.y) + 12, int(door.end.y), 16):
					canvas.draw_line(Vector2(door.position.x + 6, y), Vector2(door.end.x - 6, y), Color("3e3030"), 3)
				canvas.draw_circle(door.position + Vector2(9 if side == 0 else 80, 65), 3, Color("b39163"))
		"bar":
			var rect: Rect2 = feature.rect
			canvas.draw_rect(rect, Color("241f28"))
			for y in [rect.position.y + 50, rect.position.y + 114]:
				canvas.draw_rect(Rect2(rect.position.x, y, rect.size.x, 7), Color("79523c"))
				for i in range(7):
					var point := Vector2(rect.position.x + 13 + i * 29, y - 29)
					canvas.draw_rect(Rect2(point, Vector2(10, 28)), Color("4b6055") if i % 2 else Color("725542"))
					canvas.draw_rect(Rect2(point + Vector2(3, -7), Vector2(4, 9)), Color("716957"))
			canvas.draw_rect(Rect2(rect.position.x - 8, rect.end.y - 88, rect.size.x + 16, 88), Color("644332"))
			canvas.draw_rect(Rect2(rect.position.x - 14, rect.end.y - 96, rect.size.x + 28, 11), Color("a17b52"))
		"train":
			var point: Vector2 = feature.position
			canvas.draw_rect(Rect2(point + Vector2(-15, 155), Vector2(365, 7)), Color("182a34"))
			for i in range(5):
				canvas.draw_rect(Rect2(point + Vector2(i * 72, 163), Vector2(43, 7)), Color("675447"))
			canvas.draw_line(point + Vector2(-25, 162), point + Vector2(365, 162), Color("829092"), 3)
			for x in [45, 115, 185]:
				canvas.draw_circle(point + Vector2(x, 130), 28, Color("17232d"))
				canvas.draw_arc(point + Vector2(x, 130), 22, 0, TAU, 16, Color("67706f"), 3)
			canvas.draw_line(point + Vector2(35, 130), point + Vector2(195, 130), Color("9e9c85"), 4)
			canvas.draw_rect(Rect2(point + Vector2(22, 40), Vector2(207, 72)), Color("22343e"))
			canvas.draw_circle(point + Vector2(25, 76), 35, Color("1c2d37"))
			canvas.draw_arc(point + Vector2(25, 76), 28, 0, TAU, 20, Color("697476"), 3)
			canvas.draw_rect(Rect2(point + Vector2(207, -10), Vector2(105, 123)), Color("4c3b37"))
			canvas.draw_rect(Rect2(point + Vector2(218, 7), Vector2(68, 40)), Color("273641"))
			canvas.draw_rect(Rect2(point + Vector2(198, -18), Vector2(126, 12)), Color("192a35"))
			canvas.draw_rect(Rect2(point + Vector2(48, -2), Vector2(21, 48)), Color("1d2c35"))
			canvas.draw_rect(Rect2(point + Vector2(41, -10), Vector2(35, 10)), Color("253741"))
			canvas.draw_circle(point + Vector2(0, 40), 7, Color("dab97b"))

static func paint_legacy(canvas: CanvasItem) -> void:
	# Original background geometry and colors, retained as a selectable location.
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("111f30"))
	canvas.draw_circle(Vector2(985, 225), 67, Color("edbd78"))
	canvas.draw_circle(Vector2(985, 225), 53, Color("f2c68b"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 370), Vector2(160, 242), Vector2(340, 380), Vector2(550, 265), Vector2(800, 390), Vector2(1030, 300), Vector2(1280, 360), Vector2(1280, 520), Vector2(0, 520)]), Color("223b48"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 440), Vector2(240, 360), Vector2(480, 445), Vector2(720, 350), Vector2(1020, 430), Vector2(1280, 370), Vector2(1280, 520), Vector2(0, 520)]), Color("304952"))
	for x in [90, 180, 1090, 1190]:
		canvas.draw_line(Vector2(x, 466), Vector2(x, 393), Color("1a303a"), 10)
		canvas.draw_line(Vector2(x, 426), Vector2(x - 19, 414), Color("1a303a"), 8)
		canvas.draw_line(Vector2(x - 19, 414), Vector2(x - 19, 402), Color("1a303a"), 7)
	canvas.draw_rect(Rect2(0, 474, 1280, 8), Color("d1a36d"))
	canvas.draw_rect(Rect2(0, 482, 1280, 238), Color("342d32"))
	for x in range(20, 1280, 53):
		canvas.draw_line(Vector2(x, 494), Vector2(x + 23, 494), Color("514048"), 2)
