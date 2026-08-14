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
#   "spawn"    — spawn placement density and fallback diagnostics
#   "hell"     — blackout/bombardment event counts (Hell difficulty only)
#   "mission"  — active mission id, result (success/fail/none)
#   "pressure" — pressure mission triggered/cleared/failed counts (Hard opt-in / Hell)
#   "artifact" — selected artifact id and bounded artifact trigger events
#   "ai"       — sampled bot update budget by state and archetype
#   "doctrine" — merged bot AI profiles and selected combat plans
#   "pacing"   — first contact/upgrade/stage timings and route/POI dwell

const VersionedJsonStoreScript = preload("res://src/core/VersionedJsonStore.gd")

# ── Group toggles ─────────────────────────────────────────────────────────────

var enabled_groups: Dictionary = {
	"core":      true,
	"combat":    true,
	"tactics":   true,
	"economy":   true,
	"supply":    true,
	"zone":      true,
	"spawn":     true,
	"hell":      true,
	"mission":   true,
	"pressure":  true,
	"artifact":  true,
	"archetype": true,
	"ai":        true,
	"doctrine":  true,
	"pacing":    true,
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
const HISTORY_SCHEMA_VERSION := 1
const HISTORY_LIMIT_PER_DIFFICULTY := 50
const MAX_KILL_CONTEXT_EVENTS := 128
const OPENING_KILL_CONTEXT_SECONDS := 60.0
const OPENING_TARGET_CONTINUITY_SECONDS := 60.0
const TARGET_CONTINUITY_RELEASE_CENSOR_SECONDS := 59.0
const TARGET_CONTINUITY_REACQUIRE_SECONDS := 1.0
const MAX_TARGET_CONTINUITY_EPISODE_SAMPLES := 128
const MAX_TARGET_CONTINUITY_DISENGAGE_EXIT_SAMPLES := 128
const TARGET_CONTINUITY_SAMPLE_METHOD := "deterministic_bottom_k_stable_hash"
const MAX_TARGET_CONTINUITY_SUMMARY_KEYS := 32
var history_path: String = HISTORY_PATH
var sim_result_path: String = SIM_RESULT_PATH

const DIFF_MULT: Array = [1.0, 1.5, 2.5, 4.0]

func calculate_score(rank: int, kills: int, assists: int, win: bool, diff: int) -> int:
	var base = max(0, 1000 - (rank - 1) * 80)
	var raw  = base + kills * 100 + assists * 40 + (300 if win else 0)
	return int(raw * DIFF_MULT[clamp(diff, 0, 3)])

func clear_history() -> bool:
	match_history = {}
	if not VersionedJsonStoreScript.save_dictionary(
		history_path,
		match_history,
		HISTORY_SCHEMA_VERSION
	):
		push_error("Telemetry: failed to clear match history.")
		return false
	if not VersionedJsonStoreScript.refresh_backup(history_path):
		push_error("Telemetry: failed to finalize the cleared history backup.")
		return false
	return true

func get_history_for_difficulty(diff: int) -> Array:
	load_history()
	return match_history.get(str(diff), [])

var match_in_progress: bool = false
var _start_tick: int = 0
var _current_stage: int = 1
var _pending_weapon_collect_context: Dictionary = {}
var _pending_weapon_collect_elapsed: float = -1.0
var _target_continuity_release_episodes: Dictionary = {}
var _target_continuity_disengage_episodes: Dictionary = {}
var _target_continuity_episode_selected_samples: Dictionary = {}
var _target_continuity_disengage_selected_samples: Dictionary = {}

func _reset_metrics():
	_pending_weapon_collect_context = {}
	_pending_weapon_collect_elapsed = -1.0
	_target_continuity_release_episodes = {}
	_target_continuity_disengage_episodes = {}
	_target_continuity_episode_selected_samples = {}
	_target_continuity_disengage_selected_samples = {}
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
			"location_samples": 0,
			"hit_location_by_poi_role": {},
			"damage_location_by_poi_role": {},
			"kill_location_by_poi_role": {},
			"hit_location_by_route_role": {},
			"damage_location_by_route_role": {},
			"kill_location_by_route_role": {},
			"hit_location_by_route_id": {},
			"damage_location_by_route_id": {},
			"kill_location_by_route_id": {},
			"open_damage_by_context": {},
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
			"disengage_entries": 0,
			"disengage_reasons": {},
			"disengage_reasons_by_archetype": {},
			"cover_peek": 0,
			"combat_reposition": 0,
			"combat_kite": 0,
			"survival_break": 0,
			"zone_escape_fire": 0,
			"retreat_counterfire": 0,
			"retreat_melee_counter": 0,
			"stuck_while_threatened": 0,
			"zone_assisted_death": 0,
			"engagement_join_deferred": 0,
			"stuck_by_state": {},
			"stuck_by_poi_role": {},
			"stuck_by_route_role": {},
			"stuck_by_route_id": {},
			"stuck_by_cell": {},
			"stuck_threat_by_route_id": {},
		},
		# economy
		"economy": {
			"heals_used": 0,
			"shields_picked": 0,
			"rare_pickups": 0,
			"weapon_pickups": {},
			"pickup_spawn_by_kind": {},
			"pickup_collect_by_kind": {},
			"pickup_spawn_poi_role_by_kind": {},
			"pickup_spawn_route_role_by_kind": {},
			"pickup_collect_poi_role_by_kind": {},
			"pickup_collect_route_role_by_kind": {},
			"pickup_spawn_poi_band_by_kind": {},
			"pickup_spawn_route_band_by_kind": {},
			"pickup_spawn_source_by_kind": {},
			"pickup_collect_poi_band_by_kind": {},
			"pickup_collect_route_band_by_kind": {},
			"pickup_collect_source_by_kind": {},
			"first_upgrade_time": -1.0,
			"first_upgrade_weapon": "none",
			"first_upgrade_source": "none",
			"first_upgrade_poi_role": "none",
			"first_upgrade_poi_band": "none",
			"first_upgrade_route_role": "none",
			"first_upgrade_route_band": "none",
			"first_upgrade_nearest_poi_role": "none",
			"first_upgrade_nearest_route_role": "none",
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
		# pacing
		"pacing": {
			# Event staircase: each sample is effective from `time` until the next
			# sample. The analyzer carries the final observation to match end.
			"alive_timeline": [],
			# Bounded, death-only snapshots used to explain opening attrition.
			# This deliberately avoids per-frame actor identifiers and payloads.
			"kill_context_events": [],
			"kill_context_dropped": 0,
			# Linked, deterministic bottom-k samples. The exact summary below is
			# authoritative even when either diagnostic sample is incomplete.
			"target_continuity_episode_samples": [],
			"target_continuity_episode_sample_metadata": {
				"method": TARGET_CONTINUITY_SAMPLE_METHOD,
				"capacity": MAX_TARGET_CONTINUITY_EPISODE_SAMPLES,
				"population": 0,
				"stored": 0,
				"omitted": 0,
				"complete": true,
			},
			"target_continuity_disengage_exit_samples": [],
			"target_continuity_disengage_exit_sample_metadata": {
				"method": TARGET_CONTINUITY_SAMPLE_METHOD,
				"capacity": MAX_TARGET_CONTINUITY_DISENGAGE_EXIT_SAMPLES,
				"population": 0,
				"stored": 0,
				"omitted": 0,
				"complete": true,
			},
			# Exact opening continuity totals. This fixed-shape aggregate remains
			# complete regardless of bounded sample coverage.
			"target_continuity_summary": {
				"schema_version": 2,
				"exact": true,
				"complete": true,
				"window_seconds": OPENING_TARGET_CONTINUITY_SECONDS,
				"release_censor_seconds": TARGET_CONTINUITY_RELEASE_CENSOR_SECONDS,
				"reacquire_seconds": TARGET_CONTINUITY_REACQUIRE_SECONDS,
				"release_time_basis": "match_elapsed",
				"survival_episode_releases": 0,
				"survival_episode_reacquired_1s": 0,
				"release_by_target_state": {},
				"release_by_reason": {},
				"release_by_source": {},
				"reacquire_by_source": {},
				"reacquire_delay": {"count": 0, "sum": 0.0, "max": 0.0},
				"reacquire_displacement": {"count": 0, "sum": 0.0, "max": 0.0},
				"reacquire_stuck_delta_total": 0,
				"reacquire_disengage_entry_delta_total": 0,
				"disengage_exit_count": 0,
				"disengage_same_entry_target": 0,
				"disengage_reengage": 0,
				"disengage_stuck_positive": 0,
				"disengage_duration": {"count": 0, "sum": 0.0, "max": 0.0},
				"disengage_displacement": {"count": 0, "sum": 0.0, "max": 0.0},
				"disengage_stuck_delta_total": 0,
				"disengage_by_entry_reason": {},
				"disengage_by_exit_reason": {},
				"disengage_by_exit_state": {},
				"disengage_transitions": {},
			},
			"first_shot_time": -1.0,
			"first_target_acquisition_time": -1.0,
			"first_target_acquisition_source": "none",
			"first_target_acquisition_target_kind": "none",
			"first_target_acquisition_state": "none",
			"first_target_acquisition_distance": -1.0,
			"first_target_acquisition_poi_role": "none",
			"first_target_acquisition_poi_band": "none",
			"first_target_acquisition_route_role": "none",
			"first_target_acquisition_route_band": "none",
			"first_target_acquisition_nearest_poi_role": "none",
			"first_target_acquisition_nearest_route_role": "none",
			"first_target_acquisition_self_poi_role": "none",
			"first_target_acquisition_self_poi_band": "none",
			"first_target_acquisition_self_route_role": "none",
			"first_target_acquisition_self_route_band": "none",
			"first_target_acquisition_self_nearest_poi_role": "none",
			"first_target_acquisition_self_nearest_route_role": "none",
			"first_target_acquisition_spawn_age": -1.0,
			"first_target_acquisition_zone_distance": -1.0,
			"first_target_acquisition_zone_radius": -1.0,
			"first_target_acquisition_zone_ratio": -1.0,
			"first_target_acquisition_zone_status": "unknown",
			"first_objective_interrupt_time": -1.0,
			"first_objective_interrupt_enemy_distance": -1.0,
			"first_objective_interrupt_objective_distance": -1.0,
			"first_objective_interrupt_source": "none",
			"first_objective_interrupt_kind": "none",
			"first_objective_interrupt_need": "none",
			"first_objective_interrupt_target_match": "none",
			"first_objective_interrupt_target_detail": "none",
			"first_objective_interrupt_objective_poi_band": "none",
			"first_objective_interrupt_objective_route_band": "none",
			"first_objective_interrupt_enemy_poi_band": "none",
			"first_objective_interrupt_enemy_route_band": "none",
			"first_contact_time": -1.0,
			"first_damage_time": -1.0,
			"first_kill_time": -1.0,
			"first_non_pistol_upgrade_time": -1.0,
			"first_non_pistol_upgrade_weapon": "none",
			"first_non_pistol_upgrade_source": "none",
			"first_non_pistol_upgrade_poi_role": "none",
			"first_non_pistol_upgrade_poi_band": "none",
			"first_non_pistol_upgrade_route_role": "none",
			"first_non_pistol_upgrade_route_band": "none",
			"first_non_pistol_upgrade_nearest_poi_role": "none",
			"first_non_pistol_upgrade_nearest_route_role": "none",
			"stage_times": {},
		},
		# spawn
		"spawn": {
			"requested_count": 0,
			"placed_count": 0,
			"spawn_radius": 0.0,
			"inner_radius": 0.0,
			"entity_clearance": 0.0,
			"world_size": 0.0,
			"fallback_count": 0,
			"attempt_total": 0,
			"attempt_max": 0,
			"fixed_count": 0,
			"avg_attempts": 0.0,
			"min_nearest_distance": 0.0,
			"avg_nearest_distance": 0.0,
			"min_origin_distance": 0.0,
			"avg_origin_distance": 0.0,
			"max_origin_distance": 0.0,
			"annulus_saturation": 0.0,
			"origin_band_counts": {},
			"radial_inner_half_count": 0,
			"radial_inner_half_share": 0.0,
			"inside_poi_count": 0,
			"inside_poi_share": 0.0,
			"on_route_count": 0,
			"on_route_share": 0.0,
			"poi_role_counts": {},
			"poi_name_counts": {},
			"nearest_poi_role_counts": {},
			"route_role_counts": {},
			"nearest_route_role_counts": {},
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
			"chase_context_time_by_archetype": {},
			"chase_self_poi_role_by_context": {},
			"chase_self_route_role_by_context": {},
			"chase_target_poi_role_by_context": {},
			"chase_target_route_role_by_context": {},
			"chase_self_poi_band_by_context": {},
			"chase_target_poi_band_by_context": {},
			"chase_target_route_band_by_context": {},
			"chase_target_kind_by_context": {},
			"target_acquisition_by_source": {},
			"target_acquisition_state_by_source": {},
			"target_acquisition_poi_role_by_source": {},
			"target_acquisition_poi_band_by_source": {},
			"target_acquisition_route_role_by_source": {},
			"target_acquisition_route_band_by_source": {},
			"target_acquisition_overlap_by_source": {},
			"target_acquisition_route_role_poi_band_by_source": {},
			"target_acquisition_nearest_poi_role_by_source": {},
			"target_acquisition_nearest_route_role_by_source": {},
			"target_acquisition_distance_by_source": {},
			"loot_objective_start_by_source": {},
			"loot_objective_mode_by_source": {},
			"loot_objective_origin_state_by_source": {},
			"loot_objective_kind_by_source": {},
			"loot_objective_need_by_source": {},
			"loot_objective_ammo_band_by_source": {},
			"loot_objective_reserve_band_by_source": {},
			"loot_objective_weapon_by_source": {},
			"loot_objective_target_weapon_by_source": {},
			"loot_objective_target_detail_by_source": {},
			"loot_objective_target_match_by_source": {},
			"loot_objective_weapon_target_by_source": {},
			"loot_objective_weapon_match_by_source": {},
			"loot_objective_detail_match_by_source": {},
			"loot_objective_target_poi_role_by_source": {},
			"loot_objective_target_nearest_poi_name_by_source": {},
			"loot_objective_target_route_role_by_source": {},
			"loot_objective_route_kind_by_source": {},
			"loot_objective_route_detail_by_source": {},
			"loot_objective_target_poi_band_by_source": {},
			"loot_objective_target_route_band_by_source": {},
			"loot_objective_start_distance_by_source": {},
			"loot_objective_outcome_by_source": {},
			"loot_objective_outcome_by_kind": {},
			"loot_objective_outcome_by_target_match": {},
			"loot_objective_outcome_by_target_detail": {},
			"loot_objective_match_outcome_by_source": {},
			"loot_objective_detail_outcome_by_source": {},
			"loot_objective_duration_by_source": {},
			"loot_objective_duration_by_outcome": {},
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
	if _g("pacing"):
		metrics.pacing.stage_times["1"] = 0.0

func set_stage(stage: int):
	_current_stage = stage
	if _g("core"):
		metrics.core.zone_stage_reached = max(metrics.core.zone_stage_reached, stage)
	if _g("pacing"):
		var key := str(stage)
		if not metrics.pacing.stage_times.has(key):
			metrics.pacing.stage_times[key] = _elapsed_seconds()

func end_match(
	rank: int,
	winner_name: String,
	zone_stage: int,
	persist_history: bool = false,
	history_score_bonus: int = 0
):
	if not match_in_progress: return
	metrics.core.duration = _elapsed_seconds()
	# Preserve an explicit endpoint without guessing Main's alive count. This
	# only carries forward the most recently observed count; Main owns the
	# authoritative start/death samples through log_alive_sample().
	if _g("pacing") and not metrics.pacing.alive_timeline.is_empty():
		var last_alive_sample: Dictionary = metrics.pacing.alive_timeline[-1]
		log_alive_sample(
			int(last_alive_sample.get("alive", 0)),
			zone_stage,
			"match_end",
			bool(last_alive_sample.get("shrinking", false))
		)
	match_in_progress = false
	metrics.core.zone_stage_reached = zone_stage
	metrics.session.rank = rank
	metrics.session.win = winner_name == "Player"
	if persist_history:
		save_current_match_history(history_score_bonus)
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

# Records authoritative alive-count changes against Main.match_timer. Call
# once after the initial roster is known (`reason = "start"`) and after every
# death (`reason = "death"`). Repeating the same count at the same game time is
# ignored, while multiple deaths on one frame remain distinct because their
# alive counts differ.
func log_alive_sample(
	alive: int,
	stage: int = -1,
	reason: String = "checkpoint",
	shrinking: bool = false,
	victim_kind: String = "none",
	cause: String = "none"
) -> bool:
	if not match_in_progress or not _g("pacing"):
		return false
	var elapsed := _elapsed_seconds()
	var alive_count := maxi(0, alive)
	var resolved_stage := stage if stage > 0 else _current_stage
	var resolved_reason := reason.strip_edges()
	var resolved_victim_kind := victim_kind.strip_edges()
	var resolved_cause := cause.strip_edges()
	if resolved_reason.is_empty():
		resolved_reason = "checkpoint"
	if resolved_victim_kind.is_empty():
		resolved_victim_kind = "none"
	if resolved_cause.is_empty():
		resolved_cause = "none"

	var timeline: Array = metrics.pacing.alive_timeline
	if not timeline.is_empty():
		var previous: Dictionary = timeline[-1]
		if (
			int(previous.get("alive", -1)) == alive_count
			and is_equal_approx(float(previous.get("time", -1.0)), elapsed)
			and resolved_reason != "match_end"
		):
			return false

	timeline.append({
		"time": elapsed,
		"alive": alive_count,
		"stage": resolved_stage,
		"reason": resolved_reason,
		"shrinking": shrinking,
		"victim_kind": resolved_victim_kind,
		"cause": resolved_cause,
	})
	return true

func log_kill_context(
	cause: String,
	weapon: String,
	distance: float,
	victim_context: Dictionary,
	attacker_context: Dictionary = {}
) -> bool:
	if not match_in_progress or not _g("pacing"):
		return false
	var elapsed := _elapsed_seconds()
	if elapsed > OPENING_KILL_CONTEXT_SECONDS:
		return false
	var events: Array = metrics.pacing.kill_context_events
	if events.size() >= MAX_KILL_CONTEXT_EVENTS:
		metrics.pacing.kill_context_dropped += 1
		return false
	var main = get_tree().root.get_node_or_null("Main")
	var shrinking := false
	if main != null:
		var zone = main.get("zone")
		if zone != null:
			shrinking = bool(zone.get("shrinking"))
	var normalized_cause := _normalized_key(cause, "unknown")
	var normalized_attacker := _normalized_kill_actor_context(attacker_context)
	normalized_attacker["attack_origin"] = _kill_attack_origin(
		normalized_cause,
		String(normalized_attacker.get("attack_origin", "none"))
	)
	events.append({
		"time": elapsed,
		"stage": _current_stage,
		"shrinking": shrinking,
		"cause": normalized_cause,
		"weapon": _normalized_key(_norm_weapon(weapon), "none"),
		"distance": snappedf(distance, 0.01) if distance >= 0.0 else -1.0,
		"victim": _normalized_kill_actor_context(victim_context),
		"attacker": normalized_attacker,
	})
	return true

func can_track_target_continuity() -> bool:
	return match_in_progress \
		and _g("pacing") \
		and _elapsed_seconds() <= OPENING_TARGET_CONTINUITY_SECONDS

func track_target_continuity_release(context: Dictionary) -> Dictionary:
	var result := {
		"tracked": false,
		"first_episode": false,
		"pair_open": false,
		"sampled": false,
		"episode_key": "",
		"release_time": -1.0,
		"release_time_basis": "match_elapsed",
	}
	if not match_in_progress or not _g("pacing"):
		return result
	var elapsed := _elapsed_seconds()
	if elapsed > TARGET_CONTINUITY_RELEASE_CENSOR_SECONDS:
		return result
	var episode_key := _target_continuity_episode_key(context)
	var target_state := _normalized_key(String(context.get("target_state", "none")), "none")
	var release_reason := _normalized_key(String(context.get("reason", "unknown")), "unknown")
	if episode_key.is_empty() \
			or target_state not in ["recover", "disengage"] \
			or release_reason in ["target_killed", "invalid_target"]:
		return result
	var first_episode := not _target_continuity_release_episodes.has(episode_key)
	if first_episode:
		_target_continuity_release_episodes[episode_key] = {
			"release_time": elapsed,
			"release_reason": release_reason,
			"release_source": _normalized_key(String(context.get("source", "unknown")), "unknown"),
			"reacquired": false,
		}
		var summary: Dictionary = metrics.pacing.target_continuity_summary
		summary.survival_episode_releases += 1
		_target_continuity_increment(summary.release_by_target_state, target_state)
		_target_continuity_increment(summary.release_by_reason, release_reason)
		_target_continuity_increment(
			summary.release_by_source,
			String(context.get("source", "unknown"))
		)
		var release_sample := {
			"sample_key": episode_key,
			"sample_hash": _target_continuity_stable_hash(episode_key),
			"release": _normalized_target_continuity_release(context, elapsed),
		}
		_target_continuity_consider_sample(
			_target_continuity_episode_selected_samples,
			release_sample,
			MAX_TARGET_CONTINUITY_EPISODE_SAMPLES
		)
	else:
		var episode: Dictionary = _target_continuity_release_episodes[episode_key]
		# Before the first counted reacquisition, a repeated real release refreshes
		# the canonical pair origin without changing either the exact denominator
		# or its immutable first-release sample snapshot.
		if not bool(episode.get("reacquired", false)):
			episode["release_time"] = elapsed
			episode["release_reason"] = release_reason
			episode["release_source"] = _normalized_key(
				String(context.get("source", "unknown")),
				"unknown"
			)
			_target_continuity_release_episodes[episode_key] = episode
	var episode_state: Dictionary = _target_continuity_release_episodes[episode_key]
	_target_continuity_sync_samples(
		_target_continuity_episode_selected_samples,
		"target_continuity_episode_samples",
		"target_continuity_episode_sample_metadata",
		int(metrics.pacing.target_continuity_summary.survival_episode_releases),
		MAX_TARGET_CONTINUITY_EPISODE_SAMPLES
	)
	result.tracked = true
	result.first_episode = first_episode
	result.pair_open = not bool(episode_state.get("reacquired", false))
	result.sampled = _target_continuity_episode_selected_samples.has(episode_key)
	result.episode_key = episode_key
	result.release_time = float(episode_state.get("release_time", elapsed))
	return result

func track_target_continuity_reacquire(context: Dictionary) -> Dictionary:
	var result := {
		"tracked": false,
		"sampled": false,
		"episode_key": "",
		"release_time": -1.0,
		"release_time_basis": "match_elapsed",
		"delay_seconds": -1.0,
	}
	if not can_track_target_continuity():
		return result
	var episode_key := _target_continuity_episode_key(context)
	if episode_key.is_empty() or not _target_continuity_release_episodes.has(episode_key):
		return result
	var episode: Dictionary = _target_continuity_release_episodes[episode_key]
	if bool(episode.get("reacquired", false)):
		return result
	var elapsed := _elapsed_seconds()
	var canonical_release_time := float(episode.get("release_time", -1.0))
	# Pair membership and delay use only Telemetry's authoritative match clock.
	# A Bot spawn-age delay may be retained in the sample as a diagnostic, but
	# can never affect eligibility or the exact aggregate.
	var delay := elapsed - canonical_release_time
	if canonical_release_time < 0.0 \
			or canonical_release_time > TARGET_CONTINUITY_RELEASE_CENSOR_SECONDS \
			or elapsed < canonical_release_time \
			or delay > TARGET_CONTINUITY_REACQUIRE_SECONDS:
		return result
	episode["reacquired"] = true
	_target_continuity_release_episodes[episode_key] = episode
	var summary: Dictionary = metrics.pacing.target_continuity_summary
	summary.survival_episode_reacquired_1s += 1
	_target_continuity_increment(
		summary.reacquire_by_source,
		String(context.get("source", "unknown"))
	)
	_target_continuity_measure(summary.reacquire_delay, delay)
	_target_continuity_measure(
		summary.reacquire_displacement,
		maxf(0.0, float(context.get("displacement", 0.0)))
	)
	summary.reacquire_stuck_delta_total += maxi(0, int(context.get("stuck_delta", 0)))
	summary.reacquire_disengage_entry_delta_total += maxi(
		0,
		int(context.get("disengage_entry_delta", 0))
	)
	if _target_continuity_episode_selected_samples.has(episode_key):
		var selected: Dictionary = _target_continuity_episode_selected_samples[episode_key]
		var paired_context := context.duplicate()
		paired_context["release_reason"] = String(episode.get("release_reason", "unknown"))
		paired_context["release_source"] = String(episode.get("release_source", "unknown"))
		selected["reacquire_1s"] = _normalized_target_continuity_reacquire(
			paired_context,
			elapsed,
			canonical_release_time,
			delay
		)
		_target_continuity_episode_selected_samples[episode_key] = selected
		_target_continuity_sync_samples(
			_target_continuity_episode_selected_samples,
			"target_continuity_episode_samples",
			"target_continuity_episode_sample_metadata",
			int(summary.survival_episode_releases),
			MAX_TARGET_CONTINUITY_EPISODE_SAMPLES
		)
	result.tracked = true
	result.sampled = _target_continuity_episode_selected_samples.has(episode_key)
	result.episode_key = episode_key
	result.release_time = canonical_release_time
	result.delay_seconds = delay
	return result

func track_target_continuity_disengage_exit(context: Dictionary) -> bool:
	if not can_track_target_continuity():
		return false
	var actor_id := maxi(-1, int(context.get("actor_id", -1)))
	var state_episode_id := maxi(-1, int(context.get("state_episode_id", -1)))
	if actor_id < 0 or state_episode_id < 0:
		return false
	var episode_key := "%d|%d" % [actor_id, state_episode_id]
	if _target_continuity_disengage_episodes.has(episode_key):
		return false
	_target_continuity_disengage_episodes[episode_key] = true
	var summary: Dictionary = metrics.pacing.target_continuity_summary
	summary.disengage_exit_count += 1
	if bool(context.get("same_entry_target", false)):
		summary.disengage_same_entry_target += 1
	if bool(context.get("reengage", false)):
		summary.disengage_reengage += 1
	var stuck_delta := maxi(0, int(context.get("stuck_delta", 0)))
	if stuck_delta > 0:
		summary.disengage_stuck_positive += 1
	summary.disengage_stuck_delta_total += stuck_delta
	var duration := maxf(0.0, float(context.get("duration_seconds", 0.0)))
	var displacement := maxf(0.0, float(context.get("displacement", 0.0)))
	_target_continuity_measure(summary.disengage_duration, duration)
	_target_continuity_measure(summary.disengage_displacement, displacement)
	var entry_reason := _normalized_key(String(context.get("entry_reason", "unknown")), "unknown")
	var exit_reason := _normalized_key(String(context.get("reason", "unknown")), "unknown")
	var exit_state := _normalized_key(String(context.get("exit_state", "unknown")), "unknown")
	_target_continuity_increment(summary.disengage_by_entry_reason, entry_reason)
	_target_continuity_increment(summary.disengage_by_exit_reason, exit_reason)
	_target_continuity_increment(summary.disengage_by_exit_state, exit_state)
	_target_continuity_increment(
		summary.disengage_transitions,
		"%s->%s/%s" % [entry_reason, exit_reason, exit_state]
	)
	var exit_sample := _normalized_target_continuity_disengage_exit(context, _elapsed_seconds())
	exit_sample["sample_key"] = episode_key
	exit_sample["sample_hash"] = _target_continuity_stable_hash(episode_key)
	_target_continuity_consider_sample(
		_target_continuity_disengage_selected_samples,
		exit_sample,
		MAX_TARGET_CONTINUITY_DISENGAGE_EXIT_SAMPLES
	)
	_target_continuity_sync_samples(
		_target_continuity_disengage_selected_samples,
		"target_continuity_disengage_exit_samples",
		"target_continuity_disengage_exit_sample_metadata",
		int(summary.disengage_exit_count),
		MAX_TARGET_CONTINUITY_DISENGAGE_EXIT_SAMPLES
	)
	return true

func _target_continuity_episode_key(context: Dictionary) -> String:
	var actor_id := maxi(-1, int(context.get("actor_id", -1)))
	var target_id := maxi(-1, int(context.get("target_id", -1)))
	var target_state_episode := maxi(-1, int(context.get("target_state_episode", -1)))
	if actor_id < 0 or target_id < 0 or target_state_episode < 0:
		return ""
	return "%d|%d|%d" % [actor_id, target_id, target_state_episode]

func _target_continuity_increment(counter: Dictionary, raw_key: String) -> void:
	var key := _normalized_key(raw_key, "unknown")
	if not counter.has(key):
		var must_collapse := counter.size() >= MAX_TARGET_CONTINUITY_SUMMARY_KEYS \
			or (not counter.has("other") \
				and counter.size() >= MAX_TARGET_CONTINUITY_SUMMARY_KEYS - 1)
		if must_collapse:
			key = "other"
	counter[key] = int(counter.get(key, 0)) + 1

func _target_continuity_measure(bucket: Dictionary, value: float) -> void:
	var bounded := maxf(0.0, value)
	bucket.count = int(bucket.get("count", 0)) + 1
	bucket.sum = float(bucket.get("sum", 0.0)) + bounded
	bucket.max = maxf(float(bucket.get("max", 0.0)), bounded)

func _normalized_target_continuity_release(context: Dictionary, elapsed: float) -> Dictionary:
	return {
		"time": elapsed,
		"release_time": elapsed,
		"release_time_basis": "match_elapsed",
		"actor_id": maxi(-1, int(context.get("actor_id", -1))),
		"target_id": maxi(-1, int(context.get("target_id", -1))),
		"target_state_episode": maxi(-1, int(context.get("target_state_episode", -1))),
		"state": _normalized_key(String(context.get("state", "none")), "none"),
		"target_state": _normalized_key(String(context.get("target_state", "none")), "none"),
		"reason": _normalized_key(String(context.get("reason", "none")), "none"),
		"source": _normalized_key(String(context.get("source", "none")), "none"),
		"target_source": _normalized_key(String(context.get("target_source", "none")), "none"),
		"distance": _continuity_float(context, "distance"),
		"target_age_seconds": _continuity_float(context, "target_age_seconds"),
		"move_intent": _normalized_key(String(context.get("move_intent", "none")), "none"),
		"nav_intent": bool(context.get("nav_intent", false)),
		"speed": _continuity_float(context, "speed"),
		"nav_target_distance": _continuity_float(context, "nav_target_distance"),
	}

func _normalized_target_continuity_reacquire(
	context: Dictionary,
	elapsed: float,
	release_time: float,
	delay: float
) -> Dictionary:
	return {
		"time": elapsed,
		"release_time": release_time,
		"paired_release_time": release_time,
		"release_time_basis": "match_elapsed",
		"actor_id": maxi(-1, int(context.get("actor_id", -1))),
		"target_id": maxi(-1, int(context.get("target_id", -1))),
		"target_state_episode": maxi(-1, int(context.get("target_state_episode", -1))),
		"state": _normalized_key(String(context.get("state", "none")), "none"),
		"source": _normalized_key(String(context.get("source", "none")), "none"),
		"target_state": _normalized_key(String(context.get("target_state", "none")), "none"),
		"release_reason": _normalized_key(String(context.get("release_reason", "none")), "none"),
		"release_source": _normalized_key(String(context.get("release_source", "none")), "none"),
		"paired_release_reason": _normalized_key(String(context.get("release_reason", "none")), "none"),
		"paired_release_source": _normalized_key(String(context.get("release_source", "none")), "none"),
		"distance": _continuity_float(context, "distance"),
		"target_age_seconds": _continuity_float(context, "target_age_seconds"),
		"delay_seconds": delay,
		"spawn_delay_seconds": _continuity_float(context, "spawn_delay_seconds"),
		"displacement": maxf(0.0, float(context.get("displacement", 0.0))),
		"stuck_delta": maxi(0, int(context.get("stuck_delta", 0))),
		"disengage_entry_delta": maxi(0, int(context.get("disengage_entry_delta", 0))),
		"move_intent": _normalized_key(String(context.get("move_intent", "none")), "none"),
		"nav_intent": bool(context.get("nav_intent", false)),
		"speed": _continuity_float(context, "speed"),
		"nav_target_distance": _continuity_float(context, "nav_target_distance"),
	}

func _normalized_target_continuity_disengage_exit(
	context: Dictionary,
	elapsed: float
) -> Dictionary:
	return {
		"time": elapsed,
		"actor_id": maxi(-1, int(context.get("actor_id", -1))),
		"target_id": maxi(-1, int(context.get("target_id", -1))),
		"entry_target_id": maxi(-1, int(context.get("entry_target_id", -1))),
		"current_target_id": maxi(-1, int(context.get("current_target_id", -1))),
		"state_episode_id": maxi(-1, int(context.get("state_episode_id", -1))),
		"state": _normalized_key(String(context.get("state", "none")), "none"),
		"exit_state": _normalized_key(String(context.get("exit_state", "none")), "none"),
		"reason": _normalized_key(String(context.get("reason", "none")), "none"),
		"entry_reason": _normalized_key(String(context.get("entry_reason", "none")), "none"),
		"source": _normalized_key(String(context.get("source", "none")), "none"),
		"duration_seconds": maxf(0.0, float(context.get("duration_seconds", 0.0))),
		"displacement": maxf(0.0, float(context.get("displacement", 0.0))),
		"stuck_delta": maxi(0, int(context.get("stuck_delta", 0))),
		"same_entry_target": bool(context.get("same_entry_target", false)),
		"reengage": bool(context.get("reengage", false)),
		"visible_enemies": maxi(-1, int(context.get("visible_enemies", -1))),
		"additional_threats": maxi(-1, int(context.get("additional_threats", -1))),
		"targeting_player": bool(context.get("targeting_player", false)),
		"move_intent": _normalized_key(String(context.get("move_intent", "none")), "none"),
		"nav_intent": bool(context.get("nav_intent", false)),
		"speed": _continuity_float(context, "speed"),
		"nav_target_distance": _continuity_float(context, "nav_target_distance"),
	}

func _target_continuity_stable_hash(sample_key: String) -> int:
	# A custom, platform-stable polynomial hash. Keeping the modulus below the
	# signed 32-bit boundary makes the serialized rank a strict nonnegative int.
	var value: int = 7
	for index in range(sample_key.length()):
		value = (value * 131 + sample_key.unicode_at(index)) % 2147483647
	return value

func _target_continuity_sample_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_hash := int(a.get("sample_hash", 0))
	var b_hash := int(b.get("sample_hash", 0))
	if a_hash != b_hash:
		return a_hash < b_hash
	return String(a.get("sample_key", "")) < String(b.get("sample_key", ""))

func _target_continuity_consider_sample(
	selected: Dictionary,
	sample: Dictionary,
	capacity: int
) -> bool:
	var sample_key := String(sample.get("sample_key", ""))
	if sample_key.is_empty() or capacity <= 0:
		return false
	if selected.has(sample_key):
		selected[sample_key] = sample
		return true
	if selected.size() < capacity:
		selected[sample_key] = sample
		return true
	var worst_key := ""
	var worst_sample: Dictionary = {}
	for existing_key in selected:
		var existing: Dictionary = selected[existing_key]
		if worst_key.is_empty() or _target_continuity_sample_precedes(worst_sample, existing):
			worst_key = String(existing_key)
			worst_sample = existing
	if not _target_continuity_sample_precedes(sample, worst_sample):
		return false
	selected.erase(worst_key)
	selected[sample_key] = sample
	return true

func _target_continuity_sync_samples(
	selected: Dictionary,
	sample_field: String,
	metadata_field: String,
	population: int,
	capacity: int
) -> void:
	var samples: Array = []
	for sample in selected.values():
		samples.append(sample)
	samples.sort_custom(Callable(self, "_target_continuity_sample_precedes"))
	metrics.pacing[sample_field] = samples
	var stored := samples.size()
	var omitted := maxi(0, population - stored)
	var metadata: Dictionary = metrics.pacing[metadata_field]
	metadata["method"] = TARGET_CONTINUITY_SAMPLE_METHOD
	metadata["capacity"] = capacity
	metadata["population"] = population
	metadata["stored"] = stored
	metadata["omitted"] = omitted
	metadata["complete"] = omitted == 0

func _continuity_float(context: Dictionary, key: String) -> float:
	var value := float(context.get(key, -1.0))
	return snappedf(value, 0.01) if value >= 0.0 else -1.0

func _kill_attack_origin(cause: String, raw_origin: String) -> String:
	if cause != "melee":
		return "none"
	match _normalized_key(raw_origin, "other"):
		"recover_melee", "recover_close_player":
			return "recover_melee"
		"attack_empty":
			return "attack_empty"
		"retreat_counter":
			return "retreat"
		_:
			return "other"

func _normalized_kill_actor_context(context: Dictionary) -> Dictionary:
	return {
		"kind": _normalized_key(String(context.get("kind", "none")), "none"),
		"state": _normalized_key(String(context.get("state", "none")), "none"),
		"weapon": _normalized_key(_norm_weapon(String(context.get("weapon", "none"))), "none"),
		"mag": maxi(-1, int(context.get("mag", -1))),
		"reserve": maxi(-1, int(context.get("reserve", -1))),
		"attack_origin": _normalized_key(String(context.get("attack_origin", "none")), "none"),
		"acquisition_source": _normalized_key(String(context.get("acquisition_source", "none")), "none"),
		"target_match": bool(context.get("target_match", false)),
		"opponent_recent_attacker": bool(context.get("opponent_recent_attacker", false)),
		"opponent_pressuring": bool(context.get("opponent_pressuring", false)),
		"targeting_loot": bool(context.get("targeting_loot", false)),
		"spawn_age": snappedf(float(context.get("spawn_age", -1.0)), 0.01),
		"state_age_seconds": snappedf(float(context.get("state_age_seconds", -1.0)), 0.01),
		"target_age_seconds": snappedf(float(context.get("target_age_seconds", -1.0)), 0.01),
		"disengage_entry_reason": _normalized_key(String(context.get("disengage_entry_reason", "none")), "none"),
		"disengage_same_entry_target": bool(context.get("disengage_same_entry_target", false)),
		"state_displacement": snappedf(float(context.get("state_displacement", -1.0)), 0.01),
		"state_stuck_delta": maxi(-1, int(context.get("state_stuck_delta", -1))),
		"zone_ratio": snappedf(float(context.get("zone_ratio", -1.0)), 0.01),
		"zone_status": _normalized_key(String(context.get("zone_status", "unknown")), "unknown"),
		"poi_role": _normalized_key(String(context.get("poi_role", "open")), "open"),
		"poi_name": String(context.get("poi_name", "none")).strip_edges(),
		"poi_band": _normalized_key(String(context.get("poi_band", "unknown")), "unknown"),
		"route_role": _normalized_key(String(context.get("route_role", "off_route")), "off_route"),
		"route_band": _normalized_key(String(context.get("route_band", "unknown")), "unknown"),
	}

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

func log_combat_location(event: String, amount: float, context: Dictionary):
	if not match_in_progress or not _g("combat"): return
	var event_key = event.strip_edges().to_lower()
	if event_key == "":
		return
	var poi_role := String(context.get("poi_role", "open"))
	var route_role := String(context.get("route_role", "off_route"))
	var route_id := String(context.get("route_id", "off_route"))
	match event_key:
		"damage", "hit":
			_record_first_pacing_time("first_contact_time")
			if amount > 0.0:
				_record_first_pacing_time("first_damage_time")
			metrics.combat.location_samples += 1
			_add_bucket_count(metrics.combat.hit_location_by_poi_role, poi_role)
			_add_bucket_count(metrics.combat.hit_location_by_route_role, route_role)
			_add_bucket_count(metrics.combat.hit_location_by_route_id, route_id)
			if amount > 0.0:
				_add_bucket_value(metrics.combat.damage_location_by_poi_role, poi_role, amount)
				_add_bucket_value(metrics.combat.damage_location_by_route_role, route_role, amount)
				_add_bucket_value(metrics.combat.damage_location_by_route_id, route_id, amount)
				if poi_role == "open":
					var cell_key := String(context.get("cell", "unknown"))
					var nearest_poi_name := _normalized_key(String(context.get("nearest_poi_name", "none")), "none")
					var poi_edge_band := _poi_distance_band(context)
					var open_context_key := "%s|%s|%s" % [cell_key, nearest_poi_name, poi_edge_band]
					_add_bucket_value(metrics.combat.open_damage_by_context, open_context_key, amount)
		"kill":
			_record_first_pacing_time("first_kill_time")
			_add_bucket_count(metrics.combat.kill_location_by_poi_role, poi_role)
			_add_bucket_count(metrics.combat.kill_location_by_route_role, route_role)
			_add_bucket_count(metrics.combat.kill_location_by_route_id, route_id)

func log_shot():
	if not match_in_progress or not _g("combat"): return
	_record_first_pacing_time("first_shot_time")
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
		"disengage_triggered": log_disengage_reason("outnumbered")
		"disengage_losing_fight": log_disengage_reason("losing_fight")
		"reload_retreat": log_disengage_reason("reload_retreat")
		"cover_peek":       metrics.tactics.cover_peek += 1
		"combat_reposition": metrics.tactics.combat_reposition += 1
		"combat_kite":      metrics.tactics.combat_kite += 1
		"survival_break":   metrics.tactics.survival_break += 1
		"zone_escape_fire": metrics.tactics.zone_escape_fire += 1
		"retreat_counterfire": metrics.tactics.retreat_counterfire += 1
		"retreat_melee_counter": metrics.tactics.retreat_melee_counter += 1
		"stuck_while_threatened": metrics.tactics.stuck_while_threatened += 1
		"zone_assisted_death": metrics.tactics.zone_assisted_death += 1
		"engagement_join_deferred": metrics.tactics.engagement_join_deferred += 1

func log_stuck_context(state_name: String, context: Dictionary, threatened: bool = false):
	if not match_in_progress or not _g("tactics"): return
	var state_key = state_name.strip_edges()
	if state_key == "":
		state_key = "unknown"
	var poi_role := String(context.get("poi_role", "open"))
	var route_role := String(context.get("route_role", "off_route"))
	var route_id := String(context.get("route_id", "off_route"))
	var cell_key := String(context.get("cell", "unknown"))
	_add_bucket_count(metrics.tactics.stuck_by_state, state_key)
	_add_bucket_count(metrics.tactics.stuck_by_poi_role, poi_role)
	_add_bucket_count(metrics.tactics.stuck_by_route_role, route_role)
	_add_bucket_count(metrics.tactics.stuck_by_route_id, route_id)
	_add_bucket_count(metrics.tactics.stuck_by_cell, cell_key)
	if threatened:
		_add_bucket_count(metrics.tactics.stuck_threat_by_route_id, route_id)

func log_disengage_reason(reason: String, archetype_name: String = ""):
	if not match_in_progress or not _g("tactics"): return
	var key = reason.strip_edges().to_lower()
	if key == "":
		key = "unknown"
	metrics.tactics.disengage_entries += 1
	if key == "outnumbered":
		metrics.tactics.disengage_triggered += 1
	metrics.tactics.disengage_reasons[key] = int(metrics.tactics.disengage_reasons.get(key, 0)) + 1
	var archetype_key = archetype_name.strip_edges().to_upper()
	if archetype_key == "":
		return
	if not metrics.tactics.disengage_reasons_by_archetype.has(archetype_key):
		metrics.tactics.disengage_reasons_by_archetype[archetype_key] = {}
	var by_reason = metrics.tactics.disengage_reasons_by_archetype[archetype_key]
	by_reason[key] = int(by_reason.get(key, 0)) + 1

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
	var elapsed = _elapsed_seconds()
	if item_type == "weapon":
		var w = _norm_weapon(item_name)
		metrics.economy.weapon_pickups[w] = metrics.economy.weapon_pickups.get(w, 0) + 1
		if metrics.economy.first_upgrade_time < 0 and w != "pistol":
			metrics.economy.first_upgrade_time = elapsed
			metrics.economy.first_upgrade_weapon = w
			if absf(elapsed - _pending_weapon_collect_elapsed) <= 0.25:
				_record_first_upgrade_context(_pending_weapon_collect_context)
			if _g("pacing") and metrics.pacing.first_non_pistol_upgrade_time < 0.0:
				metrics.pacing.first_non_pistol_upgrade_time = elapsed
				metrics.pacing.first_non_pistol_upgrade_weapon = w
	if is_rare:
		metrics.economy.rare_pickups += 1

func log_pickup_location(event_name: String, item_type: String, context: Dictionary, source_name: String = "unknown"):
	if not match_in_progress or not _g("economy"): return
	var event_key = event_name.strip_edges().to_lower()
	if event_key != "spawn" and event_key != "collect":
		event_key = "unknown"
	var kind = item_type.strip_edges().to_lower()
	if kind == "":
		kind = "unknown"
	var count_key = "pickup_%s_by_kind" % event_key
	var poi_key = "pickup_%s_poi_role_by_kind" % event_key
	var route_key = "pickup_%s_route_role_by_kind" % event_key
	var poi_band_key = "pickup_%s_poi_band_by_kind" % event_key
	var route_band_key = "pickup_%s_route_band_by_kind" % event_key
	var source_key = "pickup_%s_source_by_kind" % event_key
	var source_value = source_name.strip_edges().to_lower()
	if source_value == "":
		source_value = "unknown"
	if metrics.economy.has(count_key):
		_add_bucket_value(metrics.economy[count_key], kind, 1.0)
	if metrics.economy.has(poi_key):
		_add_nested_bucket_value(
			metrics.economy[poi_key],
			kind,
			String(context.get("poi_role", "open")),
			1.0
		)
	if metrics.economy.has(poi_band_key):
		_add_nested_bucket_value(
			metrics.economy[poi_band_key],
			kind,
			_poi_distance_band(context),
			1.0
		)
	if metrics.economy.has(route_key):
		_add_nested_bucket_value(
			metrics.economy[route_key],
			kind,
			String(context.get("route_role", "off_route")),
			1.0
		)
	if metrics.economy.has(route_band_key):
		_add_nested_bucket_value(
			metrics.economy[route_band_key],
			kind,
			_route_distance_band(context),
			1.0
		)
	if metrics.economy.has(source_key):
		_add_nested_bucket_value(
			metrics.economy[source_key],
			kind,
			source_value,
			1.0
		)
	if event_key == "collect" and kind == "weapon":
		context["source"] = source_value
		_pending_weapon_collect_context = context.duplicate(true)
		_pending_weapon_collect_elapsed = _elapsed_seconds()
		if float(metrics.economy.get("first_upgrade_time", -1.0)) >= 0.0:
			_record_first_upgrade_context(context)

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

func log_doctrine_chase_context(archetype_name: String, context_name: String, seconds: float):
	if not match_in_progress or not _g("doctrine") or seconds <= 0.0: return
	var context_key = context_name.strip_edges().to_lower()
	if context_key == "":
		context_key = "unknown"
	var by_archetype = metrics.doctrine.chase_context_time_by_archetype
	if not by_archetype.has(archetype_name):
		by_archetype[archetype_name] = {}
	var context_times = by_archetype[archetype_name]
	context_times[context_key] = float(context_times.get(context_key, 0.0)) + seconds

func log_doctrine_chase_location(
	_archetype_name: String,
	context_name: String,
	self_context: Dictionary,
	target_context: Dictionary,
	target_kind: String,
	seconds: float
):
	if not match_in_progress or seconds <= 0.0: return
	var context_key = context_name.strip_edges().to_lower()
	if context_key == "":
		context_key = "unknown"
	if _g("doctrine"):
		_add_nested_bucket_value(
			metrics.doctrine.chase_self_poi_role_by_context,
			context_key,
			String(self_context.get("poi_role", "open")),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_self_route_role_by_context,
			context_key,
			String(self_context.get("route_role", "off_route")),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_target_poi_role_by_context,
			context_key,
			String(target_context.get("poi_role", "none")),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_target_route_role_by_context,
			context_key,
			String(target_context.get("route_role", "none")),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_self_poi_band_by_context,
			context_key,
			_poi_distance_band(self_context),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_target_poi_band_by_context,
			context_key,
			_poi_distance_band(target_context),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_target_route_band_by_context,
			context_key,
			_route_distance_band(target_context),
			seconds
		)
		_add_nested_bucket_value(
			metrics.doctrine.chase_target_kind_by_context,
			context_key,
			target_kind,
			seconds
		)

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

func log_doctrine_target_acquisition(
	_archetype_name: String,
	source_name: String,
	state_name: String,
	target_context: Dictionary,
	distance: float,
	self_context: Dictionary = {},
	acquisition_context: Dictionary = {}
):
	if not match_in_progress or not _g("doctrine"): return
	var source_key = source_name.strip_edges().to_lower()
	if source_key == "":
		source_key = "unknown"
	var state_key = state_name.strip_edges()
	if state_key == "":
		state_key = "UNKNOWN"
	var poi_band := _poi_distance_band(target_context)
	var route_band := _route_distance_band(target_context)
	var nearest_route_role := _nearest_route_role_key(target_context, route_band)
	var self_poi_band := _poi_distance_band(self_context)
	var self_route_band := _route_distance_band(self_context)
	var self_nearest_route_role := _nearest_route_role_key(self_context, self_route_band)
	if _g("pacing") and float(metrics.pacing.first_target_acquisition_time) < 0.0:
		metrics.pacing.first_target_acquisition_time = _elapsed_seconds()
		metrics.pacing.first_target_acquisition_source = source_key
		metrics.pacing.first_target_acquisition_target_kind = _normalized_key(
			String(acquisition_context.get("target_kind", "unknown")),
			"unknown"
		)
		metrics.pacing.first_target_acquisition_state = state_key
		metrics.pacing.first_target_acquisition_distance = distance
		metrics.pacing.first_target_acquisition_poi_role = String(target_context.get("poi_role", "open"))
		metrics.pacing.first_target_acquisition_poi_band = poi_band
		metrics.pacing.first_target_acquisition_route_role = String(target_context.get("route_role", "off_route"))
		metrics.pacing.first_target_acquisition_route_band = route_band
		metrics.pacing.first_target_acquisition_nearest_poi_role = String(target_context.get("nearest_poi_role", "none"))
		metrics.pacing.first_target_acquisition_nearest_route_role = nearest_route_role
		metrics.pacing.first_target_acquisition_self_poi_role = String(self_context.get("poi_role", "none"))
		metrics.pacing.first_target_acquisition_self_poi_band = self_poi_band
		metrics.pacing.first_target_acquisition_self_route_role = String(self_context.get("route_role", "none"))
		metrics.pacing.first_target_acquisition_self_route_band = self_route_band
		metrics.pacing.first_target_acquisition_self_nearest_poi_role = String(self_context.get("nearest_poi_role", "none"))
		metrics.pacing.first_target_acquisition_self_nearest_route_role = self_nearest_route_role
		metrics.pacing.first_target_acquisition_spawn_age = float(acquisition_context.get("spawn_age", -1.0))
		metrics.pacing.first_target_acquisition_zone_distance = float(acquisition_context.get("zone_distance", -1.0))
		metrics.pacing.first_target_acquisition_zone_radius = float(acquisition_context.get("zone_radius", -1.0))
		metrics.pacing.first_target_acquisition_zone_ratio = float(acquisition_context.get("zone_ratio", -1.0))
		metrics.pacing.first_target_acquisition_zone_status = _normalized_key(String(acquisition_context.get("zone_status", "unknown")), "unknown")
	_add_bucket_value(metrics.doctrine.target_acquisition_by_source, source_key, 1.0)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_state_by_source,
		source_key,
		state_key,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_poi_role_by_source,
		source_key,
		String(target_context.get("poi_role", "open")),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_poi_band_by_source,
		source_key,
		poi_band,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_route_role_by_source,
		source_key,
		String(target_context.get("route_role", "off_route")),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_route_band_by_source,
		source_key,
		route_band,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_overlap_by_source,
		source_key,
		"%s/%s" % [poi_band, route_band],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_route_role_poi_band_by_source,
		source_key,
		"%s/%s" % [nearest_route_role, poi_band],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_nearest_poi_role_by_source,
		source_key,
		String(target_context.get("nearest_poi_role", "none")),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.target_acquisition_nearest_route_role_by_source,
		source_key,
		nearest_route_role,
		1.0
	)
	if distance >= 0.0:
		_add_sample_bucket(metrics.doctrine.target_acquisition_distance_by_source, source_key, distance)

func log_doctrine_objective_enemy_interrupt(
	_archetype_name: String,
	source_name: String,
	_mode_name: String,
	kind_name: String,
	objective_context: Dictionary,
	objective_distance: float,
	enemy_context: Dictionary,
	enemy_distance: float,
	selection_context: Dictionary = {}
):
	if not match_in_progress or not _g("doctrine"): return
	if not _g("pacing") or float(metrics.pacing.first_objective_interrupt_time) >= 0.0:
		return
	var source_key := _normalized_key(source_name, "unknown")
	var kind_key := _normalized_key(kind_name, "pickup_unknown")
	var objective_poi_band := _poi_distance_band(objective_context)
	var objective_route_band := _route_distance_band(objective_context)
	var enemy_poi_band := _poi_distance_band(enemy_context)
	var enemy_route_band := _route_distance_band(enemy_context)
	metrics.pacing.first_objective_interrupt_time = _elapsed_seconds()
	metrics.pacing.first_objective_interrupt_enemy_distance = enemy_distance
	metrics.pacing.first_objective_interrupt_objective_distance = objective_distance
	metrics.pacing.first_objective_interrupt_source = source_key
	metrics.pacing.first_objective_interrupt_kind = kind_key
	metrics.pacing.first_objective_interrupt_need = _normalized_key(String(selection_context.get("need", "unknown")), "unknown")
	metrics.pacing.first_objective_interrupt_target_match = _normalized_key(String(selection_context.get("target_match", "unknown")), "unknown")
	metrics.pacing.first_objective_interrupt_target_detail = _normalized_key(String(selection_context.get("target_detail", kind_key)), kind_key)
	metrics.pacing.first_objective_interrupt_objective_poi_band = objective_poi_band
	metrics.pacing.first_objective_interrupt_objective_route_band = objective_route_band
	metrics.pacing.first_objective_interrupt_enemy_poi_band = enemy_poi_band
	metrics.pacing.first_objective_interrupt_enemy_route_band = enemy_route_band

func log_doctrine_loot_objective_start(
	_archetype_name: String,
	source_name: String,
	mode_name: String,
	origin_state: String,
	target_kind: String,
	target_context: Dictionary,
	distance: float,
	selection_context: Dictionary = {}
):
	if not match_in_progress or not _g("doctrine"): return
	var source_key := _normalized_key(source_name, "unknown")
	var mode_key := _normalized_key(mode_name, "unknown")
	var state_key := origin_state.strip_edges()
	if state_key == "":
		state_key = "UNKNOWN"
	var kind_key := _normalized_key(target_kind, "pickup_unknown")
	var route_band := _route_distance_band(target_context)
	var route_role := _nearest_route_role_key(target_context, route_band)
	var target_detail := _normalized_key(String(selection_context.get("target_detail", kind_key)), kind_key)
	var target_match := _normalized_key(String(selection_context.get("target_match", "unknown")), "unknown")
	var weapon_key := _normalized_key(String(selection_context.get("weapon", "none")), "none")
	var target_weapon := _normalized_key(String(selection_context.get("target_weapon", "none")), "none")
	_add_bucket_value(metrics.doctrine.loot_objective_start_by_source, source_key, 1.0)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_mode_by_source, source_key, mode_key, 1.0)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_origin_state_by_source, source_key, state_key, 1.0)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_kind_by_source, source_key, kind_key, 1.0)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_need_by_source,
		source_key,
		_normalized_key(String(selection_context.get("need", "unknown")), "unknown"),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_ammo_band_by_source,
		source_key,
		_normalized_key(String(selection_context.get("ammo_band", "unknown")), "unknown"),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_reserve_band_by_source,
		source_key,
		_normalized_key(String(selection_context.get("reserve_band", "unknown")), "unknown"),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_weapon_by_source,
		source_key,
		weapon_key,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_weapon_by_source,
		source_key,
		target_weapon,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_detail_by_source,
		source_key,
		target_detail,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_match_by_source,
		source_key,
		target_match,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_weapon_target_by_source,
		source_key,
		"%s/%s" % [weapon_key, target_weapon],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_weapon_match_by_source,
		source_key,
		"%s/%s" % [weapon_key, target_match],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_detail_match_by_source,
		source_key,
		"%s/%s" % [target_detail, target_match],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_poi_role_by_source,
		source_key,
		String(target_context.get("poi_role", "open")),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_nearest_poi_name_by_source,
		source_key,
		_normalized_key(String(target_context.get("nearest_poi_name", "none")), "none"),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_route_role_by_source,
		source_key,
		route_role,
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_route_kind_by_source,
		source_key,
		"%s/%s" % [route_role, kind_key],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_route_detail_by_source,
		source_key,
		"%s/%s" % [route_role, target_detail],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_poi_band_by_source,
		source_key,
		_poi_distance_band(target_context),
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_target_route_band_by_source,
		source_key,
		route_band,
		1.0
	)
	if distance >= 0.0:
		_add_sample_bucket(metrics.doctrine.loot_objective_start_distance_by_source, source_key, distance)

