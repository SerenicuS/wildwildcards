extends Control

signal elimination_preview_requested(effect_id: String, target: Dictionary)
signal local_appearance_changed
signal solo_requested
signal gauntlet_requested
signal local_requested
signal quit_requested
signal replay_requested(record: Dictionary)

const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const PARCHMENT := Color("eddbb8")
const GOLD := Color("e9b86d")
const MUTED := Color("aa9b90")
const Effects = preload("res://scripts/EliminationEffects.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Poster = preload("res://scripts/WantedPoster.gd")
var settings: RefCounted
var profile: RefCounted
var history_store: RefCounted
var history_list: ItemList
var history_details: RichTextLabel
var history_filter: int = 0
var history_run_id: String = ""
var history_selection: Dictionary = {}
var audio: Node
var page: String = "home"
var design: Control
var content: VBoxContainer
var page_heading: Label
var title_label: Label
var buttons: Dictionary = {}
var master_slider: HSlider
var sfx_slider: HSlider
var fullscreen_toggle: CheckButton
var save_status: Label
var arena_selector: OptionButton
var arena_preview: Control
var arena_description: Label
var difficulty_selector: OptionButton
var difficulty_status: Label
var name_edit: LineEdit
var profile_notice: Label
var draft_effect: String = "classic"
var elimination_selector: OptionButton
var effect_description: Label
var draft_appearance: Dictionary = {}
var character_preview: Node2D
var appearance_status: Label
var appearance_selectors: Dictionary = {}
var revolver_selectors: Dictionary = {}
var revolver_preview: Control
var revolver_target_selector: OptionButton
var revolver_target: int = 0
# Empty P1 follows the saved profile until explicitly equipped for this session.
var local_revolvers: Array[Dictionary] = [{}, Revolver.defaults()]
var local_appearances: Array[Dictionary] = [{}, {}]
var local_finishers: Array[String] = ["", Effects.FALLBACK]
var preset_selector: OptionButton
var preset_name: LineEdit
var preset_index: int = 0
var preset_delete_dialog: ConfirmationDialog
var navigation_panel: Panel
var wanted_paper: Control
var profile_portrait: Node2D
var profile_stat_labels: Dictionary = {}
var profile_equipped_label: Label
var bounty_label: Label
var _shown_profile_name: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := preload("res://scripts/MenuBackdrop.gd").new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	design = Control.new()
	design.size = Vector2(1280, 720)
	design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(design)
	resized.connect(_layout)
	_layout()
	_label("A   D U E L   O F   N E R V E   &   F O R T U N E", Rect2(78, 77, 650, 26), 14, GOLD)
	title_label = _label("WILD WILD\nCARDS", Rect2(73, 119, 660, 209), 86, PARCHMENT)
	var western := SystemFont.new()
	western.font_names = PackedStringArray(["Georgia", "Noto Serif", "Liberation Serif"])
	western.font_weight = 800
	title_label.add_theme_font_override("font", western)
	title_label.add_theme_color_override("font_shadow_color", Color("0d1016"))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 5)
	title_label.add_theme_constant_override("line_spacing", -16)
	_label("ONE SECOND.  ONE CHOICE.  ONE CLEAN SHOT.", Rect2(80, 335, 660, 28), 17, GOLD)
	_label("Load your luck. Read your rival. Beat the draw.", Rect2(80, 371, 650, 28), 17, MUTED)
	_label("RELOAD  /  SHIELD  /  SHOOT", Rect2(208, 639, 425, 24), 13, GOLD)
	_label("WILD WILD CARDS  ·  SOLO DUEL PROTOTYPE", Rect2(79, 658, 650, 20), 11, MUTED)
	var panel := Panel.new()
	panel.position = Vector2(772, 162)
	panel.size = Vector2(430, 473)
	panel.add_theme_stylebox_override("panel", _style(Color("211f27"), Color("69513f")))
	design.add_child(panel)
	navigation_panel = panel
	wanted_paper = Poster.new()
	wanted_paper.position = Vector2(772, 81)
	wanted_paper.size = Vector2(430, 554)
	design.add_child(wanted_paper)
	page_heading = _label("", Rect2(881, 108, 340, 32), 17, GOLD)
	content = VBoxContainer.new()
	content.position = Vector2(797, 186)
	content.size = Vector2(380, 425)
	content.add_theme_constant_override("separation", 13)
	design.add_child(content)
	open()
	profile.changed.connect(_profile_changed)
	get_window().size_changed.connect(_sync_fullscreen_toggle)
	get_window().focus_entered.connect(_sync_fullscreen_toggle)

func _input(event: InputEvent) -> void:
	# The menu node stays in the tree during duels and pause, so this shortcut
	# works everywhere without touching gameplay input or turn timing.
	if event is InputEventKey and event.pressed and not event.echo and event.alt_pressed \
			and not event.ctrl_pressed and not event.meta_pressed \
			and (event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER):
		_set_fullscreen(not settings.is_fullscreen())
		get_viewport().set_input_as_handled()

