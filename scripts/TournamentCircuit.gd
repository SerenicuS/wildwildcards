class_name TournamentCircuit
extends RefCounted

const Arenas = preload("res://scripts/ArenaDefinitions.gd")
const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")

const NAMES := [
	"Dusty Mae", "Iron Ada", "Silas Crow", "Rio Reed",
	"Pearl Flint", "Calico Finn", "Ash Boone", "Marlow West",
	"Colt Cassidy", "Belle Starr", "Wyatt Graves", "Jesse Vance",
	"Rowdy Boone", "Wildcat Sally", "Doc Holliday", "Clay Allison",
	"Frankie Ringo", "Kid Durango", "Ruby McGraw", "Beau Sterling",
	"Maverick Stone", "Sawyer Cross", "Calamity Cole", "Dallas Quinn",
	"Blackjack Bartlett", "Cassidy Hayes", "Deacon Miller", "Flint McCord",
	"Grizzly Wade", "Hank Callahan", "Jasper Kane", "Keno Sharp",
	"Lonnie Drake", "Milo Sterling", "Ned Kelly", "Otis Vance",
	"Pecos Pete", "Quinn Dalton", "Rusty Fletcher", "Shiloh Bishop",
	"Tucker Sloane", "Vince Madigan", "Wade Travis", "Zeke Thornton",
	"Abilene Kate", "Blaze Moreno", "Clint Rawlins", "Desperado Dan",
	"Ezekiel Brand", "Faro Jack", "Gabe Mercer", "Harlan Cross",
	"Ike Clanton", "Jubal Early", "Luke Short", "Marshal Dillon"
]

const ROUND_NAMES_32 := ["Round of 32", "Round of 16", "Quarterfinals", "Semifinals", "Championship"]
const ROUND_NAMES_16 := ["Round of 16", "Quarterfinals", "Semifinals", "Championship"]
const ROUND_NAMES_8 := ["Quarterfinals", "Semifinals", "Championship"]
const ROUND_NAMES := ["Quarterfinals", "Semifinals", "Championship"]
const MAX_TURNS: int = 100
const MAX_HISTORY: int = 50

var active_path: String = "user://tournament_active.json"
var history_path: String = "user://tournament_history.json"

var rng := RandomNumberGenerator.new()

var tournament_id: String = ""
var tournament_size: int = 32
var total_rounds: int = 5
var created_at: int = 0
var difficulty: String = "medium"
var participants: Array[Dictionary] = []
var matches: Array[Dictionary] = []
var current_round: int = 0
var human_slot: int = -1
var champion_slot: int = -1
var status: String = "inactive" # "inactive", "active", "completed", "eliminated"
var finish_position: String = "None"
var human_replays: Array[String] = []

func _init() -> void:
	rng.randomize()

static func get_round_name(round_idx: int, total_rnds: int) -> String:
	var dist: int = (total_rnds - 1) - round_idx
	match dist:
		0: return "Championship"
		1: return "Semifinals"
		2: return "Quarterfinals"
		3: return "Round of 16"
		4: return "Round of 32"
		_: return "Round %d" % (round_idx + 1)

func get_current_round_name() -> String:
	return get_round_name(current_round, total_rounds)

func has_active_tournament() -> bool:
	return (status == "active" or status == "eliminated") and FileAccess.file_exists(active_path)

