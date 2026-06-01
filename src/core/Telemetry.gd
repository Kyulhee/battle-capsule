extends Node
# Autoloaded as "Telemetry"
#
# Metrics are split into named groups. Call set_groups() before start_match()
# to enable only what you need for a given test session.
#
# Groups:
#   "core"     — duration, zone_stage, rank, kills, assists, win, deaths_by_stage
#   "combat"   — shots_fired, damage, kill_distances, attack_max_continuous
#   "tactics"  — RECOVER bouts, stuck, reserve_reload, patrol, weapon_drop
#   "economy"  — heals, shields, weapon pickups, first upgrade timing
#   "supply"   — supply capsule events
#   "zone"     — zone deaths, outside time, final duel deaths
#   "hell"     — blackout/bombardment event counts (Hell difficulty only)
#   "mission"  — active mission id, result (success/fail/none)
#   "pressure" — pressure mission triggered/cleared/failed counts (Hard opt-in / Hell)
#   "artifact" — selected artifact id and bounded artifact trigger events
#   "ai"       — sampled bot update budget by state and archetype
#   "doctrine" — merged bot AI profiles and selected combat plans

# ── Group toggles ─────────────────────────────────────────────────────────────

var enabled_groups: Dictionary = {
	"core":      true,
	"combat":    true,
	"tactics":   true,
	"economy":   true,
	"supply":    true,
	"zone":      true,
	"hell":      true,
	"mission":   true,
	"pressure":  true,
	"artifact":  true,
	"archetype": true,
	"ai":        true,
	"doctrine":  true,
}

func set_groups(overrides: Dictionary):
	for k in overrides:
		if enabled_groups.has(k):
			enabled_groups[k] = overrides[k]

func _g(group: String) -> bool:
	return enabled_groups.get(group, false)

# ── Metric storage ────────────────────────────────────────────────────────────

var metrics: Dictionary = {}
var match_history: Dictionary = {}  # key = str(difficulty 0-3) → Array of records
var current_difficulty: int = 1
const HISTORY_PATH = "user://match_history.json"
const SIM_RESULT_PATH = "user://sim_result_latest.json"

const DIFF_MULT: Array = [1.0, 1.5, 2.5, 4.0]

func calculate_score(rank: int, kills: int, assists: int, win: bool, diff: int) -> int:
	var base = max(0, 1000 - (rank - 1) * 80)
	var raw  = base + kills * 100 + assists * 40 + (300 if win else 0)
	return int(raw * DIFF_MULT[clamp(diff, 0, 3)])

func clear_history():
	match_history = {}
	var file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string("{}")
		file.close()

func get_history_for_difficulty(diff: int) -> Array:
	load_history()
	return match_history.get(str(diff), [])

var match_in_progress: bool = false
var _start_tick: int = 0
var _current_stage: int = 1