func _set_fullscreen(enabled: bool) -> void:
	settings.fullscreen = enabled
	var applied: bool = settings.apply_display()
	_save()
	_sync_fullscreen_toggle()
	if not applied and is_instance_valid(save_status):
		save_status.text = "Fullscreen needs a standalone window.\nDisable Embed Game on Next Play in Godot."

func _sync_fullscreen_toggle() -> void:
	if is_instance_valid(fullscreen_toggle):
		fullscreen_toggle.set_pressed_no_signal(settings.is_fullscreen())

func _layout() -> void:
	if design:
		design.position = (size - design.size) * 0.5

func _style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 19
	style.content_margin_right = 19
	return style

func _label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	design.add_child(label)
	return label

func _copy(text: String, font_size: int = 17, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	content.add_child(label)
	return label

func _button(id: String, text: String, callback: Callable, featured: bool = false, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("251d1c") if featured else PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color("251d1c"))
	button.add_theme_color_override("font_pressed_color", Color("251d1c"))
	button.add_theme_color_override("font_disabled_color", Color("817873"))
	button.add_theme_stylebox_override("normal", _style(GOLD if featured else Color("2c2830"), GOLD if featured else Color("69513f")))
	button.add_theme_stylebox_override("hover", _style(Color("f0cb8d"), Color("ffe0a3"), 2))
	button.add_theme_stylebox_override("pressed", _style(Color("c68b4b"), GOLD, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("24232a"), Color("413b3b")))
	button.pressed.connect(callback)
	content.add_child(button)
	buttons[id] = button
	return button

func open() -> void:
	show()
	show_page("home")

func show_page(next_page: String, preserve_draft: bool = false) -> void:
	if is_instance_valid(preset_delete_dialog):
		preset_delete_dialog.queue_free()
	page = next_page
	# Detach now so navigation never leaves old controls active for a frame.
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	buttons.clear()
	appearance_selectors.clear()
	revolver_selectors.clear()
	profile_stat_labels.clear()
	wanted_paper.visible = page == "profile"
	navigation_panel.visible = page != "profile"
	page_heading.visible = page != "profile"
	content.position = Vector2(797, 99) if page == "profile" else Vector2(797, 186)
	content.size = Vector2(380, 512) if page == "profile" else Vector2(380, 425)
	content.add_theme_constant_override("separation", 13)
	match page:
		"home":
			page_heading.text = "MAKE YOUR PLAY"
			_button("play", "PLAY                                 ›", func(): show_page("play"), true)
			_button("customize", "CUSTOMIZE", func(): show_page("customize"))
			_button("profile", "PROFILE", func(): show_page("profile"))
			_button("history", "MATCH HISTORY", func(): show_page("history"))
			_button("settings", "SETTINGS", func(): show_page("settings"))
			_button("quit", "QUIT", func(): quit_requested.emit())
		"history":
			_build_history()
		"play":
			page_heading.text = "CHOOSE YOUR TABLE"
			content.add_theme_constant_override("separation", 6)
			_build_difficulty_selector()
			_build_arena_selector()
			_button("solo", "SOLO DUEL                         ›", func(): solo_requested.emit(), true).custom_minimum_size.y = 42
			_button("gauntlet", "ENDLESS GAUNTLET             ›", func(): gauntlet_requested.emit()).custom_minimum_size.y = 42
			buttons.gauntlet.tooltip_text = "Survive consecutive bot duels. Uses this difficulty and random arenas; rematch restarts after defeat."
			_button("local", "LOCAL 1v1 DUEL                    ›", func(): local_requested.emit()).custom_minimum_size.y = 42
			_button("casual", "CASUAL PvP  ·  Coming Soon", func(): pass, false, true).custom_minimum_size.y = 34
			_back()
			buttons.back.custom_minimum_size.y = 34
		"customize":
			_build_customize(preserve_draft)
		"clothing":
			_build_clothing()
		"presets":
			_build_presets()
		"revolver":
			_build_revolver(preserve_draft)
		"profile":
			_build_profile()
		"settings":
			page_heading.text = "SETTINGS"
			master_slider = _volume_slider("MASTER VOLUME", settings.master_volume, func(value: float):
				settings.master_volume = value / 100.0
				settings.apply_audio(audio)
				_save())
			sfx_slider = _volume_slider("SOUND EFFECTS", settings.sfx_volume, func(value: float):
				settings.sfx_volume = value / 100.0
				settings.apply_audio(audio)
				_save())
			fullscreen_toggle = CheckButton.new()
			fullscreen_toggle.text = "FULLSCREEN"
			fullscreen_toggle.custom_minimum_size.y = 54
			fullscreen_toggle.focus_mode = Control.FOCUS_NONE
			fullscreen_toggle.add_theme_font_size_override("font_size", 18)
			fullscreen_toggle.add_theme_color_override("font_color", PARCHMENT)
			fullscreen_toggle.button_pressed = settings.is_fullscreen()
			fullscreen_toggle.toggled.connect(_set_fullscreen)
			content.add_child(fullscreen_toggle)
			save_status = _copy("Changes saved automatically.", 14)
			_back()

func _back() -> void:
	_button("back", "‹  BACK", func(): show_page("home"))

func _build_history() -> void:
	page_heading.text = "MATCH HISTORY"
	content.add_theme_constant_override("separation", 6)
	history_selection.clear()
	var filter := OptionButton.new()
	for caption in ["All completed duels", "Solo Duel", "Local / offline", "Gauntlet runs"]:
		filter.add_item(caption)
	filter.select(history_filter)
	filter.custom_minimum_size.y = 32
	filter.item_selected.connect(func(index: int):
		history_filter = index
		history_run_id = ""
		show_page("history"))
	content.add_child(filter)
	history_list = ItemList.new()
	history_list.fixed_column_width = 360
	history_list.custom_minimum_size = Vector2(380, 202)
	history_list.add_theme_font_size_override("font_size", 14)
	history_list.item_selected.connect(_select_history)
	content.add_child(history_list)
	if history_store != null:
		if history_filter == 3 and history_run_id.is_empty():
			var run_ids: Array = history_store.runs.keys()
			run_ids.sort_custom(func(a: String, b: String): return history_store.runs[a].timestamp > history_store.runs[b].timestamp)
			for id in run_ids:
				var run: Dictionary = history_store.runs[id]
				history_list.add_item("%s UTC · Streak %d · %s" % [_history_date(run.timestamp), run.streak, run.status])
				history_list.set_item_metadata(history_list.item_count - 1, {"run": id})
		else:
			for record in history_store.matches:
				if (history_filter == 1 and record.mode != "solo") or (history_filter == 2 and record.mode != "local") or (not history_run_id.is_empty() and record.run_id != history_run_id):
					continue
				var mode_name: String = "LOCAL / OFFLINE" if record.mode == "local" else record.mode.to_upper()
				history_list.add_item("%s · %s · %s vs %s" % [_history_date(record.timestamp).substr(5, 11), record.mode.to_upper(), record.actors[0].name.left(10), record.actors[1].name.left(10)])
				history_list.set_item_tooltip(history_list.item_count - 1, "%s UTC · %s\n%s vs %s" % [_history_date(record.timestamp), mode_name, record.actors[0].name, record.actors[1].name])
				history_list.set_item_metadata(history_list.item_count - 1, {"match": record.id})
	history_details = RichTextLabel.new()
	history_details.custom_minimum_size = Vector2(380, 104)
	history_details.add_theme_font_size_override("normal_font_size", 14)
	history_details.add_theme_color_override("default_color", PARCHMENT)
	history_details.text = "No completed duels yet." if history_list.item_count == 0 else "Select a duel to review its result and replay."
	if history_store != null and not history_store.notice.is_empty():
		history_details.text += "\n" + history_store.notice
	content.add_child(history_details)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	for entry in [["replay", "REPLAY", _open_history_selection], ["back", "< BACK", func():
		if not history_run_id.is_empty():
			history_run_id = ""
			show_page("history")
		else: show_page("home")]]:
		var button := _button(entry[0], entry[1], entry[2])
		button.custom_minimum_size = Vector2(184, 40)
		button.add_theme_font_size_override("font_size", 16)
		button.reparent(footer)
	buttons.replay.disabled = true

func _history_date(timestamp: int) -> String:
	return Time.get_datetime_string_from_unix_time(timestamp).replace("T", " ")

func _select_history(index: int) -> void:
	history_selection = history_list.get_item_metadata(index)
	if history_selection.has("run"):
		var run: Dictionary = history_store.runs[history_selection.run]
		var defeated: Array[String] = []
		for record in history_store.matches:
			if record.run_id == run.id and record.winner == 0:
				defeated.push_front(record.actors[1].name)
		history_details.text = "%s UTC\nFinal streak: %d · %s\nEnded by: %s\nDefeated (retained): %s" % [_history_date(run.timestamp), run.streak, run.status, run.ended_by if not run.ended_by.is_empty() else "Run ended / interrupted", ", ".join(defeated)]
		buttons.replay.text = "VIEW DUELS"
	else:
		var record: Dictionary = history_store.find_match(history_selection.match)
		var winner: String = "Draw" if record.winner == 2 else record.actors[record.winner].name
		history_details.text = "%s UTC\nWinner: %s · %d turns\n%s · %s · %s\n%s vs %s" % [_history_date(record.timestamp), winner, record.total_turns, "Local / offline" if record.mode == "local" else record.mode.capitalize(), Arenas.definition(record.arena).name, record.difficulty, record.actors[0].name, record.actors[1].name]
		buttons.replay.text = "REPLAY"
	buttons.replay.disabled = false

func _open_history_selection() -> void:
	if history_selection.has("run"):
		history_run_id = history_selection.run
		show_page("history")
	elif history_selection.has("match"):
		var record: Dictionary = history_store.find_match(history_selection.match)
		if not record.is_empty(): replay_requested.emit(record)

func _build_arena_selector() -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 32
	content.add_child(row)
	var caption := Label.new()
	caption.text = "ARENA"
	caption.custom_minimum_size.x = 112
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", MUTED)
	row.add_child(caption)
	arena_selector = OptionButton.new()
	arena_selector.focus_mode = Control.FOCUS_NONE
	arena_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_selector.add_theme_font_size_override("font_size", 15)
	arena_selector.add_theme_color_override("font_color", PARCHMENT)
	arena_selector.add_theme_stylebox_override("normal", _style(Color("302a32"), Color("69513f")))
	for id in Arenas.ORDER + [Arenas.RANDOM_ID]:
		arena_selector.add_item("Random" if id == Arenas.RANDOM_ID else Arenas.definition(id).name)
		arena_selector.set_item_metadata(arena_selector.item_count - 1, id)
		if id == settings.preferred_arena:
			arena_selector.select(arena_selector.item_count - 1)
	row.add_child(arena_selector)
	var preview_row := HBoxContainer.new()
	preview_row.custom_minimum_size.y = 82
	preview_row.add_theme_constant_override("separation", 12)
	content.add_child(preview_row)
	arena_preview = preload("res://scripts/ArenaPreview.gd").new()
	arena_preview.custom_minimum_size = Vector2(146, 82)
	preview_row.add_child(arena_preview)
	arena_description = Label.new()
	arena_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arena_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_description.add_theme_font_size_override("font_size", 13)
	arena_description.add_theme_color_override("font_color", MUTED)
	preview_row.add_child(arena_description)
	arena_selector.item_selected.connect(_select_arena)
	_refresh_arena_preview()

func _refresh_arena_preview() -> void:
	arena_preview.set_arena_id(settings.preferred_arena)
	arena_description.text = "Any of five locations. Chosen once at duel start; rematches keep it." if settings.preferred_arena == Arenas.RANDOM_ID else Arenas.definition(settings.preferred_arena).description

func _select_arena(index: int) -> void:
	if not settings.set_arena(arena_selector.get_item_metadata(index)):
		return
	var error: Error = settings.save_settings()
	_refresh_arena_preview()
	if error != OK:
		arena_description.text += "\nCould not save; kept for this session."

func _build_difficulty_selector() -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38
	content.add_child(row)
	var caption := Label.new()
	caption.text = "DIFFICULTY"
	caption.custom_minimum_size.x = 112
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", MUTED)
	row.add_child(caption)
	difficulty_selector = OptionButton.new()
	difficulty_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_selector.focus_mode = Control.FOCUS_NONE
	difficulty_selector.add_theme_font_size_override("font_size", 16)
	difficulty_selector.add_theme_color_override("font_color", PARCHMENT)
	difficulty_selector.add_theme_stylebox_override("normal", _style(Color("302a32"), Color("69513f")))
	for id in settings.DIFFICULTY_ORDER:
		difficulty_selector.add_item(settings.difficulty_text(id))
		difficulty_selector.set_item_metadata(difficulty_selector.item_count - 1, id)
		if id == settings.difficulty:
			difficulty_selector.select(difficulty_selector.item_count - 1)
	difficulty_selector.item_selected.connect(_select_difficulty)
	row.add_child(difficulty_selector)
	difficulty_status = _copy(_difficulty_hint(), 14, GOLD)

func _difficulty_hint() -> String:
	return "Original one-second showdown." if settings.difficulty == "hard" else "Applies when your next duel starts."

func _select_difficulty(index: int) -> void:
	# Takes effect at the next start_duel(); never during an active turn.
	if not settings.set_difficulty(difficulty_selector.get_item_metadata(index)):
		return
	var error: Error = settings.save_settings()
	if is_instance_valid(difficulty_status):
		difficulty_status.text = _difficulty_hint() if error == OK else "Could not save difficulty. Kept for this session."

func _build_profile() -> void:
	page_heading.text = "PLAYER PROFILE"
	content.add_theme_constant_override("separation", 6)
	var heading := _poster_copy("WANTED", 52, true)
	heading.add_theme_font_override("font", Poster.heading_font())
	_poster_copy("D E A D   O R   A L I V E", 14, true)
	name_edit = LineEdit.new()
	name_edit.text = profile.display_name
	_shown_profile_name = profile.display_name
	name_edit.placeholder_text = "Gunslinger"
	name_edit.max_length = 24
	name_edit.custom_minimum_size.y = 34
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_color_override("font_color", Poster.INK)
	name_edit.add_theme_color_override("caret_color", Poster.INK)
	name_edit.add_theme_stylebox_override("normal", Poster.frame_style(Color("e4cfa7")))
	name_edit.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Poster.INK, 2))
	content.add_child(name_edit)
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 14)
	content.add_child(portrait_row)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(164, 200)
	frame.add_theme_stylebox_override("panel", Poster.frame_style(Color("bca783")))
	portrait_row.add_child(frame)
	profile_portrait = preload("res://scripts/CharacterPreview.gd").new()
	profile_portrait.position = Vector2(49, 188)
	frame.add_child(profile_portrait)
	var record := VBoxContainer.new()
	record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record.add_theme_constant_override("separation", 10)
	portrait_row.add_child(record)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 0)
	record.add_child(grid)
	for entry in [["matches_played", "Matches played"], ["wins", "Wins"], ["losses", "Losses"],
			["win_rate", "Win rate"], ["shots_blocked", "Shots blocked"]]:
		for i in range(2):
			var label := Label.new()
			label.text = entry[1] if i == 0 else "0"
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Poster.INK)
			if i == 0:
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				profile_stat_labels[entry[0]] = label
			grid.add_child(label)
	profile_equipped_label = Label.new()
	profile_equipped_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_equipped_label.add_theme_font_size_override("font_size", 13)
	profile_equipped_label.add_theme_color_override("font_color", Poster.INK)
	record.add_child(profile_equipped_label)
	bounty_label = _poster_copy("", 23, true)
	bounty_label.add_theme_font_override("font", Poster.heading_font())
	_poster_copy("Decorative score · not spendable currency", 12, true)
	profile_notice = _poster_copy(profile.load_notice if profile.last_save_error == OK else "Could not save profile. Changes kept for this session.", 12, true)
	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 12)
	content.add_child(buttons_row)
	for entry in [["save_name", "SAVE NAME", _save_name], ["back", "‹  BACK", func(): show_page("home")]]:
		var button := _button(entry[0], entry[1], entry[2])
		button.custom_minimum_size = Vector2(184, 40)
		button.add_theme_color_override("font_color", Poster.PAPER)
		button.add_theme_stylebox_override("normal", Poster.frame_style(Poster.INK))
		button.add_theme_font_size_override("font_size", 16)
		button.reparent(buttons_row)
	_poster_copy("F R O N T I E R   M A R S H A L   R E C O R D", 11, true)
	name_edit.text_submitted.connect(func(_value: String): _save_name())
	_refresh_profile()