func log_doctrine_loot_objective_outcome(
	_archetype_name: String,
	source_name: String,
	mode_name: String,
	target_kind: String,
	outcome_name: String,
	duration: float,
	selection_context: Dictionary = {}
):
	if not match_in_progress or not _g("doctrine"): return
	var source_key := _normalized_key(source_name, "unknown")
	var kind_key := _normalized_key(target_kind, "pickup_unknown")
	var outcome_key := _normalized_key(outcome_name, "unknown")
	var target_match := _normalized_key(String(selection_context.get("target_match", "unknown")), "unknown")
	var target_detail := _normalized_key(String(selection_context.get("target_detail", kind_key)), kind_key)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_outcome_by_source, source_key, outcome_key, 1.0)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_outcome_by_kind, kind_key, outcome_key, 1.0)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_outcome_by_target_match, target_match, outcome_key, 1.0)
	_add_nested_bucket_value(metrics.doctrine.loot_objective_outcome_by_target_detail, target_detail, outcome_key, 1.0)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_match_outcome_by_source,
		source_key,
		"%s/%s" % [target_match, outcome_key],
		1.0
	)
	_add_nested_bucket_value(
		metrics.doctrine.loot_objective_detail_outcome_by_source,
		source_key,
		"%s/%s" % [target_detail, outcome_key],
		1.0
	)
	if duration >= 0.0:
		_add_sample_bucket(metrics.doctrine.loot_objective_duration_by_source, source_key, duration)
		_add_sample_bucket(metrics.doctrine.loot_objective_duration_by_outcome, outcome_key, duration)

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

