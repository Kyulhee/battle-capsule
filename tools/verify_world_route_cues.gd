extends SceneTree


const MAP_PATH := "res://data/mapSpec_night_forest_candidate.json"
const REQUIRED_ROUTE_ROLES := {
	"primary_choke": 2,
	"flank": 2,
	"loot_flow": 1,
	"recovery_exit": 1,
}


func _init() -> void:
	var game_config = load("res://src/core/GameConfig.gd").new()
	game_config.load_or_default()
	var definition = load("res://src/core/MapDefinition.gd").new()
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null or not definition.load_from_json(file.get_as_text(), MAP_PATH, game_config):
		_fail("Could not load Night map for world route cue smoke.")
		return

	var builder = load("res://src/maps/WorldBuilder.gd").new()
	builder.generate_world(definition.map_spec, null)
	var descriptors: Array[Dictionary] = builder.get_route_cue_descriptors()
	if descriptors.is_empty():
		_fail("WorldBuilder produced no route cue descriptors.")
		return

	var route_ids := {}
	var role_ids := {}
	var cue_nodes := {}
	for descriptor in descriptors:
		var route_id := String(descriptor.get("route_id", ""))
		var role := String(descriptor.get("role", ""))
		var node = descriptor.get("node")
		if route_id.is_empty() or role.is_empty():
			_fail("Route cue descriptor is missing route identity.")
			return
		if not node is MultiMeshInstance3D:
			_fail("Route cue %s is not batched in a MultiMeshInstance3D." % route_id)
			return
		if node is CollisionObject3D or _contains_collision(node):
			_fail("Route cue %s introduced collision geometry." % route_id)
			return
		if node.is_in_group("obstacles") or node.is_in_group("occluder"):
			_fail("Route cue %s entered an obstacle group." % route_id)
			return
		if float(descriptor.get("width", 0.0)) > 0.4:
			_fail("Route cue %s is too wide for a guidance strip." % route_id)
			return
		var instance_transform: Transform3D = descriptor.get("instance_transform", Transform3D.IDENTITY)
		var expected_delta: Vector2 = descriptor["end"] - descriptor["start"]
		var expected_forward := Vector3(expected_delta.x, 0.0, expected_delta.y).normalized()
		var actual_forward: Vector3 = instance_transform.basis.z.normalized()
		if actual_forward.dot(expected_forward) < 0.999:
			_fail("Route cue %s alignment mismatch: expected=%s actual=%s." % [
				route_id,
				str(expected_forward),
				str(actual_forward),
			])
			return
		if not is_equal_approx(instance_transform.basis.x.length(), float(descriptor["width"])):
			_fail("Route cue %s width was distorted by its rotation." % route_id)
			return
		if not is_equal_approx(instance_transform.basis.z.length(), float(descriptor["length"])):
			_fail("Route cue %s length was distorted by its rotation." % route_id)
			return
		route_ids[route_id] = true
		cue_nodes[node.get_instance_id()] = true
		if not role_ids.has(role):
			role_ids[role] = {}
		role_ids[role][route_id] = true

	if route_ids.size() != 6:
		_fail("World route cues must cover all 6 routes; got %d." % route_ids.size())
		return
	if cue_nodes.size() > REQUIRED_ROUTE_ROLES.size():
		_fail("World route cues need at most one batch per role; got %d nodes." % cue_nodes.size())
		return
	for role in REQUIRED_ROUTE_ROLES:
		var actual := 0
		if role_ids.has(role):
			actual = role_ids[role].size()
		if actual != int(REQUIRED_ROUTE_ROLES[role]):
			_fail("World route role %s needs %d route ids; got %d." % [
				role,
				int(REQUIRED_ROUTE_ROLES[role]),
				actual,
			])
			return

	builder.free()
	print("World route cue smoke passed: cues=%d batches=%d routes=%d roles=%s." % [
		descriptors.size(),
		cue_nodes.size(),
		route_ids.size(),
		str(REQUIRED_ROUTE_ROLES),
	])
	quit(0)


func _contains_collision(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			return true
		if _contains_collision(child):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