func _poster_copy(text: String, font_size: int, centered: bool = false) -> Label:
	var label := _copy(text, font_size, Poster.INK)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _refresh_profile() -> void:
	if page != "profile" or not is_instance_valid(profile_portrait):
		return
	if _shown_profile_name != profile.display_name:
		name_edit.text = profile.display_name
		_shown_profile_name = profile.display_name
	profile_portrait.set_player_appearance(profile.appearance)
	for key in profile_stat_labels:
		profile_stat_labels[key].text = "%.1f%%" % profile.win_rate() if key == "win_rate" else str(profile.stats[key])
	profile_equipped_label.text = "EQUIPPED\n" + Appearance.describe(profile.appearance)
	bounty_label.text = "BOUNTY  $%d" % (500 + profile.stats.wins * 250 + profile.stats.shots_blocked * 25)

func _profile_changed() -> void:
	_refresh_profile()
	if page in ["customize", "revolver", "clothing", "presets"]:
		_update_preview()

func _save_name() -> void:
	var error: Error = profile.set_display_name(name_edit.text)
	profile_notice.text = "Name saved." if error == OK else "Could not save profile. Please try again."
	if error == OK:
		name_edit.text = profile.display_name
		name_edit.release_focus()

func _build_customize(preserve_draft: bool = false) -> void:
	page_heading.text = "CUSTOMIZE"
	content.add_theme_constant_override("separation", 4)
	if not preserve_draft:
		_begin_customization()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(145, 140)
	preview_panel.add_theme_stylebox_override("panel", _style(Color("292630"), Color("69513f")))
	row.add_child(preview_panel)
	character_preview = preload("res://scripts/CharacterPreview.gd").new()
	character_preview.position = Vector2(38, 133)
	character_preview.scale = Vector2(0.72, 0.72)
	preview_panel.add_child(character_preview)
	var description := Label.new()
	description.text = "YOUR GUNSLINGER"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", PARCHMENT)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	details.add_child(description)
	var weapon_button := _button("revolver", "REVOLVER >", func(): show_page("revolver", true))
	weapon_button.custom_minimum_size = Vector2(190, 30)
	weapon_button.add_theme_font_size_override("font_size", 15)
	weapon_button.reparent(details)
	for entry in [["clothing", "CLOTHING & COLORS"], ["presets", "OUTFIT PRESETS"]]:
		var destination: String = entry[0]
		var link := _button(destination, entry[1], func(): show_page(destination, true))
		link.custom_minimum_size = Vector2(190, 30)
		link.add_theme_font_size_override("font_size", 14)
		link.reparent(details)
	for entry in [["hat", "HAT", Appearance.HATS], ["outfit", "OUTFIT COLOR", Appearance.OUTFITS],
			["accessory", "ACCESSORY", Appearance.ACCESSORIES]]:
		_appearance_row(entry[0], entry[1], entry[2])
	var effect_row := HBoxContainer.new()
	effect_row.custom_minimum_size.y = 34
	content.add_child(effect_row)
	var caption := Label.new()
	caption.text = "FINISHER"
	caption.custom_minimum_size.x = 112
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", MUTED)
	effect_row.add_child(caption)
	elimination_selector = OptionButton.new()
	elimination_selector.fit_to_longest_item = false
	elimination_selector.clip_text = true
	elimination_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elimination_selector.focus_mode = Control.FOCUS_NONE
	elimination_selector.add_theme_font_size_override("font_size", 15)
	elimination_selector.add_theme_color_override("font_color", PARCHMENT)
	elimination_selector.add_theme_stylebox_override("normal", _style(Color("302a32"), Color("69513f")))
	for id in Effects.LABELS:
		elimination_selector.add_item(Effects.LABELS[id])
		elimination_selector.set_item_metadata(elimination_selector.item_count - 1, id)
		if id == draft_effect:
			elimination_selector.select(elimination_selector.item_count - 1)
	elimination_selector.item_selected.connect(func(index: int):
		draft_effect = elimination_selector.get_item_metadata(index)
		_update_preview())
	effect_row.add_child(elimination_selector)
	effect_description = _copy("", 13)
	effect_description.custom_minimum_size.y = 30
	appearance_status = _copy("", 14, GOLD)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	for entry in [["preview_effect", "PREVIEW", _preview_elimination], ["equip", "EQUIP", _equip], ["back", "‹ BACK", func(): show_page("home")]]:
		var button := _button(entry[0], entry[1], entry[2], entry[0] == "equip")
		button.custom_minimum_size = Vector2(120, 38)
		button.add_theme_font_size_override("font_size", 15)
		button.reparent(footer)
	_update_preview()

