extends SceneTree

const AUDIT = preload("res://tools/LootSearchAudit.gd")
class Sensor:
	extends "res://src/entities/Entity.gd"
	var ray_calls := 0
	var actual_physics := false
	var clear := true
	func _ready(): pass
	func _has_los_to_point(from: Vector3, to: Vector3) -> bool:
		ray_calls += 1
		return super._has_los_to_point(from, to) if actual_physics else clear

var failures: Array[String] = []

func _init():
	_run.call_deferred()

func _counts() -> Dictionary:
	var counts := {}
	for key in AUDIT.SENSING: counts[key] = 0
	return counts

func _check(ok: bool, message: String):
	if not ok: failures.append(message)

func _case(sensor: Sensor, pos: Vector3, reason: String, expected_rays: int):
	var counts := _counts()
	sensor.ray_calls = 0
	seed(93)
	var off := sensor.can_sense_item(pos)
	var off_random := randi()
	var rays := sensor.ray_calls
	sensor.ray_calls = 0
	seed(93)
	var on := sensor.can_sense_item(pos, counts)
	var context := "%s pos=%s counts=%s" % [reason, pos, counts]
	_check(on == off and on == (reason == "passed"), "Decision differs: " + context)
	_check(randi() == off_random and sensor.ray_calls == rays and rays == expected_rays, "RNG/ray count differs: " + context)
	var expected := _counts()
	expected[reason] = 1
	_check(counts == expected, "First-exit counters differ: " + context)

func _run():
	create_timer(8.0).timeout.connect(func(): quit(1))
	var sensor := Sensor.new()
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	sensor.add_child(ray)
	root.add_child(sensor)
	sensor.set_process(false)
	sensor.set_physics_process(false)
	_case(sensor, Vector3.ZERO, "no_stats", 0)
	sensor.stats = StatsData.new()
	sensor.stats.fov_near_range = 3.0
	sensor.stats.vision_range = 10.0
	sensor.stats.fov_angle = 90.0
	_case(sensor, Vector3(0, 0, -10.01), "far_range", 0)
	_case(sensor, Vector3(0, 0, -10), "passed", 1)
	_case(sensor, Vector3(0, 20, -2), "passed", 1) # Existing range is horizontal, not 3D.
	_case(sensor, Vector3(0, 0, 3), "passed", 1) # Near boundary bypasses FOV, not LOS.
	_case(sensor, Vector3(0, 0, 3.01), "fov", 0)
	_case(sensor, Vector3(3.99, 0, -4), "passed", 1)
	# Float32 diagonal normalization can put the nominal 45-degree edge just outside.
	# Preserve the existing strict comparison, not an idealized boundary/tolerance.
	var edge_angle := rad_to_deg(acos(Vector3.FORWARD.dot(Vector3(4, 0, -4).normalized())))
	_case(sensor, Vector3(4, 0, -4), "fov" if edge_angle > 45.0 else "passed", 0 if edge_angle > 45.0 else 1)
	_case(sensor, Vector3(4.01, 0, -4), "fov", 0)
	sensor.stats.fov_angle = 180.0
	_case(sensor, Vector3(5, 0, 0), "passed", 1) # Exact axis-aligned half-angle boundary.
	sensor.stats.fov_angle = 90.0
	sensor.clear = false
	_case(sensor, Vector3(0, 0, 2), "los", 1)
	_case(sensor, Vector3(0, 0, -5), "los", 1)
	_case(sensor, Vector3(0, 0, 5), "fov", 0) # First rejection never checks blocked LOS.
	sensor.rotation.x = PI / 2.0
	_case(sensor, Vector3(0, 0, -5), "degenerate_direction", 0)
	sensor.rotation = Vector3.ZERO
	sensor.actual_physics = true
	var blocker := StaticBody3D.new()
	blocker.collision_layer = sensor.ITEM_LOS_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.5)
	shape.shape = box
	blocker.add_child(shape)
	root.add_child(blocker)
	blocker.position = Vector3(0, 0.5, -2)
	await physics_frame
	await physics_frame
	_case(sensor, Vector3(0, 0, -5), "los", 1)
	blocker.position.x = 20
	await physics_frame
	await physics_frame
	_case(sensor, Vector3(0, 0, -5), "passed", 1)
	blocker.free()
	sensor.free()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
		return
	print("Loot sensing runtime passed: actual first exits, boundaries/near bypass, real LOS blocker, ON/OFF decision/RNG/ray parity.")
	quit(0)
