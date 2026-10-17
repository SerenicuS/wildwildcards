extends SceneTree

const Tournament = preload("res://scripts/TournamentCircuit.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const MainMenu = preload("res://scripts/MainMenu.gd")
const Settings = preload("res://scripts/GameSettings.gd")

const TEST_ACTIVE_A := "res://.godot/test_registry_active_a.json"
const TEST_HISTORY_A := "res://.godot/test_registry_history_a.json"
const TEST_ACTIVE_B := "res://.godot/test_registry_active_b.json"
const TEST_HISTORY_B := "res://.godot/test_registry_history_b.json"

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILURE: " + message)

func clean_test_files() -> void:
	for path in [
		TEST_ACTIVE_A, TEST_ACTIVE_A + ".tmp", TEST_HISTORY_A, TEST_HISTORY_A + ".tmp",
		TEST_ACTIVE_B, TEST_ACTIVE_B + ".tmp", TEST_HISTORY_B, TEST_HISTORY_B + ".tmp"
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _initialize() -> void:
	clean_test_files()

	print("--- Starting Tournament Registry Tests ---")

	# -------------------------------------------------------------
	# 1. test_registry_view_loads_all_participants
	# -------------------------------------------------------------
	print("Running Requirement 1: Loads all participants in 8, 16, 32 tournaments...")
	var tourn8 := Tournament.new()
	tourn8.active_path = TEST_ACTIVE_A
	tourn8.history_path = TEST_HISTORY_A
	tourn8.create_tournament("Player 8", {}, {}, "medium", 8)
	var list8 := Tournament.filter_and_sort_participants(tourn8.participants, "all", "rank", "", tourn8.status, 0, 3, -1)
	check(list8.size() == 8, "8-participant tournament registry loads all 8 gunslingers")

	var tourn16 := Tournament.new()
	tourn16.active_path = TEST_ACTIVE_A
	tourn16.history_path = TEST_HISTORY_A
	tourn16.create_tournament("Player 16", {}, {}, "medium", 16)
	var list16 := Tournament.filter_and_sort_participants(tourn16.participants, "all", "rank", "", tourn16.status, 0, 4, -1)
	check(list16.size() == 16, "16-participant tournament registry loads all 16 gunslingers")

	var tourn32 := Tournament.new()
	tourn32.active_path = TEST_ACTIVE_A
	tourn32.history_path = TEST_HISTORY_A
	tourn32.rng.seed = 42
	tourn32.create_tournament("Marshal Dylan", {"hat": "gambler", "outfit": "duster"}, {"grip": "pearl"}, "hard", 32)
	var list32 := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "", tourn32.status, 0, 5, -1)
	check(list32.size() == 32, "32-participant tournament registry loads all 32 gunslingers")

	# -------------------------------------------------------------
	# 2. test_search_exact_match
	# -------------------------------------------------------------
	print("Running Requirement 2: Search exact match...")
	var exact_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "Marshal Dylan", tourn32.status, 0, 5, -1)
	check(exact_res.size() == 1, "Exact search finds exactly 1 gunslinger")
	check(exact_res[0].name == "Marshal Dylan", "Exact search returned expected gunslinger")

	# -------------------------------------------------------------
	# 3. test_search_case_insensitive
	# -------------------------------------------------------------
	print("Running Requirement 3: Case-insensitive search...")
	var lower_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "marshal dylan", tourn32.status, 0, 5, -1)
	var upper_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "MARSHAL DYLAN", tourn32.status, 0, 5, -1)
	var mixed_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "mArShAl DyLaN", tourn32.status, 0, 5, -1)
	check(lower_res.size() == 1 and lower_res[0].name == "Marshal Dylan", "Lowercase query matches")
	check(upper_res.size() == 1 and upper_res[0].name == "Marshal Dylan", "Uppercase query matches")
	check(mixed_res.size() == 1 and mixed_res[0].name == "Marshal Dylan", "Mixed-case query matches")

	# -------------------------------------------------------------
	# 4. test_search_partial_name
	# -------------------------------------------------------------
	print("Running Requirement 4: Partial-name matching...")
	var partial_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "dyl", tourn32.status, 0, 5, -1)
	check(partial_res.size() == 1 and partial_res[0].name == "Marshal Dylan", "Partial substring 'dyl' matches Marshal Dylan")

	var sample_bot: Dictionary = tourn32.participants[1]
	var bot_sub: String = sample_bot.name.substr(1, 3).to_lower()
	var bot_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", bot_sub, tourn32.status, 0, 5, -1)
	check(bot_res.size() >= 1, "Partial substring matches bot gunslinger")

	# -------------------------------------------------------------
	# 5. test_search_empty_clears_filter
	# -------------------------------------------------------------
	print("Running Requirement 5: Empty search restores full list...")
	var empty_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "", tourn32.status, 0, 5, -1)
	check(empty_res.size() == 32, "Empty query string returns all 32 participants")
	var whitespace_res := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "    ", tourn32.status, 0, 5, -1)
	check(whitespace_res.size() == 32, "Whitespace-only query string returns all 32 participants")

	# -------------------------------------------------------------
	# 6. test_search_no_matches_message
	# -------------------------------------------------------------
	print("Running Requirement 6: No matches behavior...")
	var no_match := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "ZzzNonexistentOutlaw99", tourn32.status, 0, 5, -1)
	check(no_match.size() == 0, "Query with no match returns empty array cleanly")

	# -------------------------------------------------------------
	# 7. test_filter_still_competing
	# -------------------------------------------------------------
	print("Running Requirement 7: Filter Still Competing...")
	# Simulate Round of 32 (human wins, 15 bot duels simulated)
	tourn32.record_human_match_result(true, 4, "", false)
	var r0_sim := tourn32.finish_round_simulation_instant(0)
	check(r0_sim.size() == 15, "15 bot duels completed in Round of 32")
	var adv := tourn32.advance_to_next_round()
	check(adv and tourn32.current_round == 1, "Tournament advanced to Round of 16")

	var competing := Tournament.filter_and_sort_participants(tourn32.participants, "competing", "rank", "", tourn32.status, 1, 5, -1)
	check(competing.size() == 16, "Filter 'competing' returns exactly 16 contenders after Round of 32")
	for p in competing:
		check(not p.get("eliminated", false), "Competing gunslinger is not eliminated")
		var s_info := Tournament.get_participant_status_info(p, tourn32.status, 1, 5, -1)
		check(s_info.is_competing == true, "Status info indicates is_competing")
		check(s_info.rank_text == "—", "Live contender rank_text is '—' (not assigned false final rank)")
		check(s_info.status_text.begins_with("Still competing"), "Status text indicates still competing")

	# -------------------------------------------------------------
	# 8. test_filter_eliminated
	# -------------------------------------------------------------
	print("Running Requirement 8: Filter Eliminated...")
	var eliminated := Tournament.filter_and_sort_participants(tourn32.participants, "eliminated", "rank", "", tourn32.status, 1, 5, -1)
	check(eliminated.size() == 16, "Filter 'eliminated' returns exactly 16 eliminated gunslingers")
	for p in eliminated:
		check(p.get("eliminated", false), "Participant is flagged eliminated")
		check(p.get("rank", 0) == 17, "Participants eliminated in Round of 32 have tied rank #17")
		var s_info := Tournament.get_participant_status_info(p, tourn32.status, 1, 5, -1)
		check(s_info.is_competing == false, "Status info indicates eliminated")
		check(s_info.rank_text == "Tied #17", "Eliminated participant has Tied #17 rank_text")

	# -------------------------------------------------------------
	# 9. test_filter_human_only
	# -------------------------------------------------------------
	print("Running Requirement 9: Filter Human Only...")
	var human_only := Tournament.filter_and_sort_participants(tourn32.participants, "human", "rank", "", tourn32.status, 1, 5, -1)
	check(human_only.size() == 1, "Human filter returns exactly 1 participant")
	check(human_only[0].name == "Marshal Dylan", "Returned participant is the human player")

	# -------------------------------------------------------------
	# 10. test_filter_bots_only
	# -------------------------------------------------------------
	print("Running Requirement 10: Filter Bots Only...")
	var bots_only := Tournament.filter_and_sort_participants(tourn32.participants, "bot", "rank", "", tourn32.status, 1, 5, -1)
	check(bots_only.size() == 31, "Bot filter returns all 31 AI gunslingers")
	for b in bots_only:
		check(not b.get("is_human", false), "Gunslinger is not human")

	# -------------------------------------------------------------
	# 11. test_concurrent_search_and_filter
	# -------------------------------------------------------------
	print("Running Requirement 11: Concurrent search and filter...")
	# Search for human by name while filtering by bots -> should be empty
	var no_human_in_bots := Tournament.filter_and_sort_participants(tourn32.participants, "bot", "rank", "Dylan", tourn32.status, 1, 5, -1)
	check(no_human_in_bots.size() == 0, "Searching human name in bots filter returns 0 results")

	# Search human in human filter -> 1 result
	var human_in_human := Tournament.filter_and_sort_participants(tourn32.participants, "human", "rank", "Dylan", tourn32.status, 1, 5, -1)
	check(human_in_human.size() == 1, "Searching human name in human filter returns 1 result")

	# Search for a letter in competing participants
	var comp_letter := Tournament.filter_and_sort_participants(tourn32.participants, "competing", "rank", "a", tourn32.status, 1, 5, -1)
	for p in comp_letter:
		check(not p.get("eliminated", false), "Concurrent result is still competing")
		check(p.name.to_lower().contains("a"), "Concurrent result name contains search query")

	# -------------------------------------------------------------
	# 12. test_sort_by_rank
	# -------------------------------------------------------------
	print("Running Requirement 12: Sort by rank in completed circuit...")
	# Simulate through completion
	tourn32.finish_all_remaining_tournament_instant()
	check(tourn32.champion_slot >= 0, "Tournament successfully crowned a champion")
	var ranked_all := Tournament.filter_and_sort_participants(tourn32.participants, "all", "rank", "", "completed", 4, 5, tourn32.champion_slot)
	check(ranked_all.size() == 32, "Ranked list includes all 32 participants")

	# Champion must be first
	var champ_entry: Dictionary = ranked_all[0]
	var champ_status := Tournament.get_participant_status_info(champ_entry, "completed", 4, 5, tourn32.champion_slot)
	check(champ_status.rank_text == "#1", "Champion rank_text is #1")
	check(champ_status.status_text == "Champion", "Champion status_text is Champion")
	check(champ_entry.slot == tourn32.champion_slot, "Champion entry matches tournament champion_slot")

	# Runner-Up must be second
	var runner_up: Dictionary = ranked_all[1]
	var ru_status := Tournament.get_participant_status_info(runner_up, "completed", 4, 5, tourn32.champion_slot)
	check(ru_status.confirmed_rank == 2, "Runner-up confirmed rank is 2")
	check(ru_status.rank_text == "Runner-Up #2", "Runner-up rank_text is Runner-Up #2")

	# Next 2 must be Semifinalists (Rank 3)
	check(ranked_all[2].rank == 3 and ranked_all[3].rank == 3, "Slots 2 and 3 are Semifinalists (Tied #3)")
	# Next 4 Quarterfinalists (Rank 5)
	for k in range(4, 8):
		check(ranked_all[k].rank == 5, "Ranked position %d is Quarterfinalist (Tied #5)" % k)
	# Next 8 Round of 16 (Rank 9)
	for k in range(8, 16):
		check(ranked_all[k].rank == 9, "Ranked position %d is Round of 16 (Tied #9)" % k)
	# Next 16 Round of 32 (Rank 17)
	for k in range(16, 32):
		check(ranked_all[k].rank == 17, "Ranked position %d is Round of 32 (Tied #17)" % k)

	# Verify monotonic order
	for k in range(31):
		var r1: int = ranked_all[k].rank
		var r2: int = ranked_all[k + 1].rank
		check(r1 <= r2, "Ranks are monotonically non-decreasing: %d <= %d" % [r1, r2])

	# -------------------------------------------------------------
	# 13. test_sort_by_wins_losses_and_percentage
	# -------------------------------------------------------------
	print("Running Requirement 13: Sort by wins, losses, win %, name...")
	var sorted_wins := Tournament.filter_and_sort_participants(tourn32.participants, "all", "wins", "", "completed", 4, 5, tourn32.champion_slot)
	for k in range(31):
		check(sorted_wins[k].wins >= sorted_wins[k + 1].wins, "Sorted by wins is in non-increasing order: %d >= %d" % [sorted_wins[k].wins, sorted_wins[k + 1].wins])
	check(sorted_wins[0].wins == 5, "Champion has maximum 5 wins")

	var sorted_losses := Tournament.filter_and_sort_participants(tourn32.participants, "all", "losses", "", "completed", 4, 5, tourn32.champion_slot)
	check(sorted_losses[0].losses == 0, "Fewest losses starts with Champion (0 losses)")
	for k in range(31):
		check(sorted_losses[k].losses <= sorted_losses[k + 1].losses, "Sorted by losses is in non-decreasing order: %d <= %d" % [sorted_losses[k].losses, sorted_losses[k + 1].losses])

	var sorted_pct := Tournament.filter_and_sort_participants(tourn32.participants, "all", "win_pct", "", "completed", 4, 5, tourn32.champion_slot)
	var prev_pct: float = 100.0
	for p in sorted_pct:
		var cur_pct: float = Tournament.win_percentage(p.wins, p.losses)
		check(cur_pct <= prev_pct + 0.001, "Win percentage is in non-increasing order: %.1f <= %.1f" % [cur_pct, prev_pct])
		prev_pct = cur_pct

	check(Tournament.format_win_percentage(5, 0) == "100%", "Win percentage format 5-0 is 100%")
	check(Tournament.format_win_percentage(1, 1) == "50%", "Win percentage format 1-1 is 50%")
	check(Tournament.format_win_percentage(0, 1) == "0%", "Win percentage format 0-1 is 0%")
	check(Tournament.format_win_percentage(1, 2) == "33.3%", "Win percentage format 1-2 is 33.3%")

	# Alphabetical sorts
	var sorted_a_z := Tournament.filter_and_sort_participants(tourn32.participants, "all", "name_asc", "", "completed", 4, 5, tourn32.champion_slot)
	for k in range(31):
		check(sorted_a_z[k].name.to_lower() <= sorted_a_z[k + 1].name.to_lower(), "A-Z sorting order valid")

	var sorted_z_a := Tournament.filter_and_sort_participants(tourn32.participants, "all", "name_desc", "", "completed", 4, 5, tourn32.champion_slot)
	for k in range(31):
		check(sorted_z_a[k].name.to_lower() >= sorted_z_a[k + 1].name.to_lower(), "Z-A sorting order valid")

	# -------------------------------------------------------------
	# 14. test_participant_dossier_contains_match_history
	# -------------------------------------------------------------
	print("Running Requirement 14: Dossier contains complete match history...")
	var champ_p: Dictionary = tourn32.participants[tourn32.champion_slot]
	var champ_matches := Tournament.get_matches_for_participant(champ_p.id, tourn32.matches)
	check(champ_matches.size() == 5, "Champion has exactly 5 match records in a 32-player tournament")

	var ru_p: Dictionary = tourn32.participants[runner_up.slot]
	var ru_matches := Tournament.get_matches_for_participant(ru_p.id, tourn32.matches)
	check(ru_matches.size() == 5, "Runner-up has exactly 5 match records (4 wins, 1 loss in finals)")

	for m in champ_matches:
		check(m.completed, "Recorded match is completed")
		check(m.winner_id == champ_p.id, "Champion won every one of their matches")
		check(m.turns > 0, "Match recorded turn count > 0")
		check(not m.round_name.is_empty(), "Match has valid round_name")
		check(not m.arena.is_empty(), "Match has valid arena definition")

	# Verify W/L totals match sum of opponent categories
	for p in tourn32.participants:
		check(p.wins == p.wins_vs_human + p.wins_vs_bots, "Overall wins equals vs_human + vs_bots for participant %s" % p.name)
		check(p.losses == p.losses_vs_human + p.losses_vs_bots, "Overall losses equals vs_human + vs_bots for participant %s" % p.name)

	# -------------------------------------------------------------
	# 15. test_tournament_isolation
	# -------------------------------------------------------------
	print("Running Requirement 15: Tournament isolation between active and archive...")
	tourn32.save_to_history()
	var hist_records: Array = tourn32.load_history()
	check(hist_records.size() >= 1, "Tournament saved to history archive")
	var archived_tourn: Dictionary = hist_records[0]

	# Create a brand new active tournament with different seed
	var new_active := Tournament.new()
	new_active.active_path = TEST_ACTIVE_B
	new_active.history_path = TEST_HISTORY_B
	new_active.rng.seed = 99999
	new_active.create_tournament("Sheriff Wyatt", {}, {}, "easy", 16)

	var active_guns := Tournament.filter_and_sort_participants(new_active.participants, "all", "rank", "", "active", 0, 4, -1)
	check(active_guns.size() == 16, "New active tournament has 16 participants")

	var arch_participants: Array = archived_tourn.get("participants", [])
	var arch_champ_slot: int = int(archived_tourn.get("champion_slot", -1))
	var arch_h_slot: int = int(archived_tourn.get("human_slot", -1))

	var archive_guns := Tournament.filter_and_sort_participants(arch_participants, "all", "rank", "", "completed", 4, 5, arch_champ_slot)
	check(archive_guns.size() == 32, "Archived tournament has 32 participants")

	# Human in active is Sheriff Wyatt, in archive is Marshal Dylan
	var active_human: Dictionary = new_active.participants[new_active.human_slot]
	check(active_human.name == "Sheriff Wyatt", "Active tournament human is Sheriff Wyatt")
	var archive_human: Dictionary = arch_participants[arch_h_slot] if arch_h_slot >= 0 and arch_h_slot < arch_participants.size() else {}
	check(archive_human.get("name", "") == "Marshal Dylan", "Archive tournament human is Marshal Dylan")

	# Searching for Sheriff Wyatt in archive returns 0
	var wyatt_in_archive := Tournament.filter_and_sort_participants(arch_participants, "all", "rank", "Sheriff Wyatt", "completed", 4, 5, arch_champ_slot)
	check(wyatt_in_archive.size() == 0, "No cross-leakage of active gunslinger into archive registry")

	# Searching for Marshal Dylan in new active returns 0
	var dylan_in_active := Tournament.filter_and_sort_participants(new_active.participants, "all", "rank", "Marshal Dylan", "active", 0, 4, -1)
	check(dylan_in_active.size() == 0, "No cross-leakage of archive gunslinger into active registry")

	# -------------------------------------------------------------
	# 16. UI Interaction & Navigation Verification
	# -------------------------------------------------------------
	print("Running UI Verification: MainMenu registry tabs, controls, and modal...")
	var menu := MainMenu.new()
	menu.tournament = new_active
	menu.settings = Settings.new()
	menu.profile = Profile.new()
	menu._ready()

	# Open tournament registry page
	menu.show_page("tournament_registry")
	check(menu.page == "tournament_registry", "Page switched to tournament_registry")
	check(is_instance_valid(menu.tournament_view), "tournament_view created for registry")

	# Verify UI elements exist in tournament_view
	var found_search := false
	var found_clear := false
	var found_filter := false
	var found_sort := false
	var found_table := false

	for child in menu.tournament_view.get_children():
		if child is Panel:
			for sub in child.get_children():
				if sub is LineEdit:
					found_search = true
				elif sub is Button and sub.text == "✕":
					found_clear = true
				elif sub is OptionButton:
					if sub.item_count == 5:
						found_filter = true
					elif sub.item_count == 6:
						found_sort = true
				elif sub is ScrollContainer:
					found_table = true

	check(found_search, "Search LineEdit present in UI")
	check(found_clear, "Clear search button present in UI")
	check(found_filter, "Filter OptionButton present in UI")
	check(found_sort, "Sort OptionButton present in UI")
	check(found_table, "Leaderboard ScrollContainer table present in UI")

	# Test opening participant modal
	var sample_p: Dictionary = new_active.participants[0]
	menu._show_participant_profile_modal(sample_p)
	check(menu.design.get_child_count() > 0, "Modal dialog added to menu design tree")

	# Clean up UI
	menu.queue_free()
	clean_test_files()

	print("\n===========================================================")
	print(" Tournament Registry Results: %d checks, %d failures" % [checks, failures])
	print("===========================================================\n")

	if failures > 0:
		quit(1)
	else:
		quit(0)
