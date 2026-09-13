extends SceneTree

# 제품 동작에 진단 CLI를 추가하지 않고 동일한 Main으로 대조/후보를 실행한다.
const AUDIT = preload("res://tools/LootFlowAudit.gd")
const CHECKPOINTS := [0.0, 120.0, 260.0]
const CANDIDATE_POIS := ["Central Meadow", "Survey Camp"]
var main
var report := {"schema_version": 3, "complete": false, "snapshots": []}
var report_path := ""
var result_path := ""
var checkpoint_index := 0
var initial_only := false
var failed := false
var trace_progress := false
var next_progress_time := 1.0
var progress_window_only := false
var loot_progress_candidate := false
var recovery_patrol_candidate := false
var trace_ai_phases := false
var ai_audit = null
var trace_loot_phase := false
var phase_window_only := false
var phase_sampled := false
var trace_loot_search := false
var search_window_only := false
var search_audit = null

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var candidate := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("flow_output="):
			report_path = arg.trim_prefix("flow_output=")
		elif arg.begins_with("result_output="):
			result_path = arg.trim_prefix("result_output=")
		elif arg == "loot_match_candidate=true":
			candidate = true
		elif arg == "initial_only=true":
			initial_only = true
		elif arg == "trace_progress=true":
			trace_progress = true
		elif arg == "progress_window_only=true":
			progress_window_only = true
		elif arg == "loot_progress_candidate=true":
			loot_progress_candidate = true
		elif arg == "recovery_patrol_candidate=true":
			recovery_patrol_candidate = true
		elif arg == "trace_ai_phases=true":
			trace_ai_phases = true
		elif arg == "trace_loot_phase=true":
			trace_loot_phase = true
		elif arg == "phase_window_only=true":
			phase_window_only = true
		elif arg == "trace_loot_search=true":
			trace_loot_search = true
		elif arg == "search_window_only=true":
			search_window_only = true
		elif arg == "autostart=true":
			_fail("Use this probe's controlled start, not autostart=true.")
			return
	if progress_window_only and (not trace_progress or initial_only):
		_fail("progress_window_only requires trace_progress and excludes initial_only.")
		return
	if phase_window_only and (not trace_loot_phase or initial_only or trace_progress or trace_ai_phases):
		_fail("phase_window_only requires trace_loot_phase and excludes initial/progress/AI tracing.")
		return
	if trace_loot_phase and (trace_progress or trace_ai_phases):
		_fail("Keep loot phase stock observations separate from progress/AI tracing.")
		return
	if search_window_only and (not trace_loot_search or initial_only):
		_fail("search_window_only requires trace_loot_search and excludes initial_only.")
		return
	if trace_loot_search and (trace_progress or trace_ai_phases or trace_loot_phase):
		_fail("Keep loot search diagnostics separate from progress/AI/phase tracing.")
		return
	if candidate and loot_progress_candidate:
		_fail("Do not mix E-068 ammo pairing and E-071 chase progress candidates.")
		return
	if recovery_patrol_candidate and (candidate or loot_progress_candidate or trace_progress or trace_ai_phases or trace_loot_phase or trace_loot_search):
		_fail("Keep E-078 patrol candidate separate from E-068/E-071 and diagnostics.")
		return
	if report_path.is_empty() or result_path.is_empty() or report_path == result_path \
			or FileAccess.file_exists(report_path) or FileAccess.file_exists(result_path):
		_fail("Provide distinct new flow_output and result_output paths.")
		return
	for path in [report_path, result_path]:
		if not path.is_absolute_path() or path.begins_with("user://") \
				or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
			_fail("Probe outputs must be writable absolute filesystem paths, not user://.")
			return
	root.get_node("Telemetry").sim_result_path = result_path
	main = load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if main._nav_region.is_baking():
		await main._nav_region.bake_finished
	if main.map_scale_preset != "night_br_m1_60" or main.bot_count != 60:
		_fail("Loot flow probe requires the 60-bot M1 preset.")
		return
	var touched: Array[String] = []
	for hotspot in main.loot_hotspots:
		var context: Dictionary = main.map_definition.describe_strategic_position(hotspot["pos"])
		var poi_name := String(context["nearest_poi_name"])
		if poi_name in CANDIDATE_POIS:
			hotspot["initial_ammo_match"] = candidate
			touched.append(poi_name)
	if touched.size() != CANDIDATE_POIS.size():
		_fail("Candidate POI scope no longer matches the map.")
		return
	main.is_simulation = true
	# 고밀도 초기 구간의 5배 가속은 process 관측을 0.5초 이상 늦출 수 있다.
	# 정밀 진행 창만 실시간으로 읽으며 전체 pacing 실행과 섞지 않는다.
	Engine.time_scale = 1.0 if progress_window_only or phase_window_only or search_window_only else 5.0
	main.start_game()
	# 비활성 진단은 Resource/RefCounted ID도 소비하지 않는다.
	# 봇 생성 뒤에만 로드해 초기 ID 기반 엄폐/조향 선택을 보존한다.
	if trace_ai_phases:
		ai_audit = load("res://tools/AiPhaseAudit.gd").new()
	if trace_loot_search:
		search_audit = load("res://tools/LootSearchAudit.gd").new()
	for bot in get_nodes_in_group("bots"):
		bot._loot_progress_timeout_enabled = loot_progress_candidate
		bot._recovery_loot_patrol_enabled = recovery_patrol_candidate
		if trace_ai_phases:
			bot._ai_phase_trace_sink = Callable(self, "_record_ai_phase")
		if trace_loot_search:
			bot._loot_search_trace_sink = Callable(self, "_record_loot_search")
	report["candidate"] = candidate
	report["loot_progress_candidate"] = loot_progress_candidate
	report["recovery_patrol_candidate"] = recovery_patrol_candidate
	if recovery_patrol_candidate: report["recovery_patrol_observations"] = []
	report["map"] = main.map_spec_path
	report["preset"] = main.map_scale_preset
	report["seed"] = main.simulation_seed
	report["initial_only"] = initial_only
	report["progress_enabled"] = trace_progress
	report["progress_window_only"] = progress_window_only
	report["time_scale"] = Engine.time_scale
	report["ai_phase_trace_enabled"] = trace_ai_phases
	report["ai_phase_audit_created"] = ai_audit != null
	report["ai_phase_audit_loaded"] = ResourceLoader.has_cached("res://tools/AiPhaseAudit.gd")
	report["loot_phase_enabled"] = trace_loot_phase
	report["phase_window_only"] = phase_window_only
	report["loot_search_enabled"] = trace_loot_search
	report["search_window_only"] = search_window_only
	report["search_audit_created"] = search_audit != null
	report["search_audit_loaded"] = ResourceLoader.has_cached("res://tools/LootSearchAudit.gd")
	if trace_loot_search:
		report["search_until"] = 260.0
	if trace_loot_phase:
		report["phase_snapshots"] = []
	if trace_progress:
		report["progress_interval"] = 1.0
		report["progress_until"] = 260.0
		report["progress"] = []
		_sample_progress(0.0)
	report["scope"] = "bot-only; checkpoint stock/positions, not player scarcity duration or path-length; POI containment, open otherwise"
	_snapshot(0.0)
	if failed:
		return
	checkpoint_index = 1
	if initial_only:
		report["complete"] = true
		_save()
		if failed:
			return
		main.queue_free()
		quit(0)
		return
	process_frame.connect(_on_frame)
	create_timer(600.0, true, false, true).timeout.connect(func(): _fail("Loot flow probe exceeded wall-clock budget."))

