extends Control

signal elimination_preview_requested(effect_id: String, target: Dictionary)
signal commemorative_poster_requested(target: Dictionary)
signal local_appearance_changed
signal solo_requested
signal gauntlet_requested
signal tournament_requested
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
const Circuit = preload("res://scripts/TournamentCircuit.gd")
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
var tournament: RefCounted
var tournament_difficulty: String = "medium"
var tournament_size: int = 32
var tournament_spectate_mode: bool = false
var tournament_catchup_speed: float = 0.3
var tournament_view: Control
var home_labels: Array[Label] = []
var replay_return_page: String = "history"
var tournament_history_selection: int = -1
var tournament_registry_source: Dictionary = {}
var registry_search_query: String = ""
var registry_filter_type: String = "all"
var registry_sort_type: String = "rank"

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
	home_labels.append(_label("A   D U E L   O F   N E R V E   &   F O R T U N E", Rect2(78, 77, 650, 26), 14, GOLD))
	title_label = _label("WILD WILD\nCARDS", Rect2(73, 119, 660, 209), 86, PARCHMENT)
	home_labels.append(title_label)
	var western := SystemFont.new()
	western.font_names = PackedStringArray(["Georgia", "Noto Serif", "Liberation Serif"])
	western.font_weight = 800
	title_label.add_theme_font_override("font", western)
	title_label.add_theme_color_override("font_shadow_color", Color("0d1016"))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 5)
	title_label.add_theme_constant_override("line_spacing", -16)
	home_labels.append(_label("ONE SECOND.  ONE CHOICE.  ONE CLEAN SHOT.", Rect2(80, 335, 660, 28), 17, GOLD))
	home_labels.append(_label("Load your luck. Read your rival. Beat the draw.", Rect2(80, 371, 650, 28), 17, MUTED))
	home_labels.append(_label("RELOAD  /  SHIELD  /  SHOOT", Rect2(208, 639, 425, 24), 13, GOLD))
	home_labels.append(_label("WILD WILD CARDS  ·  SOLO DUEL PROTOTYPE", Rect2(79, 658, 650, 20), 11, MUTED))
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
	if get_window() != null:
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
	var is_tourn: bool = next_page in ["tournament", "tournament_history", "tournament_catchup", "tournament_registry"]
	for l in home_labels:
		if is_instance_valid(l):
			l.visible = not is_tourn
	if is_instance_valid(tournament_view):
		tournament_view.queue_free()
		tournament_view = null
	# Detach now so navigation never leaves old controls active for a frame.
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	buttons.clear()
	appearance_selectors.clear()
	revolver_selectors.clear()
	profile_stat_labels.clear()
	wanted_paper.visible = page == "profile"
	navigation_panel.visible = page != "profile" and not is_tourn
	page_heading.visible = page != "profile" and not is_tourn
	content.visible = not is_tourn
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
			content.add_theme_constant_override("separation", 4)
			_build_difficulty_selector()
			_build_arena_selector()
			_button("solo", "SOLO DUEL                         ›", func(): solo_requested.emit(), true).custom_minimum_size.y = 34
			_button("tournament", "TOURNAMENT CIRCUIT             ›", func(): show_page("tournament")).custom_minimum_size.y = 34
			buttons.tournament.tooltip_text = "Single-elimination championship circuit. Defeat rivals across the frontier to claim the title."
			_button("gauntlet", "ENDLESS GAUNTLET             ›", func(): gauntlet_requested.emit()).custom_minimum_size.y = 34
			buttons.gauntlet.tooltip_text = "Survive consecutive bot duels. Uses this difficulty and random arenas; rematch restarts after defeat."
			_button("local", "LOCAL 1v1 DUEL                    ›", func(): local_requested.emit()).custom_minimum_size.y = 34
			_button("casual", "CASUAL PvP  ·  Coming Soon", func(): pass, false, true).custom_minimum_size.y = 28
			_back()
			buttons.back.custom_minimum_size.y = 28
		"tournament":
			_build_tournament()
		"tournament_registry":
			_build_tournament_registry()
		"tournament_history":
			_build_tournament_history()
		"tournament_catchup":
			_build_tournament_catchup()
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
	for caption in ["All completed duels", "Solo Duel", "Local / offline", "Gauntlet runs", "Tournament duels"]:
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
				if (history_filter == 1 and record.mode != "solo") or (history_filter == 2 and record.mode != "local") or (history_filter == 4 and record.mode != "tournament") or (not history_run_id.is_empty() and record.run_id != history_run_id):
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
			["win_rate", "Win rate"], ["shots_blocked", "Shots blocked"], ["tournaments_won", "Tourneys won"], ["best_finish", "Best circuit"]]:
		for i in range(2):
			var label := Label.new()
			label.text = entry[1] if i == 0 else "0"
			label.add_theme_font_size_override("font_size", 13)
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
		if key == "win_rate":
			profile_stat_labels[key].text = "%.1f%%" % profile.win_rate()
		elif key == "tournaments_won":
			profile_stat_labels[key].text = str(profile.tournament_records.tournaments_won)
		elif key == "best_finish":
			profile_stat_labels[key].text = profile.tournament_records.best_finish
		else:
			profile_stat_labels[key].text = str(profile.stats[key])
	profile_equipped_label.text = "EQUIPPED\n" + Appearance.describe(profile.appearance)
	var tourn_bonus: int = profile.tournament_records.tournaments_won * 2000
	bounty_label.text = "BOUNTY  $%d" % (500 + profile.stats.wins * 250 + profile.stats.shots_blocked * 25 + tourn_bonus)

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

func _build_tournament_nav_bar(parent: Control, active_tab: String) -> HBoxContainer:
	var nav := HBoxContainer.new()
	nav.position = Vector2(380, 14)
	nav.size = Vector2(580, 36)
	nav.add_theme_constant_override("separation", 10)
	parent.add_child(nav)

	var tabs: Array[Dictionary] = [
		{"id": "bracket", "label": "BRACKET", "page": "tournament"},
		{"id": "registry", "label": "GUNSLINGERS", "page": "tournament_registry"},
		{"id": "catchup", "label": "MATCH RESULTS", "page": "tournament_catchup"},
		{"id": "archives", "label": "ARCHIVES", "page": "tournament_history"}
	]

	for t in tabs:
		var btn := Button.new()
		btn.text = t.label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 34
		btn.focus_mode = Control.FOCUS_NONE
		var is_active: bool = (t.id == active_tab)
		btn.add_theme_stylebox_override("normal", _style(Color("3c342f") if is_active else Color("222026"), GOLD if is_active else Color("5c4738"), 2 if is_active else 1))
		btn.add_theme_color_override("font_color", GOLD if is_active else PARCHMENT)
		btn.add_theme_font_size_override("font_size", 13)
		var tid: String = t.id
		var tpage: String = t.page
		btn.pressed.connect(func():
			if tid == "bracket":
				tournament_registry_source = {}
				show_page(tpage)
			elif tid == "registry":
				show_page(tpage)
			elif tid == "catchup":
				if tournament != null and tournament.has_active_tournament():
					show_page(tpage)
			elif tid == "archives":
				show_page(tpage)
		)
		if tid == "catchup" and (tournament == null or not tournament.has_active_tournament()):
			btn.disabled = true
			btn.tooltip_text = "No active tournament circuit to simulate."
		nav.add_child(btn)

	return nav

func _build_tournament() -> void:
	tournament_view = Control.new()
	tournament_view.position = Vector2(60, 40)
	tournament_view.size = Vector2(1160, 640)
	design.add_child(tournament_view)

	var panel := Panel.new()
	panel.size = tournament_view.size
	panel.add_theme_stylebox_override("panel", _style(Color("1e1b24"), Color("5c4433"), 2))
	tournament_view.add_child(panel)

	_label_in(tournament_view, "WESTERN TOURNAMENT CIRCUIT", Rect2(30, 14, 340, 26), 22, GOLD, false, true)
	var active_size: int = tournament.tournament_size if tournament != null and tournament.has_active_tournament() else tournament_size
	var size_str: String = "%d-GUN SINGLE-ELIMINATION CHAMPIONSHIP" % active_size
	_label_in(tournament_view, size_str, Rect2(30, 40, 340, 18), 12, MUTED)

	_build_tournament_nav_bar(tournament_view, "bracket")

	_button_in(tournament_view, "‹  BACK TO PLAY", Rect2(980, 14, 150, 36), func(): show_page("play"))

	if tournament == null or not tournament.has_active_tournament():
		_build_tournament_entry()
	else:
		_build_tournament_bracket()