func _reset_metrics():
	metrics = {
		# core (always present — used by Main.gd result screen)
		"session": {
			"kills": 0,
			"assists": 0,
			"rank": 0,
			"win": false,
		},
		"core": {
			"duration": 0.0,
			"zone_stage_reached": 1,
			"deaths_by_stage": {},
			"heals_by_stage": {},
		},
		# combat
		"combat": {
			"shots_fired": 0,
			"total_damage_dealt": 0.0,
			"damage_by_weapon": {},
			"kills_by_weapon": {},
			"kill_distances": {},
			"attack_max_continuous": 0.0,
			"attack_disengage_count": 0,
		},
		# tactics
		"tactics": {
			"ammo_empty_enter": 0,
			"recover_bouts": 0,
			"recover_success": 0,
			"died_in_recover": 0,
			"stuck_triggered": 0,
			"reserve_reload": 0,
			"patrol_entered": 0,
			"patrol_timeout": 0,
			"weapon_drop_spawned": 0,
			"disengage_triggered": 0,
			"cover_peek": 0,
			"combat_reposition": 0,
			"combat_kite": 0,
			"survival_break": 0,
			"zone_escape_fire": 0,
			"retreat_counterfire": 0,
			"retreat_melee_counter": 0,
			"stuck_while_threatened": 0,
			"zone_assisted_death": 0,
		},
		# economy
		"economy": {
			"heals_used": 0,
			"shields_picked": 0,
			"rare_pickups": 0,
			"weapon_pickups": {},
			"first_upgrade_time": -1.0,
			"first_upgrade_weapon": "none",
		},
		# supply
		"supply": {
			"visits": 0,
			"preannounce_interest": 0,
			"contests": 0,
			"telegraphed": false,
		},
		# zone
		"zone": {
			"zone_deaths": 0,
			"zone_deaths_by_state": {},
			"max_outside_time": 0.0,
			"final_duel_deaths": [],  # deaths when exactly 2 actors remained
		},
		# hell
		"hell": {
			"blackout_count": 0,
			"bombardment_warned_count": 0,
			"bombardment_hit_count": 0,
		},
		# mission
		"mission": {
			"active_mission": "",
			"mission_progress": {},
			"mission_result": "none",  # "none" | "success" | "fail"
		},
		# pressure
		"pressure": {
			"pressure_triggered": 0,
			"pressure_cleared":   0,
			"pressure_failed":    0,
		},
		# artifact
		"artifact": {
			"selected": "none",
			"events": {},
			"emergency_shell_triggered": 0,
			"ghost_grass_started": 0,
		},
		# archetype
		"archetype": {
			"archetype_distribution":   {},  # 스폰 수 {AGGRESSIVE:3, DEFENSIVE:3, ...}
			"archetype_alive_at_zone2": {},  # 존 2단계 생존 수
			"archetype_deaths":         {},  # 아키타입별 사망 수
		},
		# ai update budget
		"ai": {
			"update_samples": 0,
			"update_total_usec": 0,
			"update_max_usec": 0,
			"update_by_state": {},
			"update_by_archetype": {},
		},
		# doctrine
		"doctrine": {
			"profile_counts": {},
			"profile_summaries": {},
			"combat_plan_counts": {
				"strafe": 0,
				"advance": 0,
				"kite": 0,
				"peek_cover": 0,
				"reposition": 0,
				"hold_angle": 0,
			},
			"plan_by_archetype": {},
			"state_time_by_archetype": {},
			"engage_range_by_archetype": {},
			"supply_decisions": {},
		},
	}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func start_match():
	_reset_metrics()
	_start_tick = Time.get_ticks_msec()
	_current_stage = 1
	match_in_progress = true

func set_stage(stage: int):
	_current_stage = stage
	if _g("core"):
		metrics.core.zone_stage_reached = max(metrics.core.zone_stage_reached, stage)

func end_match(rank: int, _winner_name: String, zone_stage: int):
	if not match_in_progress: return
	match_in_progress = false
	metrics.core.duration = (Time.get_ticks_msec() - _start_tick) / 1000.0 * Engine.time_scale
	metrics.core.zone_stage_reached = zone_stage
	metrics.session.rank = rank
	metrics.session.win = (rank == 1)
	_save_history()
	call_deferred("_save_sim_result")
	call_deferred("_print_report")

# ── Log functions — core ──────────────────────────────────────────────────────

func log_kill(source_type: String, weapon_type: String = "", distance: float = -1.0):
	if not match_in_progress: return
	metrics.session.kills += 1
	if not _g("combat"): return
	var w = _norm_weapon(weapon_type)
	_ensure_combat_weapon(w)
	metrics.combat.kills_by_weapon[w] = metrics.combat.kills_by_weapon.get(w, 0) + 1
	if distance > 0:
		if not metrics.combat.kill_distances.has(w):
			metrics.combat.kill_distances[w] = []
		metrics.combat.kill_distances[w].append(distance)

func log_death(cause: String, state: String = ""):
	if not match_in_progress or not _g("core"): return
	var key = str(_current_stage)
	metrics.core.deaths_by_stage[key] = metrics.core.deaths_by_stage.get(key, 0) + 1
	if cause == "RECOVER" or state == "RECOVER":
		if _g("tactics"):
			metrics.tactics.died_in_recover += 1

func log_final_duel_death(context: Dictionary):
	if not match_in_progress or not _g("zone"): return
	metrics.zone.final_duel_deaths.append(context)

func log_zone_death(state_at_death: String, time_outside: float):
	if not match_in_progress or not _g("zone"): return
	metrics.zone.zone_deaths += 1
	var key = state_at_death
	metrics.zone.zone_deaths_by_state[key] = metrics.zone.zone_deaths_by_state.get(key, 0) + 1
	if time_outside > metrics.zone.max_outside_time:
		metrics.zone.max_outside_time = time_outside