func log_spawn_metrics(summary: Dictionary):
	if not match_in_progress or not _g("spawn"): return
	metrics.spawn = summary.duplicate(true)

# ── Persistence ───────────────────────────────────────────────────────────────

func calculate_current_score(score_bonus: int = 0) -> int:
	return calculate_score(
		metrics.session.rank, metrics.session.kills,
		metrics.session.assists, metrics.session.win, current_difficulty
	) + max(0, score_bonus)


func save_current_match_history(score_bonus: int = 0) -> int:
	var score := calculate_current_score(score_bonus)
	var record = {
		"date":       Time.get_datetime_string_from_system().split("T")[0],
		"rank":       metrics.session.rank,
		"kills":      metrics.session.kills,
		"assists":    metrics.session.assists,
		"duration":   int(metrics.core.duration),
		"win":        metrics.session.win,
		"difficulty": current_difficulty,
		"score":      score,
		"mission_bonus": max(0, score_bonus),
	}
	load_history()
	var updated_history := match_history.duplicate(true)
	var key = str(current_difficulty)
	if not updated_history.has(key):
		updated_history[key] = []
	updated_history[key].append(record)
	updated_history[key].sort_custom(
		func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	if updated_history[key].size() > HISTORY_LIMIT_PER_DIFFICULTY:
		updated_history[key].resize(HISTORY_LIMIT_PER_DIFFICULTY)
	if not VersionedJsonStoreScript.save_dictionary(
		history_path,
		updated_history,
		HISTORY_SCHEMA_VERSION
	):
		push_error("Telemetry: failed to save match history.")
		return -1
	match_history = updated_history
	return score

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
	if _g("spawn"):   out["spawn"]   = metrics.spawn.duplicate(true)
	if _g("economy"): out["economy"] = metrics.economy.duplicate(true)
	if _g("supply"):  out["supply"]   = metrics.supply.duplicate(true)
	if _g("hell"):    out["hell"]     = metrics.hell.duplicate(true)
	if _g("mission"):    out["mission"]    = metrics.mission.duplicate(true)
	if _g("pressure"):   out["pressure"]   = metrics.pressure.duplicate(true)
	if _g("artifact"):   out["artifact"]   = metrics.artifact.duplicate(true)
	if _g("archetype"):  out["archetype"]  = metrics.archetype.duplicate(true)
	if _g("ai"):         out["ai"]         = metrics.ai.duplicate(true)
	if _g("doctrine"):   out["doctrine"]   = metrics.doctrine.duplicate(true)
	if _g("pacing"):     out["pacing"]     = metrics.pacing.duplicate(true)
	var file = FileAccess.open(sim_result_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()

func load_history() -> Dictionary:
	var loaded := VersionedJsonStoreScript.load_dictionary(
		history_path,
		HISTORY_SCHEMA_VERSION,
		{}
	)
	match_history = _normalize_history(loaded)
	if match_history != loaded:
		if not VersionedJsonStoreScript.save_dictionary(
			history_path,
			match_history,
			HISTORY_SCHEMA_VERSION
		):
			push_warning("Telemetry: normalized history could not be persisted.")
	return match_history


func _normalize_history(raw_history: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for diff in range(DIFF_MULT.size()):
		var key := str(diff)
		var raw_records = raw_history.get(key, [])
		if not (raw_records is Array):
			continue
		var records: Array = []
		for raw_record in raw_records:
			if not (raw_record is Dictionary):
				continue
			var record := _normalize_history_record(raw_record, diff)
			if record.is_empty():
				continue
			if not records.has(record):
				records.append(record)
		if not records.is_empty():
			records.sort_custom(
				func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0))
			)
			if records.size() > HISTORY_LIMIT_PER_DIFFICULTY:
				records.resize(HISTORY_LIMIT_PER_DIFFICULTY)
			normalized[key] = records
	return normalized


func _normalize_history_record(raw_record: Dictionary, diff: int) -> Dictionary:
	if not _is_history_number(raw_record.get("rank")) \
			or not _is_history_number(raw_record.get("score")):
		return {}
	var rank := maxi(1, int(raw_record.get("rank", 1)))
	var score := maxi(0, int(raw_record.get("score", 0)))
	var record := raw_record.duplicate(true)
	record["date"] = (
		String(raw_record.get("date"))
		if typeof(raw_record.get("date")) == TYPE_STRING
		else "unknown"
	)
	record["rank"] = rank
	record["kills"] = _nonnegative_history_int(raw_record.get("kills"), 0)
	record["assists"] = _nonnegative_history_int(raw_record.get("assists"), 0)
	record["duration"] = _nonnegative_history_int(raw_record.get("duration"), 0)
	record["win"] = (
		bool(raw_record.get("win"))
		if typeof(raw_record.get("win")) == TYPE_BOOL
		else false
	)
	record["difficulty"] = diff
	record["score"] = score
	record["mission_bonus"] = _nonnegative_history_int(
		raw_record.get("mission_bonus"),
		0
	)
	return record


func _nonnegative_history_int(value, fallback: int) -> int:
	return maxi(0, int(value)) if _is_history_number(value) else fallback


func _is_history_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

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
		print("  Disengage entries: %d" % metrics.tactics.disengage_entries)
		if not metrics.tactics.disengage_reasons.is_empty():
			var disengage_parts = []
			for reason in metrics.tactics.disengage_reasons:
				disengage_parts.append("%s=%d" % [reason, int(metrics.tactics.disengage_reasons.get(reason, 0))])
			disengage_parts.sort()
			print("  Disengage reasons: %s" % ", ".join(disengage_parts))
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
		print("  Engagement joins deferred: %d" % metrics.tactics.engagement_join_deferred)
		print("  Weapon drops: %d" % metrics.tactics.weapon_drop_spawned)

	if _g("economy"):
		print("── Economy ─────────────────────────────────")
		print("  Heals used: %d   Shields: %d   Rare: %d" % [
			metrics.economy.heals_used, metrics.economy.shields_picked, metrics.economy.rare_pickups
		])
		if metrics.economy.first_upgrade_time >= 0:
			print("  First upgrade: %s from %s at %.1fs" % [
				metrics.economy.first_upgrade_weapon,
				metrics.economy.first_upgrade_source,
				metrics.economy.first_upgrade_time,
			])
			print("  First upgrade context: poi=%s/%s route=%s/%s nearest=%s/%s" % [
				metrics.economy.first_upgrade_poi_role,
				metrics.economy.first_upgrade_poi_band,
				metrics.economy.first_upgrade_route_role,
				metrics.economy.first_upgrade_route_band,
				metrics.economy.first_upgrade_nearest_poi_role,
				metrics.economy.first_upgrade_nearest_route_role,
			])
		print("  Weapon pickups: %s" % str(metrics.economy.weapon_pickups))

	if _g("supply"):
		print("── Supply ──────────────────────────────────")
		print("  Telegraphed: %s  Visits: %d  Contests: %d" % [
			str(metrics.supply.telegraphed), metrics.supply.visits, metrics.supply.contests
		])
	if _g("pacing"):
		print("── Pacing ──────────────────────────────────")
		print("  First shot/contact/damage: %.1fs / %.1fs / %.1fs" % [
			float(metrics.pacing.first_shot_time),
			float(metrics.pacing.first_contact_time),
			float(metrics.pacing.first_damage_time),
		])
		print("  First acquisition: %s/%s/%s at %.1fs dist %.1fm" % [
			metrics.pacing.first_target_acquisition_source,
			metrics.pacing.first_target_acquisition_target_kind,
			metrics.pacing.first_target_acquisition_state,
			float(metrics.pacing.first_target_acquisition_time),
			float(metrics.pacing.first_target_acquisition_distance),
		])
		print("  First upgrade: %s from %s at %.1fs" % [
			metrics.pacing.first_non_pistol_upgrade_weapon,
			metrics.pacing.first_non_pistol_upgrade_source,
			float(metrics.pacing.first_non_pistol_upgrade_time),
		])
		print("  First upgrade context: poi=%s/%s route=%s/%s nearest=%s/%s" % [
			metrics.pacing.first_non_pistol_upgrade_poi_role,
			metrics.pacing.first_non_pistol_upgrade_poi_band,
			metrics.pacing.first_non_pistol_upgrade_route_role,
			metrics.pacing.first_non_pistol_upgrade_route_band,
			metrics.pacing.first_non_pistol_upgrade_nearest_poi_role,
			metrics.pacing.first_non_pistol_upgrade_nearest_route_role,
		])
		print("  Stage times: %s" % str(metrics.pacing.stage_times))
	if _g("spawn") and int(metrics.spawn.placed_count) > 0:
		print("── Spawn ───────────────────────────────────")
		print("  Placed:         %d/%d  fallback: %d" % [
			int(metrics.spawn.placed_count),
			int(metrics.spawn.requested_count),
			int(metrics.spawn.fallback_count),
		])
		print("  Nearest:        min %.1fm  avg %.1fm" % [
			float(metrics.spawn.min_nearest_distance),
			float(metrics.spawn.avg_nearest_distance),
		])
		print("  Attempts:       avg %.1f  max %d  saturation %.2f" % [
			float(metrics.spawn.avg_attempts),
			int(metrics.spawn.attempt_max),
			float(metrics.spawn.annulus_saturation),
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
		"ar", "assault rifle", "assault_rifle", "돌격소총", "노후 돌격소총", "소총": return "ar"
		"shotgun", "샷건", "낡은 산탄총": return "shotgun"
		"railgun", "rail gun", "레일건": return "railgun"
		"knife", "melee", "칼": return "knife"
		_: return n

func _ensure_combat_weapon(w: String):
	if not metrics.combat.kills_by_weapon.has(w):
		metrics.combat.kills_by_weapon[w] = 0
	if not metrics.combat.damage_by_weapon.has(w):
		metrics.combat.damage_by_weapon[w] = 0.0

func _elapsed_seconds() -> float:
	var main = get_tree().root.get_node_or_null("Main")
	if main != null:
		return maxf(0.0, float(main.match_timer))
	# Script-only verifiers do not instantiate Main.
	return (Time.get_ticks_msec() - _start_tick) / 1000.0 * Engine.time_scale

func _record_first_pacing_time(metric_name: String):
	if not _g("pacing") or not metrics.has("pacing"):
		return
	if not metrics.pacing.has(metric_name):
		return
	if float(metrics.pacing.get(metric_name, -1.0)) < 0.0:
		metrics.pacing[metric_name] = _elapsed_seconds()

func _record_first_upgrade_context(context: Dictionary):
	if context.is_empty():
		return
	if not metrics.has("economy"):
		return
	var poi_band := _poi_distance_band(context)
	var route_band := _route_distance_band(context)
	var poi_role := String(context.get("poi_role", "open"))
	var route_role := String(context.get("route_role", "off_route"))
	var nearest_poi_role := String(context.get("nearest_poi_role", "none"))
	var nearest_route_role := _nearest_route_role_key(context, route_band)
	var source := String(context.get("source", "unknown"))
	if _g("economy") and String(metrics.economy.get("first_upgrade_poi_role", "none")) == "none":
		metrics.economy.first_upgrade_source = source
		metrics.economy.first_upgrade_poi_role = poi_role
		metrics.economy.first_upgrade_poi_band = poi_band
		metrics.economy.first_upgrade_route_role = route_role
		metrics.economy.first_upgrade_route_band = route_band
		metrics.economy.first_upgrade_nearest_poi_role = nearest_poi_role
		metrics.economy.first_upgrade_nearest_route_role = nearest_route_role
	if _g("pacing") and metrics.has("pacing") and String(metrics.pacing.get("first_non_pistol_upgrade_poi_role", "none")) == "none":
		metrics.pacing.first_non_pistol_upgrade_source = source
		metrics.pacing.first_non_pistol_upgrade_poi_role = poi_role
		metrics.pacing.first_non_pistol_upgrade_poi_band = poi_band
		metrics.pacing.first_non_pistol_upgrade_route_role = route_role
		metrics.pacing.first_non_pistol_upgrade_route_band = route_band
		metrics.pacing.first_non_pistol_upgrade_nearest_poi_role = nearest_poi_role
		metrics.pacing.first_non_pistol_upgrade_nearest_route_role = nearest_route_role

func _add_bucket_count(bucket: Dictionary, key: String, amount: int = 1):
	var bucket_key = key if key.strip_edges() != "" else "unknown"
	bucket[bucket_key] = int(bucket.get(bucket_key, 0)) + amount

func _add_bucket_value(bucket: Dictionary, key: String, amount: float):
	var bucket_key = key if key.strip_edges() != "" else "unknown"
	bucket[bucket_key] = float(bucket.get(bucket_key, 0.0)) + amount

func _add_nested_bucket_value(bucket: Dictionary, outer_key: String, inner_key: String, amount: float):
	var resolved_outer = outer_key if outer_key.strip_edges() != "" else "unknown"
	if not bucket.has(resolved_outer):
		bucket[resolved_outer] = {}
	var nested: Dictionary = bucket[resolved_outer]
	_add_bucket_value(nested, inner_key, amount)

func _add_sample_bucket(bucket: Dictionary, key: String, value: float):
	var bucket_key = key if key.strip_edges() != "" else "unknown"
	if not bucket.has(bucket_key):
		bucket[bucket_key] = {
			"count": 0,
			"total": 0.0,
			"min": value,
			"max": value,
		}
	var sample = bucket[bucket_key]
	var count = int(sample.get("count", 0))
	sample["count"] = count + 1
	sample["total"] = float(sample.get("total", 0.0)) + value
	sample["min"] = value if count == 0 else minf(float(sample.get("min", value)), value)
	sample["max"] = value if count == 0 else maxf(float(sample.get("max", value)), value)

func _normalized_key(value: String, fallback: String) -> String:
	var key := value.strip_edges().to_lower()
	return fallback if key == "" else key

func _poi_distance_band(context: Dictionary) -> String:
	if bool(context.get("poi_inside", false)):
		return "inside"
	var role = String(context.get("poi_role", "open"))
	if role != "" and role != "open" and role != "none":
		return "inside"
	var edge_distance = float(context.get("nearest_poi_edge_distance", -1.0))
	if edge_distance < 0.0:
		return "unknown"
	if edge_distance <= 4.0:
		return "near_0_4m"
	if edge_distance <= 8.0:
		return "near_4_8m"
	return "far_8m_plus"

func _route_distance_band(context: Dictionary) -> String:
	if bool(context.get("route_on", false)):
		return "on_route"
	var role = String(context.get("route_role", "off_route"))
	if role != "" and role != "off_route" and role != "none":
		return "on_route"
	var edge_distance = float(context.get("nearest_route_edge_distance", -1.0))
	if edge_distance < 0.0:
		return "unknown"
	if edge_distance <= 4.0:
		return "near_0_4m"
	if edge_distance <= 8.0:
		return "near_4_8m"
	return "far_8m_plus"

func _nearest_route_role_key(context: Dictionary, route_band: String) -> String:
	if route_band == "far_8m_plus" or route_band == "unknown":
		return "off_route"
	var role := String(context.get("route_role", "off_route"))
	if role == "" or role == "off_route" or role == "none":
		role = String(context.get("nearest_route_role", "none"))
	if role == "":
		return "none"
	return role
