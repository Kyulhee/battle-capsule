extends Node

# --- Metrics Container ---
var metrics = {
	"match": {
		"duration": 0.0,
		"max_zone_stage": 1,
		"first_weapon_upgrade_time": -1.0,
		"first_upgraded_weapon_type": "none",
		"spawn_nearest_enemy_distance_avg": 0.0,
		"spawn_los_blocked_rate": 0.0,
		"rare_pickup_timing": []
	},
	"stages": {
		"deaths_by_stage": {},
		"heals_by_stage": {},
		"supply_visits": 0,
		"supply_contest_count": 0,
		"supply_preannounce_interest": 0,
		"match_summary": {
			"duration": 0.0,
			"ammo_empty_bouts": 0,
			"recovery_success_count": 0,
			"recovery_total_bouts": 0,
			"died_while_recovering": 0,
			"reengaged_after_recovery": 0,
			"supply_interest": 0,
			"supply_contests": 0,
			"kill_distances": {},
			"engagements_by_area": {
				"center": 0,
				"outpost": 0,
				"outer_open": 0,
				"edge": 0
			},
			"loot_by_area": {
				"center": 0,
				"outpost": 0,
				"outer_open": 0,
				"edge": 0
			}
		}
	},
	"tactics": {
		"ammo_empty_enter_count": 0,
		"ammo_recovery_success_count": 0,
		"died_while_recovering_count": 0,
		"reengage_after_recovery_count": 0,
		"avg_recovery_time": 0.0,
		"total_recovery_bouts": 0
	},
	"combat": {
		"total_kills": 0,
		"attack_max_continuous": 0.0,
		"attack_disengage_count": 0,
		"kill_distances": {} # weapon: [distances]
	},
	"weapons": {},
	"economy": {
		"heals_used": 0,
		"shield_pickups": 0,
		"shield_breaks": 0,
		"rare_item_pickups": 0
	},
	"session": {
		"kills": 0,
		"assists": 0,
		"rank": 0,
		"start_time": 0.0
	}
}

const HISTORY_PATH = "user://match_history.json"
var match_history: Array = []

var match_in_progress: bool = false
var start_tick: int = 0
var current_match_stage: int = 1

func start_match():
	start_tick = Time.get_ticks_msec()
	match_in_progress = true
	metrics.session.kills = 0
	metrics.session.assists = 0
	metrics.session.rank = 0
	metrics.session.start_time = Time.get_unix_time_from_system()
	print("[TELEMETRY] Match tracking started.")

func set_stage(stage_num: int):
	current_match_stage = stage_num

func log_engagement(attacker, victim, dist: float):
	metrics.stages.match_summary.engagements_by_area[get_area_name(victim.global_position)] += 1

func log_spawn_metrics(avg_dist: float, los_blocked_rate: float):
	metrics.match.spawn_nearest_enemy_distance_avg = avg_dist
	metrics.match.spawn_los_blocked_rate = los_blocked_rate

func log_kill(source_type: String, weapon_type: String = "", distance: float = -1.0):
	if not match_in_progress: return
	metrics.combat.total_kills += 1
	if weapon_type != "":
		var w_key = _normalize_weapon(weapon_type)
		_ensure_weapon_exists(w_key)
		metrics.weapons[w_key].kills += 1
		if distance > 0:
			if not metrics.combat.kill_distances.has(w_key): metrics.combat.kill_distances[w_key] = []
			metrics.combat.kill_distances[w_key].append(distance)

func log_death(cause: String, state_name: String = ""):
	if not match_in_progress: return
	var stage_key = str(current_match_stage)
	metrics.stages.deaths_by_stage[stage_key] = metrics.stages.deaths_by_stage.get(stage_key, 0) + 1
	if state_name == "RECOVER":
		metrics.tactics.died_while_recovering_count += 1

func log_loot(collector, item):
	metrics.stages.match_summary.loot_by_area[get_area_name(collector.global_position)] += 1

func log_pickup(item_name: String, item_type: String, is_rare: bool):
	if not match_in_progress: return
	var time_elapsed = (Time.get_ticks_msec() - start_tick) / 1000.0
	if item_type == "weapon":
		var w_key = _normalize_weapon(item_name)
		_ensure_weapon_exists(w_key)
		metrics.weapons[w_key].pickups += 1
		if metrics.match.first_weapon_upgrade_time < 0:
			metrics.match.first_weapon_upgrade_time = time_elapsed
			metrics.match.first_upgraded_weapon_type = w_key
	if is_rare:
		metrics.economy.rare_item_pickups += 1
		metrics.match.rare_pickup_timing.append(time_elapsed)

func log_economy(event: String):
	if not match_in_progress: return
	if event == "heals_used":
		var stage_key = str(current_match_stage)
		metrics.stages.heals_by_stage[stage_key] = metrics.stages.heals_by_stage.get(stage_key, 0) + 1
		metrics.economy.heals_used += 1

