extends SceneTree


const APPROACH_POSITION := Vector2(0.0, 55.0)
const ZONE_CENTER := Vector2(22.4, -19.0)
const ZONE_RADIUS := 74.4
const PROBE_TIMEOUT_SECONDS := 8.0
const MAX_STUCK_RECOVERIES := 1


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
	if not _has_navigation_mesh(main):
		await _cleanup(main)
		_fail("Night nav hotspot runtime found an empty navigation mesh.")
		return
	var minimaps := main.find_children("Minimap", "Control", true, false)
	if minimaps.size() != 1:
		await _cleanup(main)
		_fail("Main runtime must have exactly one HUD-owned Minimap, got %d." % minimaps.size())
		return
	var minimap_colliders := minimaps[0].find_children(
		"*",
		"CollisionObject3D",
		true,
		false
	)
	if not minimap_colliders.is_empty():
		await _cleanup(main)
		_fail("Minimap subtree must not inject physics colliders into the world.")
		return
	main.start_game()

	var player: Entity = main.player_ref
	var bots := get_nodes_in_group("bots")
	if not is_instance_valid(player) or bots.size() != 1:
		await _cleanup(main)
		_fail("Night nav hotspot runtime must spawn one player and one bot.")
		return

	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector3(400.0, player.global_position.y, 400.0)
	var bot = bots[0]
	bot.global_position = Vector3(APPROACH_POSITION.x, bot.global_position.y, APPROACH_POSITION.y)
	bot.velocity = Vector3.ZERO
	bot.target_actor = null
	bot.is_targeting_loot = false
	main.zone.current_center = ZONE_CENTER
	main.zone.next_center = ZONE_CENTER
	main.zone.current_radius = ZONE_RADIUS
	main.zone.next_radius = ZONE_RADIUS
	main.zone.stage = 2
	main.zone.timer = 600.0
	main.zone.shrinking = false
	bot.change_state(bot.State.ZONE_ESCAPE)

	var telemetry = root.get_node_or_null("Telemetry")
	var initial_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else 0
	var elapsed := 0.0
	while elapsed < PROBE_TIMEOUT_SECONDS and bot.current_state == bot.State.ZONE_ESCAPE:
		await create_timer(0.05).timeout
		elapsed += 0.05

	var final_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else initial_stuck
	var stuck_delta := final_stuck - initial_stuck
	var final_position: Vector3 = bot.global_position
	var final_distance := Vector2(final_position.x, final_position.z).distance_to(ZONE_CENTER)
	var final_state := String(bot.State.keys()[bot.current_state])
	var path_snapshot := _path_snapshot(bot)
	var strategic_wait := 0.0
	while strategic_wait < 1.0 and bot.get("_strategic_destination").is_empty():
		await create_timer(0.05).timeout
		strategic_wait += 0.05
	var strategic_destination: Dictionary = bot.get("_strategic_destination").duplicate(true)
	await _cleanup(main)
	if final_state == "ZONE_ESCAPE":
		_fail("Night nav hotspot bot did not escape: elapsed=%.2fs stuck=%d pos=(%.1f,%.1f) zone_dist=%.1f %s." % [
			elapsed,
			stuck_delta,
			final_position.x,
			final_position.z,
			final_distance,
			path_snapshot,
		])
		return
	if stuck_delta > MAX_STUCK_RECOVERIES:
		_fail("Night nav hotspot bot exceeded stuck budget: stuck=%d pos=(%.1f,%.1f) %s." % [
			stuck_delta,
			final_position.x,
			final_position.z,
			path_snapshot,
		])
		return
	if strategic_destination.is_empty():
		_fail("Night nav hotspot bot escaped the zone but did not select a strategic POI destination.")
		return
	var strategic_role := String(strategic_destination.get("role", ""))
	if strategic_role not in ["loot_hub", "transit_choke", "recovery_pocket", "concealment_field"]:
		_fail("Night nav hotspot bot selected an invalid strategic role: %s." % strategic_role)
		return
	print("Night nav hotspot smoke passed: elapsed=%.2fs stuck=%d pos=(%.1f,%.1f) zone_dist=%.1f." % [
		elapsed,
		stuck_delta,
		final_position.x,
		final_position.z,
		final_distance,
	])
	quit(0)


func _path_snapshot(bot: Node) -> String:
	var nav_agent = bot.get("_nav_agent")
	var path: PackedVector3Array = nav_agent.get_current_navigation_path() if nav_agent else PackedVector3Array()
	var points: Array[String] = []
	for point_index in range(mini(path.size(), 4)):
		points.append("(%.1f,%.1f)" % [path[point_index].x, path[point_index].z])
	var collisions: Array[String] = []
	for slide_index in range(bot.get_slide_collision_count()):
		var collision = bot.get_slide_collision(slide_index)
		var collider = collision.get_collider()
		if collider is Node3D:
			collisions.append("%s@(%.1f,%.1f)" % [
				collider.get_path(),
				collider.global_position.x,
				collider.global_position.z,
			])
	return "path=%d/%d points=%s target=(%.1f,%.1f) collisions=%s" % [
		int(nav_agent.get_current_navigation_path_index()) if nav_agent else -1,
		path.size(),
		points,
		float(bot.get("_nav_target_position").x),
		float(bot.get("_nav_target_position").z),
		collisions,
	]


func _has_navigation_mesh(main: Node) -> bool:
	var nav_region = main.get("_nav_region")
	var nav_mesh: NavigationMesh = nav_region.navigation_mesh if nav_region else null
	return nav_mesh != null and nav_mesh.get_polygon_count() > 0 and nav_mesh.get_vertices().size() > 0


func _wait_for_navigation(main: Node) -> void:
	var nav_region = main.get("_nav_region")
	if nav_region != null and nav_region.has_method("is_baking") and nav_region.is_baking():
		await nav_region.bake_finished


func _cleanup(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
