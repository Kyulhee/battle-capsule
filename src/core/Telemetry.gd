extends Node
# Autoloaded as "Telemetry"
#
# Metrics are split into named groups. Call set_groups() before start_match()
# to enable only what you need for a given test session.
#
# Groups:
#   "core"    — duration, zone_stage, rank, kills, assists, win, deaths_by_stage
#   "combat"  — shots_fired, damage, kill_distances, attack_max_continuous
#   "tactics" — RECOVER bouts, stuck, reserve_reload, patrol, weapon_drop
#   "economy" — heals, shields, weapon pickups, first upgrade timing
#   "supply"  — supply capsule events

# ── Group toggles ─────────────────────────────────────────────────────────────

var enabled_groups: Dictionary = {
	"core":    true,
	"combat":  true,
	"tactics": true,
	"economy": true,
	"supply":  true,
}

func set_groups(overrides: Dictionary):
	for k in overrides:
		if enabled_groups.has(k):
			enabled_groups[k] = overrides[k]

func _g(group: String) -> bool:
	return enabled_groups.get(group, false)

# ── Metric storage ────────────────────────────────────────────────────────────

var metrics: Dictionary = {}
var match_history: Array = []
const HISTORY_PATH = "user://match_history.json"
const SIM_RESULT_PATH = "user://sim_result_latest.json"

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
			"weapon_drop_spawned": 0,
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
	metrics.core.duration = (Time.get_ticks_msec() - _start_tick) / 1000.0
	metrics.core.zone_stage_reached = zone_stage
	metrics.session.rank = rank
	metrics.session.win = (rank == 1)
	_save_history()
	_save_sim_result()
	_print_report()

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

func log_death(cause: String, _state: String = ""):
	if not match_in_progress or not _g("core"): return
	var key = str(_current_stage)
	metrics.core.deaths_by_stage[key] = metrics.core.deaths_by_stage.get(key, 0) + 1
	if cause == "RECOVER":
		if _g("tactics"):
			metrics.tactics.died_in_recover += 1

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
		"recovery_success": metrics.tactics.recover_success += 1
		"stuck_triggered":  metrics.tactics.stuck_triggered += 1
		"reserve_reload":   metrics.tactics.reserve_reload += 1
		"patrol_entered":   metrics.tactics.patrol_entered += 1
		"weapon_drop_spawned": metrics.tactics.weapon_drop_spawned += 1

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

# ── Stubs kept for call-site compatibility ────────────────────────────────────

func log_stealth(_event: String): pass  # reserved for v0.5+ stealth metrics
func log_spawn_metrics(_avg_dist: float, _los_rate: float): pass

# ── Persistence ───────────────────────────────────────────────────────────────

func _save_history():
	var record = {
		"date":        Time.get_datetime_string_from_system().split("T")[0],
		"time_of_day": Time.get_time_string_from_system(),
		"rank":        metrics.session.rank,
		"kills":       metrics.session.kills,
		"assists":     metrics.session.assists,
		"duration":    int(metrics.core.duration),
		"win":         metrics.session.win,
	}
	load_history()
	match_history.append(record)
	match_history.sort_custom(func(a, b):
		if a.rank != b.rank: return a.rank < b.rank
		return a.kills > b.kills
	)
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
	if _g("economy"): out["economy"] = metrics.economy.duplicate(true)
	if _g("supply"):  out["supply"]  = metrics.supply.duplicate(true)
	var file = FileAccess.open(SIM_RESULT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()

func load_history():
	if not FileAccess.file_exists(HISTORY_PATH):
		match_history = []; return
	var file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	match_history = parsed if parsed is Array else []

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
		print("  Reserve reloads: %d" % metrics.tactics.reserve_reload)
		print("  Patrol entries: %d" % metrics.tactics.patrol_entered)
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
	print("=".repeat(44) + "\n")

# ── Internal helpers ──────────────────────────────────────────────────────────

func _norm_weapon(w: String) -> String:
	var n = w.to_lower().strip_edges()
	match n:
		"ar", "assault rifle", "assault_rifle": return "assault_rifle"
		_: return n

func _ensure_combat_weapon(w: String):
	if not metrics.combat.kills_by_weapon.has(w):
		metrics.combat.kills_by_weapon[w] = 0
	if not metrics.combat.damage_by_weapon.has(w):
		metrics.combat.damage_by_weapon[w] = 0.0