func log_damage(amount: float, source: String, weapon_type: String, _dist: float):
	if not match_in_progress or not _g("combat"): return
	if source != "gun": return
	metrics.combat.total_damage_dealt += amount
	var w = _norm_weapon(weapon_type)
	_ensure_combat_weapon(w)
	metrics.combat.damage_by_weapon[w] = metrics.combat.damage_by_weapon.get(w, 0.0) + amount

func log_shot():
	if not match_in_progress or not _g("combat"): return
	metrics.combat.shots_fired += 1

# ── Log functions — tactics ───────────────────────────────────────────────────

func log_tactics(event: String, _value: float = 0.0):
	if not match_in_progress or not _g("tactics"): return
	match event:
		"ammo_empty":       metrics.tactics.ammo_empty_enter += 1
		"recovery_start":   metrics.tactics.recover_bouts += 1
		"recovery_success":
			if metrics.tactics.recover_success < metrics.tactics.recover_bouts:
				metrics.tactics.recover_success += 1
		"stuck_triggered":  metrics.tactics.stuck_triggered += 1
		"reserve_reload":   metrics.tactics.reserve_reload += 1
		"patrol_entered":      metrics.tactics.patrol_entered += 1
		"patrol_timeout":      metrics.tactics.patrol_timeout += 1
		"weapon_drop_spawned": metrics.tactics.weapon_drop_spawned += 1
		"disengage_triggered": metrics.tactics.disengage_triggered += 1
		"cover_peek":       metrics.tactics.cover_peek += 1
		"combat_reposition": metrics.tactics.combat_reposition += 1
		"combat_kite":      metrics.tactics.combat_kite += 1
		"survival_break":   metrics.tactics.survival_break += 1
		"zone_escape_fire": metrics.tactics.zone_escape_fire += 1
		"retreat_counterfire": metrics.tactics.retreat_counterfire += 1
		"retreat_melee_counter": metrics.tactics.retreat_melee_counter += 1
		"stuck_while_threatened": metrics.tactics.stuck_while_threatened += 1
		"zone_assisted_death": metrics.tactics.zone_assisted_death += 1

func log_combat_audit(event: String, value: float = 0.0):
	if not match_in_progress or not _g("combat"): return
	match event:
		"attack_max_continuous":
			metrics.combat.attack_max_continuous = max(metrics.combat.attack_max_continuous, value)
		"attack_disengage":
			metrics.combat.attack_disengage_count += 1
		"kills":
			metrics.session.kills += int(value)
		"assists":
			metrics.session.assists += int(value)

# ── Log functions — economy ───────────────────────────────────────────────────

func log_pickup(item_name: String, item_type: String, is_rare: bool):
	if not match_in_progress or not _g("economy"): return
	var elapsed = (Time.get_ticks_msec() - _start_tick) / 1000.0
	if item_type == "weapon":
		var w = _norm_weapon(item_name)
		metrics.economy.weapon_pickups[w] = metrics.economy.weapon_pickups.get(w, 0) + 1
		if metrics.economy.first_upgrade_time < 0 and w != "pistol":
			metrics.economy.first_upgrade_time = elapsed
			metrics.economy.first_upgrade_weapon = w
	if is_rare:
		metrics.economy.rare_pickups += 1

func log_economy(event: String):
	if not match_in_progress: return
	match event:
		"heals_used":
			metrics.session.kills  # keep session alive
			if _g("economy"): metrics.economy.heals_used += 1
			if _g("core"):
				var key = str(_current_stage)
				metrics.core.heals_by_stage[key] = metrics.core.heals_by_stage.get(key, 0) + 1
		"shield_pickup":
			if _g("economy"): metrics.economy.shields_picked += 1

# ── Log functions — supply ────────────────────────────────────────────────────

func log_supply_event(event: String):
	if not match_in_progress or not _g("supply"): return
	match event:
		"visit":                  metrics.supply.visits += 1
		"preannounce_interest":   metrics.supply.preannounce_interest += 1
		"contest":                metrics.supply.contests += 1
		"telegraph":              metrics.supply.telegraphed = true

# ── Log functions — hell ─────────────────────────────────────────────────────