func _build_tournament_entry() -> void:
	var card := Panel.new()
	card.position = Vector2(180, 70)
	card.size = Vector2(800, 540)
	card.add_theme_stylebox_override("panel", _style(Color("26222c"), Color("69513f"), 1))
	tournament_view.add_child(card)

	_label_in(card, "TERRITORY INVITATIONAL", Rect2(30, 20, 740, 34), 28, PARCHMENT, true, true)
	var sub_text: String = "One bracket. %d outlaws. One champion." % (tournament_size - 1)
	_label_in(card, sub_text, Rect2(30, 56, 740, 22), 16, GOLD, true)

	var desc := Label.new()
	desc.position = Vector2(50, 86)
	desc.size = Vector2(700, 160)
	desc.text = ("Draw against %d notorious AI gunslingers seeded into a %d-combatant single-elimination circuit.\n\n" % [tournament_size - 1, tournament_size]) \
		+ "• Authoritative simultaneous Reload, Shield, and Shoot combat rules\n" \
		+ "• Opponents retain their names, appearance, and shooting temperaments throughout\n" \
		+ "• Accelerated Catch-Up allows you to watch rival duels or simulate them instantly\n" \
		+ "• Win the Championship to claim the purse, commemorative WANTED poster, and frontier glory!"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", PARCHMENT)
	card.add_child(desc)

	# Tournament Size Selection
	_label_in(card, "SELECT BRACKET SIZE:", Rect2(50, 252, 300, 22), 14, GOLD)
	var size_row := HBoxContainer.new()
	size_row.position = Vector2(50, 278)
	size_row.size = Vector2(700, 36)
	size_row.add_theme_constant_override("separation", 14)
	card.add_child(size_row)

	var size_opts: Array[int] = [8, 16, 32]
	for s_val in size_opts:
		var s_btn := Button.new()
		var s_lbl: String = "%d GUNS (3 ROUNDS)" % s_val if s_val == 8 else ("%d GUNS (4 ROUNDS)" % s_val if s_val == 16 else "%d GUNS (5 ROUNDS - DEFAULT)" % s_val)
		s_btn.text = s_lbl
		s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_btn.custom_minimum_size.y = 34
		var is_sel: bool = (tournament_size == s_val)
		s_btn.add_theme_stylebox_override("normal", _style(Color("3c342f") if is_sel else Color("222026"), GOLD if is_sel else Color("5c4738"), 2 if is_sel else 1))
		s_btn.add_theme_color_override("font_color", GOLD if is_sel else PARCHMENT)
		s_btn.pressed.connect(func():
			tournament_size = s_val
			show_page("tournament"))
		size_row.add_child(s_btn)

	# Difficulty Selection
	_label_in(card, "SELECT TURN PACE / DIFFICULTY:", Rect2(50, 324, 300, 22), 14, GOLD)
	var diff_row := HBoxContainer.new()
	diff_row.position = Vector2(50, 350)
	diff_row.size = Vector2(700, 36)
	diff_row.add_theme_constant_override("separation", 14)
	card.add_child(diff_row)

	var diff_opts: Array[String] = ["easy", "medium", "hard"]
	for d_key in diff_opts:
		var d_btn := Button.new()
		var d_info: Dictionary = settings.DIFFICULTIES[d_key]
		var secs: float = float(d_info.turn_usec) / 1000000.0
		d_btn.text = "%s (%.1fs)" % [d_info.label, secs]
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.custom_minimum_size.y = 34
		var is_sel: bool = (tournament_difficulty == d_key)
		d_btn.add_theme_stylebox_override("normal", _style(Color("3c342f") if is_sel else Color("222026"), GOLD if is_sel else Color("5c4738"), 2 if is_sel else 1))
		d_btn.add_theme_color_override("font_color", GOLD if is_sel else PARCHMENT)
		d_btn.pressed.connect(func():
			tournament_difficulty = d_key
			show_page("tournament"))
		diff_row.add_child(d_btn)

	var _start_btn := _button_in(card, "ENTER TOURNAMENT CIRCUIT  ›", Rect2(200, 412, 400, 48), func():
		tournament.create_tournament(profile.display_name, profile.appearance, profile.appearance, tournament_difficulty, tournament_size)
		show_page("tournament"), true, 18)

	var _hist_btn := _button_in(card, "VIEW TOURNAMENT ARCHIVES", Rect2(260, 474, 280, 34), func():
		show_page("tournament_history"), false, 14)