func create_tournament(player_name: String, player_appearance: Dictionary, player_revolver: Dictionary, preset_difficulty: String = "medium", requested_size: int = 32) -> void:
	tournament_size = requested_size if requested_size in [8, 16, 32] else 32
	total_rounds = int(round(log(tournament_size) / log(2)))
	tournament_id = "tourn_%d_%d" % [int(Time.get_unix_time_from_system()), rng.randi_range(1000, 9999)]
	created_at = int(Time.get_unix_time_from_system())
	difficulty = preset_difficulty
	status = "active"
	current_round = 0
	champion_slot = -1
	finish_position = "In Progress"
	human_replays.clear()

	var num_bots: int = tournament_size - 1
	var available_names := NAMES.duplicate()
	var bot_names: Array[String] = []
	for i in range(num_bots):
		var idx: int = rng.randi_range(0, available_names.size() - 1)
		bot_names.append(available_names[idx])
		available_names.remove_at(idx)

	var generated_bots: Array[Dictionary] = []
	for b_name in bot_names:
		var bot_pers := {
			"aggression": snappedf(rng.randf_range(0.7, 1.3), 0.01),
			"caution": snappedf(rng.randf_range(0.7, 1.3), 0.01),
			"greed": snappedf(rng.randf_range(0.7, 1.3), 0.01)
		}
		var bot_app := Appearance.randomized(rng)
		var bot_rev := Revolver.randomized(rng)
		generated_bots.append({
			"id": "",
			"name": b_name,
			"is_human": false,
			"personality": bot_pers,
			"appearance": bot_app,
			"revolver": bot_rev,
			"slot": -1,
			"wins": 0,
			"losses": 0,
			"wins_vs_human": 0,
			"losses_vs_human": 0,
			"wins_vs_bots": 0,
			"losses_vs_bots": 0,
			"placement": "In Progress",
			"rank": 0,
			"eliminated": false,
			"eliminator_id": "",
			"eliminated_in_round": -1
		})

	var human_part := {
		"id": "",
		"name": player_name if not player_name.strip_edges().is_empty() else "Gunslinger",
		"is_human": true,
		"personality": {"aggression": 1.0, "caution": 1.0, "greed": 1.0},
		"appearance": Appearance.sanitize(player_appearance),
		"revolver": Revolver.sanitize(player_revolver),
		"slot": -1,
		"wins": 0,
		"losses": 0,
		"wins_vs_human": 0,
		"losses_vs_human": 0,
		"wins_vs_bots": 0,
		"losses_vs_bots": 0,
		"placement": "In Progress",
		"rank": 0,
		"eliminated": false,
		"eliminator_id": "",
		"eliminated_in_round": -1
	}

	var all_entries := [human_part]
	all_entries.append_array(generated_bots)
	var slots: Array[int] = []
	for i in range(tournament_size):
		slots.append(i)
	slots.shuffle()

	participants.clear()
	participants.resize(tournament_size)
	for i in range(tournament_size):
		var slot_idx: int = slots[i]
		var entry: Dictionary = all_entries[i].duplicate(true)
		entry["slot"] = slot_idx
		entry["id"] = "%s_p%d" % [tournament_id, slot_idx]
		participants[slot_idx] = entry
		if entry.is_human:
			human_slot = slot_idx

	matches.clear()
	var arena_pool := Arenas.ORDER.duplicate()
	arena_pool.shuffle()

	var match_id_counter: int = 0
	for rnd in range(total_rounds):
		var matches_in_rnd: int = tournament_size >> (rnd + 1)
		var r_name: String = get_round_name(rnd, total_rounds)
		for k in range(matches_in_rnd):
			var s_a: int = -1
			var s_b: int = -1
			var p_a_id: String = ""
			var p_b_id: String = ""
			if rnd == 0:
				s_a = k * 2
				s_b = k * 2 + 1
				p_a_id = participants[s_a].id
				p_b_id = participants[s_b].id

			var arena_choice: String = arena_pool[match_id_counter % arena_pool.size()]
			matches.append({
				"tournament_id": tournament_id,
				"match_id": match_id_counter,
				"id": match_id_counter,
				"round": rnd,
				"round_name": r_name,
				"slot_a": s_a,
				"slot_b": s_b,
				"participant_a_id": p_a_id,
				"participant_b_id": p_b_id,
				"winner_slot": -1,
				"loser_slot": -1,
				"winner_id": "",
				"loser_id": "",
				"completed": false,
				"turns": 0,
				"arena": arena_choice,
				"replay_id": ""
			})
			match_id_counter += 1

	save_active()

