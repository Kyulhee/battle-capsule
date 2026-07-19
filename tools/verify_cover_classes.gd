extends SceneTree


const COVER_EXPECTATIONS := {
	"hard": {"position": Vector2(-12.0, 0.0), "layer": 1 | 8, "los": false, "ballistic": true},
	"screen": {"position": Vector2(0.0, 0.0), "layer": 1 | 16, "los": false, "ballistic": false},
	"soft": {"position": Vector2(12.0, 0.0), "layer": 1, "los": true, "ballistic": false},
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var spec = load("res://src/core/MapSpec.gd").new()
	spec.metadata = {"id": "cover_contract_probe", "world_size": 64.0}
	for obstacle in [
		{"type": "canyon_wall", "cover_class": "hard", "pos": [-12.0, 0.0], "scale": [1.0, 2.0, 2.0]},
		{"type": "tree_cluster", "cover_class": "screen", "pos": [0.0, 0.0], "scale": [1.0, 2.0, 2.0]},
		{"type": "log_pile", "cover_class": "soft", "pos": [12.0, 0.0], "scale": [1.0, 2.0, 2.0]},
	]:
		spec.obstacles.append(obstacle)

	var builder = load("res://src/maps/WorldBuilder.gd").new()
	root.add_child(builder)
	builder.generate_world(spec)
	await physics_frame

	var obstacles := {}
	for child in builder.find_children("*", "StaticBody3D", true, false):
		var cover_class := String(child.get_meta("cover_class", ""))
		if not cover_class.is_empty():
			obstacles[cover_class] = child
	for cover_class in COVER_EXPECTATIONS:
		if not obstacles.has(cover_class):
			_fail("Generated cover class is missing: %s." % cover_class)
			return
		var obstacle := obstacles[cover_class] as StaticBody3D
		var expected: Dictionary = COVER_EXPECTATIONS[cover_class]
		if obstacle.collision_layer != int(expected["layer"]):
			_fail("%s collision layer mismatch: %d." % [cover_class, obstacle.collision_layer])
			return
		if cover_class == "hard" and not obstacle.is_in_group("hard_cover"):
			_fail("Hard cover group is missing.")
			return
		if cover_class == "screen" and not obstacle.is_in_group("vision_screens"):
			_fail("Vision screen group is missing.")
			return

	var source = load("res://src/entities/Entity.gd").new()
	var target := Node3D.new()
	root.add_child(source)
	root.add_child(target)
	source.set_physics_process(false)

	for cover_class in COVER_EXPECTATIONS:
		var expected: Dictionary = COVER_EXPECTATIONS[cover_class]
		var x := float((expected["position"] as Vector2).x)
		source.global_position = Vector3(x, 0.0, -6.0)
		target.global_position = Vector3(x, 0.0, 6.0)
		await physics_frame
		if source.has_los_to(target) != bool(expected["los"]):
			_fail("%s perception LOS contract mismatch." % cover_class)
			return
		var ballistic_hit := _ray_hits(source, target, 8)
		if ballistic_hit != bool(expected["ballistic"]):
			_fail("%s ballistic contract mismatch." % cover_class)
			return

	print("Cover class smoke passed: hard blocks LOS+ballistics, screen blocks LOS, soft blocks movement only.")
	source.queue_free()
	target.queue_free()
	builder.queue_free()
	await process_frame
	quit(0)


func _ray_hits(source: CollisionObject3D, target: Node3D, mask: int) -> bool:
	var from := source.global_position + Vector3(0.0, 1.0, 0.0)
	var to := target.global_position + Vector3(0.0, 1.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.exclude = [source.get_rid()]
	return not source.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