func _build_tournament_bracket() -> void:
	var prog: Dictionary = tournament.get_round_progress(tournament.current_round)
	var summary_text: String = "Round %d of %d: %s   ·   %d / %d Matches Completed   ·   Bracket Size: %d Guns" % [
		prog.round + 1, tournament.total_rounds, prog.round_name, prog.completed_matches, prog.total_matches, tournament.tournament_size
	]
	_label_in(tournament_view, summary_text, Rect2(30, 44, 900, 20), 13, MUTED)

	var current_hm: Dictionary = tournament.get_human_match()

	# Scrollable bracket canvas
	var bracket_scroll := ScrollContainer.new()
	bracket_scroll.position = Vector2(30, 68)
	bracket_scroll.size = Vector2(1100, 350)
	tournament_view.add_child(bracket_scroll)

	var bracket_canvas := Control.new()
	bracket_scroll.add_child(bracket_canvas)

	var col_w: float = 240.0
	var col_gap: float = 24.0
	var card_w: float = 224.0
	var card_h: float = 58.0
	var row_h: float = 72.0

	var total_rounds: int = tournament.total_rounds
	var num_rounds_display: int = total_rounds + 1
	var canvas_w: float = maxf(1100.0, float(num_rounds_display) * (col_w + col_gap) + 40.0)
	var first_round_matches: int = tournament.tournament_size / 2
	var canvas_h: float = maxf(350.0, float(first_round_matches) * row_h + 60.0)
	bracket_canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)

	# Calculate match positions
	var match_positions: Dictionary = {}
	for k in range(first_round_matches):
		match_positions[k] = Vector2(20.0, 36.0 + float(k) * row_h)

	for rnd in range(1, total_rounds):
		var matches_in_rnd: int = tournament.tournament_size >> (rnd + 1)
		var r_start: int = tournament.tournament_size - (tournament.tournament_size >> rnd)
		var prev_r_start: int = tournament.tournament_size - (tournament.tournament_size >> (rnd - 1))
		var col_x: float = 20.0 + float(rnd) * (col_w + col_gap)
		for k in range(matches_in_rnd):
			var m_id: int = r_start + k
			var feed_1: int = prev_r_start + k * 2
			var feed_2: int = prev_r_start + k * 2 + 1
			var y_pos: float = (match_positions[feed_1].y + match_positions[feed_2].y) / 2.0
			match_positions[m_id] = Vector2(col_x, y_pos)

	# Connectors drawing
	var lines_drawer := Control.new()
	lines_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines_drawer.draw.connect(func():
		var line_color := Color("6d5543")
		for rnd in range(1, total_rounds):
			var matches_in_rnd: int = tournament.tournament_size >> (rnd + 1)
			var r_start: int = tournament.tournament_size - (tournament.tournament_size >> rnd)
			var prev_r_start: int = tournament.tournament_size - (tournament.tournament_size >> (rnd - 1))
			for k in range(matches_in_rnd):
				var m_id: int = r_start + k
				var p1: Vector2 = match_positions[prev_r_start + k * 2]
				var p2: Vector2 = match_positions[prev_r_start + k * 2 + 1]
				var tgt: Vector2 = match_positions[m_id]
				var mid_x: float = (p1.x + card_w + tgt.x) / 2.0
				var y1: float = p1.y + card_h / 2.0
				var y2: float = p2.y + card_h / 2.0
				var ty: float = tgt.y + card_h / 2.0
				lines_drawer.draw_line(Vector2(p1.x + card_w, y1), Vector2(mid_x, y1), line_color, 2)
				lines_drawer.draw_line(Vector2(p2.x + card_w, y2), Vector2(mid_x, y2), line_color, 2)
				lines_drawer.draw_line(Vector2(mid_x, y1), Vector2(mid_x, y2), line_color, 2)
				lines_drawer.draw_line(Vector2(mid_x, ty), Vector2(tgt.x, ty), line_color, 2)

		var champ_m_id: int = tournament.matches.size() - 1
		if match_positions.has(champ_m_id):
			var final_pos: Vector2 = match_positions[champ_m_id]
			var champ_col_x: float = 20.0 + float(total_rounds) * (col_w + col_gap)
			lines_drawer.draw_line(Vector2(final_pos.x + card_w, final_pos.y + card_h / 2.0), Vector2(champ_col_x, final_pos.y + card_h / 2.0), line_color, 2)
	)
	bracket_canvas.add_child(lines_drawer)

	# Column Headers
	for rnd in range(total_rounds):
		var col_x: float = 20.0 + float(rnd) * (col_w + col_gap)
		var r_title: String = tournament.get_round_name(rnd, total_rounds).to_upper()
		_label_in(bracket_canvas, r_title, Rect2(col_x, 8, card_w, 20), 12, GOLD, true)

	var champ_col_x: float = 20.0 + float(total_rounds) * (col_w + col_gap)
	_label_in(bracket_canvas, "CHAMPION", Rect2(champ_col_x, 8, card_w, 20), 12, GOLD, true)

	# Render Match Cards
	var human_m_pos: Vector2 = Vector2.ZERO
	for m_idx in range(tournament.matches.size()):
		var m: Dictionary = tournament.matches[m_idx]
		var pos: Vector2 = match_positions[m_idx]
		var is_human_m: bool = not current_hm.is_empty() and current_hm.id == m_idx
		if is_human_m:
			human_m_pos = pos

		var card := Panel.new()
		card.position = pos
		card.size = Vector2(card_w, card_h)
		var border_col: Color = GOLD if is_human_m else (Color("5a4436") if m.completed else Color("3d3129"))
		var bg_col: Color = Color("382f3b") if is_human_m else (Color("221f27") if m.completed else Color("1a171f"))
		card.add_theme_stylebox_override("panel", _style(bg_col, border_col, 2 if is_human_m else 1))
		bracket_canvas.add_child(card)

		# Slot A Button
		var p_a: Dictionary = tournament.get_participant(m.slot_a)
		var text_a: String = "TBD" if p_a.is_empty() else p_a.name
		if not p_a.is_empty() and p_a.is_human:
			text_a += " (YOU)"
		if m.completed and m.winner_slot == m.slot_a:
			text_a = "✓ " + text_a
		var col_a: Color = (GOLD if p_a.get("is_human", false) else PARCHMENT) if (not m.completed or m.winner_slot == m.slot_a) else MUTED
		var btn_a := Button.new()
		btn_a.text = text_a
		btn_a.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_a.position = Vector2(6, 4)
		btn_a.size = Vector2(card_w - 12, 18)
		btn_a.flat = true
		btn_a.focus_mode = Control.FOCUS_NONE
		btn_a.add_theme_font_size_override("font_size", 12)
		btn_a.add_theme_color_override("font_color", col_a)
		btn_a.add_theme_color_override("font_hover_color", GOLD)
		if not p_a.is_empty():
			btn_a.pressed.connect(func(): _show_participant_profile_modal(p_a))
		card.add_child(btn_a)

		# Slot B Button
		var p_b: Dictionary = tournament.get_participant(m.slot_b)
		var text_b: String = "TBD" if p_b.is_empty() else p_b.name
		if not p_b.is_empty() and p_b.is_human:
			text_b += " (YOU)"
		if m.completed and m.winner_slot == m.slot_b:
			text_b = "✓ " + text_b
		var col_b: Color = (GOLD if p_b.get("is_human", false) else PARCHMENT) if (not m.completed or m.winner_slot == m.slot_b) else MUTED
		var btn_b := Button.new()
		btn_b.text = text_b
		btn_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_b.position = Vector2(6, 22)
		btn_b.size = Vector2(card_w - 12, 18)
		btn_b.flat = true
		btn_b.focus_mode = Control.FOCUS_NONE
		btn_b.add_theme_font_size_override("font_size", 12)
		btn_b.add_theme_color_override("font_color", col_b)
		btn_b.add_theme_color_override("font_hover_color", GOLD)
		if not p_b.is_empty():
			btn_b.pressed.connect(func(): _show_participant_profile_modal(p_b))
		card.add_child(btn_b)

		var arena_name: String = Arenas.definition(m.arena).name if not m.arena.is_empty() else ""
		var status_str: String = "Played (%d turns)" % m.turns if m.completed else (arena_name if not arena_name.is_empty() else "Pending")
		_label_in(card, status_str, Rect2(8, 40, card_w - 16, 14), 10, Color("80746b"))

	# Champion Card (Podium)
	var final_m_idx: int = tournament.matches.size() - 1
	var final_y: float = match_positions[final_m_idx].y if match_positions.has(final_m_idx) else 36.0
	var champ_card := Panel.new()
	champ_card.position = Vector2(champ_col_x, final_y - 20.0)
	champ_card.size = Vector2(card_w, 98.0)
	var champ_known: bool = tournament.champion_slot >= 0
	var champ_p: Dictionary = tournament.get_participant(tournament.champion_slot) if champ_known else {}
	var champ_is_human: bool = champ_known and champ_p.get("is_human", false)
	var champ_border: Color = GOLD if champ_known else Color("493b33")
	var champ_bg: Color = Color("362a26") if champ_known else Color("1b1820")
	champ_card.add_theme_stylebox_override("panel", _style(champ_bg, champ_border, 2 if champ_known else 1))
	bracket_canvas.add_child(champ_card)

	_label_in(champ_card, "★  CHAMPION  ★", Rect2(10, 8, card_w - 20, 20), 12, GOLD, true, true)
	var champ_name_text: String = "AWAITING FINAL DUEL" if not champ_known else (champ_p.name + (" (YOU)" if champ_is_human else ""))
	var champ_btn := Button.new()
	champ_btn.text = champ_name_text
	champ_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ_btn.position = Vector2(10, 32)
	champ_btn.size = Vector2(card_w - 20, 28)
	champ_btn.flat = true
	champ_btn.focus_mode = Control.FOCUS_NONE
	champ_btn.add_theme_font_size_override("font_size", 15)
	champ_btn.add_theme_color_override("font_color", GOLD if champ_is_human else PARCHMENT)
	champ_btn.add_theme_color_override("font_hover_color", GOLD)
	if champ_known:
		champ_btn.pressed.connect(func(): _show_participant_profile_modal(champ_p))
	champ_card.add_child(champ_btn)
	if champ_known:
		_label_in(champ_card, "Western Circuit Winner", Rect2(10, 64, card_w - 20, 18), 11, MUTED, true)

	# Auto-scroll toward human match if active
	if human_m_pos != Vector2.ZERO:
		bracket_scroll.set_deferred("scroll_horizontal", int(maxf(0.0, human_m_pos.x - 100.0)))
		bracket_scroll.set_deferred("scroll_vertical", int(maxf(0.0, human_m_pos.y - 100.0)))

	# Bottom Dashboard
	var dash := Panel.new()
	dash.position = Vector2(30, 430)
	dash.size = Vector2(1090, 180)
	dash.add_theme_stylebox_override("panel", _style(Color("221f28"), Color("5c4738"), 1))
	tournament_view.add_child(dash)

	if tournament.status == "active":
		var opp: Dictionary = tournament.get_human_opponent()
		var hm: Dictionary = tournament.get_human_match()

		if not hm.is_empty() and not opp.is_empty():
			_label_in(dash, "UPCOMING DUEL: %s" % str(hm.get("round_name", "Duel")).to_upper(), Rect2(24, 16, 500, 24), 16, GOLD, false, true)
			_label_in(dash, "OPPONENT: %s" % str(opp.get("name", "Opponent")), Rect2(24, 44, 500, 28), 22, PARCHMENT, false, true)

			var pers: Dictionary = opp.get("personality", {})
			var style_desc: String = "Shooting style: "
			var agg: float = pers.get("aggression", 1.0)
			var cau: float = pers.get("caution", 1.0)
			var grd: float = pers.get("greed", 1.0)
			if agg >= 1.15:
				style_desc += "Quick on the trigger and aggressive."
			elif cau >= 1.15:
				style_desc += "Methodical and defensive with their shield."
			elif grd >= 1.15:
				style_desc += "Greedy with their ammunition and patient."
			else:
				style_desc += "Balanced duelist with unpredictable nerve."
			_label_in(dash, style_desc, Rect2(24, 76, 550, 22), 14, MUTED)

			var arena_name: String = Arenas.definition(str(hm.get("arena", ""))).name if not str(hm.get("arena", "")).is_empty() else "Standard Arena"
			var secs: float = float(settings.DIFFICULTIES.get(tournament.difficulty, settings.DIFFICULTIES["medium"]).turn_usec) / 1000000.0
			_label_in(dash, "ARENA: %s   ·   PACE: %.1f SECONDS" % [arena_name, secs], Rect2(24, 102, 550, 22), 13, Color("c2b4a5"))

			var _enter_btn := _button_in(dash, "DRAW & DUEL  ›", Rect2(690, 24, 360, 48), func():
				tournament_requested.emit(), true, 19)

			var b_row := HBoxContainer.new()
			b_row.position = Vector2(690, 80)
			b_row.size = Vector2(360, 36)
			b_row.add_theme_constant_override("separation", 10)
			dash.add_child(b_row)

			var opp_btn := Button.new()
			opp_btn.text = "VIEW OPPONENT"
			opp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opp_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			opp_btn.add_theme_color_override("font_color", PARCHMENT)
			opp_btn.pressed.connect(func(): _show_participant_profile_modal(opp))
			b_row.add_child(opp_btn)

			var reg_btn := Button.new()
			reg_btn.text = "GUNSLINGERS"
			reg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reg_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			reg_btn.add_theme_color_override("font_color", GOLD)
			reg_btn.pressed.connect(func():
				tournament_registry_source = {}
				show_page("tournament_registry"))
			b_row.add_child(reg_btn)

			var catchup_btn := Button.new()
			catchup_btn.text = "CATCH-UP"
			catchup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			catchup_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			catchup_btn.add_theme_color_override("font_color", PARCHMENT)
			catchup_btn.pressed.connect(func(): show_page("tournament_catchup"))
			b_row.add_child(catchup_btn)

			var b_row2 := HBoxContainer.new()
			b_row2.position = Vector2(690, 124)
			b_row2.size = Vector2(360, 36)
			b_row2.add_theme_constant_override("separation", 10)
			dash.add_child(b_row2)

			var forfeit_btn := Button.new()
			forfeit_btn.text = "FORFEIT CIRCUIT"
			forfeit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			forfeit_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			forfeit_btn.add_theme_color_override("font_color", MUTED)
			forfeit_btn.pressed.connect(func():
				tournament.clear_active()
				show_page("tournament"))
			b_row2.add_child(forfeit_btn)

			var arch_btn := Button.new()
			arch_btn.text = "ARCHIVES"
			arch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			arch_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			arch_btn.add_theme_color_override("font_color", PARCHMENT)
			arch_btn.pressed.connect(func(): show_page("tournament_history"))
			b_row2.add_child(arch_btn)
		else:
			# Human duel in this round is already finished!
			var cur_r_name: String = tournament.get_round_name(tournament.current_round, tournament.total_rounds)
			var is_round_done: bool = tournament.is_round_complete(tournament.current_round)
			if is_round_done:
				_label_in(dash, "ROUND COMPLETE: %s" % cur_r_name.to_upper(), Rect2(24, 16, 550, 24), 16, GOLD, false, true)
				_label_in(dash, "ALL DUELS RESOLVED", Rect2(24, 44, 550, 28), 22, PARCHMENT, false, true)
				_label_in(dash, "All frontier duels in %s are settled! Advance to the next round to meet your next challenger." % cur_r_name, Rect2(24, 76, 620, 22), 14, MUTED)

				var _adv_btn := _button_in(dash, "ADVANCE TO NEXT ROUND  ›", Rect2(690, 24, 360, 48), func():
					if tournament.current_round < tournament.total_rounds - 1:
						tournament.advance_to_next_round()
						show_page("tournament")
					else:
						show_page("tournament"), true, 18)

				var b_row_adv := HBoxContainer.new()
				b_row_adv.position = Vector2(690, 80)
				b_row_adv.size = Vector2(360, 36)
				b_row_adv.add_theme_constant_override("separation", 10)
				dash.add_child(b_row_adv)

				var reg_btn := Button.new()
				reg_btn.text = "GUNSLINGERS"
				reg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				reg_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				reg_btn.add_theme_color_override("font_color", GOLD)
				reg_btn.pressed.connect(func():
					tournament_registry_source = {}
					show_page("tournament_registry"))
				b_row_adv.add_child(reg_btn)

				var arch_btn := Button.new()
				arch_btn.text = "ARCHIVES"
				arch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				arch_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				arch_btn.add_theme_color_override("font_color", PARCHMENT)
				arch_btn.pressed.connect(func(): show_page("tournament_history"))
				b_row_adv.add_child(arch_btn)

				var b_row_adv2 := HBoxContainer.new()
				b_row_adv2.position = Vector2(690, 124)
				b_row_adv2.size = Vector2(360, 36)
				b_row_adv2.add_theme_constant_override("separation", 10)
				dash.add_child(b_row_adv2)

				var forfeit_btn := Button.new()
				forfeit_btn.text = "FORFEIT CIRCUIT"
				forfeit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				forfeit_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				forfeit_btn.add_theme_color_override("font_color", MUTED)
				forfeit_btn.pressed.connect(func():
					tournament.clear_active()
					show_page("tournament"))
				b_row_adv2.add_child(forfeit_btn)
			else:
				var uncomp: Array[Dictionary] = tournament.get_uncompleted_bot_matches_in_round(tournament.current_round)
				_label_in(dash, "DUEL WON: %s" % cur_r_name.to_upper(), Rect2(24, 16, 550, 24), 16, GOLD, false, true)
				_label_in(dash, "CONCURRENT MATCHES PENDING", Rect2(24, 44, 550, 28), 22, PARCHMENT, false, true)
				_label_in(dash, "You won your duel! %d rival matches remain to be resolved in %s." % [uncomp.size(), cur_r_name], Rect2(24, 76, 620, 22), 14, MUTED)
				_label_in(dash, "Enter Catch-Up to simulate concurrent duels at high speed or finish instantly.", Rect2(24, 102, 620, 22), 13, Color("c2b4a5"))

				var _sim_btn := _button_in(dash, "SIMULATE ROUND (CATCH-UP)  ›", Rect2(690, 24, 360, 48), func():
					show_page("tournament_catchup"), true, 17)

				var b_row_sim := HBoxContainer.new()
				b_row_sim.position = Vector2(690, 80)
				b_row_sim.size = Vector2(360, 36)
				b_row_sim.add_theme_constant_override("separation", 10)
				dash.add_child(b_row_sim)

				var inst_btn := Button.new()
				inst_btn.text = "INSTANT SIMULATE"
				inst_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				inst_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				inst_btn.add_theme_color_override("font_color", GOLD)
				inst_btn.pressed.connect(func():
					tournament.finish_round_simulation_instant(tournament.current_round)
					show_page("tournament"))
				b_row_sim.add_child(inst_btn)

				var reg_btn := Button.new()
				reg_btn.text = "GUNSLINGERS"
				reg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				reg_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				reg_btn.add_theme_color_override("font_color", PARCHMENT)
				reg_btn.pressed.connect(func():
					tournament_registry_source = {}
					show_page("tournament_registry"))
				b_row_sim.add_child(reg_btn)

				var b_row_sim2 := HBoxContainer.new()
				b_row_sim2.position = Vector2(690, 124)
				b_row_sim2.size = Vector2(360, 36)
				b_row_sim2.add_theme_constant_override("separation", 10)
				dash.add_child(b_row_sim2)

				var forfeit_btn := Button.new()
				forfeit_btn.text = "FORFEIT CIRCUIT"
				forfeit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				forfeit_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				forfeit_btn.add_theme_color_override("font_color", MUTED)
				forfeit_btn.pressed.connect(func():
					tournament.clear_active()
					show_page("tournament"))
				b_row_sim2.add_child(forfeit_btn)

				var arch_btn := Button.new()
				arch_btn.text = "ARCHIVES"
				arch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				arch_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
				arch_btn.add_theme_color_override("font_color", PARCHMENT)
				arch_btn.pressed.connect(func(): show_page("tournament_history"))
				b_row_sim2.add_child(arch_btn)

	elif tournament.status == "completed":
		_label_in(dash, "★ TOURNAMENT CHAMPION! ★", Rect2(30, 20, 600, 32), 24, GOLD, false, true)
		_label_in(dash, "You ran the circuit, bested %d outlaws, and claimed the Championship title!" % (tournament.tournament_size - 1), Rect2(30, 56, 600, 22), 15, PARCHMENT)
		_label_in(dash, "Commemorative WANTED poster and tournament records preserved in frontier archives.", Rect2(30, 80, 600, 22), 13, MUTED)

		var _post_btn := _button_in(dash, "COMMEMORATIVE POSTER", Rect2(690, 16, 360, 36), func():
			commemorative_poster_requested.emit({"name": profile.display_name, "appearance": profile.appearance, "coat": Color("eddbb8")}), true, 15)

		var _reg_btn := _button_in(dash, "GUNSLINGERS & LEADERBOARD", Rect2(690, 56, 360, 34), func():
			tournament_registry_source = {}
			show_page("tournament_registry"), false, 14)

		var _new_btn := _button_in(dash, "START NEW TOURNAMENT", Rect2(690, 94, 360, 34), func():
			tournament.clear_active()
			show_page("tournament"), false, 14)

		var _arch_btn := _button_in(dash, "VIEW ARCHIVES", Rect2(690, 132, 360, 34), func():
			show_page("tournament_history"), false, 14)

	elif tournament.status == "eliminated":
		_label_in(dash, "CIRCUIT ELIMINATION — %s" % tournament.finish_position.to_upper(), Rect2(30, 16, 600, 30), 22, Color("e0887a"), false, true)

		if tournament.champion_slot < 0:
			_label_in(dash, "You were eliminated in the %s. The remaining gunslingers continue to battle for the championship!" % tournament.finish_position, Rect2(30, 50, 640, 22), 14, PARCHMENT)
			_label_in(dash, "Spectate the rest of the circuit or finish headlessly to crown an outlaw champion.", Rect2(30, 74, 640, 22), 13, MUTED)

			var _spec_btn := _button_in(dash, "SPECTATE TOURNAMENT  ›", Rect2(690, 20, 360, 44), func():
				tournament_spectate_mode = true
				show_page("tournament_catchup"), true, 16)

			var _inst_btn := _button_in(dash, "FINISH INSTANTLY", Rect2(690, 72, 360, 40), func():
				tournament.finish_all_remaining_tournament_instant()
				show_page("tournament"), false, 15)

			var b_row_elim := HBoxContainer.new()
			b_row_elim.position = Vector2(690, 122)
			b_row_elim.size = Vector2(360, 36)
			b_row_elim.add_theme_constant_override("separation", 10)
			dash.add_child(b_row_elim)

			var new_btn := Button.new()
			new_btn.text = "NEW TOURNAMENT"
			new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			new_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			new_btn.add_theme_color_override("font_color", PARCHMENT)
			new_btn.pressed.connect(func():
				tournament.clear_active()
				show_page("tournament"))
			b_row_elim.add_child(new_btn)

			var reg_btn_elim := Button.new()
			reg_btn_elim.text = "GUNSLINGERS"
			reg_btn_elim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reg_btn_elim.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			reg_btn_elim.add_theme_color_override("font_color", GOLD)
			reg_btn_elim.pressed.connect(func():
				tournament_registry_source = {}
				show_page("tournament_registry"))
			b_row_elim.add_child(reg_btn_elim)

			var arch_btn2 := Button.new()
			arch_btn2.text = "ARCHIVES"
			arch_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			arch_btn2.add_theme_stylebox_override("normal", _style(Color("2a252e"), Color("493b33")))
			arch_btn2.add_theme_color_override("font_color", MUTED)
			arch_btn2.pressed.connect(func(): show_page("tournament_history"))
			b_row_elim.add_child(arch_btn2)
		else:
			var champ_name: String = tournament.participants[tournament.champion_slot].name
			_label_in(dash, "You were eliminated in the %s. %s went on to win the Tournament Championship." % [tournament.finish_position, champ_name], Rect2(30, 50, 640, 22), 14, PARCHMENT)
			_label_in(dash, "All duel matches and simulation results have been recorded in the Tournament Archives.", Rect2(30, 74, 640, 22), 13, MUTED)

			var _reg_btn := _button_in(dash, "GUNSLINGERS & LEADERBOARD", Rect2(690, 24, 360, 42), func():
				tournament_registry_source = {}
				show_page("tournament_registry"), true, 15)

			var _new_btn := _button_in(dash, "START NEW TOURNAMENT", Rect2(690, 72, 360, 40), func():
				tournament.clear_active()
				show_page("tournament"), false, 14)

			var _arch_btn := _button_in(dash, "VIEW ARCHIVES", Rect2(690, 118, 360, 36), func():
				show_page("tournament_history"), false, 14)

