extends SceneTree

const Main = preload("res://scripts/GameManager.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Looks = preload("res://scripts/CharacterAppearance.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func click(control: Control) -> void:
	await settle()
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	control.get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		control.get_viewport().push_input(event, true)
	await settle()

func choose(menu: Control, key: String, id: String) -> void:
	var picker: OptionButton = menu.appearance_selectors[key]
	for index in picker.item_count:
		if picker.get_item_metadata(index) == id:
			picker.select(index)
			picker.item_selected.emit(index)
			return
	check(false, "Missing cosmetic picker ID " + id)

func fit(menu: Control) -> void:
	for child in menu.content.get_children():
		if child is Control:
			check(child.get_global_rect().end.y <= 635, "Customization control stays inside menu: " + menu.page)

func capture(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("res://.godot/expanded_%s.png" % name)

func gallery() -> void:
	var canvas := Node2D.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("292630")
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	var entries: Array = []
	for key in ["hat", "outfit_style", "accessory"]:
		for id in Looks.catalogs()[key]:
			entries.append([key, id, Looks.catalogs()[key][id]])
	for i in entries.size():
		var entry: Array = entries[i]
		var x: float = 75 + (i % 6) * 210
		var y: float = 215 + (i / 6) * 220
		var preview := preload("res://scripts/CharacterPreview.gd").new()
		preview.position = Vector2(x, y)
		preview.scale = Vector2(0.85, 0.85)
		var value := Looks.defaults()
		value[entry[0]] = entry[1]
		value.outfit = ["teal", "rust", "violet", "sand"][i % 4]
		preview.set_player_appearance(value)
		canvas.add_child(preview)
		var label := Label.new()
		label.text = entry[2]
		label.position = Vector2(x - 53, y + 12)
		label.add_theme_font_size_override("font_size", 15)
		canvas.add_child(label)
	await capture("gallery")
	canvas.queue_free()
	await process_frame

func run() -> void:
	var profile := Profile.new()
	profile.path = "res://.godot/expanded_ui.json"
	profile.save_profile(true)
	var game := Main.new()
	game.profile.path = profile.path
	game.settings.path = "res://.godot/expanded_ui.cfg"
	root.add_child(game)
	game.set_process(false)
	await settle()
	var menu: Control = game.main_menu
	await click(menu.buttons.customize)
	fit(menu)
	# Every ID produces distinct pixels with animation frozen, not just different data.
	for entry in [["hat", Looks.HATS], ["outfit", Looks.OUTFITS], ["accessory", Looks.ACCESSORIES]]:
		var seen := {}
		for id in entry[1]:
			choose(menu, entry[0], id)
			menu.character_preview.set_process(false)
			menu.character_preview.clock = 0.0
			await settle()
			var pixels := root.get_texture().get_image().get_region(Rect2i(797,186,145,140)).get_data()
			seen[hash(pixels)] = true
		check(seen.size() == entry[1].size(), "Every %s option visibly distinct" % entry[0])
	await click(menu.buttons.clothing)
	fit(menu)
	for entry in [["outfit_style", Looks.STYLES], ["hat_color", Looks.TINTS], ["accessory_color", Looks.TINTS]]:
		menu.draft_appearance.accessory = "bandana"
		var seen := {}
		for id in entry[1]:
			choose(menu, entry[0], id)
			menu.character_preview.set_process(false)
			menu.character_preview.clock = 0.0
			await settle()
			seen[hash(root.get_texture().get_image().get_region(Rect2i(900,186,150,140)).get_data())] = true
		check(seen.size() == entry[1].size(), "Every %s option visibly distinct" % entry[0])
	choose(menu, "outfit_style", "poncho")
	choose(menu, "hat_color", "cream")
	choose(menu, "accessory_color", "dark_red")
	await settle()
	var torso_before := root.get_texture().get_image().get_region(Rect2i(925,257,35,30)).get_data()
	choose(menu, "hat_color", "navy")
	await settle()
	check(root.get_texture().get_image().get_region(Rect2i(925,257,35,30)).get_data() == torso_before, "Hat tint does not recolor outfit or accessory")
	var hat_before := root.get_texture().get_image().get_region(Rect2i(910,191,60,30)).get_data()
	choose(menu, "accessory_color", "forest")
	await settle()
	check(root.get_texture().get_image().get_region(Rect2i(910,191,60,30)).get_data() == hat_before, "Accessory tint does not recolor hat")
	choose(menu, "hat_color", "cream")
	choose(menu, "accessory_color", "dark_red")
	await capture("clothing")
	var selected: Dictionary = menu.draft_appearance.duplicate()
	await click(menu.buttons.equip)
	check(game.profile.appearance == selected and game.arena.player_appearance == selected, "Equip updates saved and real character")
	await click(menu.buttons.look)
	await capture("customize")
	await click(menu.buttons.presets)
	fit(menu)
	menu.preset_name.text = "Trail Rider"
	await click(menu.buttons.save_preset)
	check(game.profile.outfit_presets.size() == 1 and game.profile.outfit_presets[0].appearance == selected, "Save current draft captures all cosmetic fields")
	menu.preset_name.text = "Moon Rider"
	await click(menu.buttons.rename_preset)
	check(game.profile.outfit_presets[0].name == "Moon Rider", "Rename via UI")
	menu.draft_appearance.hat = "classic"
	await click(menu.buttons.load_preset)
	check(menu.draft_appearance == selected and menu.character_preview.player_appearance == selected, "Load updates live preview")
	await capture("presets")
	menu.preset_name.text = "W".repeat(24)
	await click(menu.buttons.rename_preset)
	check(menu.preset_selector.size.x <= 380 and menu.content.size.x <= 380, "Maximum-width preset names cannot expand the menu")
	await click(menu.buttons.delete_preset)
	check(game.profile.outfit_presets.size() == 1 and menu.preset_delete_dialog.visible, "Deletion requires explicit confirmation")
	menu.preset_delete_dialog.canceled.emit()
	await settle()
	check(game.profile.outfit_presets.size() == 1, "Cancel deletion preserves preset")
	await click(menu.buttons.delete_preset)
	menu.preset_delete_dialog.confirmed.emit()
	await settle()
	check(game.profile.outfit_presets.is_empty(), "Confirmed deletion succeeds")
	await click(menu.buttons.back)
	await click(menu.buttons.clothing)
	var target: OptionButton = menu.content.get_child(1)
	target.select(2)
	target.item_selected.emit(2)
	await settle()
	choose(menu, "outfit_style", "duster")
	choose(menu, "hat_color", "black")
	await click(menu.buttons.look)
	choose(menu, "hat", "outlaw")
	choose(menu, "outfit", "dark_red")
	choose(menu, "accessory", "gloves")
	await click(menu.buttons.equip)
	var guest: Dictionary = menu.local_appearance(1)
	check(guest.outfit_style == "duster" and guest.hat == "outlaw", "Local P2 full clothing equipped for session")
	check(game.profile.appearance == selected, "Guest equip cannot overwrite saved primary")
	game.start_local_duel()
	check(game.arena.player_appearance == selected and game.arena.opponent_appearance == guest, "Local duel applies independent complete appearances")
	game.arena.set_process(false)
	var muzzle: Vector2 = game.arena.muzzle_world(1)
	for style in Looks.STYLES:
		var clothed := guest.duplicate()
		clothed.outfit_style = style
		game.arena.set_opponent_appearance(clothed)
		check(game.arena.muzzle_world(1) == muzzle, "Clothing preserves mirrored muzzle position")
	game.arena.set_opponent_appearance(guest)
	var nodes_before := get_node_count()
	var rng := RandomNumberGenerator.new()
	rng.seed = 50504
	for i in range(40):
		game.arena.set_player_appearance(Looks.randomized(rng))
		game.arena.set_opponent_appearance(Looks.randomized(rng))
		await settle()
	check(get_node_count() == nodes_before, "Repeated expanded rendering allocates no extra scene nodes")
	game.arena.set_player_appearance(selected)
	game.arena.set_opponent_appearance(guest)
	await capture("local")
	game.show_menu()
	menu.show_page("customize")
	await settle()
	choose(menu, "hat", "cattleman")
	await click(menu.buttons.back)
	check(game.profile.appearance == selected, "Back cancels unsaved appearance draft")
	game.start_duel()
	check(game.arena.player_appearance == selected, "Solo uses saved look after guest changes")
	game.show_menu()
	menu.show_page("profile")
	await settle()
	check(menu.profile_portrait.player_appearance == selected, "WANTED profile portrait uses all equipped layers")
	await capture("profile")
	var before_stats: Dictionary = game.profile.stats.duplicate()
	game.elimination.play("wanted_eliminated", {"name": "Local Player 2", "appearance": guest}, true)
	await settle()
	check(game.elimination.portrait.player_appearance == guest, "WANTED elimination portrait includes expanded defeated clothing")
	game.elimination.skip()
	check(game.profile.stats == before_stats, "Expanded finisher preview leaves stats unchanged")
	game.start_gauntlet()
	check(game.arena.opponent_appearance == game.gauntlet.opponent.appearance, "Gauntlet applies expanded generated appearance")
	game.show_menu()
	game._confirm_gauntlet_exit()
	check(game.profile.stats.matches_played == 0, "Preview, presets and local/abandoned duels do not change Solo results")
	game.queue_free()
	await process_frame
	await gallery()
	print("Expanded appearance UI/integration: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