func _begin_customization() -> void:
	draft_effect = Effects.resolve_id(profile.equipped_elimination_effect)
	draft_appearance = profile.appearance.duplicate()
	revolver_target = 0

func _target_revolver() -> Dictionary:
	if revolver_target == 0 or local_revolvers[revolver_target - 1].is_empty():
		return Revolver.sanitize(profile.appearance)
	return local_revolvers[revolver_target - 1]

func _select_revolver_target(index: int) -> void:
	# Session targets deliberately discard drafts rather than save the profile.
	revolver_target = index
	draft_appearance = local_appearance(index - 1) if index > 0 else profile.appearance.duplicate()
	draft_appearance.merge(_target_revolver(), true)
	draft_effect = local_finisher(index - 1) if index > 0 else Effects.resolve_id(profile.equipped_elimination_effect)
	for key in revolver_selectors:
		var picker: OptionButton = revolver_selectors[key]
		for i in picker.item_count:
			if picker.get_item_metadata(i) == draft_appearance[key]:
				picker.select(i)
	_update_preview()

func _build_revolver(preserve_draft: bool) -> void:
	page_heading.text = "REVOLVER"
	content.add_theme_constant_override("separation", 5)
	if not preserve_draft:
		_begin_customization()
	revolver_target_selector = OptionButton.new()
	revolver_target_selector.custom_minimum_size.y = 32
	revolver_target_selector.focus_mode = Control.FOCUS_NONE
	for caption in ["Saved profile / Solo", "Local Player 1 (session only)", "Local Player 2 (session only)"]:
		revolver_target_selector.add_item(caption)
	revolver_target_selector.select(revolver_target)
	revolver_target_selector.item_selected.connect(_select_revolver_target)
	content.add_child(revolver_target_selector)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(380, 115)
	preview_panel.add_theme_stylebox_override("panel", _style(Color("292630"), Color("69513f")))
	content.add_child(preview_panel)
	revolver_preview = preload("res://scripts/RevolverPreview.gd").new()
	preview_panel.add_child(revolver_preview)
	for entry in [["revolver_model", "MODEL", Revolver.MODELS], ["revolver_finish", "METAL", Revolver.FINISHES], ["revolver_grip", "GRIP", Revolver.GRIPS]]:
		_appearance_row(entry[0], entry[1], entry[2])
		revolver_selectors[entry[0]] = appearance_selectors[entry[0]]
		appearance_selectors.erase(entry[0])
	_copy("Cosmetic only. Every revolver plays identically.", 13)
	appearance_status = _copy("", 13, GOLD)
	appearance_status.custom_minimum_size.y = 34
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	for entry in [["gunslinger", "< LOOK", func():
		# Session-only revolvers must never flow into the saved-look Equip path.
		if revolver_target > 0:
			_begin_customization()
		show_page("customize", true)], ["equip", "EQUIP", _equip], ["back", "CANCEL", func(): show_page("home")]]:
		var button := _button(entry[0], entry[1], entry[2], entry[0] == "equip")
		button.custom_minimum_size = Vector2(120, 38)
		button.add_theme_font_size_override("font_size", 15)
		button.reparent(footer)
	_update_preview()

