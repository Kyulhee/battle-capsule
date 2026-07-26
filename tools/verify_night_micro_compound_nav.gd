extends SceneTree


const COMPOUND_PROBES := [
	{
		"id": "brush_camp",
		"poi_name": "Inner Brush North",
		"target_anchor_id": "brush_fire_objective",
		"approach_anchor_ids": {
			"road": "brush_road_entry",
			"forest": "brush_forest_entry",
			"north": "brush_north_outer",
		},
		"runtime_approach_id": "forest",
	},
	{
		"id": "survey_camp",
		"poi_name": "Survey Camp",
		"target_anchor_id": "survey_yard_objective",
		"approach_anchor_ids": {
			"road": "survey_road_entry",
			"forest": "survey_forest_entry",
			"south": "survey_south_outer",
		},
	},
]
const MAX_ENDPOINT_SNAP_DISTANCE := 3.0
const MAX_PATH_DIRECT_RATIO := 2.2
const MAX_ANCHOR_SAMPLE_SNAP_DISTANCE := 0.35
const ANCHOR_JITTER_SAMPLE_COUNT := 12
const ANCHOR_JITTER_RADIUS_FACTORS := [0.35, 0.65, 0.95, 1.0]
const RUNTIME_TIMEOUT_SECONDS := 8.0
const RUNTIME_ARRIVAL_DISTANCE := 3.0
const RUNTIME_MAX_STUCK_RECOVERIES := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		_fail("Could not load Main.tscn.")
		return
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_navigation(main)
	main.start_game()
	await physics_frame
	await physics_frame

	var definition = main.map_definition
	if definition == null:
		await _cleanup(main)
		_fail("Micro-compound probe has no map definition.")
		return
	var bots := get_nodes_in_group("bots")
	var nav_agent = bots[0].get("_nav_agent") if not bots.is_empty() else null
	var map_rid: RID = nav_agent.get_navigation_map() if nav_agent else RID()
	if not map_rid.is_valid():
		await _cleanup(main)
		_fail("Micro-compound probe has no navigation map.")
		return

	var summaries: Array[String] = []
	for probe in COMPOUND_PROBES:
		var compound_id := String(probe["id"])
		var poi := _poi_by_name(definition, String(probe["poi_name"]))
		if poi.is_empty():
			await _cleanup(main)
			_fail("%s POI is missing from the active map definition." % compound_id)
			return
		var target_anchor := _anchor_by_id(poi, String(probe["target_anchor_id"]))
		var target_position := _anchor_position(target_anchor)
		if not target_position.is_finite():
			await _cleanup(main)
			_fail("%s objective anchor is missing or invalid." % compound_id)
			return
		var target := NavigationServer3D.map_get_closest_point(
			map_rid,
			Vector3(target_position.x, 0.0, target_position.y)
		)
		if _flat(target).distance_to(target_position) > MAX_ENDPOINT_SNAP_DISTANCE:
			await _cleanup(main)
			_fail("%s objective is not represented on the NavMesh." % compound_id)
			return
		var target_issue := _anchor_nav_issue(
			map_rid,
			target_position,
			float(target_anchor.get("jitter_radius", 0.0))
		)
		if not target_issue.is_empty():
			await _cleanup(main)
			_fail("%s objective jitter is unsafe: %s." % [compound_id, target_issue])
			return

		var approach_anchor_ids: Dictionary = probe["approach_anchor_ids"]
		for approach_id in approach_anchor_ids:
			var approach_anchor := _anchor_by_id(
				poi,
				String(approach_anchor_ids[approach_id])
			)
			var approach_position := _anchor_position(approach_anchor)
			if not approach_position.is_finite():
				await _cleanup(main)
				_fail("%s %s anchor is missing or invalid." % [
					compound_id,
					approach_id,
				])
				return
			var start := NavigationServer3D.map_get_closest_point(
				map_rid,
				Vector3(approach_position.x, 0.0, approach_position.y)
			)
			if _flat(start).distance_to(approach_position) > MAX_ENDPOINT_SNAP_DISTANCE:
				await _cleanup(main)
				_fail("%s %s approach is not represented on the NavMesh." % [
					compound_id,
					approach_id,
				])
				return
			var approach_issue := _anchor_nav_issue(
				map_rid,
				approach_position,
				float(approach_anchor.get("jitter_radius", 0.0))
			)
			if not approach_issue.is_empty():
				await _cleanup(main)
				_fail("%s %s jitter is unsafe: %s." % [
					compound_id,
					approach_id,
					approach_issue,
				])
				return
			var path: PackedVector3Array = NavigationServer3D.map_get_path(
				map_rid,
				start,
				target,
				true
			)
			if path.size() < 2:
				await _cleanup(main)
				_fail("%s %s approach has no path to the objective." % [
					compound_id,
					approach_id,
				])
				return
			var path_length := _path_length(path)
			var direct_distance := maxf(0.1, start.distance_to(target))
			if path_length > direct_distance * MAX_PATH_DIRECT_RATIO:
				await _cleanup(main)
				_fail("%s %s detour is excessive: %.1fm / %.1fm." % [
					compound_id,
					approach_id,
					path_length,
					direct_distance,
				])
				return
			summaries.append("%s/%s=%.1fm" % [
				compound_id,
				approach_id,
				path_length,
			])

	var brush_probe: Dictionary = COMPOUND_PROBES[0]
	var brush_poi := _poi_by_name(definition, String(brush_probe["poi_name"]))
	var brush_target_anchor := _anchor_by_id(
		brush_poi,
		String(brush_probe["target_anchor_id"])
	)
	var brush_approach_ids: Dictionary = brush_probe["approach_anchor_ids"]
	var runtime_approach_id := String(brush_probe["runtime_approach_id"])
	var brush_runtime_anchor := _anchor_by_id(
		brush_poi,
		String(brush_approach_ids[runtime_approach_id])
	)
	var runtime_check := await _run_brush_west_runtime(
		main,
		map_rid,
		_anchor_position(brush_runtime_anchor),
		_anchor_position(brush_target_anchor)
	)
	if not bool(runtime_check.get("ok", false)):
		await _cleanup(main)
		_fail(String(runtime_check.get("message", "Brush Camp west runtime failed.")))
		return
	summaries.append(String(runtime_check.get("summary", "")))

	await _cleanup(main)
	print("Night micro-compound nav smoke passed: %s." % ", ".join(summaries))
	quit(0)