func _build_tournament_registry() -> void:
	tournament_view = Control.new()
	tournament_view.position = Vector2(60, 40)
	tournament_view.size = Vector2(1160, 640)
	design.add_child(tournament_view)

	var panel := Panel.new()
	panel.size = tournament_view.size
	panel.add_theme_stylebox_override("panel", _style(Color("1e1b24"), Color("5c4433"), 2))
	tournament_view.add_child(panel)

	# Determine data source: active tournament or archive
	var is_archive: bool = not tournament_registry_source.is_empty()
	var part_list: Array = []
	var match_list: Array = []
	var tourn_status: String = ""
	var cur_round: int = 0
	var tot_rounds: int = 0
	var champ_slot: int = -1
	var human_slot_idx: int = -1
	var tourney_size: int = 32

	if is_archive:
		part_list = tournament_registry_source.get("participants", [])
		match_list = tournament_registry_source.get("matches", [])
		tourn_status = "completed"
		tot_rounds = tournament_registry_source.get("total_rounds", 5)
		cur_round = tot_rounds - 1
		champ_slot = tournament_registry_source.get("champion_slot", -1)
		human_slot_idx = tournament_registry_source.get("human_slot", -1)
		tourney_size = tournament_registry_source.get("tournament_size", part_list.size())
	elif tournament != null and tournament.has_active_tournament():
		part_list = tournament.participants
		match_list = tournament.matches
		tourn_status = tournament.status
		cur_round = tournament.current_round
		tot_rounds = tournament.total_rounds
		champ_slot = tournament.champion_slot
		human_slot_idx = tournament.human_slot
		tourney_size = tournament.tournament_size

	var title_text: String = "GUNSLINGER REGISTRY"
	var sub_text: String = ""
	if is_archive:
		var d_str: String = _history_date(tournament_registry_source.get("created_at", 0)).substr(0, 10)
		sub_text = "ARCHIVED CIRCUIT (%d GUNS)  ·  %s" % [tourney_size, d_str]
	elif tournament != null and tournament.has_active_tournament():
		sub_text = "ACTIVE CIRCUIT (%d GUNS)  ·  ROUND %d OF %d" % [tourney_size, cur_round + 1, tot_rounds]
	else:
		sub_text = "NO ACTIVE TOURNAMENT CIRCUIT"

	_label_in(tournament_view, title_text, Rect2(30, 14, 340, 26), 22, GOLD, false, true)
	_label_in(tournament_view, sub_text, Rect2(30, 40, 340, 18), 12, MUTED)

	_build_tournament_nav_bar(tournament_view, "registry")

	_button_in(tournament_view, "‹  BACK TO PLAY", Rect2(980, 14, 150, 36), func(): show_page("play"))

	if part_list.is_empty():
		var empty_panel := Panel.new()
		empty_panel.position = Vector2(180, 120)
		empty_panel.size = Vector2(800, 420)
		empty_panel.add_theme_stylebox_override("panel", _style(Color("26222c"), Color("69513f"), 1))
		tournament_view.add_child(empty_panel)

		_label_in(empty_panel, "NO GUNSLINGERS IN CIRCUIT", Rect2(30, 80, 740, 32), 24, GOLD, true, true)
		_label_in(empty_panel, "There is currently no active tournament circuit.\nEnter the circuit from BRACKET or view a completed tournament in ARCHIVES.", Rect2(30, 130, 740, 40), 15, PARCHMENT, true)

		var _enter_btn := _button_in(empty_panel, "ENTER TOURNAMENT CIRCUIT  ›", Rect2(250, 210, 300, 46), func():
			show_page("tournament"), true, 16)

		var _arch_btn := _button_in(empty_panel, "VIEW ARCHIVES", Rect2(280, 276, 240, 38), func():
			show_page("tournament_history"), false, 14)
		return

	# Controls Bar (Search, Clear, Filter, Sort, Count)
	var ctrl_card := Panel.new()
	ctrl_card.position = Vector2(30, 68)
	ctrl_card.size = Vector2(1100, 46)
	ctrl_card.add_theme_stylebox_override("panel", _style(Color("26222c"), Color("69513f"), 1))
	tournament_view.add_child(ctrl_card)

	var search_input := LineEdit.new()
	search_input.position = Vector2(16, 8)
	search_input.size = Vector2(230, 30)
	search_input.placeholder_text = "Search gunslinger by name..."
	search_input.text = registry_search_query
	search_input.add_theme_font_size_override("font_size", 13)
	search_input.add_theme_stylebox_override("normal", _style(Color("1b1820"), Color("5c4738"), 1))
	search_input.add_theme_color_override("font_color", PARCHMENT)
	ctrl_card.add_child(search_input)

	var clear_btn := Button.new()
	clear_btn.text = "✕"
	clear_btn.position = Vector2(252, 8)
	clear_btn.size = Vector2(32, 30)
	clear_btn.tooltip_text = "Clear search"
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.add_theme_stylebox_override("normal", _style(Color("222026"), Color("5c4738"), 1))
	clear_btn.add_theme_color_override("font_color", MUTED)
	ctrl_card.add_child(clear_btn)

	var filter_opt := OptionButton.new()
	filter_opt.position = Vector2(296, 8)
	filter_opt.size = Vector2(180, 30)
	filter_opt.focus_mode = Control.FOCUS_NONE
	filter_opt.add_theme_font_size_override("font_size", 13)
	filter_opt.add_theme_stylebox_override("normal", _style(Color("222026"), Color("5c4738"), 1))
	filter_opt.add_item("All Participants", 0)
	filter_opt.add_item("Still Competing", 1)
	filter_opt.add_item("Eliminated", 2)
	filter_opt.add_item("Human Duelist", 3)
	filter_opt.add_item("AI Gunslingers", 4)
	match registry_filter_type:
		"competing": filter_opt.selected = 1
		"eliminated": filter_opt.selected = 2
		"human": filter_opt.selected = 3
		"bot": filter_opt.selected = 4
		_: filter_opt.selected = 0
	ctrl_card.add_child(filter_opt)

	var sort_opt := OptionButton.new()
	sort_opt.position = Vector2(488, 8)
	sort_opt.size = Vector2(200, 30)
	sort_opt.focus_mode = Control.FOCUS_NONE
	sort_opt.add_theme_font_size_override("font_size", 13)
	sort_opt.add_theme_stylebox_override("normal", _style(Color("222026"), Color("5c4738"), 1))
	sort_opt.add_item("Sort: Placement / Rank", 0)
	sort_opt.add_item("Sort: Most Wins", 1)
	sort_opt.add_item("Sort: Fewest Losses", 2)
	sort_opt.add_item("Sort: Highest Win %", 3)
	sort_opt.add_item("Sort: Name (A to Z)", 4)
	sort_opt.add_item("Sort: Name (Z to A)", 5)
	match registry_sort_type:
		"wins": sort_opt.selected = 1
		"losses": sort_opt.selected = 2
		"win_pct": sort_opt.selected = 3
		"name_asc": sort_opt.selected = 4
		"name_desc": sort_opt.selected = 5
		_: sort_opt.selected = 0
	ctrl_card.add_child(sort_opt)

	var count_lbl := _label_in(ctrl_card, "", Rect2(700, 12, 380, 24), 13, MUTED)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Leaderboard Table Container
	var table_card := Panel.new()
	table_card.position = Vector2(30, 122)
	table_card.size = Vector2(1100, 496)
	table_card.add_theme_stylebox_override("panel", _style(Color("211e27"), Color("493b33"), 1))
	tournament_view.add_child(table_card)

	# Table Header
	var header_bar := Panel.new()
	header_bar.position = Vector2(12, 10)
	header_bar.size = Vector2(1076, 32)
	header_bar.add_theme_stylebox_override("panel", _style(Color("2c2633"), Color("5c4738"), 1))
	table_card.add_child(header_bar)

	_label_in(header_bar, "RANK", Rect2(12, 6, 110, 20), 12, GOLD, false, true)
	_label_in(header_bar, "GUNSLINGER", Rect2(130, 6, 230, 20), 12, GOLD, false, true)
	_label_in(header_bar, "W", Rect2(370, 6, 40, 20), 12, GOLD, true, true)
	_label_in(header_bar, "L", Rect2(420, 6, 40, 20), 12, GOLD, true, true)
	_label_in(header_bar, "WIN %", Rect2(470, 6, 70, 20), 12, GOLD, true, true)
	_label_in(header_bar, "STATUS & PLACEMENT", Rect2(550, 6, 350, 20), 12, GOLD, false, true)
	_label_in(header_bar, "DOSSIER", Rect2(910, 6, 150, 20), 12, GOLD, true, true)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 46)
	scroll.size = Vector2(1076, 438)
	table_card.add_child(scroll)

	var row_list := VBoxContainer.new()
	row_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_list.add_theme_constant_override("separation", 4)
	scroll.add_child(row_list)

	var ctx: Dictionary = {
		"tournament_status": tourn_status,
		"current_round": cur_round,
		"total_rounds": tot_rounds,
		"champion_slot": champ_slot,
		"human_slot": human_slot_idx,
		"participants": part_list,
		"matches": match_list
	}

	var render_table = func():
		for child in row_list.get_children():
			child.queue_free()

		var guns: Array[Dictionary] = Circuit.filter_and_sort_participants(
			part_list,
			registry_filter_type,
			registry_sort_type,
			registry_search_query,
			tourn_status,
			cur_round,
			tot_rounds,
			champ_slot
		)

		count_lbl.text = "Showing %d of %d Gunslingers" % [guns.size(), part_list.size()]

		if guns.is_empty():
			var empty_msg := Label.new()
			if not registry_search_query.strip_edges().is_empty():
				empty_msg.text = "\n\nNo gunslingers match '%s'" % registry_search_query.strip_edges()
			else:
				empty_msg.text = "\n\nNo gunslingers match the selected filter."
			empty_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_msg.add_theme_font_size_override("font_size", 16)
			empty_msg.add_theme_color_override("font_color", MUTED)
			row_list.add_child(empty_msg)
			return

		for i in range(guns.size()):
			var p: Dictionary = guns[i]
			var is_human: bool = p.get("is_human", false)
			var s_info: Dictionary = Circuit.get_participant_status_info(p, tourn_status, cur_round, tot_rounds, champ_slot)

			var row := Panel.new()
			row.custom_minimum_size = Vector2(1050, 38)
			var row_bg: Color = Color("322a36") if is_human else (Color("232029") if (i % 2 == 0) else Color("1b1822"))
			var row_border: Color = GOLD if is_human else Color("3f342d")
			row.add_theme_stylebox_override("panel", _style(row_bg, row_border, 1))
			row_list.add_child(row)

			# Clickable overlay row button
			var row_btn := Button.new()
			row_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row_btn.flat = true
			row_btn.focus_mode = Control.FOCUS_NONE
			row_btn.pressed.connect(func(): _show_participant_profile_modal(p, ctx))
			row.add_child(row_btn)

			var r_lbl := _label_in(row, s_info.rank_text, Rect2(12, 9, 110, 20), 13, GOLD if is_human or s_info.rank_text == "#1" else PARCHMENT)
			r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var name_str: String = p.get("name", "Unknown")
			if is_human:
				name_str += " (YOU)"
			var n_lbl := _label_in(row, name_str, Rect2(130, 9, 230, 20), 13, GOLD if is_human else PARCHMENT, false, is_human)
			n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var w_val: int = p.get("wins", 0)
			var l_val: int = p.get("losses", 0)
			var pct_str: String = Circuit.format_win_percentage(w_val, l_val)

			var w_lbl := _label_in(row, str(w_val), Rect2(370, 9, 40, 20), 13, PARCHMENT, true)
			w_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l_lbl := _label_in(row, str(l_val), Rect2(420, 9, 40, 20), 13, MUTED, true)
			l_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pct_lbl := _label_in(row, pct_str, Rect2(470, 9, 70, 20), 13, GOLD if pct_str == "100%" else PARCHMENT, true)
			pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var stat_col: Color = GOLD if s_info.status_text == "Champion" else (PARCHMENT if s_info.is_competing else MUTED)
			var st_lbl := _label_in(row, s_info.status_text, Rect2(550, 9, 350, 20), 13, stat_col)
			st_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var view_btn := Button.new()
			view_btn.text = "VIEW DOSSIER"
			view_btn.position = Vector2(920, 5)
			view_btn.size = Vector2(130, 28)
			view_btn.focus_mode = Control.FOCUS_NONE
			view_btn.add_theme_font_size_override("font_size", 12)
			view_btn.add_theme_stylebox_override("normal", _style(Color("2a252e"), GOLD if is_human else Color("5c4738"), 1))
			view_btn.add_theme_color_override("font_color", GOLD if is_human else PARCHMENT)
			view_btn.pressed.connect(func(): _show_participant_profile_modal(p, ctx))
			row.add_child(view_btn)

	# Connect search input
	search_input.text_changed.connect(func(new_text: String):
		registry_search_query = new_text
		render_table.call())

	clear_btn.pressed.connect(func():
		registry_search_query = ""
		search_input.text = ""
		render_table.call())

	filter_opt.item_selected.connect(func(idx: int):
		match idx:
			1: registry_filter_type = "competing"
			2: registry_filter_type = "eliminated"
			3: registry_filter_type = "human"
			4: registry_filter_type = "bot"
			_: registry_filter_type = "all"
		render_table.call())

	sort_opt.item_selected.connect(func(idx: int):
		match idx:
			1: registry_sort_type = "wins"
			2: registry_sort_type = "losses"
			3: registry_sort_type = "win_pct"
			4: registry_sort_type = "name_asc"
			5: registry_sort_type = "name_desc"
			_: registry_sort_type = "rank"
		render_table.call())

	render_table.call()