func _preview_elimination() -> void:
	elimination_preview_requested.emit(draft_effect, {"name": ("Player %d" % revolver_target) if revolver_target > 0 else profile.display_name,
		"appearance": draft_appearance.duplicate(), "coat": Appearance.COLORS[draft_appearance.outfit]})

func _appearance_row(key: String, caption: String, options: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34
	content.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 112
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_theme_font_size_override("font_size", 16)
	picker.add_theme_color_override("font_color", PARCHMENT)
	picker.add_theme_stylebox_override("normal", _style(Color("302a32"), Color("69513f")))
	for id in options:
		picker.add_item(options[id])
		picker.set_item_metadata(picker.item_count - 1, id)
		if draft_appearance[key] == id:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int):
		draft_appearance[key] = picker.get_item_metadata(index)
		_update_preview())
	row.add_child(picker)
	appearance_selectors[key] = picker

func _update_preview() -> void:
	if page == "revolver":
		revolver_preview.set_configuration(draft_appearance)
		var equipped: bool = Revolver.sanitize(draft_appearance) == _target_revolver() and draft_effect == (local_finisher(revolver_target - 1) if revolver_target > 0 else profile.equipped_elimination_effect)
		if revolver_target == 0:
			equipped = equipped and draft_appearance == profile.appearance and draft_effect == profile.equipped_elimination_effect
		appearance_status.text = ("Equipped: " if equipped else "Draft: ") + Revolver.describe(draft_appearance)
		buttons.equip.text = "EQUIPPED" if equipped else "EQUIP"
		buttons.equip.disabled = equipped
		return
	character_preview.set_player_appearance(draft_appearance)
	if page == "customize":
		effect_description.text = Effects.DESCRIPTIONS[draft_effect]
	var equipped: bool = draft_appearance == (local_appearance(revolver_target - 1) if revolver_target > 0 else profile.appearance) and draft_effect == (local_finisher(revolver_target - 1) if revolver_target > 0 else profile.equipped_elimination_effect)
	appearance_status.text = ("Equipped" if equipped else "Draft · not equipped") + (" · Local P%d" % revolver_target if revolver_target > 0 else " · Saved / Solo")
	buttons.equip.text = "EQUIPPED" if equipped else "EQUIP"
	buttons.equip.disabled = equipped