func log_tactics(event: String, value: float = 0.0):
	if not match_in_progress: return
	match event:
		"ammo_empty": metrics.tactics.ammo_empty_enter_count += 1
		"recovery_start": metrics.tactics.total_recovery_bouts += 1
		"recovery_success": metrics.tactics.ammo_recovery_success_count += 1
		"reengage": metrics.tactics.reengage_after_recovery_count += 1
		"recovery_time": 
			metrics.tactics.avg_recovery_time += value

func log_supply_event(event: String):
	if not match_in_progress: return
	match event:
		"visit": metrics.stages.supply_visits += 1
		"preannounce_interest": metrics.stages.supply_preannounce_interest += 1
		"contest": metrics.stages.supply_contest_count += 1

func log_shot(): pass # Future: track shots fired / accuracy
func log_stealth(event: String): pass # Future: bush usage tracking
func log_state_duration(state_name: String, duration: float): pass
func log_state_transition(): pass
func log_damage(a, b, c, d): pass

func log_combat_audit(event: String, value: float = 0.0):
	if event == "attack_max_continuous":
		metrics.combat.attack_max_continuous = max(metrics.combat.attack_max_continuous, value)
	elif event == "attack_disengage":
		metrics.combat.attack_disengage_count += 1
	elif event == "assists":
		metrics.session.assists += int(value)
	elif event == "kills":
		metrics.session.kills += int(value)

func end_match(rank: int, winner_name: String, zone_stage: int):
	if not match_in_progress: return
	metrics.match.duration = (Time.get_ticks_msec() - start_tick) / 1000.0
	metrics.match.max_zone_stage = zone_stage
	metrics.session.rank = rank
	match_in_progress = false
	
	save_match_record()
	generate_report()

func save_match_record():
	var record = {
		"date": Time.get_datetime_string_from_system().split("T")[0],
		"time_of_day": Time.get_time_string_from_system(),
		"rank": metrics.session.rank,
		"kills": metrics.session.kills,
		"assists": metrics.session.assists,
		"duration": int(metrics.match.duration),
		"win": metrics.session.rank == 1
	}
	
	load_history()
	match_history.append(record)
	
	# Sort by best rank first, then most kills
	match_history.sort_custom(func(a, b):
		if a.rank != b.rank: return a.rank < b.rank
		return a.kills > b.kills
	)
	
	var file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(match_history))
		file.close()

func load_history():
	if FileAccess.file_exists(HISTORY_PATH):
		var file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
		var text = file.get_as_text()
		var p = JSON.parse_string(text)
		if p is Array:
			match_history = p
		file.close()
	else:
		match_history = []

func get_area_name(pos: Vector3) -> String:
	var dist = Vector2(pos.x, pos.z).length()
	if dist < 22.0:
		return "center"
	if dist < 45.0:
		return "outpost" if dist > 35.0 else "outer_open"
	return "edge"

func _ensure_weapon_exists(w_name: String):
	if not metrics.weapons.has(w_name): metrics.weapons[w_name] = {"pickups": 0, "kills": 0}

func _normalize_weapon(w_name: String) -> String:
	var n = w_name.to_lower().replace(" ", "_")
	if n == "ar": return "assault_rifle"
	return n

func generate_report():
	print("\n" + "=".repeat(40))
	print("       AI TACTICS & ECONOMY SUMMARY")
	print("=".repeat(40))
	print("Duration: %.2f seconds" % metrics.match.duration)
	print("Deaths by Stage: ", metrics.stages.deaths_by_stage)
	print("Heals by Stage: ", metrics.stages.heals_by_stage)
	print("Supply Interest/Contests: %d / %d" % [metrics.stages.supply_preannounce_interest, metrics.stages.supply_contest_count])
	print("-".repeat(20))
	print("[TACTICS AUDIT]")
	print("  Ammo Empty Bouts: %d" % metrics.tactics.ammo_empty_enter_count)
	print("  Recovery Success Rate: %.1f%% (%d/%d)" % [
		(float(metrics.tactics.ammo_recovery_success_count)/max(1, metrics.tactics.total_recovery_bouts))*100.0,
		metrics.tactics.ammo_recovery_success_count, metrics.tactics.total_recovery_bouts
	])
	print("  Died While Recovering: %d" % metrics.tactics.died_while_recovering_count)
	print("  Re-engaged After Recovery: %d" % metrics.tactics.reengage_after_recovery_count)
	print("-".repeat(20))
	print("[COMBAT DISTANCES]")
	for w in metrics.combat.kill_distances:
		var dists = metrics.combat.kill_distances[w]
		var avg = 0.0
		if dists.size() > 0:
			for d in dists: avg += d
			avg /= dists.size()
		print("  %s: Avg Kill Dist %.1fm (n=%d)" % [w, avg, dists.size()])
	print("=".repeat(40) + "\n")
