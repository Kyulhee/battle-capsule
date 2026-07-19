extends SceneTree


const YARD_POSITION := Vector2(0.0, 99.0)
const ENTRY_POSITIONS := {
	"south": Vector2(0.0, 78.0),
	"west": Vector2(-32.0, 100.0),
	"east": Vector2(32.0, 98.0),
}
const MAX_ENDPOINT_SNAP_DISTANCE := 3.0
const MAX_PATH_DIRECT_RATIO := 1.8


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
		_fail("Cabin compound probe has no navigation map.")
		return

	var summaries: Array[String] = []
	for entry_id in ENTRY_POSITIONS:
		var entry_position: Vector2 = ENTRY_POSITIONS[entry_id]
		var start := NavigationServer3D.map_get_closest_point(
			map_rid,
			Vector3(entry_position.x, 0.0, entry_position.y)
		)
		var target := NavigationServer3D.map_get_closest_point(
			map_rid,
			Vector3(YARD_POSITION.x, 0.0, YARD_POSITION.y)
		)
		var entry_snap_distance := _flat(start).distance_to(entry_position)
		if entry_snap_distance > MAX_ENDPOINT_SNAP_DISTANCE:
			await _cleanup(main)
			_fail("Cabin Row %s entry is not represented on the NavMesh: requested=%s snapped=%s distance=%.1fm." % [
				entry_id,
				entry_position,
				_flat(start),
				entry_snap_distance,
			])
			return
		if _flat(target).distance_to(YARD_POSITION) > MAX_ENDPOINT_SNAP_DISTANCE:
			await _cleanup(main)
			_fail("Cabin Row yard is not represented on the NavMesh.")
			return
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			map_rid,
			start,
			target,
			true
		)
		if path.size() < 2:
			await _cleanup(main)
			_fail("Cabin Row %s entry has no path to the yard." % entry_id)
			return
		var path_length := _path_length(path)
		var direct_distance := maxf(0.1, start.distance_to(target))
		if path_length > direct_distance * MAX_PATH_DIRECT_RATIO:
			await _cleanup(main)
			_fail("Cabin Row %s entry detour is excessive: %.1fm / %.1fm." % [
				entry_id,
				path_length,
				direct_distance,
			])
			return
		summaries.append("%s=%.1fm" % [entry_id, path_length])

	await _cleanup(main)
	print("Cabin compound nav smoke passed: %s." % ", ".join(summaries))
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