func log_hell_event(event: String):
	if not match_in_progress or not _g("hell"): return
	match event:
		"blackout":              metrics.hell.blackout_count += 1
		"bombardment_warned":    metrics.hell.bombardment_warned_count += 1
		"bombardment_hit":       metrics.hell.bombardment_hit_count += 1

# ── Log functions — mission ───────────────────────────────────────────────────

func log_mission_start(mission_id: String):
	if not match_in_progress or not _g("mission"): return
	metrics.mission.active_mission = mission_id
	metrics.mission.mission_result = "none"
	metrics.mission.mission_progress = {}

func log_mission_result(success: bool, progress: Dictionary = {}):
	if not _g("mission"): return
	metrics.mission.mission_result = "success" if success else "fail"
	metrics.mission.mission_progress = progress.duplicate()

# ── Log functions — pressure ──────────────────────────────────────────────────

func log_pressure_event(event: String, mission_id: String = ""):
	if not match_in_progress or not _g("pressure"): return
	match event:
		"triggered":
			metrics.pressure.pressure_triggered += 1
			if mission_id != "" and not metrics.pressure.has("triggered_ids"):
				metrics.pressure["triggered_ids"] = []
			if mission_id != "":
				metrics.pressure["triggered_ids"].append(mission_id)
		"cleared":
			metrics.pressure.pressure_cleared += 1
		"failed":
			metrics.pressure.pressure_failed += 1

# ── Log functions — archetype ─────────────────────────────────────────────────

func log_archetype_spawn(archetype_name: String):
	if not match_in_progress or not _g("archetype"): return
	var d = metrics.archetype.archetype_distribution
	d[archetype_name] = d.get(archetype_name, 0) + 1

func log_archetype_death(archetype_name: String):
	if not match_in_progress or not _g("archetype"): return
	var d = metrics.archetype.archetype_deaths
	d[archetype_name] = d.get(archetype_name, 0) + 1

func log_archetype_alive_at_zone2(distribution: Dictionary):
	if not match_in_progress or not _g("archetype"): return
	metrics.archetype.archetype_alive_at_zone2 = distribution.duplicate()

# ── Log functions — ai ───────────────────────────────────────────────────────

func log_ai_update(archetype_name: String, state_name: String, elapsed_usec: int):
	if not match_in_progress or not _g("ai"): return
	var elapsed = max(0, elapsed_usec)
	metrics.ai.update_samples += 1
	metrics.ai.update_total_usec += elapsed
	metrics.ai.update_max_usec = max(metrics.ai.update_max_usec, elapsed)
	_log_ai_update_bucket(metrics.ai.update_by_state, state_name, elapsed)
	_log_ai_update_bucket(metrics.ai.update_by_archetype, archetype_name, elapsed)

func _log_ai_update_bucket(buckets: Dictionary, key: String, elapsed_usec: int):
	var bucket_key = key if key != "" else "unknown"
	if not buckets.has(bucket_key):
		buckets[bucket_key] = {
			"samples": 0,
			"total_usec": 0,
			"max_usec": 0,
		}
	var bucket = buckets[bucket_key]
	bucket["samples"] = int(bucket.get("samples", 0)) + 1
	bucket["total_usec"] = int(bucket.get("total_usec", 0)) + elapsed_usec
	bucket["max_usec"] = max(int(bucket.get("max_usec", 0)), elapsed_usec)

# ── Log functions — doctrine ─────────────────────────────────────────────────

func log_doctrine_profile(summary: Dictionary):
	if not match_in_progress or not _g("doctrine"): return
	var key = String(summary.get("archetype", "unknown"))
	metrics.doctrine.profile_counts[key] = metrics.doctrine.profile_counts.get(key, 0) + 1
	if not metrics.doctrine.profile_summaries.has(key):
		metrics.doctrine.profile_summaries[key] = summary.duplicate(true)

func log_doctrine_plan(plan_id: String, archetype_name: String = ""):
	if not match_in_progress or not _g("doctrine"): return
	var plans = metrics.doctrine.combat_plan_counts
	plans[plan_id] = plans.get(plan_id, 0) + 1
	if archetype_name != "":
		var by_archetype = metrics.doctrine.plan_by_archetype
		if not by_archetype.has(archetype_name):
			by_archetype[archetype_name] = {}
		var archetype_plans = by_archetype[archetype_name]
		archetype_plans[plan_id] = archetype_plans.get(plan_id, 0) + 1