func _equip() -> void:
	if revolver_target > 0:
		local_finishers[revolver_target - 1] = Effects.resolve_id(draft_effect)
		if page != "revolver":
			local_appearances[revolver_target - 1] = Appearance.sanitize(draft_appearance)
		local_revolvers[revolver_target - 1] = Revolver.sanitize(draft_appearance)
		local_appearance_changed.emit()
		_update_preview()
		return
	if profile.equip_loadout(draft_appearance, draft_effect) == OK:
		_update_preview()
	else:
		appearance_status.text = "Could not save customization. Please try again."

# Session looks never write ProfileManager. Empty P1 follows the saved profile.
func local_finisher(index: int) -> String:
	return Effects.resolve_id(profile.equipped_elimination_effect if index == 0 and local_finishers[0].is_empty() else local_finishers[index])

func local_appearance(index: int) -> Dictionary:
	var value: Dictionary = profile.appearance.duplicate() if index == 0 else Appearance.sanitize({"hat": "gambler", "outfit": "violet", "accessory": "bandana"})
	value.merge(local_appearances[index], true)
	value.merge(local_revolvers[index], true)
	return Appearance.sanitize(value)

func _small_character_preview() -> void:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(380, 140)
	frame.add_theme_stylebox_override("panel", _style(Color("292630"), Color("69513f")))
	content.add_child(frame)
	character_preview = preload("res://scripts/CharacterPreview.gd").new()
	character_preview.position = Vector2(145, 133)
	character_preview.scale = Vector2(0.72, 0.72)
	frame.add_child(character_preview)