func _on_frame() -> void:
	if failed or not is_instance_valid(main) or report["complete"]:
		return
	if main.game_over:
		if search_window_only:
			_fail("Match ended before the search diagnostic window completed.")
			return
		if phase_window_only and not phase_sampled:
			_fail("Match ended before the requested loot phase observation.")
			return
		report["complete"] = true
		report["end_time"] = main.match_timer
		report["checkpoints_not_reached"] = CHECKPOINTS.slice(checkpoint_index)
		_save()
		return
	if checkpoint_index < CHECKPOINTS.size() and main.match_timer >= CHECKPOINTS[checkpoint_index]:
		_snapshot(CHECKPOINTS[checkpoint_index])
		checkpoint_index += 1
	if search_window_only and main.match_timer >= 260.0:
		report["complete"] = true
		report["end_time"] = main.match_timer
		report["checkpoints_not_reached"] = CHECKPOINTS.slice(checkpoint_index)
		_save()
		if not failed:
			main.queue_free()
			quit(0)
		return
	if trace_loot_phase and not phase_sampled:
		_sample_loot_phase()
		if failed:
			return
	if phase_window_only and phase_sampled:
		report["complete"] = true
		report["end_time"] = main.match_timer
		report["checkpoints_not_reached"] = CHECKPOINTS.slice(checkpoint_index)
		_save()
		if not failed:
			main.queue_free()
			quit(0)
		return
	if trace_progress and next_progress_time <= 260.0 and main.match_timer >= next_progress_time:
		_sample_progress(next_progress_time)
		if failed:
			return
		# 누락된 시점을 같은 현재 상태로 채우지 않는다. 지연은 observed_time에 남긴다.
		next_progress_time = floorf(main.match_timer) + 1.0
	if progress_window_only and next_progress_time > 260.0:
		report["complete"] = true
		report["end_time"] = main.match_timer
		report["checkpoints_not_reached"] = CHECKPOINTS.slice(checkpoint_index)
		_save()
		if not failed:
			main.queue_free()
			quit(0)