func log_doctrine_state_time(archetype_name: String, state_name: String, seconds: float):
	if not match_in_progress or not _g("doctrine") or seconds <= 0.0: return
	var by_archetype = metrics.doctrine.state_time_by_archetype
	if not by_archetype.has(archetype_name):
		by_archetype[archetype_name] = {}
	var state_times = by_archetype[archetype_name]
	state_times[state_name] = float(state_times.get(state_name, 0.0)) + seconds

func log_doctrine_engage_range(archetype_name: String, distance: float):
	if not match_in_progress or not _g("doctrine") or distance < 0.0: return
	var by_archetype = metrics.doctrine.engage_range_by_archetype
	if not by_archetype.has(archetype_name):
		by_archetype[archetype_name] = {
			"count": 0,
			"total": 0.0,
			"min": distance,
			"max": distance,
		}
	var bucket = by_archetype[archetype_name]
	var count = int(bucket.get("count", 0))
	bucket["count"] = count + 1
	bucket["total"] = float(bucket.get("total", 0.0)) + distance
	bucket["min"] = distance if count == 0 else minf(float(bucket.get("min", distance)), distance)
	bucket["max"] = distance if count == 0 else maxf(float(bucket.get("max", distance)), distance)

func log_doctrine_supply(decision: String):
	if not match_in_progress or not _g("doctrine"): return
	var decisions = metrics.doctrine.supply_decisions
	decisions[decision] = decisions.get(decision, 0) + 1

# Weapon drops can fire on the same frame as end_match, bypassing match_in_progress.
func log_weapon_drop():
	if _g("tactics") and metrics.has("tactics"):
		metrics.tactics.weapon_drop_spawned += 1

func log_artifact_selected(artifact_id: String):
	if not match_in_progress or not _g("artifact") or not metrics.has("artifact"):
		return
	metrics.artifact.selected = artifact_id if artifact_id != "" else "none"

func log_artifact_event(event: String):
	if event == "" or not match_in_progress or not _g("artifact") or not metrics.has("artifact"):
		return
	metrics.artifact.events[event] = metrics.artifact.events.get(event, 0) + 1
	if event == "emergency_shell_triggered":
		metrics.artifact.emergency_shell_triggered += 1
	elif event == "ghost_grass_started":
		metrics.artifact.ghost_grass_started += 1

# ── Stubs kept for call-site compatibility ────────────────────────────────────

func log_stealth(_event: String): pass  # reserved for v0.5+ stealth metrics
func log_spawn_metrics(_avg_dist: float, _los_rate: float): pass

# ── Persistence ───────────────────────────────────────────────────────────────

func _save_history():
	var score = calculate_score(
		metrics.session.rank, metrics.session.kills,
		metrics.session.assists, metrics.session.win, current_difficulty
	)
	var record = {
		"date":       Time.get_datetime_string_from_system().split("T")[0],
		"rank":       metrics.session.rank,
		"kills":      metrics.session.kills,
		"assists":    metrics.session.assists,
		"duration":   int(metrics.core.duration),
		"win":        metrics.session.win,
		"difficulty": current_difficulty,
		"score":      score,
	}
	load_history()
	var key = str(current_difficulty)
	if not match_history.has(key):
		match_history[key] = []
	match_history[key].append(record)
	match_history[key].sort_custom(func(a, b): return a.score > b.score)
	var file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(match_history, "\t"))
		file.close()