func get_participant(slot: int) -> Dictionary:
	if slot >= 0 and slot < participants.size():
		return participants[slot]
	return {}

func get_match(match_id: int) -> Dictionary:
	if match_id >= 0 and match_id < matches.size():
		return matches[match_id]
	return {}

func get_human_match() -> Dictionary:
	for m in matches:
		if m.round == current_round and not m.completed:
			if m.slot_a == human_slot or m.slot_b == human_slot:
				return m
	return {}

func get_human_opponent() -> Dictionary:
	var hm := get_human_match()
	if hm.is_empty():
		return {}
	var opp_slot: int = hm.slot_b if hm.slot_a == human_slot else hm.slot_a
	return get_participant(opp_slot)

func get_participant_by_id(part_id: String) -> Dictionary:
	for p in participants:
		if p.get("id", "") == part_id:
			return p
	return {}

func get_participant_matches(part_id: String) -> Array[Dictionary]:
	return get_matches_for_participant(part_id, matches)

static func win_percentage(wins: int, losses: int) -> float:
	var total: int = wins + losses
	if total <= 0:
		return 0.0
	return (float(wins) / float(total)) * 100.0

static func format_win_percentage(wins: int, losses: int) -> String:
	var total: int = wins + losses
	if total <= 0:
		return "0%"
	var pct := (float(wins) / float(total)) * 100.0
	if is_equal_approx(pct, roundf(pct)):
		return "%d%%" % int(roundf(pct))
	return "%.1f%%" % pct