func _show_participant_profile_modal(p: Dictionary, context_dict: Dictionary = {}) -> void:
	if p.is_empty():
		return

	var ctx: Dictionary = context_dict
	if ctx.is_empty():
		if not tournament_registry_source.is_empty():
			ctx = {
				"tournament_status": "completed",
				"current_round": tournament_registry_source.get("total_rounds", 5) - 1,
				"total_rounds": tournament_registry_source.get("total_rounds", 5),
				"champion_slot": tournament_registry_source.get("champion_slot", -1),
				"human_slot": tournament_registry_source.get("human_slot", -1),
				"participants": tournament_registry_source.get("participants", []),
				"matches": tournament_registry_source.get("matches", [])
			}
		elif tournament != null and tournament.has_active_tournament():
			ctx = {
				"tournament_status": tournament.status,
				"current_round": tournament.current_round,
				"total_rounds": tournament.total_rounds,
				"champion_slot": tournament.champion_slot,
				"human_slot": tournament.human_slot,
				"participants": tournament.participants,
				"matches": tournament.matches
			}

	var t_status: String = str(ctx.get("tournament_status", "active"))
	var c_round: int = int(ctx.get("current_round", 0))
	var tot_rounds: int = int(ctx.get("total_rounds", 5))
	var champ_slot: int = int(ctx.get("champion_slot", -1))
	var parts: Array = ctx.get("participants", [])
	var m_list: Array = ctx.get("matches", [])

	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design.add_child(modal)

	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0, 0, 0, 0.75)
	backdrop.add_theme_stylebox_override("panel", b_style)
	modal.add_child(backdrop)

	var card := Panel.new()
	card.position = Vector2(320, 45)
	card.size = Vector2(640, 630)
	card.add_theme_stylebox_override("panel", _style(Color("221f28"), GOLD, 2))
	modal.add_child(card)

	var is_human: bool = p.get("is_human", false)
	var title_col: Color = GOLD if is_human else PARCHMENT
	var title_str: String = p.get("name", "Gunslinger") + (" (YOU)" if is_human else "")
	_label_in(card, title_str, Rect2(24, 16, 540, 30), 24, title_col, false, true)
	var sub_type: String = "HUMAN DUELIST" if is_human else "AI GUNSLINGER"
	_label_in(card, sub_type, Rect2(24, 46, 540, 20), 13, MUTED)

	var close_x := Button.new()
	close_x.text = "✕"
	close_x.position = Vector2(596, 16)
	close_x.size = Vector2(30, 30)
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.flat = true
	close_x.add_theme_color_override("font_color", MUTED)
	close_x.add_theme_color_override("font_hover_color", GOLD)
	close_x.pressed.connect(func(): modal.queue_free())
	card.add_child(close_x)

	var sep1 := HSeparator.new()
	sep1.position = Vector2(24, 68)
	sep1.size = Vector2(592, 8)
	card.add_child(sep1)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 76)
	scroll.size = Vector2(592, 495)
	card.add_child(scroll)

	var modal_content := VBoxContainer.new()
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation", 10)
	scroll.add_child(modal_content)

	# Status & Placement
	var s_info: Dictionary = Circuit.get_participant_status_info(p, t_status, c_round, tot_rounds, champ_slot)
	var stat_header := Label.new()
	stat_header.text = "STATUS & PLACEMENT"
	stat_header.add_theme_font_size_override("font_size", 13)
	stat_header.add_theme_color_override("font_color", GOLD)
	modal_content.add_child(stat_header)

	var stat_detail: String = s_info.status_text
	if p.get("eliminated", false):
		var elim_name: String = "Rival"
		var elim_id: String = p.get("eliminator_id", "")
		if not elim_id.is_empty():
			for other in parts:
				if other is Dictionary and other.get("id") == elim_id:
					elim_name = other.get("name", "Opponent")
					break
		stat_detail += " (Rank: %s) by %s" % [s_info.rank_text, elim_name]
	elif s_info.rank_text == "#1":
		stat_detail = "★ TOURNAMENT CHAMPION ★ (Rank #1)"

	var stat_lbl := Label.new()
	stat_lbl.text = stat_detail
	stat_lbl.add_theme_font_size_override("font_size", 14)
	stat_lbl.add_theme_color_override("font_color", PARCHMENT)
	modal_content.add_child(stat_lbl)

	# Circuit Record
	var rec_header := Label.new()
	rec_header.text = "CIRCUIT RECORD"
	rec_header.add_theme_font_size_override("font_size", 13)
	rec_header.add_theme_color_override("font_color", GOLD)
	modal_content.add_child(rec_header)

	var w: int = p.get("wins", 0)
	var l: int = p.get("losses", 0)
	var w_h: int = p.get("wins_vs_human", 0)
	var l_h: int = p.get("losses_vs_human", 0)
	var w_b: int = p.get("wins_vs_bots", 0)
	var l_b: int = p.get("losses_vs_bots", 0)
	var pct_str: String = Circuit.format_win_percentage(w, l)

	var rec_lbl := Label.new()
	rec_lbl.text = "Overall: %d W - %d L (Win Rate: %s)\nvs Human: %d W - %d L   ·   vs Bots: %d W - %d L" % [
		w, l, pct_str, w_h, l_h, w_b, l_b
	]
	rec_lbl.add_theme_font_size_override("font_size", 13)
	rec_lbl.add_theme_color_override("font_color", PARCHMENT)
	modal_content.add_child(rec_lbl)

	# Temperament (if bot)
	if not is_human:
		var pers: Dictionary = p.get("personality", {})
		var pers_header := Label.new()
		pers_header.text = "SHOOTING TEMPERAMENT"
		pers_header.add_theme_font_size_override("font_size", 13)
		pers_header.add_theme_color_override("font_color", GOLD)
		modal_content.add_child(pers_header)

		var agg: float = pers.get("aggression", 1.0)
		var cau: float = pers.get("caution", 1.0)
		var grd: float = pers.get("greed", 1.0)
		var pers_lbl := Label.new()
		pers_lbl.text = "Aggression: %.2fx   ·   Caution: %.2fx   ·   Greed: %.2fx" % [agg, cau, grd]
		pers_lbl.add_theme_font_size_override("font_size", 13)
		pers_lbl.add_theme_color_override("font_color", PARCHMENT)
		modal_content.add_child(pers_lbl)

	# Gear
	var gear_header := Label.new()
	gear_header.text = "OUTLAW GEAR"
	gear_header.add_theme_font_size_override("font_size", 13)
	gear_header.add_theme_color_override("font_color", GOLD)
	modal_content.add_child(gear_header)

	var app: Dictionary = p.get("appearance", {})
	var rev: Dictionary = p.get("revolver", {})
	var hat_str: String = app.get("hat", "None").capitalize()
	var outfit_str: String = app.get("outfit", "Default").capitalize()
	var grip_str: String = rev.get("grip", "Wood").capitalize()
	var metal_str: String = rev.get("metal", "Blued Steel").capitalize()
	var gear_lbl := Label.new()
	gear_lbl.text = "Attire: %s hat, %s outfit\nSidearm: %s with %s grip" % [hat_str, outfit_str, metal_str, grip_str]
	gear_lbl.add_theme_font_size_override("font_size", 13)
	gear_lbl.add_theme_color_override("font_color", MUTED)
	modal_content.add_child(gear_lbl)

	# Match History Section
	var hist_sep := HSeparator.new()
	modal_content.add_child(hist_sep)

	var hist_header := Label.new()
	hist_header.text = "TOURNAMENT MATCH HISTORY"
	hist_header.add_theme_font_size_override("font_size", 14)
	hist_header.add_theme_color_override("font_color", GOLD)
	modal_content.add_child(hist_header)

	var p_id: String = str(p.get("id", ""))
	var p_matches: Array[Dictionary] = Circuit.get_matches_for_participant(p_id, m_list)

	if p_matches.is_empty():
		var no_m := Label.new()
		no_m.text = "No duels resolved yet in this tournament circuit."
		no_m.add_theme_font_size_override("font_size", 13)
		no_m.add_theme_color_override("font_color", MUTED)
		modal_content.add_child(no_m)
	else:
		for m in p_matches:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			modal_content.add_child(row)

			var is_a: bool = (str(m.get("participant_a_id", "")) == p_id)
			var opp_id: String = str(m.get("participant_b_id", "") if is_a else m.get("participant_a_id", ""))
			var opp_name: String = "Opponent"
			for other in parts:
				if other is Dictionary and str(other.get("id", "")) == opp_id:
					opp_name = str(other.get("name", "Opponent"))
					break

			var is_winner: bool = (str(m.get("winner_id", "")) == p_id)
			var outcome_str: String = "VICTORY" if is_winner else "DEFEAT"
			var outcome_col: Color = GOLD if is_winner else Color("e0887a")
			var arena_id: String = str(m.get("arena", ""))
			var arena_name: String = Arenas.definition(arena_id).name if not arena_id.is_empty() else "Standard Arena"

			var m_desc := Label.new()
			m_desc.text = "• %s vs %s: %s (%d turns, %s)" % [
				str(m.get("round_name", "Duel")), opp_name, outcome_str, int(m.get("turns", 0)), arena_name
			]
			m_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m_desc.add_theme_font_size_override("font_size", 13)
			m_desc.add_theme_color_override("font_color", outcome_col)
			row.add_child(m_desc)

			var rep_id: String = str(m.get("replay_id", ""))
			if not rep_id.is_empty() and history_store != null:
				var rep_match: Dictionary = {}
				for hist_rec in history_store.matches:
					if hist_rec.id == rep_id:
						rep_match = hist_rec
						break
				if not rep_match.is_empty():
					var watch_btn := Button.new()
					watch_btn.text = "WATCH REPLAY"
					watch_btn.custom_minimum_size = Vector2(120, 26)
					watch_btn.add_theme_stylebox_override("normal", _style(Color("2f2735"), GOLD, 1))
					watch_btn.add_theme_color_override("font_color", PARCHMENT)
					watch_btn.add_theme_font_size_override("font_size", 12)
					watch_btn.pressed.connect(func():
						replay_return_page = page
						modal.queue_free()
						replay_requested.emit(rep_match))
					row.add_child(watch_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.position = Vector2(240, 580)
	close_btn.size = Vector2(160, 36)
	close_btn.add_theme_stylebox_override("normal", _style(Color("2c2830"), GOLD, 1))
	close_btn.add_theme_color_override("font_color", PARCHMENT)
	close_btn.pressed.connect(func(): modal.queue_free())
	card.add_child(close_btn)

func _build_tournament_catchup() -> void:
	tournament_view = Control.new()
	tournament_view.position = Vector2(60, 40)
	tournament_view.size = Vector2(1160, 640)
	design.add_child(tournament_view)

	var panel := Panel.new()
	panel.size = tournament_view.size
	panel.add_theme_stylebox_override("panel", _style(Color("1e1b24"), Color("5c4433"), 2))
	tournament_view.add_child(panel)

	var current_r_name: String = tournament.get_current_round_name()
	var is_spectating: bool = tournament_spectate_mode or tournament.status == "eliminated"
	var header_text: String = ("SPECTATING CIRCUIT — %s" % current_r_name.to_upper()) if is_spectating else ("TOURNAMENT CATCH-UP — %s" % current_r_name.to_upper())
	_label_in(tournament_view, header_text, Rect2(30, 14, 340, 26), 22, GOLD, false, true)
	_label_in(tournament_view, "Accelerated simulation of concurrent frontier duels", Rect2(30, 40, 340, 18), 12, MUTED)

	_build_tournament_nav_bar(tournament_view, "catchup")

	_button_in(tournament_view, "‹  VIEW BRACKET", Rect2(980, 14, 150, 36), func():
		tournament_spectate_mode = false
		show_page("tournament"))

	# Progress and Speed Controls Card
	var ctrl_card := Panel.new()
	ctrl_card.position = Vector2(30, 80)
	ctrl_card.size = Vector2(1100, 70)
	ctrl_card.add_theme_stylebox_override("panel", _style(Color("26222c"), Color("69513f"), 1))
	tournament_view.add_child(ctrl_card)

	var prog_lbl := _label_in(ctrl_card, "", Rect2(20, 16, 450, 36), 16, PARCHMENT, false, true)

	var speed_row := HBoxContainer.new()
	speed_row.position = Vector2(490, 16)
	speed_row.size = Vector2(360, 38)
	speed_row.add_theme_constant_override("separation", 10)
	ctrl_card.add_child(speed_row)

	var spd_4x := Button.new()
	spd_4x.text = "4x SPEED"
	spd_4x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spd_4x.add_theme_stylebox_override("normal", _style(Color("3c342f") if tournament_catchup_speed == 0.3 else Color("222026"), GOLD if tournament_catchup_speed == 0.3 else Color("5c4738")))
	spd_4x.add_theme_color_override("font_color", GOLD if tournament_catchup_speed == 0.3 else PARCHMENT)
	speed_row.add_child(spd_4x)

	var spd_8x := Button.new()
	spd_8x.text = "8x SPEED"
	spd_8x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spd_8x.add_theme_stylebox_override("normal", _style(Color("3c342f") if tournament_catchup_speed == 0.15 else Color("222026"), GOLD if tournament_catchup_speed == 0.15 else Color("5c4738")))
	spd_8x.add_theme_color_override("font_color", GOLD if tournament_catchup_speed == 0.15 else PARCHMENT)
	speed_row.add_child(spd_8x)

	var spd_inst := Button.new()
	spd_inst.text = "INSTANT"
	spd_inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spd_inst.add_theme_stylebox_override("normal", _style(Color("222026"), Color("5c4738")))
	spd_inst.add_theme_color_override("font_color", PARCHMENT)
	speed_row.add_child(spd_inst)

	var action_btn := Button.new()
	action_btn.position = Vector2(870, 16)
	action_btn.size = Vector2(210, 38)
	action_btn.add_theme_stylebox_override("normal", _style(Color("222026"), Color("493b33")))
	action_btn.add_theme_color_override("font_color", MUTED)
	action_btn.disabled = true
	ctrl_card.add_child(action_btn)

	var ticker_box := Panel.new()
	ticker_box.position = Vector2(30, 160)
	ticker_box.size = Vector2(1100, 450)
	ticker_box.add_theme_stylebox_override("panel", _style(Color("211e27"), Color("493b33"), 1))
	tournament_view.add_child(ticker_box)

	_label_in(ticker_box, "MATCH RESULTS TICKER", Rect2(20, 12, 400, 22), 14, GOLD, false, true)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 40)
	scroll.size = Vector2(1060, 390)
	ticker_box.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var update_status = func():
		var prog: Dictionary = tournament.get_round_progress(tournament.current_round)
		prog_lbl.text = "%s Progress: %d / %d Matches Complete" % [prog.round_name, prog.completed_matches, prog.total_matches]
		if prog.is_complete:
			if tournament.current_round < tournament.total_rounds - 1:
				action_btn.text = "NEXT ROUND  ›" if is_spectating else "ADVANCE TO NEXT ROUND  ›"
				action_btn.disabled = false
				action_btn.add_theme_stylebox_override("normal", _style(GOLD, Color("f0cb8d"), 2))
				action_btn.add_theme_color_override("font_color", Color("251d1c"))
			else:
				action_btn.text = "VIEW FINAL RESULTS  ›"
				action_btn.disabled = false
				action_btn.add_theme_stylebox_override("normal", _style(GOLD, Color("f0cb8d"), 2))
				action_btn.add_theme_color_override("font_color", Color("251d1c"))
		else:
			action_btn.text = "SIMULATING..."
			action_btn.disabled = true

	for m in tournament.matches:
		if m.round == tournament.current_round and m.completed:
			var win_p: Dictionary = tournament.get_participant(m.winner_slot)
			var lose_p: Dictionary = tournament.get_participant(m.loser_slot)
			var arena_name: String = Arenas.definition(m.arena).name if not m.arena.is_empty() else "Frontier"
			var lbl := Label.new()
			lbl.text = "• [%s] %s defeated %s in %d turns (%s)" % [m.round_name, win_p.name, lose_p.name, m.turns, arena_name]
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", GOLD if win_p.get("is_human", false) else PARCHMENT)
			list.add_child(lbl)

	update_status.call()

	var step_timer := Timer.new()
	step_timer.wait_time = tournament_catchup_speed
	step_timer.one_shot = false
	tournament_view.add_child(step_timer)

	var do_step = func():
		var res: Dictionary = tournament.step_round_simulation(tournament.current_round)
		if not res.is_empty():
			var win_p: Dictionary = tournament.get_participant(res.winner_slot)
			var lose_p: Dictionary = tournament.get_participant(res.loser_slot)
			var arena_name: String = Arenas.definition(res.arena).name if not res.arena.is_empty() else "Frontier"
			var lbl := Label.new()
			lbl.text = "• [%s] %s defeated %s in %d turns (%s)" % [res.round_name, win_p.name, lose_p.name, res.turns, arena_name]
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", PARCHMENT)
			list.add_child(lbl)
			update_status.call()
		else:
			step_timer.stop()
			update_status.call()

	step_timer.timeout.connect(do_step)

	spd_4x.pressed.connect(func():
		tournament_catchup_speed = 0.3
		step_timer.wait_time = 0.3
		spd_4x.add_theme_stylebox_override("normal", _style(Color("3c342f"), GOLD))
		spd_8x.add_theme_stylebox_override("normal", _style(Color("222026"), Color("5c4738")))
		if not tournament.is_round_complete(tournament.current_round):
			step_timer.start())

	spd_8x.pressed.connect(func():
		tournament_catchup_speed = 0.15
		step_timer.wait_time = 0.15
		spd_8x.add_theme_stylebox_override("normal", _style(Color("3c342f"), GOLD))
		spd_4x.add_theme_stylebox_override("normal", _style(Color("222026"), Color("5c4738")))
		if not tournament.is_round_complete(tournament.current_round):
			step_timer.start())

	spd_inst.pressed.connect(func():
		step_timer.stop()
		var res_list: Array[Dictionary] = tournament.finish_round_simulation_instant(tournament.current_round)
		for res in res_list:
			var win_p: Dictionary = tournament.get_participant(res.winner_slot)
			var lose_p: Dictionary = tournament.get_participant(res.loser_slot)
			var arena_name: String = Arenas.definition(res.arena).name if not res.arena.is_empty() else "Frontier"
			var lbl := Label.new()
			lbl.text = "• [%s] %s defeated %s in %d turns (%s)" % [res.round_name, win_p.name, lose_p.name, res.turns, arena_name]
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", PARCHMENT)
			list.add_child(lbl)
		update_status.call())

	action_btn.pressed.connect(func():
		step_timer.stop()
		if tournament.is_round_complete(tournament.current_round):
			if tournament.current_round < tournament.total_rounds - 1:
				tournament.advance_to_next_round()
				if is_spectating:
					show_page("tournament_catchup")
				else:
					show_page("tournament")
			else:
				tournament_spectate_mode = false
				show_page("tournament"))

	if not tournament.is_round_complete(tournament.current_round):
		step_timer.start()