func _save_sim_result():
	# Writes only enabled groups so QA scripts know what was measured
	var out: Dictionary = {
		"enabled_groups": enabled_groups.duplicate(),
		"session":        metrics.session.duplicate(),
	}
	if _g("core"):    out["core"]    = metrics.core.duplicate(true)
	if _g("combat"):  out["combat"]  = metrics.combat.duplicate(true)
	if _g("tactics"): out["tactics"] = metrics.tactics.duplicate(true)
	if _g("zone"):    out["zone"]    = metrics.zone.duplicate(true)
	if _g("economy"): out["economy"] = metrics.economy.duplicate(true)
	if _g("supply"):  out["supply"]   = metrics.supply.duplicate(true)
	if _g("hell"):    out["hell"]     = metrics.hell.duplicate(true)
	if _g("mission"):    out["mission"]    = metrics.mission.duplicate(true)
	if _g("pressure"):   out["pressure"]   = metrics.pressure.duplicate(true)
	if _g("artifact"):   out["artifact"]   = metrics.artifact.duplicate(true)
	if _g("archetype"):  out["archetype"]  = metrics.archetype.duplicate(true)
	if _g("ai"):         out["ai"]         = metrics.ai.duplicate(true)
	if _g("doctrine"):   out["doctrine"]   = metrics.doctrine.duplicate(true)
	var file = FileAccess.open(SIM_RESULT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()

func load_history():
	if not FileAccess.file_exists(HISTORY_PATH):
		match_history = {}; return
	var file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		match_history = parsed
	else:
		match_history = {}  # old Array format — discard (incompatible)

# ── Report ────────────────────────────────────────────────────────────────────

func _print_report():
	print("\n" + "=".repeat(44))
	print("  MATCH REPORT  (rank #%d  |  %ds)" % [metrics.session.rank, int(metrics.core.duration)])
	print("=".repeat(44))
	print("Kills: %d   Assists: %d   Win: %s" % [
		metrics.session.kills, metrics.session.assists,
		"YES" if metrics.session.win else "no"
	])
	print("Zone stage reached: %d" % metrics.core.zone_stage_reached)
	print("Deaths by stage: %s" % str(metrics.core.deaths_by_stage))

	if _g("combat"):
		print("── Combat ──────────────────────────────────")
		print("  Shots fired: %d" % metrics.combat.shots_fired)
		print("  Total damage dealt: %.1f" % metrics.combat.total_damage_dealt)
		print("  Longest attack bout: %.1fs" % metrics.combat.attack_max_continuous)
		for w in metrics.combat.kill_distances:
			var dists: Array = metrics.combat.kill_distances[w]
			var avg = dists.reduce(func(a, b): return a + b, 0.0) / max(1, dists.size())
			print("  %s kills: %d  avg_dist: %.1fm" % [
				w, metrics.combat.kills_by_weapon.get(w, 0), avg
			])

	if _g("tactics"):
		print("── Tactics ─────────────────────────────────")
		var rb = metrics.tactics.recover_bouts
		var rs = metrics.tactics.recover_success
		print("  Ammo-empty enters: %d" % metrics.tactics.ammo_empty_enter)
		print("  Recover bouts: %d   success: %d (%.0f%%)" % [
			rb, rs, 100.0 * rs / max(1, rb)
		])
		print("  Died in RECOVER: %d" % metrics.tactics.died_in_recover)
		print("  Stuck triggers: %d" % metrics.tactics.stuck_triggered)
		print("  Disengage triggers: %d" % metrics.tactics.disengage_triggered)
		print("  Combat plans: cover=%d  reposition=%d  kite=%d  survival=%d" % [
			metrics.tactics.cover_peek,
			metrics.tactics.combat_reposition,
			metrics.tactics.combat_kite,
			metrics.tactics.survival_break
		])
		print("  Retreat combat: zone_fire=%d  counterfire=%d  melee=%d  stuck_threat=%d  zone_assist=%d" % [
			metrics.tactics.zone_escape_fire,
			metrics.tactics.retreat_counterfire,
			metrics.tactics.retreat_melee_counter,
			metrics.tactics.stuck_while_threatened,
			metrics.tactics.zone_assisted_death
		])
		print("  Reserve reloads: %d" % metrics.tactics.reserve_reload)
		print("  Patrol entries: %d  timeouts: %d" % [metrics.tactics.patrol_entered, metrics.tactics.patrol_timeout])
		print("  Weapon drops: %d" % metrics.tactics.weapon_drop_spawned)

	if _g("economy"):
		print("── Economy ─────────────────────────────────")
		print("  Heals used: %d   Shields: %d   Rare: %d" % [
			metrics.economy.heals_used, metrics.economy.shields_picked, metrics.economy.rare_pickups
		])
		if metrics.economy.first_upgrade_time >= 0:
			print("  First upgrade: %s at %.1fs" % [
				metrics.economy.first_upgrade_weapon, metrics.economy.first_upgrade_time
			])
		print("  Weapon pickups: %s" % str(metrics.economy.weapon_pickups))

	if _g("supply"):
		print("── Supply ──────────────────────────────────")
		print("  Telegraphed: %s  Visits: %d  Contests: %d" % [
			str(metrics.supply.telegraphed), metrics.supply.visits, metrics.supply.contests
		])
	if _g("hell") and (metrics.hell.blackout_count > 0 or metrics.hell.bombardment_warned_count > 0):
		print("── Hell ────────────────────────────────────")
		print("  Blackouts: %d  Bombardments warned: %d  hit: %d" % [
			metrics.hell.blackout_count,
			metrics.hell.bombardment_warned_count,
			metrics.hell.bombardment_hit_count,
		])
	if _g("pressure") and metrics.pressure.pressure_triggered > 0:
		print("── Pressure ────────────────────────────────")
		print("  Triggered: %d  Cleared: %d  Failed: %d" % [
			metrics.pressure.pressure_triggered,
			metrics.pressure.pressure_cleared,
			metrics.pressure.pressure_failed,
		])
		if metrics.pressure.has("triggered_ids"):
			print("  IDs: %s" % str(metrics.pressure["triggered_ids"]))
	if _g("archetype"):
		print("── Archetypes ──────────────────────────────")
		print("  Spawned:        %s" % str(metrics.archetype.archetype_distribution))
		print("  Alive@zone2:    %s" % str(metrics.archetype.archetype_alive_at_zone2))
		print("  Deaths:         %s" % str(metrics.archetype.archetype_deaths))
	if _g("ai"):
		print("── AI Update ───────────────────────────────")
		var samples = int(metrics.ai.update_samples)
		var avg_usec = float(metrics.ai.update_total_usec) / max(1, samples)
		print("  Samples:        %d  avg: %.1fus  max: %dus" % [
			samples,
			avg_usec,
			int(metrics.ai.update_max_usec),
		])
		if not metrics.ai.update_by_state.is_empty():
			var state_summary = {}
			for state_name in metrics.ai.update_by_state:
				var bucket = metrics.ai.update_by_state[state_name]
				var count = int(bucket.get("samples", 0))
				if count <= 0:
					continue
				state_summary[state_name] = {
					"avg_us": float(bucket.get("total_usec", 0)) / count,
					"max_us": int(bucket.get("max_usec", 0)),
					"count": count,
				}
			print("  By state:       %s" % str(state_summary))
	if _g("doctrine"):
		print("── Doctrine ────────────────────────────────")
		print("  Profiles:       %s" % str(metrics.doctrine.profile_counts))
		print("  Plans:          %s" % str(metrics.doctrine.combat_plan_counts))
		if not metrics.doctrine.plan_by_archetype.is_empty():
			print("  Plans/type:     %s" % str(metrics.doctrine.plan_by_archetype))
		if not metrics.doctrine.state_time_by_archetype.is_empty():
			print("  State time/type:%s" % str(metrics.doctrine.state_time_by_archetype))
		if not metrics.doctrine.engage_range_by_archetype.is_empty():
			var range_summary = {}
			for archetype_name in metrics.doctrine.engage_range_by_archetype:
				var bucket = metrics.doctrine.engage_range_by_archetype[archetype_name]
				var count = int(bucket.get("count", 0))
				if count <= 0:
					continue
				range_summary[archetype_name] = {
					"avg": float(bucket.get("total", 0.0)) / count,
					"min": bucket.get("min", 0.0),
					"max": bucket.get("max", 0.0),
					"count": count,
				}
			print("  Range/type:     %s" % str(range_summary))
		if not metrics.doctrine.supply_decisions.is_empty():
			print("  Supply:         %s" % str(metrics.doctrine.supply_decisions))
	print("=".repeat(44) + "\n")

# ── Internal helpers ──────────────────────────────────────────────────────────

func _norm_weapon(w: String) -> String:
	var n = w.to_lower().strip_edges()
	match n:
		"pistol", "피스톨": return "pistol"
		"ar", "assault rifle", "assault_rifle", "돌격소총", "소총": return "ar"
		"shotgun", "샷건": return "shotgun"
		"railgun", "rail gun", "레일건": return "railgun"
		"knife", "melee", "칼": return "knife"
		_: return n

func _ensure_combat_weapon(w: String):
	if not metrics.combat.kills_by_weapon.has(w):
		metrics.combat.kills_by_weapon[w] = 0
	if not metrics.combat.damage_by_weapon.has(w):
		metrics.combat.damage_by_weapon[w] = 0.0