static func get_matches_for_participant(part_id: String, match_list: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in match_list:
		if m is Dictionary:
			if m.get("participant_a_id", "") == part_id or m.get("participant_b_id", "") == part_id:
				if m.get("completed", false):
					result.append(m)
	return result

static func get_participant_status_info(p: Dictionary, tourn_status: String, cur_round: int, tot_rounds: int, champ_slot: int) -> Dictionary:
	var slot: int = p.get("slot", -1)
	var rank: int = p.get("rank", 0)
	var is_elim: bool = p.get("eliminated", false)
	var is_champ: bool = (champ_slot >= 0 and slot == champ_slot)

	if is_champ:
		return {
			"rank_text": "#1",
			"status_text": "Champion",
			"is_competing": false,
			"confirmed_rank": 1
		}

	var is_finished: bool = (tourn_status == "completed") or (champ_slot >= 0 and not is_elim and slot != champ_slot)

	if is_elim or is_finished:
		if rank == 1:
			return {"rank_text": "#1", "status_text": "Champion", "is_competing": false, "confirmed_rank": 1}
		elif rank == 2:
			return {"rank_text": "Runner-Up #2", "status_text": "Runner-Up", "is_competing": false, "confirmed_rank": 2}
		elif rank > 0:
			var place_name: String = p.get("placement", "")
			return {"rank_text": "Tied #%d" % rank, "status_text": "Eliminated in %s" % place_name, "is_competing": false, "confirmed_rank": rank}
		else:
			return {"rank_text": "—", "status_text": "Eliminated", "is_competing": false, "confirmed_rank": 999}
	else:
		var dist: int = (tot_rounds - 1) - cur_round
		var stage_name: String = ""
		match dist:
			0: stage_name = "Finals"
			1: stage_name = "Semifinals"
			2: stage_name = "Quarterfinals"
			3: stage_name = "Round of 16"
			4: stage_name = "Round of 32"
			_: stage_name = "Round %d" % (cur_round + 1)
		var desc: String = "Still competing — %s" % stage_name
		return {
			"rank_text": "—",
			"status_text": desc,
			"is_competing": true,
			"confirmed_rank": 0
		}

static func filter_and_sort_participants(part_list: Array, filter_type: String, sort_type: String, search_query: String, tourn_status: String, cur_round: int, tot_rounds: int, champ_slot: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var q: String = search_query.strip_edges().to_lower()

	for item in part_list:
		if not item is Dictionary:
			continue
		var p: Dictionary = item

		if not q.is_empty():
			var p_name: String = p.get("name", "").to_lower()
			if not p_name.contains(q):
				continue

		var status_info := get_participant_status_info(p, tourn_status, cur_round, tot_rounds, champ_slot)
		match filter_type:
			"competing":
				if not status_info.is_competing:
					continue
			"eliminated":
				if not p.get("eliminated", false):
					continue
			"human":
				if not p.get("is_human", false):
					continue
			"bot":
				if p.get("is_human", false):
					continue
			_:
				pass

		filtered.append(p)

	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var info_a := get_participant_status_info(a, tourn_status, cur_round, tot_rounds, champ_slot)
		var info_b := get_participant_status_info(b, tourn_status, cur_round, tot_rounds, champ_slot)
		var slot_a: int = a.get("slot", 0)
		var slot_b: int = b.get("slot", 0)

		match sort_type:
			"wins":
				var w_a: int = a.get("wins", 0)
				var w_b: int = b.get("wins", 0)
				if w_a != w_b:
					return w_a > w_b
				var l_a: int = a.get("losses", 0)
				var l_b: int = b.get("losses", 0)
				if l_a != l_b:
					return l_a < l_b
				return slot_a < slot_b

			"losses":
				var l_a: int = a.get("losses", 0)
				var l_b: int = b.get("losses", 0)
				if l_a != l_b:
					return l_a < l_b
				var w_a: int = a.get("wins", 0)
				var w_b: int = b.get("wins", 0)
				if w_a != w_b:
					return w_a > w_b
				return slot_a < slot_b

			"win_pct":
				var pct_a: float = win_percentage(a.get("wins", 0), a.get("losses", 0))
				var pct_b: float = win_percentage(b.get("wins", 0), b.get("losses", 0))
				if not is_equal_approx(pct_a, pct_b):
					return pct_a > pct_b
				var w_a: int = a.get("wins", 0)
				var w_b: int = b.get("wins", 0)
				if w_a != w_b:
					return w_a > w_b
				return slot_a < slot_b

			"name_asc":
				var n_a: String = a.get("name", "").to_lower()
				var n_b: String = b.get("name", "").to_lower()
				if n_a != n_b:
					return n_a < n_b
				return slot_a < slot_b

			"name_desc":
				var n_a: String = a.get("name", "").to_lower()
				var n_b: String = b.get("name", "").to_lower()
				if n_a != n_b:
					return n_a > n_b
				return slot_a < slot_b

			_:
				var r_a: int = info_a.confirmed_rank
				var r_b: int = info_b.confirmed_rank
				var s_a: int = 999 if r_a == 0 else r_a
				var s_b: int = 999 if r_b == 0 else r_b
				if info_a.is_competing and info_b.is_competing:
					return slot_a < slot_b
				if info_a.is_competing != info_b.is_competing and tourn_status != "completed":
					return info_a.is_competing
				if s_a != s_b:
					return s_a < s_b
				return slot_a < slot_b
	)

	return filtered

func get_rankings() -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for p in participants:
		ranked.append(p.duplicate(true))

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = a.get("rank", 0)
		var rank_b: int = b.get("rank", 0)
		var sort_a: int = 999 if rank_a == 0 else rank_a
		var sort_b: int = 999 if rank_b == 0 else rank_b
		if sort_a != sort_b:
			return sort_a < sort_b
		return a.get("slot", 0) < b.get("slot", 0)
	)
	return ranked

func get_next_match_link(m_id: int) -> Dictionary:
	if m_id < 0 or m_id >= matches.size():
		return {"next_match_id": -1, "slot_prop": "", "id_prop": ""}
	var m: Dictionary = matches[m_id]
	var rnd: int = m.round
	if rnd >= total_rounds - 1:
		return {"next_match_id": -1, "slot_prop": "", "id_prop": ""}

	var r_start: int = tournament_size - (tournament_size >> rnd)
	var next_r_start: int = tournament_size - (tournament_size >> (rnd + 1))
	var k: int = m_id - r_start
	var next_m_id: int = next_r_start + int(k / 2)
	var is_slot_a: bool = (k % 2 == 0)
	return {
		"next_match_id": next_m_id,
		"slot_prop": "slot_a" if is_slot_a else "slot_b",
		"id_prop": "participant_a_id" if is_slot_a else "participant_b_id"
	}

