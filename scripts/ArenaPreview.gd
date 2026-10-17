extends Control

const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const Backdrop = preload("res://scripts/ArenaBackdrop.gd")
var arena_id: String = Arenas.DEFAULT_ID
var signage_font: Font = preload("res://scripts/WantedPoster.gd").heading_font()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_arena_id(value: String) -> void:
	arena_id = value if Arenas.valid_preference(value) else Arenas.DEFAULT_ID
	queue_redraw()

func _scene(id: String, rect: Rect2) -> void:
	var factor: float = minf(rect.size.x / 1280.0, rect.size.y / 720.0)
	draw_set_transform(rect.position + (rect.size - Vector2(1280, 720) * factor) / 2, 0, Vector2.ONE * factor)
	Backdrop.paint(self, Arenas.definition(id), signage_font)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if arena_id != Arenas.RANDOM_ID:
		_scene(arena_id, Rect2(Vector2.ZERO, size))
	else:
		for i in Arenas.ORDER.size():
			_scene(Arenas.ORDER[i], Rect2(Vector2((i % 3) * size.x / 3, (i / 3) * size.y / 2), Vector2(size.x / 3, size.y / 2)))
		var cell := size / Vector2(3, 2)
		draw_rect(Rect2(Vector2(cell.x * 2, cell.y), cell), Color("302a32"))
		var width := signage_font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(signage_font, Vector2(cell.x * 2 + (cell.x - width) / 2, cell.y + 36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("e9b86d"))
