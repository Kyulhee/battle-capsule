extends SceneTree


const EXPECTED_BOTS := 4
const PROBE_TIMEOUT_SECONDS := 12.0
const ARRIVAL_DISTANCE := {
	"open_traffic_4": 4.5,
	"wall_traffic_4": 5.0,
}
const MAX_ELAPSED_SECONDS := {
	"open_traffic_4": 5.5,
	"wall_traffic_4": 12.0,
}
const MAX_STUCK_RECOVERIES := {
	"open_traffic_4": 0,
	"wall_traffic_4": 4,
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var preset := _argument_value("scale_preset")
	if not MAX_STUCK_RECOVERIES.has(preset) or not ARRIVAL_DISTANCE.has(preset):
		_fail("Traffic runtime needs a supported scale_preset.")
		return
	var arrival_distance := float(ARRIVAL_DISTANCE[preset])
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		_fail("Could not load Main.tscn.")
		return
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_navigation(main)
	if not _verify_navigation_mesh(main):
		await _cleanup(main)
		return
	main.start_game()

	var player: Entity = main.player_ref
	var bots := get_nodes_in_group("bots")
	if not is_instance_valid(player) or bots.size() != EXPECTED_BOTS:
		await _cleanup(main)
		_fail("Traffic runtime must spawn one player and four bots.")
		return
	player.set_process(false)
	player.set_physics_process(false)

	var minimum_distances := {}
	for bot in bots:
		minimum_distances[bot.get_instance_id()] = bot.global_position.distance_to(player.global_position)
		bot.stats.attack_range = 0.5
		bot.stats.current_ammo = max(1, bot.stats.current_ammo)
		_force_chase(bot, player)

	var telemetry = root.get_node_or_null("Telemetry")
	var initial_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else 0
	var observed_stuck := initial_stuck
	var stuck_snapshots: Array[String] = []
	var elapsed := 0.0
	var all_arrived := false
	while elapsed < PROBE_TIMEOUT_SECONDS and is_instance_valid(player):
		await create_timer(0.05).timeout
		elapsed += 0.05
		var current_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else observed_stuck
		if current_stuck > observed_stuck:
			stuck_snapshots.append("t=%.2f %s" % [elapsed, _traffic_snapshot(bots)])
			observed_stuck = current_stuck
		all_arrived = true
		for bot in bots:
			if not is_instance_valid(bot):
				all_arrived = false
				continue
			var bot_id := bot.get_instance_id()
			var distance: float = float(bot.global_position.distance_to(player.global_position))
			minimum_distances[bot_id] = minf(float(minimum_distances[bot_id]), distance)
			if float(minimum_distances[bot_id]) > arrival_distance:
				all_arrived = false
				_force_chase(bot, player)
		if all_arrived:
			break

	var final_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else 0
	var stuck_delta := final_stuck - initial_stuck
	var stuck_cells: Dictionary = telemetry.metrics.tactics.stuck_by_cell.duplicate() if telemetry else {}
	var worst_minimum := 0.0
	for distance in minimum_distances.values():
		worst_minimum = maxf(worst_minimum, float(distance))
	var details: Array[String] = []
	for bot in bots:
		var nav_agent = bot.get("_nav_agent")
		var path_points: int = int(nav_agent.get_current_navigation_path().size()) if nav_agent else 0
		details.append("(%.1f,%.1f) %s min=%.1f path=%d" % [
			bot.global_position.x,
			bot.global_position.z,
			String(bot.State.keys()[bot.current_state]),
			float(minimum_distances.get(bot.get_instance_id(), INF)),
			path_points,
		])
	await _cleanup(main)
	if not all_arrived:
		_fail("%s traffic did not clear: worst_min=%.2fm stuck=%d cells=%s bots=%s." % [
			preset,
			worst_minimum,
			stuck_delta,
			stuck_cells,
			"; ".join(details),
		])
		return
	if elapsed > float(MAX_ELAPSED_SECONDS[preset]):
		_fail("%s traffic exceeded time budget: elapsed=%.2fs stuck=%d cells=%s snapshots=%s." % [
			preset,
			elapsed,
			stuck_delta,
			stuck_cells,
			stuck_snapshots,
		])
		return
	if stuck_delta > int(MAX_STUCK_RECOVERIES[preset]):
		_fail("%s traffic exceeded stuck budget: stuck=%d." % [preset, stuck_delta])
		return
	print("AI arena traffic smoke passed: preset=%s elapsed=%.2fs worst_min=%.2fm stuck=%d cells=%s." % [
		preset,
		elapsed,
		worst_minimum,
		stuck_delta,
		stuck_cells,
	])
	quit(0)


func _force_chase(bot, player: Entity) -> void:
	bot.target_actor = player
	bot.is_targeting_loot = false
	if bot.current_state != bot.State.CHASE:
		bot.change_state(bot.State.CHASE)


func _argument_value(key: String) -> String:
	var prefix := key + "="
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _traffic_snapshot(bots: Array) -> String:
	var parts: Array[String] = []
	for bot in bots:
		if not is_instance_valid(bot):
			continue
		var velocity: Vector3 = bot.velocity
		var nav_agent = bot.get("_nav_agent")
		var path: PackedVector3Array = nav_agent.get_current_navigation_path() if nav_agent else PackedVector3Array()
		var path_index := int(nav_agent.get_current_navigation_path_index()) if nav_agent else -1
		var next_point := path[path_index] if path_index >= 0 and path_index < path.size() else Vector3.INF
		parts.append("id=%d pos=(%.1f,%.1f) vel=(%.1f,%.1f) state=%s path=%d/%d next=(%.1f,%.1f) slides=%d" % [
			bot.get_instance_id(),
			bot.global_position.x,
			bot.global_position.z,
			velocity.x,
			velocity.z,
			String(bot.State.keys()[bot.current_state]),
			path_index,
			path.size(),
			next_point.x,
			next_point.z,
			bot.get_slide_collision_count(),
		])
	return "; ".join(parts)


func _wait_for_navigation(main: Node) -> void:
	var nav_region = main.get("_nav_region")
	if nav_region != null and nav_region.has_method("is_baking") and nav_region.is_baking():
		await nav_region.bake_finished


func _verify_navigation_mesh(main: Node) -> bool:
	var nav_region = main.get("_nav_region")
	var nav_mesh: NavigationMesh = nav_region.navigation_mesh if nav_region else null
	var polygon_count := nav_mesh.get_polygon_count() if nav_mesh else 0
	var vertex_count := nav_mesh.get_vertices().size() if nav_mesh else 0
	if polygon_count <= 0 or vertex_count <= 0:
		_fail("Traffic runtime found an empty navigation mesh: polygons=%d vertices=%d." % [
			polygon_count,
			vertex_count,
		])
		return false
	return true


func _cleanup(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
