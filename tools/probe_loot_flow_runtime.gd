extends SceneTree

# 제품 동작에 진단 CLI를 추가하지 않고 동일한 Main으로 대조/후보를 실행한다.
const AUDIT = preload("res://tools/LootFlowAudit.gd")
const CHECKPOINTS := [0.0, 120.0, 260.0]
const CANDIDATE_POIS := ["Central Meadow", "Survey Camp"]
var main
var report := {"schema_version": 2, "complete": false, "snapshots": []}
var report_path := ""
var result_path := ""
var checkpoint_index := 0
var initial_only := false
var failed := false

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
		elif arg == "autostart=true":
			_fail("Use this probe's controlled start, not autostart=true.")
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
	Engine.time_scale = 5.0
	main.start_game()
	report["candidate"] = candidate
	report["map"] = main.map_spec_path
	report["preset"] = main.map_scale_preset
	report["seed"] = main.simulation_seed
	report["initial_only"] = initial_only
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
		report["complete"] = true
		report["end_time"] = main.match_timer
		report["checkpoints_not_reached"] = CHECKPOINTS.slice(checkpoint_index)
		_save()
		return
	if checkpoint_index < CHECKPOINTS.size() and main.match_timer >= CHECKPOINTS[checkpoint_index]:
		_snapshot(CHECKPOINTS[checkpoint_index])
		checkpoint_index += 1

func _snapshot(requested_time: float) -> void:
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
	snapshot["actors"] = actors
	snapshot["occupancy"] = occupancy
	snapshot["needs"] = needs
	if actors.size() != main.alive_count:
		_fail("Bot snapshot population differs from simulation alive count.")
		return
	report["snapshots"].append(snapshot)
	_save()
	print("LOOT_FLOW t=%.2f alive=%d packs=%d needs=%s" % [main.match_timer, main.alive_count, snapshot["totals"]["ammo_packs"], JSON.stringify(needs)])

func _save() -> void:
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
