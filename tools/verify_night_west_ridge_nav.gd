extends SceneTree


const WATCH_POST_OBJECTIVE := Vector2(-59.0, 33.0)
const APPROACH_POSITIONS := {
	"road": Vector2(-74.0, 13.0),
	"forest_flank": Vector2(-68.0, 45.0),
}
const MAX_ENDPOINT_SNAP_DISTANCE := 3.0
const MAX_PATH_DIRECT_RATIO := 2.2


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

	var bots := get_nodes_in_group("bots")
	var nav_agent = bots[0].get("_nav_agent") if not bots.is_empty() else null
	var map_rid: RID = nav_agent.get_navigation_map() if nav_agent else RID()
	if not map_rid.is_valid():
		await _cleanup(main)
		_fail("West Ridge probe has no navigation map.")
		return

	var summaries: Array[String] = []
	for approach_id in APPROACH_POSITIONS:
		var approach_position: Vector2 = APPROACH_POSITIONS[approach_id]
		var start := NavigationServer3D.map_get_closest_point(
			map_rid,
			Vector3(approach_position.x, 0.0, approach_position.y)
		)
		var target := NavigationServer3D.map_get_closest_point(
			map_rid,
			Vector3(WATCH_POST_OBJECTIVE.x, 0.0, WATCH_POST_OBJECTIVE.y)
		)
		if _flat(start).distance_to(approach_position) > MAX_ENDPOINT_SNAP_DISTANCE:
			await _cleanup(main)
			_fail("West Ridge %s approach is not represented on the NavMesh." % approach_id)
			return
		if _flat(target).distance_to(WATCH_POST_OBJECTIVE) > MAX_ENDPOINT_SNAP_DISTANCE:
			await _cleanup(main)
			_fail("West Ridge objective is not represented on the NavMesh.")
			return
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			map_rid,
			start,
			target,
			true
		)
		if path.size() < 2:
			await _cleanup(main)
			_fail("West Ridge %s approach has no path to the watch post." % approach_id)
			return
		var path_length := _path_length(path)
		var direct_distance := maxf(0.1, start.distance_to(target))
		if path_length > direct_distance * MAX_PATH_DIRECT_RATIO:
			await _cleanup(main)
			_fail("West Ridge %s detour is excessive: %.1fm / %.1fm." % [
				approach_id,
				path_length,
				direct_distance,
			])
			return
		summaries.append("%s=%.1fm" % [approach_id, path_length])

	await _cleanup(main)
	print("West Ridge nav smoke passed: %s." % ", ".join(summaries))
	quit(0)


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