func _sample_progress(requested_time: float) -> void:
	var actors: Array = []
	for bot in get_nodes_in_group("bots"):
		if not is_instance_valid(bot) or bot.is_dead:
			continue
		var target = bot.target_actor
		var target_valid: bool = is_instance_valid(target) and not target.is_queued_for_deletion()
		var cached = bot._cached_pickup
		var cached_valid: bool = is_instance_valid(cached) and not cached.is_queued_for_deletion()
		var destination: Dictionary = bot._strategic_destination
		var strategy_target: Vector2 = destination.get("target", Vector2.INF)
		# 상태/캐시/이동 의도만 읽는다. 탐색, 지각, navigation 진행 함수는 호출하지 않는다.
		actors.append({
			"id": bot.get_instance_id(), "position": _xz(bot.global_position),
			"family": bot.stats.weapon_type, "loaded": bot.stats.current_ammo,
			"reserve": bot.reserve_ammo, "state": bot.State.keys()[bot.current_state],
			"episode": bot._state_episode_id, "state_timer": bot.state_timer,
			"recovery_substate": bot.recovery_substate, "recovery_timer": bot.recovery_timer,
			"targeting_loot": bot.is_targeting_loot, "recovering": bot._recovering,
			"loot_source": bot._loot_objective_source, "loot_kind": bot._loot_objective_kind,
			"target_id": target.get_instance_id() if target_valid else null,
			"target_position": _xz(target.global_position) if target_valid else null,
			"cached_pickup_id": cached.get_instance_id() if cached_valid else null,
			"pickup_search_timer": bot._pickup_search_timer,
			"cached_search_radius": bot._cached_pickup_radius,
			"vision_range": bot.stats.vision_range, "near_range": bot.stats.fov_near_range,
			"fov_angle": bot.stats.fov_angle, "yaw": bot.rotation.y,
			"health_ratio": bot.current_health / maxf(1.0, bot.stats.max_health),
			"destination": destination.get("name", "none"),
			"strategy_target": [strategy_target.x, strategy_target.y] if strategy_target.is_finite() else null,
			"planning_mode": destination.get("planning_mode", "none"),
			"holding_preposition_geometry": bot._is_holding_strategic_preposition(main),
			"nav_target": _xz(bot._nav_target_position) if bot._has_nav_target else null,
			"patrol_target": _xz(bot.patrol_target) if bot.current_state == bot.State.RECOVER \
				and bot.recovery_substate == "patrol" else null,
		})
	if actors.size() != main.alive_count:
		_fail("Progress population differs from simulation alive count.")
		return
	report["progress"].append({"requested_time": requested_time,
		"observed_time": main.match_timer, "alive": main.alive_count, "actors": actors})