func _commit_match_outcome(match_id: int, winner: int, loser: int, turns: int, replay_id: String) -> void:
	var m: Dictionary = matches[match_id]
	if m.completed:
		return # Update participant statistics exactly once per completed match

	var winner_p: Dictionary = participants[winner]
	var loser_p: Dictionary = participants[loser]

	m.tournament_id = tournament_id
	m.winner_slot = winner
	m.loser_slot = loser
	m.winner_id = winner_p.id
	m.loser_id = loser_p.id
	m.completed = true
	m.turns = turns
	m.replay_id = replay_id

	# Update participant statistics exactly once
	winner_p.wins += 1
	if loser_p.is_human:
		winner_p.wins_vs_human += 1
	else:
		winner_p.wins_vs_bots += 1

	loser_p.losses += 1
	if winner_p.is_human:
		loser_p.losses_vs_human += 1
	else:
		loser_p.losses_vs_bots += 1

	loser_p.eliminated = true
	loser_p.eliminated_in_round = m.round
	loser_p.eliminator_id = winner_p.id

	var r_dist: int = (total_rounds - 1) - m.round
	if r_dist == 0:
		loser_p.placement = "Runner-Up"
		loser_p.rank = 2
	else:
		loser_p.placement = get_round_name(m.round, total_rounds)
		loser_p.rank = (1 << r_dist) + 1

	# Advance winner to next round match
	var link := get_next_match_link(match_id)
	if link.next_match_id >= 0:
		var next_m: Dictionary = matches[link.next_match_id]
		if link.slot_prop == "slot_a":
			next_m.slot_a = winner
			next_m.participant_a_id = winner_p.id
		else:
			next_m.slot_b = winner
			next_m.participant_b_id = winner_p.id
	else:
		champion_slot = winner
		winner_p.placement = "Champion"
		winner_p.rank = 1
		winner_p.eliminated = false
		winner_p.eliminator_id = ""
		winner_p.eliminated_in_round = -1

func simulate_bot_match(match_id: int) -> Dictionary:
	var m: Dictionary = matches[match_id]
	if m.completed or m.slot_a < 0 or m.slot_b < 0:
		return m

	var bot_a := BotController.new()
	var bot_b := BotController.new()
	bot_a.set_personality(participants[m.slot_a].personality)
	bot_b.set_personality(participants[m.slot_b].personality)

	var snap_a := {"ammo": 0, "shields": 0, "alive": true}
	var snap_b := {"ammo": 0, "shields": 0, "alive": true}

	var turn_count: int = 0
	var winner: int = -1
	var loser: int = -1

	while turn_count < MAX_TURNS:
		turn_count += 1
		var act_a: int = bot_a.choose_action(snap_a, snap_b)
		var act_b: int = bot_b.choose_action(snap_b, snap_a)
		var res: Dictionary = DuelRules.resolve(snap_a, snap_b, act_a, act_b)
		snap_a = res.left
		snap_b = res.right

		if snap_a.alive and not snap_b.alive:
			winner = m.slot_a
			loser = m.slot_b
			break
		elif snap_b.alive and not snap_a.alive:
			winner = m.slot_b
			loser = m.slot_a
			break

	# Tiebreaker if reached MAX_TURNS without elimination
	if winner == -1:
		if snap_a.ammo > snap_b.ammo:
			winner = m.slot_a
			loser = m.slot_b
		elif snap_b.ammo > snap_a.ammo:
			winner = m.slot_b
			loser = m.slot_a
		elif snap_a.shields > snap_b.shields:
			winner = m.slot_a
			loser = m.slot_b
		elif snap_b.shields > snap_a.shields:
			winner = m.slot_b
			loser = m.slot_a
		else:
			if rng.randf() < 0.5:
				winner = m.slot_a
				loser = m.slot_b
			else:
				winner = m.slot_b
				loser = m.slot_a

	_commit_match_outcome(match_id, winner, loser, turn_count, "")
	return matches[match_id]