func _compact_footer(entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	for entry in entries:
		var button := _button(entry[0], entry[1], entry[2], entry[0] == "equip")
		button.custom_minimum_size = Vector2(120, 34)
		button.add_theme_font_size_override("font_size", 14)
		button.reparent(row)

func _build_clothing() -> void:
	page_heading.text = "CLOTHING & COLORS"
	content.add_theme_constant_override("separation", 5)
	_small_character_preview()
	var target := OptionButton.new()
	target.custom_minimum_size.y = 30
	for caption in ["Saved profile / Solo", "Local Player 1 (session only)", "Local Player 2 (session only)"]:
		target.add_item(caption)
	target.select(revolver_target)
	target.item_selected.connect(func(index: int):
		revolver_target = index
		draft_appearance = local_appearance(index - 1) if index > 0 else profile.appearance.duplicate()
		draft_effect = local_finisher(index - 1) if index > 0 else Effects.resolve_id(profile.equipped_elimination_effect)
		show_page("clothing", true))
	content.add_child(target)
	for entry in [["outfit_style", "OUTERWEAR", Appearance.STYLES], ["hat_color", "HAT COLOR", Appearance.TINTS], ["accessory_color", "ACC. COLOR", Appearance.TINTS]]:
		_appearance_row(entry[0], entry[1], entry[2])
	_copy("One accessory at a time; gloves follow both hands.\nChoose hat, outfit color and accessory under Look.", 13)
	appearance_status = _copy("", 13, GOLD)
	_compact_footer([["look", "< LOOK", func(): show_page("customize", true)], ["equip", "EQUIP", _equip], ["back", "CANCEL", func(): show_page("home")]])
	_update_preview()

func _build_presets() -> void:
	page_heading.text = "OUTFIT PRESETS"
	content.add_theme_constant_override("separation", 5)
	_small_character_preview()
	preset_selector = OptionButton.new()
	preset_selector.fit_to_longest_item = false
	preset_selector.clip_text = true
	preset_selector.custom_minimum_size.y = 32
	for preset in profile.outfit_presets:
		preset_selector.add_item(preset.name)
	preset_index = clampi(preset_index, 0, maxi(0, profile.outfit_presets.size() - 1))
	if not profile.outfit_presets.is_empty():
		preset_selector.select(preset_index)
	content.add_child(preset_selector)
	preset_name = LineEdit.new()
	preset_name.max_length = 24
	preset_name.placeholder_text = "Name this outfit"
	preset_name.custom_minimum_size.y = 32
	preset_name.text = profile.outfit_presets[preset_index].name if not profile.outfit_presets.is_empty() else "Outfit 1"
	content.add_child(preset_name)
	preset_selector.item_selected.connect(func(index: int):
		preset_index = index
		preset_name.text = profile.outfit_presets[index].name)
	_compact_footer([["save_preset", "SAVE NEW", _save_preset], ["load_preset", "LOAD", _load_preset], ["rename_preset", "RENAME", _rename_preset]])
	_compact_footer([["delete_preset", "DELETE", _confirm_delete_preset], ["equip", "EQUIP", _equip], ["back", "< LOOK", func(): show_page("customize", true)]])
	buttons.save_preset.disabled = profile.outfit_presets.size() >= 5
	for id in ["load_preset", "rename_preset", "delete_preset"]:
		buttons[id].disabled = profile.outfit_presets.is_empty()
	_copy("%d / 5 saved · Load previews only; Equip applies.\nPresets contain clothing and revolver, not finishers." % profile.outfit_presets.size(), 13)
	appearance_status = _copy("", 13, GOLD)
	_update_preview()

func _save_preset() -> void:
	var error: Error = profile.save_outfit_preset(preset_name.text, draft_appearance)
	if error == OK:
		preset_index = profile.outfit_presets.size() - 1
		show_page("presets", true)
	else:
		appearance_status.text = "Could not save preset; five slots maximum."

func _load_preset() -> void:
	if preset_index >= profile.outfit_presets.size():
		return
	draft_appearance = profile.outfit_presets[preset_index].appearance.duplicate()
	_update_preview()

func _rename_preset() -> void:
	if profile.rename_outfit_preset(preset_index, preset_name.text) == OK:
		show_page("presets", true)
	else:
		appearance_status.text = "Could not rename preset."

func _confirm_delete_preset() -> void:
	if is_instance_valid(preset_delete_dialog) or preset_index >= profile.outfit_presets.size():
		return
	var index := preset_index
	var snapshot: Dictionary = profile.outfit_presets[index].duplicate(true)
	preset_delete_dialog = ConfirmationDialog.new()
	var dialog := preset_delete_dialog
	preset_delete_dialog.title = "Delete outfit preset?"
	preset_delete_dialog.dialog_text = "Delete “%s”?\nYour equipped appearance stays unchanged." % snapshot.name
	preset_delete_dialog.confirmed.connect(func():
		dialog.queue_free()
		if index < profile.outfit_presets.size() and profile.outfit_presets[index] == snapshot:
			if profile.delete_outfit_preset(index) == OK:
				show_page("presets", true)
			else:
				appearance_status.text = "Could not delete preset.", CONNECT_ONE_SHOT)
	preset_delete_dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	add_child(preset_delete_dialog)
	preset_delete_dialog.popup_centered(Vector2i(440, 130))

func _volume_slider(caption: String, value: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	content.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	row.add_child(name_label)
	var percent := Label.new()
	percent.text = "%d%%" % roundi(value * 100)
	percent.add_theme_color_override("font_color", GOLD)
	row.add_child(percent)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value * 100
	slider.custom_minimum_size = Vector2(380, 35)
	slider.focus_mode = Control.FOCUS_NONE
	slider.add_theme_stylebox_override("slider", _style(Color("463a3d"), Color("69513f")))
	slider.add_theme_stylebox_override("grabber_area", _style(GOLD, GOLD))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(Color("f0cb8d"), GOLD))
	slider.value_changed.connect(func(new_value: float):
		percent.text = "%d%%" % roundi(new_value)
		callback.call(new_value))
	content.add_child(slider)
	return slider

func _save() -> void:
	var error: Error = settings.save_settings()
	if is_instance_valid(save_status):
		save_status.text = "Changes saved automatically." if error == OK else "Could not save changes. Please try again."