func _xz(pos: Vector3) -> Array:
	return [pos.x, pos.z]

func _sample_loot_phase() -> void:
	# Main의 단계 전환/보급 생성 콜백이 끝난 후의 canonical game-time을 기준으로 읽는다.
	var stages: Dictionary = root.get_node("Telemetry").metrics["pacing"]["stage_times"]
	if not stages.has("2"):
		return
	var stage_started := float(stages["2"])
	if main.match_timer < stage_started + 1.0:
		return
	if main.zone.stage != 2 or main.zone.shrinking:
		_fail("Requested stage2 post-wave phase was missed; do not substitute another phase.")
		return
	_snapshot(stage_started + 1.0, stage_started)
	phase_sampled = not failed

func _snapshot(requested_time: float, phase_anchor: float = -1.0) -> void:
	if recovery_patrol_candidate:
		var survivor_selections := 0
		var selected_survivors := 0
		for bot in get_nodes_in_group("bots"):
			if not is_instance_valid(bot) or bot.is_dead: continue
			survivor_selections += bot._recovery_loot_patrol_selections
			selected_survivors += int(bot._recovery_loot_patrol_selections > 0)
		report["recovery_patrol_observations"].append({"requested_time": requested_time,
			"observed_time": main.match_timer, "survivor_selections": survivor_selections,
			"selected_survivors": selected_survivors})
	var records: Array = []
	for pickup in get_nodes_in_group("pickups"):
		if not is_instance_valid(pickup) or pickup.is_queued_for_deletion() or pickup.item == null:
			continue
		var item: ItemData = pickup.item
		var pos := Vector2(pickup.global_position.x, pickup.global_position.z)
		var context: Dictionary = main.map_definition.describe_strategic_position(pos)
		records.append({
			"poi": context["poi_name"], "kind": ItemData.Type.keys()[item.type].to_lower(),
			"family": item.weapon_stats.weapon_type if item.type == ItemData.Type.WEAPON \
				else item.ammo_weapon_type if item.type == ItemData.Type.AMMO else "",
			"amount": item.amount, "name": item.item_name, "source": pickup._spawn_source,
			"position": [pos.x, pos.y],
		})
	var snapshot: Dictionary = AUDIT.summarize(records)
	snapshot["records"] = records
	snapshot["requested_time"] = requested_time
	snapshot["observed_time"] = main.match_timer
	snapshot["alive"] = main.alive_count
	snapshot["zone_stage"] = main.zone.stage
	snapshot["zone_shrinking"] = main.zone.shrinking
	snapshot["zone"] = {
		"center": [main.zone.current_center.x, main.zone.current_center.y],
		"radius": main.zone.current_radius,
		"next_center": [main.zone.next_center.x, main.zone.next_center.y],
		"next_radius": main.zone.next_radius, "timer": main.zone.timer,
	}
	var actors: Array = []
	var occupancy := {}
	var needs := {"no_long_gun": 0, "no_ammo": 0, "low_loaded_no_reserve": 0}
	for bot in get_nodes_in_group("bots"):
		if not is_instance_valid(bot) or bot.is_dead:
			continue
		var pos := Vector2(bot.global_position.x, bot.global_position.z)
		var context: Dictionary = main.map_definition.describe_strategic_position(pos)
		var family := String(bot.stats.weapon_type)
		var no_ammo: bool = bot.stats.current_ammo <= 0 and bot.reserve_ammo <= 0
		var low_ammo: bool = bot.reserve_ammo <= 0 and bot.stats.max_ammo > 0 \
			and bot.stats.current_ammo <= bot.stats.max_ammo * 0.25
		needs["no_long_gun"] += int(family in ["", "knife", "pistol"])
		needs["no_ammo"] += int(no_ammo)
		needs["low_loaded_no_reserve"] += int(low_ammo)
		var poi_name := String(context["poi_name"])
		occupancy[poi_name] = int(occupancy.get(poi_name, 0)) + 1
		var destination: Dictionary = bot._strategic_destination
		var strategy_target: Vector2 = destination.get("target", Vector2.INF)
		var nearest_ammo_distance := INF
		for record in records:
			if record["kind"] == "ammo" and record["family"] == family and record["amount"] > 0:
				var ammo_pos := Vector2(record["position"][0], record["position"][1])
				nearest_ammo_distance = minf(nearest_ammo_distance, pos.distance_to(ammo_pos))
		# 이미 존재하는 계획/위치를 읽기만 한다. 탐색·LOS·nav query나 AI 갱신은 호출하지 않는다.
		# geometry=true도 실제 idle 분기 실행의 증거는 아니다(적 감지/사후 탐색이 우선).
		actors.append({
			"id": bot.get_instance_id(), "poi": poi_name, "position": [pos.x, pos.y],
			"family": family, "loaded": bot.stats.current_ammo, "reserve": bot.reserve_ammo,
			"state": bot.current_state, "destination": destination.get("name", "none"),
			"planning_mode": destination.get("planning_mode", "none"),
			"planned_zone_stage": destination.get("planned_zone_stage", -1),
			"strategy_target_distance": pos.distance_to(strategy_target) if strategy_target.is_finite() else null,
			"holding_preposition_geometry": bot._is_holding_strategic_preposition(main),
			"health_ratio": bot.current_health / maxf(1.0, bot.stats.max_health),
			"post_kill_scan_active": bot._post_kill_scan_timer > 0.0,
			"outside_current_zone": pos.distance_to(main.zone.current_center) > main.zone.current_radius,
			"outside_next_zone": pos.distance_to(main.zone.next_center) > main.zone.next_radius,
			"nearest_compatible_ammo_distance": nearest_ammo_distance if is_finite(nearest_ammo_distance) else null,
		})
		if phase_anchor >= 0.0:
			actors[-1].merge({"state_name": bot.State.keys()[bot.current_state],
				"recovery_substate": bot.recovery_substate, "recovery_timer": bot.recovery_timer,
				"pickup_search_timer": bot._pickup_search_timer,
				"cached_search_radius": bot._cached_pickup_radius})
	snapshot["actors"] = actors
	snapshot["occupancy"] = occupancy
	snapshot["needs"] = needs
	if actors.size() != main.alive_count:
		_fail("Bot snapshot population differs from simulation alive count.")
		return
	if phase_anchor >= 0.0:
		snapshot["phase_key"] = "stage2_post_wave_1s"
		snapshot["phase_anchor_time"] = phase_anchor
		snapshot["phase_offset_seconds"] = 1.0
		report["phase_snapshots"].append(snapshot)
	else:
		report["snapshots"].append(snapshot)
	_save()
	print("LOOT_FLOW t=%.2f alive=%d packs=%d needs=%s" % [main.match_timer, main.alive_count, snapshot["totals"]["ammo_packs"], JSON.stringify(needs)])

func _record_ai_phase(sample: Dictionary) -> void:
	if failed or main.game_over:
		return
	ai_audit.record(sample, main.match_timer)
	if not ai_audit.report["valid"]:
		_fail("AI phase timing identity failed.")

func _record_loot_search(sample: Dictionary) -> void:
	if failed or main.game_over or main.match_timer > 260.0:
		return
	search_audit.record(sample, main.match_timer)
	if not search_audit.report["valid"]:
		_fail("Loot search filter accounting failed.")

func _save() -> void:
	if trace_loot_search:
		report["loot_search"] = search_audit.report
	if trace_loot_phase:
		report["phase_stage_times"] = root.get_node("Telemetry").metrics["pacing"]["stage_times"].duplicate()
	if trace_ai_phases:
		report["ai_phase_trace"] = ai_audit.report
		var metrics: Dictionary = root.get_node("Telemetry").metrics["ai"]
		report["ai_phase_trace"]["telemetry_samples"] = metrics["update_samples"]
		report["ai_phase_trace"]["telemetry_max_usec"] = metrics["update_max_usec"]
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write loot flow report.")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()

func _fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)
