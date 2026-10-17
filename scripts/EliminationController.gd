extends CanvasLayer

# Presentation only: the caller has already committed the authoritative result.
signal finished
const Effects = preload("res://scripts/EliminationEffects.gd")
const Poster = preload("res://scripts/WantedPoster.gd")
var audio: Node
var active: bool = false
var previewing: bool = false
var effect_id: String = "classic"
var target: Dictionary = {}
var surface: Control
var design: Control
var paper: Control
var portrait: Node2D
var stamp: Control
var tween: Tween
var stamp_count: int = 0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.025, 0.04, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(shade)
	design = Control.new()
	design.size = Vector2(1280, 720)
	design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(design)
	surface.resized.connect(func(): design.position = (surface.size - design.size) / 2)
	design.position = (surface.size - design.size) / 2
	surface.hide()

func _label(parent: Control, text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", Poster.heading_font())
	label.add_theme_color_override("font_color", Poster.INK)
	parent.add_child(label)
	return label

func play(id: String, defeated: Dictionary, preview: bool = false) -> bool:
	cancel()
	effect_id = Effects.resolve_id(id)
	if effect_id == "classic" and not preview:
		return false
	active = true
	previewing = preview
	target = defeated.duplicate(true)
	for child in design.get_children():
		child.free()
	paper = Poster.new()
	paper.position = Vector2(425, 105)
	paper.size = Vector2(430, 490)
	paper.pivot_offset = paper.size / 2
	design.add_child(paper)
	_label(paper, "WANTED" if effect_id != "classic" else "CLASSIC", Rect2(20, 22, 390, 64), 52)
	_label(paper, "D E A D   O R   A L I V E" if effect_id != "classic" else "THE ORIGINAL HIT AND FALL", Rect2(20, 90, 390, 25), 13)
	_label(paper, str(target.get("name", "Gunslinger")), Rect2(20, 122, 390, 34), 24)
	var frame := Panel.new()
	frame.position = Vector2(108, 169)
	frame.size = Vector2(214, 233)
	frame.add_theme_stylebox_override("panel", Poster.frame_style(Color("bca783")))
	paper.add_child(frame)
	portrait = preload("res://scripts/CharacterPreview.gd").new()
	portrait.position = Vector2(80, 218)
	portrait.set_player_appearance(target.get("appearance", {}))
	portrait.coat_override = target.get("coat", Color.TRANSPARENT)
	frame.add_child(portrait)
	portrait.active = effect_id == "classic"
	if effect_id == "classic":
		portrait.alive[0] = false
		portrait.effect_age = 0.0
	_label(paper, "FRONTIER MARSHAL RECORD", Rect2(20, 435, 390, 25), 14)
	stamp = preload("res://scripts/EliminationStamp.gd").new()
	stamp.position = Vector2(25, 285)
	stamp.size = Vector2(380, 90)
	stamp.pivot_offset = stamp.size / 2
	stamp.rotation = -0.16
	stamp.scale = Vector2(1.65, 1.65)
	stamp.modulate.a = 0.0
	paper.add_child(stamp)
	var hint := _label(design, "COSMETIC PREVIEW · Click or press a key to close" if preview else "Click or press a key to skip", Rect2(240, 625, 800, 28), 15)
	hint.add_theme_color_override("font_color", Poster.PAPER)
	surface.show()
	surface.modulate.a = 1.0
	paper.modulate.a = 0.0
	tween = create_tween()
	# Keep the existing muzzle flash and hit readable before covering the arena.
	if not preview:
		surface.modulate.a = 0.0
		tween.tween_interval(0.18)
		tween.tween_property(surface, "modulate:a", 1.0, 0.12)
	tween.tween_property(paper, "modulate:a", 1.0, 0.12)
	if effect_id == "wanted_eliminated":
		tween.tween_interval(0.12)
		tween.tween_property(stamp, "modulate:a", 1.0, 0.04)
		tween.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_stamp_impact)
		tween.tween_property(paper, "position:y", 110.0, 0.035)
		tween.tween_property(paper, "position:y", 102.0, 0.045)
		tween.tween_property(paper, "position:y", 105.0, 0.06)
	tween.tween_interval(0.35)
	tween.tween_property(surface, "modulate:a", 0.0, 0.16)
	tween.tween_callback(skip)
	return true

func _stamp_impact() -> void:
	stamp_count += 1
	if is_instance_valid(audio):
		audio.play_effect("stamp")

func skip() -> void:
	if not active:
		return
	var notify := not previewing
	cancel()
	if notify:
		finished.emit()

func cancel() -> void:
	active = false
	if is_instance_valid(portrait):
		portrait.active = false
	if tween:
		tween.kill()
		tween = null
	if is_instance_valid(surface):
		surface.hide()
	if is_instance_valid(audio):
		audio.stop_effect("stamp")

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Keep fullscreen, console, and the existing immediate R rematch available.
		if event.alt_pressed or event.keycode == KEY_QUOTELEFT:
			return
		var rematch: bool = not previewing and event.keycode == KEY_R
		skip()
		if not rematch:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		skip()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	cancel()