func record_human_match_result(human_won: bool, turns: int, replay_id: String, auto_simulate_rest: bool = true) -> void:
	var hm := get_human_match()
	if hm.is_empty():
		return

	var opp_slot: int = hm.slot_b if hm.slot_a == human_slot else hm.slot_a
	var winner: int = human_slot if human_won else opp_slot
	var loser: int = opp_slot if human_won else human_slot

	if not replay_id.is_empty():
		human_replays.append(replay_id)

	_commit_match_outcome(hm.id, winner, loser, turns, replay_id)

	if human_won:
		if current_round == total_rounds - 1:
			champion_slot = human_slot
			status = "completed"
			finish_position = "Champion"
			save_to_history()
			clear_active()
		elif auto_simulate_rest:
			finish_round_simulation_instant(current_round)
			advance_to_next_round()
		else:
			save_active()
	else:
		status = "eliminated"
		finish_position = participants[human_slot].placement
		if auto_simulate_rest:
			finish_all_remaining_tournament_instant()
		else:
			save_active()

func get_uncompleted_bot_matches_in_round(rnd: int = -1) -> Array[Dictionary]:
	var target_round: int = current_round if rnd < 0 else rnd
	var list: Array[Dictionary] = []
	for m in matches:
		if m.round == target_round and not m.completed:
			if m.slot_a != human_slot and m.slot_b != human_slot and m.slot_a >= 0 and m.slot_b >= 0:
				list.append(m)
	return list

func is_round_complete(rnd: int = -1) -> bool:
	var target_round: int = current_round if rnd < 0 else rnd
	for m in matches:
		if m.round == target_round and not m.completed:
			return false
	return true

func step_round_simulation(rnd: int = -1) -> Dictionary:
	var target_round: int = current_round if rnd < 0 else rnd
	for m in matches:
		if m.round == target_round and not m.completed:
			if m.slot_a != human_slot and m.slot_b != human_slot and m.slot_a >= 0 and m.slot_b >= 0:
				var res := simulate_bot_match(m.id)
				save_active()
				return res
	return {}

func finish_round_simulation_instant(rnd: int = -1) -> Array[Dictionary]:
	var target_round: int = current_round if rnd < 0 else rnd
	var simulated: Array[Dictionary] = []
	for m in matches:
		if m.round == target_round and not m.completed:
			if m.slot_a != human_slot and m.slot_b != human_slot and m.slot_a >= 0 and m.slot_b >= 0:
				var res := simulate_bot_match(m.id)
				simulated.append(res)
	save_active()
	return simulated

func advance_to_next_round() -> bool:
	if not is_round_complete(current_round):
		return false
	if current_round < total_rounds - 1:
		current_round += 1
		save_active()
		return true
	else:
		if champion_slot == human_slot:
			status = "completed"
			finish_position = "Champion"
		else:
			status = "eliminated"
		save_to_history()
		clear_active()
		return false

func finish_all_remaining_tournament_instant() -> void:
	for rnd in range(current_round, total_rounds):
		for m in matches:
			if m.round == rnd and not m.completed and m.slot_a >= 0 and m.slot_b >= 0:
				simulate_bot_match(m.id)

	if champion_slot >= 0:
		if champion_slot == human_slot:
			status = "completed"
			finish_position = "Champion"
		else:
			status = "eliminated"
			var h_p := get_participant(human_slot)
			finish_position = h_p.get("placement", "Eliminated")
	save_to_history()
	clear_active()