func _build_tournament_history() -> void:
	tournament_view = Control.new()
	tournament_view.position = Vector2(60, 40)
	tournament_view.size = Vector2(1160, 640)
	design.add_child(tournament_view)

	var panel := Panel.new()
	panel.size = tournament_view.size
	panel.add_theme_stylebox_override("panel", _style(Color("1e1b24"), Color("5c4433"), 2))
	tournament_view.add_child(panel)

	_label_in(tournament_view, "CIRCUIT ARCHIVES", Rect2(30, 14, 340, 26), 22, GOLD, false, true)
	_label_in(tournament_view, "PAST TOURNAMENT RECORDS & REPLAYS", Rect2(30, 40, 340, 18), 12, MUTED)

	_build_tournament_nav_bar(tournament_view, "archives")

	_button_in(tournament_view, "‹  BACK TO PLAY", Rect2(980, 14, 150, 36), func(): show_page("play"))

	var records: Array = tournament.load_history()
	if records.is_empty():
		_label_in(tournament_view, "No completed tournaments on record yet.\nEnter the circuit and make your mark on the frontier!", Rect2(280, 260, 600, 80), 18, MUTED, true)
		return

	var list_box := Panel.new()
	list_box.position = Vector2(30, 80)
	list_box.size = Vector2(400, 520)
	list_box.add_theme_stylebox_override("panel", _style(Color("232029"), Color("493b33")))
	tournament_view.add_child(list_box)

	_label_in(list_box, "COMPLETED TOURNAMENTS", Rect2(16, 12, 360, 22), 14, GOLD, false, true)

	var tourn_list := ItemList.new()
	tourn_list.position = Vector2(16, 40)
	tourn_list.size = Vector2(368, 460)
	tourn_list.add_theme_font_size_override("font_size", 13)
	list_box.add_child(tourn_list)

	for i in range(records.size()):
		var rec: Dictionary = records[i]
		var d_str: String = _history_date(rec.get("created_at", 0)).substr(0, 10)
		var diff: String = rec.get("difficulty", "medium").capitalize()
		var champ: String = rec.get("champion_name", "Unknown")
		var finish: String = rec.get("finish_position", "None")
		var title: String = "%s · %s · %s" % [d_str, diff, champ]
		tourn_list.add_item(title)
		tourn_list.set_item_tooltip(i, "Result: %s\nChampion: %s" % [finish, champ])

	var details_box := Panel.new()
	details_box.position = Vector2(450, 80)
	details_box.size = Vector2(680, 520)
	details_box.add_theme_stylebox_override("panel", _style(Color("232029"), Color("493b33")))
	tournament_view.add_child(details_box)

	var details_scroll := ScrollContainer.new()
	details_scroll.position = Vector2(20, 20)
	details_scroll.size = Vector2(640, 480)
	details_box.add_child(details_scroll)

	var details_content := VBoxContainer.new()
	details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_content.add_theme_constant_override("separation", 10)
	details_scroll.add_child(details_content)

	var show_details = func(idx: int):
		for child in details_content.get_children():
			child.queue_free()
		if idx < 0 or idx >= records.size():
			return
		var rec: Dictionary = records[idx]

		var head_lbl := Label.new()
		head_lbl.text = "CIRCUIT TOURNAMENT — %s PACE" % rec.get("difficulty", "medium").to_upper()
		head_lbl.add_theme_font_size_override("font_size", 20)
		head_lbl.add_theme_color_override("font_color", GOLD)
		details_content.add_child(head_lbl)

		var date_lbl := Label.new()
		date_lbl.text = "Date: %s UTC   ·   Champion: %s   ·   Your Result: %s" % [
			_history_date(rec.get("created_at", 0)), rec.get("champion_name", "Unknown"), rec.get("finish_position", "None")
		]
		date_lbl.add_theme_font_size_override("font_size", 14)
		date_lbl.add_theme_color_override("font_color", PARCHMENT)
		details_content.add_child(date_lbl)

		var reg_btn := Button.new()
		reg_btn.text = "VIEW ARCHIVE GUNSLINGERS & LEADERBOARD  ›"
		reg_btn.custom_minimum_size = Vector2(400, 36)
		reg_btn.add_theme_stylebox_override("normal", _style(Color("3c342f"), GOLD, 1))
		reg_btn.add_theme_color_override("font_color", GOLD)
		reg_btn.pressed.connect(func():
			tournament_registry_source = rec
			show_page("tournament_registry"))
		details_content.add_child(reg_btn)

		var sep := HSeparator.new()
		details_content.add_child(sep)

		var part_head := Label.new()
		part_head.text = "PARTICIPANTS"
		part_head.add_theme_font_size_override("font_size", 15)
		part_head.add_theme_color_override("font_color", GOLD)
		details_content.add_child(part_head)

		var parts: Array = rec.get("participants", [])
		var arch_ctx: Dictionary = {
			"tournament_status": "completed",
			"current_round": rec.get("total_rounds", 5) - 1,
			"total_rounds": rec.get("total_rounds", 5),
			"champion_slot": rec.get("champion_slot", -1),
			"human_slot": rec.get("human_slot", -1),
			"participants": rec.get("participants", []),
			"matches": rec.get("matches", [])
		}

		for p in parts:
			var p_btn := Button.new()
			var p_role: String = " (YOU)" if p.get("is_human", false) else ""
			var elim_rnd: int = p.get("eliminated_in_round", 0)
			var elim_name: String = Circuit.ROUND_NAMES[elim_rnd] if elim_rnd >= 0 and elim_rnd < Circuit.ROUND_NAMES.size() else "Quarterfinals"
			var status_desc: String = "Champion" if p.get("slot") == rec.get("champion_slot") else ("Eliminated in %s" % elim_name if p.get("eliminated", false) else "Eliminated")
			p_btn.text = "• %s%s — %s  [View Dossier]" % [p.get("name", "Unknown"), p_role, status_desc]
			p_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			p_btn.flat = true
			p_btn.add_theme_font_size_override("font_size", 13)
			p_btn.add_theme_color_override("font_color", GOLD if p.get("is_human", false) else MUTED)
			p_btn.add_theme_color_override("font_hover_color", GOLD)
			p_btn.pressed.connect(func(): _show_participant_profile_modal(p, arch_ctx))
			details_content.add_child(p_btn)

		var sep2 := HSeparator.new()
		details_content.add_child(sep2)

		var rep_head := Label.new()
		rep_head.text = "YOUR MATCHES & REPLAYS"
		rep_head.add_theme_font_size_override("font_size", 15)
		rep_head.add_theme_color_override("font_color", GOLD)
		details_content.add_child(rep_head)

		var tourn_matches: Array = rec.get("matches", [])
		var found_human_match: bool = false

		for m in tourn_matches:
			if m.get("completed", false) and (m.get("slot_a") == rec.get("human_slot", -1) or m.get("slot_b") == rec.get("human_slot", -1)):
				found_human_match = true
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 14)
				details_content.add_child(row)

				var is_winner: bool = m.get("winner_slot") == rec.get("human_slot")
				var opp_slot: int = m.get("slot_b") if m.get("slot_a") == rec.get("human_slot") else m.get("slot_a")
				var opp_name: String = parts[opp_slot].name if opp_slot >= 0 and opp_slot < parts.size() else "Opponent"

				var m_desc := Label.new()
				m_desc.text = "%s: vs %s  ·  %s in %d turns" % [
					m.get("round_name", "Duel"), opp_name, "VICTORY" if is_winner else "DEFEAT", m.get("turns", 0)
				]
				m_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				m_desc.add_theme_font_size_override("font_size", 14)
				m_desc.add_theme_color_override("font_color", GOLD if is_winner else Color("e0887a"))
				row.add_child(m_desc)

				var rep_id: String = m.get("replay_id", "")
				if not rep_id.is_empty() and history_store != null:
					var rep_match: Dictionary = {}
					for hist_rec in history_store.matches:
						if hist_rec.id == rep_id:
							rep_match = hist_rec
							break
					if not rep_match.is_empty():
						var watch_btn := Button.new()
						watch_btn.text = "WATCH REPLAY"
						watch_btn.custom_minimum_size = Vector2(130, 30)
						watch_btn.add_theme_stylebox_override("normal", _style(Color("2f2735"), GOLD, 1))
						watch_btn.add_theme_color_override("font_color", PARCHMENT)
						watch_btn.pressed.connect(func():
							replay_return_page = "tournament_history"
							replay_requested.emit(rep_match))
						row.add_child(watch_btn)

		if not found_human_match:
			var no_m := Label.new()
			no_m.text = "No recorded duels found for this circuit."
			no_m.add_theme_font_size_override("font_size", 13)
			no_m.add_theme_color_override("font_color", MUTED)
			details_content.add_child(no_m)

	tourn_list.item_selected.connect(func(index: int):
		tournament_history_selection = index
		show_details.call(index))

	if tournament_history_selection >= 0 and tournament_history_selection < records.size():
		tourn_list.select(tournament_history_selection)
		show_details.call(tournament_history_selection)
	else:
		tourn_list.select(0)
		show_details.call(0)

func _label_in(parent: Control, text_val: String, rect: Rect2, font_size: int, color: Color = PARCHMENT, centered: bool = false, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text_val
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold:
		var western := SystemFont.new()
		western.font_names = PackedStringArray(["Georgia", "Noto Serif", "Liberation Serif"])
		western.font_weight = 800
		label.add_theme_font_override("font", western)
	parent.add_child(label)
	return label

func _button_in(parent: Control, text_val: String, rect: Rect2, callback: Callable, featured: bool = false, font_size: int = 16) -> Button:
	var button := Button.new()
	button.text = text_val
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("251d1c") if featured else PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color("251d1c"))
	button.add_theme_color_override("font_pressed_color", Color("251d1c"))
	button.add_theme_stylebox_override("normal", _style(GOLD if featured else Color("2c2830"), GOLD if featured else Color("69513f")))
	button.add_theme_stylebox_override("hover", _style(Color("f0cb8d"), Color("ffe0a3"), 2))
	button.add_theme_stylebox_override("pressed", _style(Color("c68b4b"), GOLD, 2))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
