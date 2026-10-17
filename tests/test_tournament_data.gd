extends SceneTree

const Tournament = preload("res://scripts/TournamentCircuit.gd")
const Profile = preload("res://scripts/ProfileManager.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
const Arenas = preload("res://scripts/ArenaDefinitions.gd")

const TEST_ACTIVE := "res://.godot/test_tournament_active.json"
const TEST_HISTORY := "res://.godot/test_tournament_history.json"
const TEST_PROFILE := "res://.godot/test_tournament_profile.json"

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILURE: " + message)

func clean_test_files() -> void:
	for path in [TEST_ACTIVE, TEST_ACTIVE + ".tmp", TEST_HISTORY, TEST_HISTORY + ".tmp", TEST_PROFILE, TEST_PROFILE + ".tmp", TEST_PROFILE + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _initialize() -> void:
	clean_test_files()

	# -------------------------------------------------------------
	# 1. Default 32-Participant Tournament Creation & Seeding
	# -------------------------------------------------------------
	var tourn := Tournament.new()
	tourn.active_path = TEST_ACTIVE
	tourn.history_path = TEST_HISTORY
	tourn.rng.seed = 12345

	tourn.create_tournament("Marshal Dylan", {"hat": "gambler", "outfit": "duster"}, {"grip": "pearl"}, "hard")
	check(tourn.status == "active", "Tournament status starts as active")
	check(tourn.difficulty == "hard", "Tournament preserves difficulty preset")
	check(tourn.tournament_size == 32, "Default tournament size is 32")
	check(tourn.total_rounds == 5, "32-player tournament has 5 rounds")
	check(tourn.current_round == 0, "Starts at round 0 (Round of 32)")
	check(tourn.participants.size() == 32, "32 participants generated")
	check(tourn.human_slot >= 0 and tourn.human_slot < 32, "Human participant placed in valid bracket slot")

	var human: Dictionary = tourn.participants[tourn.human_slot]
	check(human.is_human and human.name == "Marshal Dylan", "Human participant has correct identity")
	check(human.appearance.hat == "gambler", "Human participant has correct appearance")

	var bot_names := {}
	var unique_bots: int = 0
	for i in range(32):
		var p: Dictionary = tourn.participants[i]
		check(p.slot == i, "Participant slot matches index")
		if not p.is_human:
			check(p.personality.aggression >= 0.7 and p.personality.aggression <= 1.3, "Bot aggression within valid bounds")
			check(p.personality.caution >= 0.7 and p.personality.caution <= 1.3, "Bot caution within valid bounds")
			check(p.personality.greed >= 0.7 and p.personality.greed <= 1.3, "Bot greed within valid bounds")
			check(Appearance.sanitize(p.appearance) == p.appearance, "Bot appearance is sanitized and valid")
			check(Revolver.sanitize(p.revolver) == p.revolver, "Bot revolver is sanitized and valid")
			if not bot_names.has(p.name):
				bot_names[p.name] = true
				unique_bots += 1

	check(unique_bots == 31, "All 31 bot participants have unique names")
	check(tourn.matches.size() == 31, "32-player bracket contains exactly 31 matches")

	# Check Round 0 (Round of 32: 16 matches) seeding
	for m_idx in range(16):
		var m: Dictionary = tourn.matches[m_idx]
		check(m.round == 0 and m.round_name == "Round of 32", "Matches 0..15 are Round of 32")
		check(m.slot_a == m_idx * 2 and m.slot_b == m_idx * 2 + 1, "R32 matches seed adjacent pairs")
		check(Arenas.ORDER.has(m.arena), "Match assigned a valid arena")
		check(not m.completed and m.winner_slot == -1, "Match starts unplayed")

	# Check pending placeholder slots for subsequent rounds
	for m_idx in range(16, 24):
		check(tourn.matches[m_idx].round == 1 and tourn.matches[m_idx].round_name == "Round of 16", "Matches 16..23 are Round of 16")
		check(tourn.matches[m_idx].slot_a == -1 and tourn.matches[m_idx].slot_b == -1, "R16 match slots pending R32 winners")

	for m_idx in range(24, 28):
		check(tourn.matches[m_idx].round == 2 and tourn.matches[m_idx].round_name == "Quarterfinals", "Matches 24..27 are Quarterfinals")

	for m_idx in range(28, 30):
		check(tourn.matches[m_idx].round == 3 and tourn.matches[m_idx].round_name == "Semifinals", "Matches 28..29 are Semifinals")

	check(tourn.matches[30].round == 4 and tourn.matches[30].round_name == "Championship", "Match 30 is Championship")
	check(tourn.matches[30].slot_a == -1 and tourn.matches[30].slot_b == -1, "Championship slots pending SF winners")

	# -------------------------------------------------------------
	# 2. Persistence of 32-player Active Tournament
	# -------------------------------------------------------------
	check(tourn.has_active_tournament(), "Active tournament file recognized")
	var loaded_tourn := Tournament.new()
	loaded_tourn.active_path = TEST_ACTIVE
	loaded_tourn.history_path = TEST_HISTORY
	check(loaded_tourn.load_active(), "Active tournament successfully loaded from disk")
	check(loaded_tourn.tournament_id == tourn.tournament_id, "Tournament ID preserved across reload")
	check(loaded_tourn.tournament_size == 32, "Tournament size preserved across reload")
	check(loaded_tourn.total_rounds == 5, "Total rounds preserved across reload")
	check(loaded_tourn.participants.size() == 32, "All 32 participants preserved across reload")
	check(loaded_tourn.matches.size() == 31, "All 31 matches preserved across reload")

	# -------------------------------------------------------------
	# 3. Stepped Simulation & Catch-Up Mechanics
	# -------------------------------------------------------------
	var r0_prog := tourn.get_round_progress(0)
	check(r0_prog.total_matches == 16, "Round 0 has 16 total matches")
	check(r0_prog.completed_matches == 0, "Initially 0 completed matches")
	check(not r0_prog.is_complete, "Round is not initially complete")

	# Step one bot match
	var step_res := tourn.step_round_simulation(0)
	check(not step_res.is_empty(), "step_round_simulation resolved one match")
	check(step_res.completed, "Stepped match is completed")
	check(step_res.round == 0, "Stepped match is in Round 0")
	var r0_prog_after := tourn.get_round_progress(0)
	check(r0_prog_after.completed_matches == 1, "Progress shows 1 completed match")

	# Instant finish remaining in round 0 (except human match if not yet played)
	var instant_list := tourn.finish_round_simulation_instant(0)
	check(instant_list.size() == 14, "finish_round_simulation_instant resolved remaining 14 bot matches (15 total bot matches)")

	# -------------------------------------------------------------
	# 4. Human Match & Advancement Across 5 Rounds to Championship
	# -------------------------------------------------------------
	# Human wins Round of 32
	var hm := tourn.get_human_match()
	check(not hm.is_empty() and hm.round == 0, "Human match found in R32")
	tourn.record_human_match_result(true, 4, "rep_r32_001", false)
	check(tourn.is_round_complete(0), "All 16 matches in R32 completed")

	# Advance to Round of 16
	check(tourn.advance_to_next_round(), "Advanced to Round 1 (Round of 16)")
	check(tourn.current_round == 1, "Current round is 1")

	# Human wins Round of 16 with auto_simulate_rest = true
	hm = tourn.get_human_match()
	check(not hm.is_empty() and hm.round == 1, "Human match found in R16")
	tourn.record_human_match_result(true, 5, "rep_r16_001", true)
	check(tourn.current_round == 2, "Auto-advanced to Quarterfinals (Round 2)")
	check(tourn.is_round_complete(1), "All R16 matches completed")

	# Human wins Quarterfinals (Round 2)
	tourn.record_human_match_result(true, 4, "rep_qf_001", true)
	check(tourn.current_round == 3, "Auto-advanced to Semifinals (Round 3)")
	check(tourn.is_round_complete(2), "All QF matches completed")

	# Human wins Semifinals (Round 3)
	tourn.record_human_match_result(true, 6, "rep_sf_001", true)
	check(tourn.current_round == 4, "Auto-advanced to Championship (Round 4)")
	check(tourn.is_round_complete(3), "All SF matches completed")

	# Human wins Championship (Round 4)
	hm = tourn.get_human_match()
	check(not hm.is_empty() and hm.round == 4, "Human match found in Championship")
	tourn.record_human_match_result(true, 7, "rep_champ_001", true)
	check(tourn.status == "completed", "Tournament marked completed on Championship victory")
	check(tourn.champion_slot == tourn.human_slot, "Human is crowned Champion")
	check(tourn.finish_position == "Champion", "Finish position is Champion")
	check(not tourn.has_active_tournament(), "Active tournament cleared on completion")

	# -------------------------------------------------------------
	# 5. Rankings Verification for 32 Participants
	# -------------------------------------------------------------
	var rankings := tourn.get_rankings()
	check(rankings.size() == 32, "Rankings contains all 32 participants")
	check(rankings[0].rank == 1 and rankings[0].placement == "Champion", "Rank 1 is Champion")
	check(rankings[1].rank == 2 and rankings[1].placement == "Runner-Up", "Rank 2 is Runner-Up")
	check(rankings[2].rank == 3 and rankings[3].rank == 3, "Tied Rank 3 are Semifinalists (2 participants)")
	for i in range(4, 8):
		check(rankings[i].rank == 5 and rankings[i].placement == "Quarterfinals", "Tied Rank 5 are Quarterfinalists (4 participants)")
	for i in range(8, 16):
		check(rankings[i].rank == 9 and rankings[i].placement == "Round of 16", "Tied Rank 9 are R16 losers (8 participants)")
	for i in range(16, 32):
		check(rankings[i].rank == 17 and rankings[i].placement == "Round of 32", "Tied Rank 17 are R32 losers (16 participants)")

	var total_wins: int = 0
	var total_losses: int = 0
	for p in tourn.participants:
		total_wins += p.wins
		total_losses += p.losses
		check(p.wins == p.wins_vs_human + p.wins_vs_bots, "Participant %s wins equal sum of categories" % p.name)
		check(p.losses == p.losses_vs_human + p.losses_vs_bots, "Participant %s losses equal sum of categories" % p.name)

	check(total_wins == 31, "Total tournament wins across all 32 participants equals 31")
	check(total_losses == 31, "Total tournament losses across all 32 participants equals 31")

	# -------------------------------------------------------------
	# 6. Human Elimination in Round of 32 & Headless Finish
	# -------------------------------------------------------------
	var tourn_elim := Tournament.new()
	tourn_elim.active_path = TEST_ACTIVE
	tourn_elim.history_path = TEST_HISTORY
	tourn_elim.rng.seed = 8888
	tourn_elim.create_tournament("Calamity Dan", {}, {}, "medium", 32)

	# Human loses in Round 0 (Round of 32)
	tourn_elim.record_human_match_result(false, 3, "rep_loss_001", false)
	check(tourn_elim.status == "eliminated", "Tournament marked eliminated on defeat")
	check(tourn_elim.finish_position == "Round of 32", "Finish position recorded as Round of 32")
	check(tourn_elim.participants[tourn_elim.human_slot].rank == 17, "Eliminated human rank is 17")

	# Spectate / Finish Instantly headlessly resolves all remaining matches
	tourn_elim.finish_all_remaining_tournament_instant()
	check(tourn_elim.champion_slot >= 0 and tourn_elim.champion_slot != tourn_elim.human_slot, "AI champion crowned")
	for m in tourn_elim.matches:
		check(m.completed, "All 31 matches completed after headless finish")

	# -------------------------------------------------------------
	# 7. Backward Compatibility: 8-Player & 16-Player Sizes
	# -------------------------------------------------------------
	var tourn_8 := Tournament.new()
	tourn_8.active_path = TEST_ACTIVE
	tourn_8.history_path = TEST_HISTORY
	tourn_8.create_tournament("Eight Gunner", {}, {}, "medium", 8)
	check(tourn_8.tournament_size == 8, "8-player tournament size is 8")
	check(tourn_8.total_rounds == 3, "8-player tournament has 3 rounds")
	check(tourn_8.participants.size() == 8, "8-player has 8 participants")
	check(tourn_8.matches.size() == 7, "8-player has 7 matches")
	check(tourn_8.matches[0].round_name == "Quarterfinals", "Round 0 is Quarterfinals for 8-gun circuit")
	tourn_8.finish_all_remaining_tournament_instant()
	check(tourn_8.get_rankings().size() == 8, "8-player rankings has 8 participants")

	var tourn_16 := Tournament.new()
	tourn_16.active_path = TEST_ACTIVE
	tourn_16.history_path = TEST_HISTORY
	tourn_16.create_tournament("Sixteen Gunner", {}, {}, "medium", 16)
	check(tourn_16.tournament_size == 16, "16-player tournament size is 16")
	check(tourn_16.total_rounds == 4, "16-player tournament has 4 rounds")
	check(tourn_16.participants.size() == 16, "16-player has 16 participants")
	check(tourn_16.matches.size() == 15, "16-player has 15 matches")
	check(tourn_16.matches[0].round_name == "Round of 16", "Round 0 is Round of 16 for 16-gun circuit")
	tourn_16.finish_all_remaining_tournament_instant()
	check(tourn_16.get_rankings().size() == 16, "16-player rankings has 16 participants")

	# Verify History Persistence
	var history_all := tourn.load_history()
	check(history_all.size() >= 3, "History preserves multiple tournament records with various sizes")

	clean_test_files()
	print("Tournament Circuit Data: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