func get_round_progress(rnd: int = -1) -> Dictionary:
	var target_round: int = current_round if rnd < 0 else rnd
	var total_m: int = 0
	var completed_m: int = 0
	for m in matches:
		if m.round == target_round:
			total_m += 1
			if m.completed:
				completed_m += 1
	return {
		"round": target_round,
		"round_name": get_round_name(target_round, total_rounds),
		"total_matches": total_m,
		"completed_matches": completed_m,
		"remaining_matches": total_m - completed_m,
		"is_complete": total_m > 0 and completed_m == total_m
	}

func save_active() -> Error:
	var payload := {
		"version": 1,
		"tournament_id": tournament_id,
		"tournament_size": tournament_size,
		"total_rounds": total_rounds,
		"created_at": created_at,
		"difficulty": difficulty,
		"participants": participants,
		"matches": matches,
		"current_round": current_round,
		"human_slot": human_slot,
		"champion_slot": champion_slot,
		"status": status,
		"finish_position": finish_position,
		"human_replays": human_replays
	}
	var tmp_file := active_path + ".tmp"
	var file := FileAccess.open(tmp_file, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(tmp_file, active_path)

func load_active() -> bool:
	if not FileAccess.file_exists(active_path):
		return false
	var file := FileAccess.open(active_path, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return false
	var data: Dictionary = parser.data
	if data.get("status") != "active" and data.get("status") != "eliminated":
		return false

	tournament_id = str(data.get("tournament_id", ""))
	created_at = int(data.get("created_at", 0))
	difficulty = str(data.get("difficulty", "medium"))
	participants = []
	for p in data.get("participants", []):
		if p is Dictionary:
			participants.append(p)
	matches = []
	for m in data.get("matches", []):
		if m is Dictionary:
			matches.append(m)
	current_round = int(data.get("current_round", 0))
	human_slot = int(data.get("human_slot", -1))
	champion_slot = int(data.get("champion_slot", -1))
	status = str(data.get("status", "inactive"))
	finish_position = str(data.get("finish_position", "None"))
	human_replays = []
	for r in data.get("human_replays", []):
		human_replays.append(str(r))

	tournament_size = int(data.get("tournament_size", 0))
	if tournament_size not in [8, 16, 32]:
		var p_count: int = participants.size()
		tournament_size = p_count if p_count in [8, 16, 32] else 32
	total_rounds = int(round(log(tournament_size) / log(2)))

	return participants.size() == tournament_size and matches.size() == tournament_size - 1

func clear_active() -> void:
	if FileAccess.file_exists(active_path):
		DirAccess.remove_absolute(active_path)
	if FileAccess.file_exists(active_path + ".tmp"):
		DirAccess.remove_absolute(active_path + ".tmp")

func save_to_history() -> Error:
	var hist: Array = load_history()
	var champ_name: String = ""
	var champ_id: String = ""
	if champion_slot >= 0 and champion_slot < participants.size():
		champ_name = participants[champion_slot].name
		champ_id = participants[champion_slot].id

	var record := {
		"tournament_id": tournament_id,
		"tournament_size": tournament_size,
		"total_rounds": total_rounds,
		"created_at": created_at,
		"difficulty": difficulty,
		"human_won": champion_slot == human_slot,
		"champion_name": champ_name,
		"champion_slot": champion_slot,
		"champion_id": champ_id,
		"finish_position": finish_position,
		"human_slot": human_slot,
		"participants": participants.duplicate(true),
		"matches": matches.duplicate(true),
		"rankings": get_rankings(),
		"human_replays": human_replays.duplicate()
	}
	hist.push_front(record)
	while hist.size() > MAX_HISTORY:
		hist.pop_back()

	var tmp_file := history_path + ".tmp"
	var file := FileAccess.open(tmp_file, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "tournaments": hist}, "\t"))
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(tmp_file, history_path)

func load_history() -> Array:
	if not FileAccess.file_exists(history_path):
		return []
	var file := FileAccess.open(history_path, FileAccess.READ)
	if file == null:
		return []
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return []
	var data: Dictionary = parser.data
	var list: Variant = data.get("tournaments", [])
	return list if list is Array else []
