extends Control

signal elimination_preview_requested(effect_id: String, target: Dictionary)
signal solo_requested
signal quit_requested

const PARCHMENT := Color("eddbb8")
const GOLD := Color("e9b86d")
const MUTED := Color("aa9b90")
const Effects = preload("res://scripts/EliminationEffects.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Poster = preload("res://scripts/WantedPoster.gd")
var settings: RefCounted
var profile: RefCounted
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
var name_edit: LineEdit
var profile_notice: Label
var draft_effect: String = "classic"
var elimination_selector: OptionButton
var effect_description: Label
var draft_appearance: Dictionary = {}
var character_preview: Node2D
var appearance_status: Label
var appearance_selectors: Dictionary = {}
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

func show_page(next_page: String) -> void:
	page = next_page
	# Detach now so navigation never leaves old controls active for a frame.
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	buttons.clear()
	appearance_selectors.clear()
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
			_button("settings", "SETTINGS", func(): show_page("settings"))
			_button("quit", "QUIT", func(): quit_requested.emit())
			_copy("The next hand is yours.", 14)
		"play":
			page_heading.text = "CHOOSE YOUR TABLE"
			_copy("A duel against Copper Jack.\nEvery second counts.", 18, PARCHMENT)
			_button("solo", "SOLO DUEL                         ›", func(): solo_requested.emit(), true)
			_button("casual", "CASUAL PvP  ·  Coming Soon", func(): pass, false, true)
			_button("local", "LOCAL PvP  ·  Coming Soon", func(): pass, false, true)
			_back()
		"customize":
			_build_customize()
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
	if page == "customize" and is_instance_valid(character_preview):
		_update_preview()

func _save_name() -> void:
	var error: Error = profile.set_display_name(name_edit.text)
	profile_notice.text = "Name saved." if error == OK else "Could not save profile. Please try again."
	if error == OK:
		name_edit.text = profile.display_name
		name_edit.release_focus()

func _build_customize() -> void:
	page_heading.text = "CUSTOMIZE"
	content.add_theme_constant_override("separation", 4)
	draft_effect = Effects.resolve_id(profile.equipped_elimination_effect)
	draft_appearance = profile.appearance.duplicate()
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
	description.text = "YOUR GUNSLINGER\n\nTry a look.\nEquip it for Solo Duel."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", PARCHMENT)
	row.add_child(description)
	for entry in [["hat", "HAT", Appearance.HATS], ["outfit", "OUTFIT", Appearance.OUTFITS],
			["accessory", "ACCESSORY", Appearance.ACCESSORIES]]:
		_appearance_row(entry[0], entry[1], entry[2])
	var effect_row := HBoxContainer.new()
	effect_row.custom_minimum_size.y = 34
	content.add_child(effect_row)
	var caption := Label.new()
	caption.text = "ELIMINATION"
	caption.custom_minimum_size.x = 112
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", MUTED)
	effect_row.add_child(caption)
	elimination_selector = OptionButton.new()
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

func _preview_elimination() -> void:
	elimination_preview_requested.emit(draft_effect, {"name": profile.display_name,
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
	character_preview.set_player_appearance(draft_appearance)
	effect_description.text = Effects.DESCRIPTIONS[draft_effect]
	var equipped: bool = draft_appearance == profile.appearance and draft_effect == profile.equipped_elimination_effect
	appearance_status.text = "Equipped for Solo Duel" if equipped else "Preview · not equipped"
	buttons.equip.text = "EQUIPPED" if equipped else "EQUIP"
	buttons.equip.disabled = equipped

func _equip() -> void:
	if profile.equip_loadout(draft_appearance, draft_effect) == OK:
		_update_preview()
	else:
		appearance_status.text = "Could not save appearance. Please try again."

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