func _poi_by_name(definition, poi_name: String) -> Dictionary:
	for poi in definition.get_poi_descriptors():
		if String(poi.get("name", "")) == poi_name:
			return poi
	return {}


func _anchor_by_id(poi: Dictionary, anchor_id: String) -> Dictionary:
	for anchor in poi.get("strategic_anchors", []):
		if anchor is Dictionary and String(anchor.get("id", "")) == anchor_id:
			return anchor
	return {}


func _anchor_position(anchor: Dictionary) -> Vector2:
	var raw_position = anchor.get("pos", [])
	if raw_position is Array and raw_position.size() >= 2:
		return Vector2(float(raw_position[0]), float(raw_position[1]))
	return Vector2.INF


func _anchor_nav_issue(map_rid: RID, center: Vector2, jitter_radius: float) -> String:
	var samples: Array[Vector2] = [center]
	var sample_labels: Array[String] = ["center"]
	for radius_factor in ANCHOR_JITTER_RADIUS_FACTORS:
		for angle_index in range(ANCHOR_JITTER_SAMPLE_COUNT):
			var angle := TAU * float(angle_index) / float(ANCHOR_JITTER_SAMPLE_COUNT)
			samples.append(
				center
				+ Vector2.from_angle(angle) * jitter_radius * float(radius_factor)
			)
			sample_labels.append("%d%%/%d" % [
				roundi(float(radius_factor) * 100.0),
				angle_index,
			])
	for sample_index in range(samples.size()):
		var sample := samples[sample_index]
		var closest := NavigationServer3D.map_get_closest_point(
			map_rid,
			Vector3(sample.x, 0.0, sample.y)
		)
		var snap_distance := _flat(closest).distance_to(sample)
		if snap_distance > MAX_ANCHOR_SAMPLE_SNAP_DISTANCE:
			return "sample %s snaps %.2fm from (%.1f,%.1f)" % [
				sample_labels[sample_index],
				snap_distance,
				sample.x,
				sample.y,
			]
	return ""


func _run_brush_west_runtime(
	main: Node,
	map_rid: RID,
	start_position: Vector2,
	target_position: Vector2
) -> Dictionary:
	var player = main.player_ref
	var bots := get_nodes_in_group("bots")
	if not is_instance_valid(player) or bots.size() != 1:
		return {
			"ok": false,
			"message": "Brush Camp west runtime needs one player and one bot.",
		}
	var bot = bots[0]
	if not is_instance_valid(bot):
		return {
			"ok": false,
			"message": "Brush Camp west runtime bot is invalid.",
		}
	var start := NavigationServer3D.map_get_closest_point(
		map_rid,
		Vector3(start_position.x, 0.0, start_position.y)
	)
	var target := NavigationServer3D.map_get_closest_point(
		map_rid,
		Vector3(target_position.x, 0.0, target_position.y)
	)

	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector3(target.x, player.global_position.y, target.z)
	bot.global_position = Vector3(start.x, bot.global_position.y, start.z)
	bot.velocity = Vector3.ZERO
	bot.stats.attack_range = 1.0
	bot.stats.current_ammo = maxi(1, int(bot.stats.current_ammo))
	bot.target_actor = player
	bot.is_targeting_loot = false
	bot.change_state(bot.State.CHASE)
	await physics_frame
	await physics_frame
	if not is_instance_valid(bot) or not is_instance_valid(player):
		return {
			"ok": false,
			"message": "Brush Camp west runtime actor disappeared during setup.",
		}

	var telemetry = root.get_node_or_null("Telemetry")
	var initial_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else 0
	var minimum_distance := _flat(bot.global_position).distance_to(_flat(player.global_position))
	var elapsed := 0.0
	while elapsed < RUNTIME_TIMEOUT_SECONDS \
			and is_instance_valid(bot) \
			and is_instance_valid(player):
		await create_timer(0.05).timeout
		elapsed += 0.05
		if not is_instance_valid(bot) or not is_instance_valid(player):
			return {
				"ok": false,
				"message": "Brush Camp west runtime actor disappeared at %.2fs." % elapsed,
			}
		minimum_distance = minf(
			minimum_distance,
			_flat(bot.global_position).distance_to(_flat(player.global_position))
		)
		if minimum_distance <= RUNTIME_ARRIVAL_DISTANCE:
			break
		_force_chase(bot, player)

	if not is_instance_valid(bot) or not is_instance_valid(player):
		return {
			"ok": false,
			"message": "Brush Camp west runtime actor disappeared before reporting.",
		}
	var final_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else initial_stuck
	var stuck_delta := final_stuck - initial_stuck
	var stuck_cells: Dictionary = telemetry.metrics.tactics.stuck_by_cell.duplicate() if telemetry else {}
	if minimum_distance > RUNTIME_ARRIVAL_DISTANCE:
		return {
			"ok": false,
			"message": "Brush Camp west runtime did not arrive: min=%.2fm stuck=%d cells=%s %s." % [
				minimum_distance,
				stuck_delta,
				stuck_cells,
				_runtime_snapshot(bot),
			],
		}
	if stuck_delta > RUNTIME_MAX_STUCK_RECOVERIES:
		return {
			"ok": false,
			"message": "Brush Camp west runtime exceeded stuck budget: stuck=%d cells=%s %s." % [
				stuck_delta,
				stuck_cells,
				_runtime_snapshot(bot),
			],
		}
	return {
		"ok": true,
		"summary": "brush_camp/west_runtime=%.2fs stuck=%d" % [elapsed, stuck_delta],
	}


func _force_chase(bot, player) -> void:
	bot.target_actor = player
	bot.is_targeting_loot = false
	if bot.current_state != bot.State.CHASE:
		bot.change_state(bot.State.CHASE)


func _runtime_snapshot(bot) -> String:
	if not is_instance_valid(bot):
		return "bot=invalid"
	var nav_agent = bot.get("_nav_agent")
	var path: PackedVector3Array = (
		nav_agent.get_current_navigation_path()
		if nav_agent
		else PackedVector3Array()
	)
	var path_index := int(nav_agent.get_current_navigation_path_index()) if nav_agent else -1
	return "pos=(%.1f,%.1f) state=%s path=%d/%d slides=%d" % [
		bot.global_position.x,
		bot.global_position.z,
		String(bot.State.keys()[bot.current_state]),
		path_index,
		path.size(),
		bot.get_slide_collision_count(),
	]


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func _flat(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _wait_for_navigation(main: Node) -> void:
	var nav_region = main.get("_nav_region")
	if nav_region != null and nav_region.has_method("is_baking") and nav_region.is_baking():
		await nav_region.bake_finished
	await physics_frame
	await physics_frame


func _cleanup(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
